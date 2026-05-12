// These Firebase options were generated from the platform config files
// `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`.
// Re-run `flutterfire configure` from the project root whenever the linked
// Firebase project changes or a new platform target is added.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web. '
        'Run `flutterfire configure` with web enabled to support it.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for $defaultTargetPlatform. '
          'Re-run `flutterfire configure` to add this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA9oR4JQN1SVes9CeefLzY6a-C8VzJex3k',
    appId: '1:742057440870:android:ee8d9ef378fef17cecdfa7',
    messagingSenderId: '742057440870',
    projectId: 'tugas-ppb-3',
    storageBucket: 'tugas-ppb-3.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDzjs2mno0JGMCIJDuAdIR7dlgo2QZVLDk',
    appId: '1:742057440870:ios:e2f4c6ed91d93cabecdfa7',
    messagingSenderId: '742057440870',
    projectId: 'tugas-ppb-3',
    storageBucket: 'tugas-ppb-3.firebasestorage.app',
    iosBundleId: 'com.muizfata.tugasppb3',
  );

}