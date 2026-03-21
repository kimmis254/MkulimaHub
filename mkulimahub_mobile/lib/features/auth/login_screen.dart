import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/auth/register_screen.dart';
import 'package:mkulimahub_mobile/features/home/home_screen.dart';
import 'package:mkulimahub_mobile/features/auth/auth_service.dart';
import 'package:mkulimahub_mobile/features/home/profile_screen.dart'; 

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
  final _authService = AuthService(); 
  
  bool _isLoading = false;
  bool _isGoogleLoading = false; 

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
      if (mounted) _showError(error);
    }
  }

  // 🔥 Updated Google Sign-In Logic to sync with your Database
  void _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    
    // 1. Authenticate securely with Firebase
    final userCredential = await _authService.signInWithGoogle();

    if (userCredential != null && userCredential.user != null) {
      // 2. Send the Google User's details to YOUR backend database
      final error = await _apiClient.googleLogin(
        email: userCredential.user!.email ?? '',
        name: userCredential.user!.displayName ?? 'Farmer',
        uid: userCredential.user!.uid, 
      );

      setState(() => _isGoogleLoading = false);

      if (error == null) {
        // 🎉 Existing user in DB, token received! Go to Home.
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false
          );
        }
      } else if (error == 'needs_profile') {
        // 🔥 THE FIX: Route them directly to the Profile Screen!
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (_) => const ProfileScreen(isNewUser: true)),
            (route) => false
          );
        }
      } else {
        if (mounted) _showError(error);
      }
    } else {
      setState(() => _isGoogleLoading = false);
      if (mounted) _showError('Google Sign-In failed or was cancelled.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()), 
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 New Premium UI using a Stack and Gradients
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient Header
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade900, Colors.green.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 1. Header Icon & Text (Now White to pop on the green background)
                    FadeInDown(
                      duration: const Duration(milliseconds: 600),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.sprout, size: 50, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeInDown(
                      delay: const Duration(milliseconds: 200),
                      child: Text(
                        "MkulimaHub",
                        style: GoogleFonts.poppins(
                          fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // 2. The Main Form Floating Card
                    FadeInUp(
                      delay: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                "Welcome Back",
                                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black87),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Log in to access your farm dashboard",
                                style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 30),

                              // Form Fields
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
                              
                              // Forgot Password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {}, // TODO: Implement Forgot Password
                                  child: Text("Forgot Password?", style: GoogleFonts.poppins(color: Colors.green.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Login Button
                              SizedBox(
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: (_isLoading || _isGoogleLoading) ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  child: _isLoading 
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : Text("Log In", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Divider OR
                              Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.grey[200], thickness: 1.5)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text("or continue with", style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12)),
                                  ),
                                  Expanded(child: Divider(color: Colors.grey[200], thickness: 1.5)),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Google Sign-In Button
                              SizedBox(
                                height: 55,
                                child: OutlinedButton(
                                  onPressed: (_isLoading || _isGoogleLoading) ? null : _handleGoogleSignIn,
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade50,
                                    side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: _isGoogleLoading
                                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.green, strokeWidth: 2))
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Image.network(
                                              'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                                              height: 22,
                                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 30, color: Colors.black87),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              "Google",
                                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Register Link at the bottom
                    FadeInUp(
                      delay: const Duration(milliseconds: 400),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("New to MkulimaHub? ", style: GoogleFonts.poppins(color: Colors.black54)),
                          GestureDetector(
                            onTap: () {
                               Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                            },
                            child: Text(
                              "Create Account", 
                              style: GoogleFonts.poppins(color: Colors.green.shade800, fontWeight: FontWeight.bold)
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
        ],
      ),
    );
  }

  // Refined Helper Widget for Cleaner Fields
  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: inputType,
      style: GoogleFonts.poppins(fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade600, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}