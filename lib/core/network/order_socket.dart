import 'dart:async';
import 'dart:convert';

import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/data/local/token_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Server'dan kelgan bitta real-time buyurtma hodisasi.
// action: "created" | "priced" | "accepted" | "reverted" | "updated" | "deleted".
// order: GET /api/orders dagi element bilan AYNAN bir xil shakldagi Map.
class OrderSocketEvent {
  final String action;
  final Map<String, dynamic> order;

  const OrderSocketEvent({required this.action, required this.order});
}

// Buyurtmalar uchun yagona (singleton) WebSocket ulanishi.
// Ombor va Yuk provider'lari shu bitta ulanishga obuna bo'ladi; server
// relevance bo'yicha filtrlab yuborgani uchun client har bir order'ni
// ishonib upsert qiladi.
class OrderSocket {
  OrderSocket._();
  static final OrderSocket instance = OrderSocket._();

  final TokenStorage _tokenStorage = sl<TokenStorage>();

  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;

  // Eventlarni tarqatuvchi broadcast stream — bir nechta provider obuna bo'lishi mumkin.
  final StreamController<OrderSocketEvent> _controller =
      StreamController<OrderSocketEvent>.broadcast();

  Stream<OrderSocketEvent> get events => _controller.stream;

  // Foydalanuvchi (provider) connect chaqirganmi — reconnect faqat shunda davom etadi.
  bool _wantConnected = false;

  // Hozir ulanish jarayoni ketяptimi (ikki marta parallel ulanmaslik uchun).
  bool _connecting = false;

  // Auto-reconnect uchun backoff (1s, 2s, 4s ... max 15s).
  Duration _backoff = const Duration(seconds: 1);
  static const Duration _maxBackoff = Duration(seconds: 15);
  Timer? _reconnectTimer;

  // Ulanishni boshlash. Bir necha marta chaqirilsa ham bitta aktiv ulanish
  // bo'ladi (idempotent).
  Future<void> connect() async {
    _wantConnected = true;
    if (_channel != null || _connecting) return;
    await _openConnection();
  }

  Future<void> _openConnection() async {
    if (_connecting) return;
    _connecting = true;
    try {
      final token = await _tokenStorage.getToken();
      // Token bo'lmasa ulanmaymiz (login qilinmagan).
      if (token.isEmpty) {
        _connecting = false;
        return;
      }
      // Foydalanuvchi ulanmoqchi bo'lib turibdimi — connect orasida disconnect bo'lmasin.
      if (!_wantConnected) {
        _connecting = false;
        return;
      }

      final uri = Uri.parse('${AppUrls.wsOrders}?token=$token');
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      _channelSub = channel.stream.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );

      // Muvaffaqiyatli ulanish — backoff'ni qayta tiklaymiz.
      _backoff = const Duration(seconds: 1);
    } catch (_) {
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is! Map) return;
      if (decoded['type'] != 'order') return;
      final order = decoded['order'];
      if (order is! Map) return;
      final action = decoded['action']?.toString() ?? '';
      _controller.add(
        OrderSocketEvent(
          action: action,
          order: Map<String, dynamic>.from(order),
        ),
      );
    } catch (_) {
      // Noto'g'ri JSON kelса e'tiborsiz qoldiramiz — UI crash bo'lmasin.
    }
  }

  // Ulanish uzilganda backoff bilan qayta ulanishni rejalashtirish.
  void _scheduleReconnect() {
    _cleanupChannel();
    if (!_wantConnected) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_backoff, () {
      // Keyingi urinish uchun backoff'ni ikkilantiramiz (max 15s).
      final next = _backoff * 2;
      _backoff = next > _maxBackoff ? _maxBackoff : next;
      _openConnection();
    });
  }

  // Faol ulanishni va subscription'ni tozalash (controller'ga tegmaydi).
  void _cleanupChannel() {
    _channelSub?.cancel();
    _channelSub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  // Ulanishni butunlay uzish (logout yoki ekrandan chiqishda).
  void disconnect() {
    _wantConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _backoff = const Duration(seconds: 1);
    _cleanupChannel();
  }
}
