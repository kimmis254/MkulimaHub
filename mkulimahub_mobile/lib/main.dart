import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 🔥 Import dotenv
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/auth/login_screen.dart';
import 'package:mkulimahub_mobile/features/home/home_screen.dart';

// 🔥 Change main to async to load environment variables first
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required for async main
  await dotenv.load(fileName: ".env"); // Load the variables
  runApp(const MkulimaHubApp());
}

class MkulimaHubApp extends StatelessWidget {
  const MkulimaHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ApiClient apiClient = ApiClient();

    return MaterialApp(
      title: 'MkulimaHub',
      debugShowCheckedModeBanner: false, // Cleaner production look
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
      home: FutureBuilder<String?>(
        future: apiClient.getToken(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
          }
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