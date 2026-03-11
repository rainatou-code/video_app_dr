import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'login_page.dart';
import 'home_page.dart';

void main() async {
  // 1. Indispensable pour Firebase
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyBF_pl1aP40NxswpoyCxXq0Zu1L-uYXo98",
          authDomain: "video-app-diallo.firebaseapp.com",
          projectId: "video-app-diallo",
          storageBucket: "video-app-diallo.firebasestorage.app",
          messagingSenderId: "600353512470",
          appId: "1:600353512470:web:0d33338f8646e06c072937",
        ),
      );
    } else {
      // Pour Android, utilise le fichier google-services.json automatiquement
      await Firebase.initializeApp();
    }
    debugPrint("Firebase initialisé avec succès !");
  } catch (e) {
    debugPrint("Erreur d'initialisation Firebase : $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Video App',
      // Utilisation d'un thème plus moderne pour UTS
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Pendant le chargement de l'état de connexion
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Si l'utilisateur est connecté -> Home
        if (snapshot.hasData && snapshot.data != null) {
          return const HomePage();
        }

        // Sinon -> Login
        return const LoginPage();
      },
    );
  }
}