// core/network/error_handler.dart — parseDioError(): DioException'ni o'qiladigan
// xato matniga aylantiradi (javob body'sidagi message/error, aks holda tarmoq xatosi).
import 'package:dio/dio.dart';

/// DioException ni o'qiladigan xato matniga aylantiradi.
///
/// Server javobi bo'lsa, javob tanasidagi `message` yoki `error` maydonini
/// qaytaradi (ikkalasi ham bo'lmasa [fallback]). Aks holda tarmoq xatosi
/// matnini qaytaradi.
String parseDioError(DioException e, {String fallback = 'Noma\'lum server xatosi'}) {
  if (e.response != null) {
    // Javob tanasi har doim Map bo'lmaydi: bo'sh body, nginx HTML 5xx sahifasi
    // yoki List kelishi mumkin — u holda ['message'] o'qish o'zi crash qilardi.
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message'] ?? data['error'];
      if (msg != null) return msg.toString();
    }
    return fallback;
  }
  return 'Tarmoq xatosi: ${e.message}';
}
