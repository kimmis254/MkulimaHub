import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/auth/register_screen.dart';
import 'package:mkulimahub_mobile/features/home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiClient = ApiClient();
  bool _isLoading = false;

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final error = await _apiClient.login(
      _phoneController.text.trim(),
      _passwordController.text.trim()
    );

    setState(() => _isLoading = false);

    if (error == null) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Consistent light background
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Animated Header
                FadeInDown(
                  duration: const Duration(milliseconds: 600),
                  child: Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(LucideIcons.sprout, size: 60, color: Colors.green[700]),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                
                FadeInDown(
                  delay: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      Text(
                        "Welcome Back!",
                        style: GoogleFonts.poppins(
                          fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Sign in to access your farm dashboard.",
                        style: GoogleFonts.poppins(color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                
                // 2. Form Fields (Staggered)
                FadeInUp(
                  delay: const Duration(milliseconds: 300),
                  child: Column(
                    children: [
                      _buildModernField(
                        controller: _phoneController,
                        label: "Phone Number",
                        icon: LucideIcons.phone,
                        inputType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (!RegExp(r'^0(7|1)\d{8}$').hasMatch(value)) return 'Invalid format (e.g., 0712...)';
                          return null;
                        }
                      ),
                      const SizedBox(height: 20),
                      
                      _buildModernField(
                        controller: _passwordController,
                        label: "Password",
                        icon: LucideIcons.lock,
                        isPassword: true,
                        validator: (value) => value!.isEmpty ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                
                // 3. Login Button
                FadeInUp(
                  delay: const Duration(milliseconds: 400),
                  child: SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[800],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                        shadowColor: Colors.green.withOpacity(0.4),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Log In", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(width: 10),
                              const Icon(LucideIcons.arrowRight, color: Colors.white, size: 20),
                            ],
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                
                // 4. Register Link
                FadeInUp(
                  delay: const Duration(milliseconds: 500),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("New Farmer? ", style: GoogleFonts.poppins(color: Colors.grey[600])),
                      GestureDetector(
                        onTap: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                        },
                        child: Text(
                          "Create Account", 
                          style: GoogleFonts.poppins(color: Colors.green[700], fontWeight: FontWeight.bold)
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper Widget for Clean Fields
  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: inputType,
        style: GoogleFonts.poppins(fontSize: 14),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
          prefixIcon: Icon(icon, color: Colors.green[700], size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}