// core/data/local/base_storage.dart — lokal saqlash abstraksiyasi (BaseStorage):
// putString/getString/remove interfeysi (implementatsiya SharedPreferencesImpl).
abstract class BaseStorage {
  Future<void> putString({required String key, required String value});
  String getString({required String key});
  Future<void> remove({required String key});
}
