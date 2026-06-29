import 'package:dio/dio.dart';

/// DioException ni o'qiladigan xato matniga aylantiradi.
///
/// Server javobi bo'lsa, javob tanasidagi `message` yoki `error` maydonini
/// qaytaradi (ikkalasi ham bo'lmasa [fallback]). Aks holda tarmoq xatosi
/// matnini qaytaradi.
String parseDioError(DioException e, {String fallback = 'Noma\'lum server xatosi'}) {
  if (e.response != null) {
    return e.response?.data['message'] ?? e.response?.data['error'] ?? fallback;
  }
  return 'Tarmoq xatosi: ${e.message}';
}
