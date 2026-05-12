import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[main] binding initialized');

  try {
    await dotenv.load(fileName: '.env');
    debugPrint('[main] dotenv loaded');
  } catch (e, st) {
    debugPrint('[main] dotenv FAILED: $e\n$st');
  }

  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('[main] Firebase initialized');
  } catch (e, st) {
    debugPrint('[main] Firebase FAILED: $e\n$st');
  }

  debugPrint('[main] runApp');
  runApp(const PersonalBuddyApp());
}

class PersonalBuddyApp extends StatelessWidget {
  const PersonalBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Personal Buddy',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const AuthGate(),
      ),
    );
  }
}
