import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/auth/register_screen.dart';
import 'package:mkulimahub_mobile/features/home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>(); // For Validation
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiClient = ApiClient();
  bool _isLoading = false;

  void _handleLogin() async {
    // 1. Validate Input
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    // 2. Call API
    final error = await _apiClient.login(
      _phoneController.text.trim(), // Trim whitespace
      _passwordController.text.trim()
    );

    setState(() => _isLoading = false);

    if (error == null) {
      if (mounted) {
        // Go to Home and remove Login from "Back" history
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        // FIX #2: Scrollable view prevents "Bottom Overflow" when keyboard opens
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey, // FIX #5: Enable Validation
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.agriculture, size: 80, color: Colors.green),
                const SizedBox(height: 20),
                Text(
                  "Welcome Back",
                  style: GoogleFonts.poppins(
                    fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green[800]
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                
                // Phone Field with Validation
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: "Phone Number",
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter phone number';
                    // Regex for Kenyan Phone Numbers (Simple check: starts with 07 or 01, 10 digits)
                    if (!RegExp(r'^0(7|1)\d{8}$').hasMatch(value)) {
                      return 'Enter valid valid number (e.g., 0712...)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Password Field
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter password';
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Login", style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
                const SizedBox(height: 20),
                
                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("New Farmer? "),
                    GestureDetector(
                      onTap: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                      },
                      child: const Text("Create Account", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}