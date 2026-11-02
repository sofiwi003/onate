import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Firebase está comprobando si existe una sesión.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('No se pudo comprobar la sesión.')),
          );
        }

        // Si hay una sesión, muestra tu Home de música.
        if (snapshot.hasData) {
          return const HomeScreen();
        }

        // Si no hay sesión, muestra el inicio de sesión.
        return const LoginScreen();
      },
    );
  }
}
