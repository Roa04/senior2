import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/bottom_nav_shell.dart';
import 'services/user_data_service.dart';
import 'models/models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Offline cache: on by default on Android/iOS; explicit so it also works on web.
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  runApp(const ThromboGuardApp());
}

class ThromboGuardApp extends StatelessWidget {
  const ThromboGuardApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ThromboGuard',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}

/// Decides the first screen on every app start / page reload.
/// Firebase restores the saved session on its own (web: IndexedDB), so we wait
/// for that, then route: no user -> Login, user without profile -> Onboarding,
/// user with profile -> main app.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<Widget> _target = _resolve();

  Future<Widget> _resolve() async {
    // First event of authStateChanges fires only after the saved session is restored.
    final user = await FirebaseAuth.instance.authStateChanges().first;
    if (user == null) return const LoginScreen();
    final PatientProfile? profile = await UserDataService.loadProfile();
    return profile == null ? const OnboardingScreen() : BottomNavShell(profile: profile);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _target,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          // Signed in but profile could not be loaded (e.g. offline): retry, don't kick to login.
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load your profile. Check your connection.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(() => _target = _resolve()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        return snap.data!;
      },
    );
  }
}