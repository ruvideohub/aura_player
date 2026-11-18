import 'package:shared_preferences/shared_preferences.dart';

class VkTokenStorage {
  static const _key = 'vk_music_token';
  static const _uidKey = 'vk_music_uid';
  static const _exKey = 'vk_exchange_token';
  final SharedPreferences prefs;
  VkTokenStorage(this.prefs);
  String? get token => prefs.getString(_key);
  int? get uid => prefs.getInt(_uidKey);
  String? get exchangeToken => prefs.getString(_exKey);
  Future<void> save(String token, int uid) async {
    await prefs.setString(_key, token);
    await prefs.setInt(_uidKey, uid);
  }
  Future<void> saveExchange(String ex) async => prefs.setString(_exKey, ex);
  Future<void> clear() async {
    await prefs.remove(_key);
    await prefs.remove(_uidKey);
    await prefs.remove(_exKey);
  }
  bool get isAuthorized => token != null && token!.isNotEmpty;
}
