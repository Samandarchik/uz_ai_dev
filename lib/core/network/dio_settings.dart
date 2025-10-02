import 'package:dio/dio.dart';
import 'package:talker_dio_logger/talker_dio_logger_interceptor.dart';
import 'package:talker_dio_logger/talker_dio_logger_settings.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/network/print.dart';
import '../data/local/token_storage.dart';

class AppDioClient {
  final TokenStorage tokenStorage;

  AppDioClient({required this.tokenStorage});

  Dio createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: AppUrls.baseUrl,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
            'Authorization'
            'Bearer ${tokenStorage.getToken()}'
      },
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // Logger interceptor qo'shish
    dio.interceptors.add(TalkerDioLogger(
      settings: const TalkerDioLoggerSettings(
        enabled: true,
        printErrorHeaders: true,
        printRequestData: true,
        printErrorData: true,
        printErrorMessage: true,
        printRequestHeaders: true,
        printResponseData: true,
        printResponseHeaders: true,
        printResponseMessage: true,
        printResponseRedirects: true,
      ),
    ));

    // Auth token interceptor qo'shish
    dio.interceptors.add(AppInterceptors(dio, tokenStorage));

    return dio;
  }
}

class AppInterceptors extends QueuedInterceptorsWrapper {
  final Dio dio;
  final TokenStorage tokenStorage;

  AppInterceptors(this.dio, this.tokenStorage);

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final token = await tokenStorage.getToken();
      if (token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      pPrint('Request: ${options.uri}', 1);
      handler.next(options);
    } catch (error) {
      pPrint('Request interceptor error: $error', 4);
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          message: 'Error in request interceptor',
        ),
      );
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    pPrint('Response: ${response.data}', 2);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    pPrint('onError: ${err.message}', 4);

    // Token muddati tugagan bo'lsa, yangilash logikasi
    if (_isTokenExpiredError(err)) {
      try {
        final updatedRequest =
            await _refreshTokenAndUpdateRequest(err.requestOptions);
        // Token yangilangandan so'ng, so'rovni qayta yuborish
        final response = await dio.fetch(updatedRequest);
        return handler.resolve(response);
      } catch (refreshError) {
        // Token yangilash muvaffaqiyatsiz bo'lsa, xatoni qaytarish
        pPrint('Token refresh failed: $refreshError', 4);
        return handler.next(err);
      }
    }

    // Boshqa Ошибкаlar uchun xatoni uzatish
    return handler.next(err);
  }

  /// Token muddati tugagan xatoni tekshirish
  bool _isTokenExpiredError(DioException err) {
    return err.response?.statusCode == 401 || err.response?.statusCode == 403;
  }

  /// Token yangilash va so'rovni yangilangan token bilan yangilash
  Future<RequestOptions> _refreshTokenAndUpdateRequest(
      RequestOptions requestOptions) async {
    try {
      // Refresh token olish
      final refreshToken = await tokenStorage.getRefreshToken();

      if (refreshToken.isEmpty) {
        throw Exception('Refresh token not available');
      }

      // Refresh token endpoint ga so'rov yuborish
      final refreshDio = dio.clone(
          options: BaseOptions(
        baseUrl: AppUrls.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));

      final refreshResponse = await refreshDio.post(
        AppUrls.refresh,
        data: {"refreshToken": refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (refreshResponse.statusCode == 200) {
        // Yangi token va refresh tokenlarni Сохранять
        final accessToken = refreshResponse.data['token'];
        final newRefreshToken = refreshResponse.data['refreshToken'];

        await tokenStorage.putToken(accessToken);
        await tokenStorage.putRefreshToken(newRefreshToken);

        pPrint('Token refreshed successfully', 2);

        // So'rovni yangilangan token bilan yangilash
        final updatedRequestOptions = requestOptions;
        updatedRequestOptions.headers['Authorization'] = 'Bearer $accessToken';

        return updatedRequestOptions;
      } else {
        throw Exception(
            'Failed to refresh token: ${refreshResponse.statusCode}');
      }
    } catch (error) {
      pPrint('Error refreshing token: $error', 4);
      throw error;
    }
  }
}

/*
class AppInterceptors extends QueuedInterceptorsWrapper {
  final Dio dio;
  final TokenStorage tokenStorage;

  AppInterceptors(this.dio, this.tokenStorage);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await tokenStorage.getToken();
    if (token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    pPrint('Request: ${options.uri}', 1);
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    pPrint('Response: ${response.data}', 2);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    pPrint('onError: ${err.message}', 4);
    handler.next(err);
  }
}*/
