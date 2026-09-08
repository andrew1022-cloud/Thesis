import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/auth_screen.dart';
import 'services/notification_service.dart';

/// App-wide theme mode, toggled from the Profile screen's Dark Mode
/// button. Kept as a simple ValueNotifier (rather than threading
/// state through every screen) — resets to light on app restart.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Sets up the local-notification plugin and device timezone data.
  // Actual scheduling/permission requests happen later, once a user
  // is signed in and lands on Home (see HomeController).
  await NotificationService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'RevEduc',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          home: const AuthScreen(),
        );
      },
    );
  }
}

// ── Brand colors (stay consistent across both themes) ─────────────
const Color _maroon = Color(0xFF6E1B24);
const Color _gold = Color(0xFFC9A24B);

final ThemeData _lightTheme = ThemeData(
  brightness: Brightness.light,
  fontFamily: 'Roboto',
  scaffoldBackgroundColor: const Color(0xFFF5EDE3),
  cardColor: Colors.white,
  dividerColor: Colors.grey.shade300,
  colorScheme: const ColorScheme.light(
    primary: _maroon,
    secondary: _gold,
    surface: Colors.white,
    onSurface: Colors.black87,
    background: Color(0xFFF5EDE3),
    onBackground: Colors.black87,
  ),
  textTheme: ThemeData.light().textTheme.apply(
        bodyColor: Colors.black87,
        displayColor: Colors.black87,
      ),
  iconTheme: const IconThemeData(color: Colors.black87),
);

final ThemeData _darkTheme = ThemeData(
  brightness: Brightness.dark,
  fontFamily: 'Roboto',
  scaffoldBackgroundColor: const Color(0xFF1A1210),
  cardColor: const Color(0xFF2A211D),
  dividerColor: const Color(0xFF3D322C),
  colorScheme: const ColorScheme.dark(
    primary: _maroon,
    secondary: _gold,
    surface: Color(0xFF2A211D),
    onSurface: Colors.white,
    background: Color(0xFF1A1210),
    onBackground: Colors.white,
  ),
  textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
  iconTheme: const IconThemeData(color: Colors.white),
);
