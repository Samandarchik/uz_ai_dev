import 'base_storage.dart';

final class TokenStorage {
  static const String _token = 'token';
  static const String _refreshToken = 'refresh_token';

  final BaseStorage _baseStorage;

  TokenStorage(this._baseStorage);

  Future<String> getToken() async {
    return _baseStorage.getString(key: _token);
  }

  Future<void> removeToken() async {
    await _baseStorage.remove(key: _token);
  }

  Future<void> removeRefreshToken() async {
    await _baseStorage.remove(key: _refreshToken);
  }
}
