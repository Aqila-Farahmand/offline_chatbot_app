import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/chat_screen.dart';
import 'services/app_state.dart';
import 'services/model_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/admin_logs_screen.dart';
import 'config/app_constants.dart';
import 'config/firebase_config.dart';
import 'utils/chat_history_remote_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with timeout to prevent blocking when offline
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(Duration(seconds: AppConstants.firebaseInitTimeoutSeconds));

    // Enable offline persistence for chat history logging
    // This allows writes to be queued when offline and synced automatically
    ChatHistoryRemoteLogger.enableOfflinePersistence().catchError(
      (e) => debugPrint('Failed to enable offline persistence: $e'),
    );

    // Configure Firebase to use emulators when running locally (web only)
    if (kIsWeb && kDebugMode) {
      try {
        // Check if we're running on localhost (emulator scenario)
        final host = Uri.base.host;
        if (FirebaseConfig.isEmulatorEnvironment(host)) {
          debugPrint('Configuring Firebase to use emulators...');
          FirebaseFirestore.instance.useFirestoreEmulator(
            AppConstants.firestoreEmulatorHost,
            AppConstants.firestoreEmulatorPort,
          );
          // Note: Auth emulator is typically auto-detected, but you can configure it explicitly if needed
          debugPrint(
            'Firestore emulator configured: ${AppConstants.firestoreEmulatorHost}:${AppConstants.firestoreEmulatorPort}',
          );
          // Prevent persistent auto-login on localhost by using session-only persistence
          try {
            await FirebaseAuth.instance.setPersistence(
              FirebaseConfig.emulatorAuthPersistence,
            );
            // Ensure no previously persisted user is auto-restored
            if (FirebaseAuth.instance.currentUser != null) {
              await FirebaseAuth.instance.signOut();
            }
            debugPrint(
              'Auth persistence set to SESSION and signed out on localhost.',
            );
          } catch (e) {
            debugPrint('Error setting web auth persistence: $e');
          }
        }
      } catch (e) {
        debugPrint(
          'Error configuring emulators (may already be configured): $e',
        );
      }
    }
  } on TimeoutException {
    debugPrint('Firebase initialization timeout - continuing offline');
    // Continue app startup even if Firebase times out
  } catch (e) {
    debugPrint('Firebase initialization error: $e - continuing offline');
    // Continue app startup even if Firebase fails
  }

  // Listen for authentication state changes and print the user UID when available.
  // This won't block if Firebase isn't initialized
  try {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        debugPrint('Signed-in user UID: ${user.uid}');
      }
    });
  } catch (e) {
    debugPrint('Firebase Auth listener error: $e - continuing offline');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ModelManager()),
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: MaterialApp(
        title: AppConstants.appTitle,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/launch': (context) => _MainAppRouter(),
          '/settings': (context) => const SettingsScreen(),
          '/admin/logs': (context) => const AdminLogsScreen(),
        },
      ),
    );
  }
}

class _MainAppRouter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Firebase Auth caches authentication state locally, so authStateChanges()
    // works offline and emits immediately with cached state.
    // Only login/signup operations require internet connection.
    Stream<User?> authStream;
    try {
      authStream = FirebaseAuth.instance.authStateChanges();
    } catch (e) {
      debugPrint('Firebase Auth error: $e - checking cached user');
      // If auth stream fails, check for cached currentUser
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        return const ChatScreen();
      }
      return const LoginScreen();
    }

    // Use currentUser as initial data to show cached auth state immediately
    // This allows offline access for already-authenticated users
    return StreamBuilder<User?>(
      stream: authStream,
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        // Show loading only briefly while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // If user is authenticated (from cache or stream), show chat screen
        if (snapshot.hasData || snapshot.data != null) {
          return const ChatScreen();
        }
        // Otherwise show login screen (user needs to login/signup which requires internet)
        return const LoginScreen();
      },
    );
  }
}

class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Important Disclaimer',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                'MedicoAI is not a substitute for professional medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'This is an offline AI assistant that provides general health information. In case of emergency, contact emergency services immediately.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const ChatScreen()),
                  );
                },
                child: const Text('I Understand'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void printProviderProfiles() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return; // not signed in

  for (final providerProfile in user.providerData) {
    final providerId = providerProfile.providerId;
    final uid = providerProfile.uid;
    final name = providerProfile.displayName;
    final email = providerProfile.email;
    debugPrint('[$providerId] uid=$uid  name=$name  email=$email');
  }
}
