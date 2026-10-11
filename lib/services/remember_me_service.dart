import 'package:shared_preferences/shared_preferences.dart';

/// RememberMeService
/// -----------------
/// Stores whether the user ticked "Remember Me" at login (and whether
/// that account was an admin), so the app can skip the login screen on
/// the next launch.
///
/// Firebase Auth already keeps the signed-in session on the device;
/// this flag only decides whether StartupGate should honour it.
class RememberMeService {
  RememberMeService._internal();
  static final RememberMeService instance = RememberMeService._internal();

  static const String _kRemember = 'remember_me';
  static const String _kIsAdmin = 'remember_is_admin';

  /// Call after every successful sign-in.
  Future<void> save({required bool remember, required bool isAdmin}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRemember, remember);
    await prefs.setBool(_kIsAdmin, isAdmin);
  }

  Future<bool> isRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kRemember) ?? false;
  }

  /// Last known admin status — used as a fallback when the app starts
  /// offline and `admins/{uid}` can't be read.
  Future<bool> wasAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIsAdmin) ?? false;
  }

  /// Call on logout.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRemember);
    await prefs.remove(_kIsAdmin);
  }
}
