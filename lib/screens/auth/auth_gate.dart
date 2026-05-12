import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, User;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/camera_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/grammar_provider.dart';
import '../../providers/profile_provider.dart';
import '../home/home_shell.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final initialUser = FirebaseAuth.instance.currentUser;
    debugPrint('[AuthGate] build, currentUser=${initialUser?.uid ?? "null"}');
    return StreamBuilder<User?>(
      stream: auth.authState,
      initialData: initialUser,
      builder: (context, snap) {
        debugPrint(
            '[AuthGate] connection=${snap.connectionState} user=${snap.data?.uid ?? "null"}');
        final user = snap.data;
        if (user == null) {
          return const LoginScreen();
        }
        return MultiProvider(
          key: ValueKey(user.uid),
          providers: [
            ChangeNotifierProvider(create: (_) => ProfileProvider(user.uid)),
            ChangeNotifierProvider(create: (_) => ChatProvider(uid: user.uid)),
            ChangeNotifierProvider(create: (_) => GrammarProvider()),
            ChangeNotifierProvider(create: (_) => CameraProvider()),
          ],
          child: const _SignedInRouter(),
        );
      },
    );
  }
}

class _SignedInRouter extends StatelessWidget {
  const _SignedInRouter();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    debugPrint(
        '[SignedInRouter] profile=${profile.profile?.uid ?? "null"} err=${profile.bootstrapError}');
    if (profile.profile == null) {
      if (profile.bootstrapError != null) {
        return _ProfileErrorScreen(error: profile.bootstrapError!);
      }
      return const _Splash(label: 'Setting things up…');
    }
    return const HomeShell();
  }
}

class _ProfileErrorScreen extends StatelessWidget {
  const _ProfileErrorScreen({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text("Can't reach Firestore",
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.read<ProfileProvider>().retry(),
                child: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => context.read<AuthProvider>().signOut(),
                child: const Text('Sign out'),
              ),
              const SizedBox(height: 16),
              const Text(
                'If this keeps happening, make sure Firestore is enabled in '
                'the Firebase console.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({this.label});
  final String? label;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (label != null) ...[
                const SizedBox(height: 16),
                Text(label!),
              ],
            ],
          ),
        ),
      );
}
