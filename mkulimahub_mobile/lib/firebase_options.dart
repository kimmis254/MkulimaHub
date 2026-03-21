
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;


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
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDi0J77p3IYRb1CP-j5vM6rHtTSoupqV_0',
    appId: '1:654543955611:web:71808ec88badf3243e883e',
    messagingSenderId: '654543955611',
    projectId: 'mkulimahub-b4341',
    authDomain: 'mkulimahub-b4341.firebaseapp.com',
    storageBucket: 'mkulimahub-b4341.firebasestorage.app',
    measurementId: 'G-KPC6LS93HT',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC5L7qeGlO8Hf4myhVzY2vy0m1_HMX_5u4',
    appId: '1:654543955611:android:40db2c8c9ceaa2913e883e',
    messagingSenderId: '654543955611',
    projectId: 'mkulimahub-b4341',
    storageBucket: 'mkulimahub-b4341.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC-iSsJy8WjquoYqu0h_0JLHYz0Y-XtAfk',
    appId: '1:654543955611:ios:f8f8a27a1c053f7b3e883e',
    messagingSenderId: '654543955611',
    projectId: 'mkulimahub-b4341',
    storageBucket: 'mkulimahub-b4341.firebasestorage.app',
    iosBundleId: 'com.example.mkulimahubMobile',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyC-iSsJy8WjquoYqu0h_0JLHYz0Y-XtAfk',
    appId: '1:654543955611:ios:f8f8a27a1c053f7b3e883e',
    messagingSenderId: '654543955611',
    projectId: 'mkulimahub-b4341',
    storageBucket: 'mkulimahub-b4341.firebasestorage.app',
    iosBundleId: 'com.example.mkulimahubMobile',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDi0J77p3IYRb1CP-j5vM6rHtTSoupqV_0',
    appId: '1:654543955611:web:26c02f4342e7140f3e883e',
    messagingSenderId: '654543955611',
    projectId: 'mkulimahub-b4341',
    authDomain: 'mkulimahub-b4341.firebaseapp.com',
    storageBucket: 'mkulimahub-b4341.firebasestorage.app',
    measurementId: 'G-H6KERT6VWT',
  );
}
