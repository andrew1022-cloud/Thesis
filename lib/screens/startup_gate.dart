import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/remember_me_service.dart';
import 'admin_screen.dart';
import 'auth_screen.dart';
import 'home_screen.dart';

/// First screen shown at launch. Decides where to go:
///  - signed in + "Remember Me" saved  -> Admin dashboard or Home
///  - signed in but NOT remembered     -> sign out, show login
///  - nobody signed in                 -> login
///
/// Works offline: the admin check falls back to the last known value.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  static const Color _maroon = Color(0xFF6E1B24);

  late final Future<Widget> _destination = _decide();

  Future<Widget> _decide() async {
    try {
      // Waits for Firebase to restore any saved session.
      final user = await FirebaseAuth.instance.authStateChanges().first;
      if (user == null) return const AuthScreen();

      final remembered = await RememberMeService.instance.isRemembered();
      if (!remembered) {
        await FirebaseAuth.instance.signOut();
        return const AuthScreen();
      }

      final isAdmin = await _resolveIsAdmin(user.uid);
      return isAdmin ? const AdminScreen() : const HomeScreen();
    } catch (e) {
      debugPrint('StartupGate: failed to decide start screen: $e');
      return const AuthScreen();
    }
  }

  /// Ask Firestore first (so revoked admins are caught when online);
  /// if that fails or times out (offline), use the saved value.
  Future<bool> _resolveIsAdmin(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 4));
      final isAdmin = doc.exists;
      await RememberMeService.instance.save(remember: true, isAdmin: isAdmin);
      return isAdmin;
    } catch (_) {
      return RememberMeService.instance.wasAdmin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _destination,
      builder: (context, snapshot) {
        if (snapshot.hasData) return snapshot.data!;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: const Center(
            child: CircularProgressIndicator(color: _maroon),
          ),
        );
      },
    );
  }
}
