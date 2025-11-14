// File generated from .firebase.configs
// WARNING: This file contains REAL Firebase API keys and credentials
// DO NOT edit manually - changes will be overwritten
// Regenerate with: ./scripts/load_env_and_setup.sh
// ignore_for_file: type=lint
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
          'you can reconfigure this by running the setup script again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAjTzxOYGdAtg4dm4g4nlxjurlQgpntCSg',
    appId: '1:436937306861:web:a2b31ca2c099c9065752e4',
    messagingSenderId: '436937306861',
    projectId: 'medicoai-65160',
    authDomain: 'medicoai-65160.firebaseapp.com',
    storageBucket: 'medicoai-65160.firebasestorage.app',
    measurementId: 'G-STCDF6C7EH',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBC20RMhT7HUQ9JUheWLouWNKOVEpk_gbg',
    appId: '1:436937306861:android:cf85ca7fe1d649e85752e4',
    messagingSenderId: '436937306861',
    projectId: 'medicoai-65160',
    storageBucket: 'medicoai-65160.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA4iJVPeDceMSDYeZKk07P-Yb9MXxEGXlw',
    appId: '1:436937306861:ios:2c799a1e82ed8c5d5752e4',
    messagingSenderId: '436937306861',
    projectId: 'medicoai-65160',
    storageBucket: 'medicoai-65160.firebasestorage.app',
    iosBundleId: 'it.aqila.farahmand.medicoai.ios',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA4iJVPeDceMSDYeZKk07P-Yb9MXxEGXlw',
    appId: '1:436937306861:ios:288a256b6a7d3a285752e4',
    messagingSenderId: '436937306861',
    projectId: 'medicoai-65160',
    storageBucket: 'medicoai-65160.firebasestorage.app',
    iosBundleId: 'it.aqila.farahmand.medicoai.macos',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAjTzxOYGdAtg4dm4g4nlxjurlQgpntCSg',
    appId: '1:436937306861:web:a2b31ca2c099c9065752e4',
    messagingSenderId: '436937306861',
    projectId: 'medicoai-65160',
    authDomain: 'medicoai-65160.firebaseapp.com',
    storageBucket: 'medicoai-65160.firebasestorage.app',
    measurementId: 'G-STCDF6C7EH',
  );
}
