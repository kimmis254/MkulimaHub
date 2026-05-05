import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'package:firebase_core/firebase_core.dart'; 
import 'firebase_options.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; // 🔥 Added for Onboarding check

import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/auth/welcome_screen.dart';
import 'package:mkulimahub_mobile/features/home/home_screen.dart';
import 'package:mkulimahub_mobile/features/buyer/buyer_dashboard.dart';
import 'package:mkulimahub_mobile/features/onboarding/splash_screen.dart'; // 🔥 Added Splash Screen

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  
  await dotenv.load(fileName: ".env"); 
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MkulimaHubApp());
}

Future<Widget> _getInitialScreen(ApiClient apiClient) async {
  // 🔥 1. Check if it's the absolute first time the app is opened
  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

  if (!hasSeenOnboarding) {
    // Mark it as seen so they never have to watch it again!
    await prefs.setBool('has_seen_onboarding', true);
    return const SplashScreen(); // Start the Splash -> Onboarding flow
  }

  // 🔥 2. Not their first time. Check if they are logged in.
  final token = await apiClient.getToken();

  if (token == null || token.isEmpty) {
    return const WelcomeScreen(); // Logged out -> Send to Front Door
  }

  // 🔥 3. Instantly read the cached role from the phone
  final role = await apiClient.getUserRole();
  
  if (role == 'buyer') {
    return const BuyerDashboard(); // 🏢 Route to Customer
  } 
  
  // 🔥 4. Default to Farmer Dashboard
  return const HomeScreen(); // 🚜 Route to Farmer
}

class MkulimaHubApp extends StatelessWidget {
  const MkulimaHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ApiClient apiClient = ApiClient();

    return MaterialApp(
      title: 'MkulimaHub',
      debugShowCheckedModeBanner: false, 
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
      home: FutureBuilder<Widget>(
        future: _getInitialScreen(apiClient), 
        builder: (context, snapshot) {
          // While deciding where to send them, show a blank white screen 
          // (so it doesn't flash weird colors before the splash screen loads)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF0A192F), // Matches your splash screen background
              body: Center(
                child: CircularProgressIndicator(color: Colors.green)
              )
            );
          }
          
          // Once the decision is made, snap to that screen!
          return snapshot.data ?? const WelcomeScreen(); 
        },
      ),
    );
  }
}