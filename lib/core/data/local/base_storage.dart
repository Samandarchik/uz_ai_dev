abstract class BaseStorage {
  Future<void> putString({required String key, required String value});
  String getString({required String key});
  Future<void> remove({required String key});
}
