// core/data/local/shared_preferences_impl.dart — BaseStorage'ning SharedPreferences
// implementatsiyasi (SharedPreferencesImpl): key-value string saqlash.
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uz_ai_dev/core/data/local/base_storage.dart';

final class SharedPreferencesImpl implements BaseStorage {
  final SharedPreferences _pref;

  SharedPreferencesImpl(this._pref);

  @override
  Future<void> putString({required String key, required String value}) async {
    await _pref.setString(key, value);
  }

  @override
  String getString({required String key}) {
    return _pref.getString(key) ?? '';
  }

  @override
  Future<void> remove({required String key}) async {
    await _pref.remove(key);
  }
}
