import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uz_ai_dev/core/data/local/app_storage.dart';
import 'package:uz_ai_dev/core/data/local/base_storage.dart';
import 'package:uz_ai_dev/core/data/local/shared_preferences_impl.dart';
import 'package:uz_ai_dev/core/data/local/token_storage.dart';
import 'package:uz_ai_dev/core/network/dio_settings.dart';

final GetIt sl = GetIt.instance;

Future<void> setupInit() async {
  /// Register Dio client
  final SharedPreferences pref = await SharedPreferences.getInstance();

  /// register local storage
  sl.registerLazySingleton<BaseStorage>(() => SharedPreferencesImpl(pref));
  sl.registerLazySingleton<TokenStorage>(() => TokenStorage(sl<BaseStorage>()));
  sl.registerLazySingleton<AppStorage>(() => AppStorage(sl<BaseStorage>()));

  final dioClient = AppDioClient(tokenStorage: sl<TokenStorage>());
  final dio = dioClient.createDio();
  sl.registerLazySingleton<Dio>(() => dio);
}
