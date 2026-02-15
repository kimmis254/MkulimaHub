import 'package:flutter/material.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/auth/login_screen.dart';
import 'package:mkulimahub_mobile/features/home/home_screen.dart';

void main() {
  runApp(const MkulimaHubApp());
}

class MkulimaHubApp extends StatelessWidget {
  const MkulimaHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ApiClient apiClient = ApiClient();

    return MaterialApp(
      title: 'MkulimaHub',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        // Standard input styling for the whole app
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
      // LOGIC: Check for token on startup
      home: FutureBuilder<String?>(
        future: apiClient.getToken(),
        builder: (context, snapshot) {
          // 1. While checking, show a blank loading screen
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          // 2. If token exists, go to Home. If not, Login.
          if (snapshot.hasData && snapshot.data != null) {
            return const HomeScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}