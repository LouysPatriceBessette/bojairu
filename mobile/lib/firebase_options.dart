// ignore_for_file: lines_longer_than_80_chars
//
// Android options match `android/app/google-services.json` (Firebase project
// `bojairu`). Regenerate with `flutterfire configure` after adding .dev /
// .staging / iOS apps in the Console.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_WEB_API_KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'compartarenta-placeholder',
    authDomain: 'compartarenta-placeholder.firebaseapp.com',
    storageBucket: 'compartarenta-placeholder.appspot.com',
  );

  // From Firebase project `bojairu`. Default Dart options target the **dev**
  // Android app (matches `run:dev` / flavor `dev`). Native plugin still
  // selects the matching client from google-services.json per applicationId.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCkmsxmA4QWul3msv1it0TvjY3vyusYdZU',
    appId: '1:333095166523:android:01aa74954ac09983efb21e',
    messagingSenderId: '333095166523',
    projectId: 'bojairu',
    storageBucket: 'bojairu.firebasestorage.app',
  );
  // iOS app not registered yet in project `bojairu` — update via flutterfire
  // configure after adding bundle IDs in the Console.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_API_KEY',
    appId: '1:333095166523:ios:0000000000000000000000',
    messagingSenderId: '333095166523',
    projectId: 'bojairu',
    storageBucket: 'bojairu.firebasestorage.app',
    iosBundleId: 'app.incoherences.bojairu',
  );
  static const FirebaseOptions macos = ios;

  /// True while [firebase_options.dart] / `google-services.json` still ship
  /// template values. FCM registration is skipped until `flutterfire configure`.
  static bool get isPlaceholder =>
      currentPlatform.apiKey.startsWith('REPLACE_WITH');
}
