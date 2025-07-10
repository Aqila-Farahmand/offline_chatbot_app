import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/chat_screen.dart';
import 'services/app_state.dart';
import 'services/model_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Listen for authentication state changes and print the user UID when available.
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user != null) {
      debugPrint('Signed-in user UID: ${user.uid}');
    }
  });
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
        title: 'MedicoAI',
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
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // While Firebase is still figuring out who the user is, show a loader
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // If we have a logged-in user => go straight to chat
            if (snapshot.hasData) {
              return const ChatScreen();
            }

            // Otherwise, show the sign-in / sign-up form
            return const LoginScreen();
          },
        ),
      ),
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
    final providerId = providerProfile.providerId; // e.g. google.com
    final uid = providerProfile.uid; // provider-specific UID
    final name = providerProfile.displayName; // may be null
    final email = providerProfile.email; // may be null
    debugPrint('[$providerId] uid=$uid  name=$name  email=$email');
  }
}
