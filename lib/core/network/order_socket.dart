// core/network/order_socket.dart — real-time WebSocket (OrderSocket singleton):
// buyurtma / targovli-pul / ishlab-chiqarish hodisalarini alohida stream'larga
// tarqatadi (OrderSocketEvent / TransferSocketEvent / ProductionSocketEvent);
// ref-count + auto-reconnect backoff. Ombor/Yuk provider'lari obuna bo'ladi.
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

// Targovli tizimidan kelgan pul bo'yicha real-time hodisa.
// action: "created" | "updated" | "deleted".
// transfer: GET /api/yuk/transfers dagi element bilan bir xil shakldagi Map.
class TransferSocketEvent {
  final String action;
  final Map<String, dynamic> transfer;

  const TransferSocketEvent({required this.action, required this.transfer});
}

// Ishlab chiqarish (production) buyurtmasi bo'yicha real-time hodisa.
// Shef/ombor ekranlari shu hodisada ro'yxatni jim yangilaydi.
class ProductionSocketEvent {
  final String action;

  const ProductionSocketEvent({required this.action});
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

  // Targovli pul hodisalari — alohida stream (buyurtma oqimini buzmaslik uchun).
  final StreamController<TransferSocketEvent> _transferController =
      StreamController<TransferSocketEvent>.broadcast();

  Stream<TransferSocketEvent> get transferEvents => _transferController.stream;

  // Ishlab chiqarish hodisalari — alohida stream (shef ekrani obuna bo'ladi).
  final StreamController<ProductionSocketEvent> _productionController =
      StreamController<ProductionSocketEvent>.broadcast();

  Stream<ProductionSocketEvent> get productionEvents =>
      _productionController.stream;

  // Foydalanuvchi (provider) connect chaqirganmi — reconnect faqat shunda davom etadi.
  bool _wantConnected = false;

  // Nechta ekran/provider ulanishni ushlab turibdi (reference count).
  // Bitta ekran yopilganda boshqa ochiq ekranlarning real-time oqimi
  // uzilib qolmasligi uchun ulanish faqat OXIRGI disconnect'da yopiladi.
  int _refs = 0;

  // Hozir ulanish jarayoni ketяptimi (ikki marta parallel ulanmaslik uchun).
  bool _connecting = false;

  // Auto-reconnect uchun backoff (1s, 2s, 4s ... max 15s).
  Duration _backoff = const Duration(seconds: 1);
  static const Duration _maxBackoff = Duration(seconds: 15);
  Timer? _reconnectTimer;

  // Ulanishni boshlash. Bir necha marta chaqirilsa ham bitta aktiv ulanish
  // bo'ladi (idempotent). Har bir connect() mos disconnect() bilan
  // juftlanishi kerak (provider'lar buni _socketSub orqali kafolatlaydi).
  Future<void> connect() async {
    _refs++;
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

      // qty=milli — yangi klient belgisi: broadcast'lar gram tilida kelsin
      // (belgisiz ulanishga server kg/l ga o'girib yuboradi, legacy_qty.go).
      final uri = Uri.parse('${AppUrls.wsOrders}?token=$token&qty=milli');
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
      final action = decoded['action']?.toString() ?? '';
      // Targovli tizimidan kelgan pul hodisasi — alohida stream'ga.
      if (decoded['type'] == 'targovli_transfer') {
        final transfer = decoded['transfer'];
        if (transfer is! Map) return;
        _transferController.add(
          TransferSocketEvent(
            action: action,
            transfer: Map<String, dynamic>.from(transfer),
          ),
        );
        return;
      }
      // Ishlab chiqarish hodisasi — obunachilar ro'yxatni o'zi qayta oladi
      // (payload shakli muhim emas, faqat signal).
      if (decoded['type'] == 'production' || action == 'production') {
        _productionController.add(ProductionSocketEvent(action: action));
        return;
      }
      if (decoded['type'] != 'order') return;
      final order = decoded['order'];
      if (order is! Map) return;
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

  // Bitta obunachi ulanishni qo'yib yubordi (ekrandan chiqish yoki logout).
  // Ulanish faqat boshqa hech kim ushlab turmaganda YOPILADI — aks holda
  // ochiq qolgan ekranlarning real-time oqimi davom etadi.
  void disconnect() {
    if (_refs > 0) _refs--;
    if (_refs > 0) return;
    _wantConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _backoff = const Duration(seconds: 1);
    _cleanupChannel();
  }
}
