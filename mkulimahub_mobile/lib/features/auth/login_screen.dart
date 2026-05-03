import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/home/home_screen.dart';
import 'package:mkulimahub_mobile/features/auth/auth_service.dart';
import 'package:mkulimahub_mobile/features/home/profile_screen.dart';
import 'package:mkulimahub_mobile/features/auth/otp_verification_screen.dart';
import 'package:mkulimahub_mobile/features/auth/google_phone_link_screen.dart'; 
import 'package:mkulimahub_mobile/features/buyer/buyer_dashboard.dart';
import 'package:mkulimahub_mobile/features/auth/welcome_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  bool _isResettingPassword = false;
  bool _obscurePassword = true; // 🔥 Added for password toggle

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final rawPhone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    // 🔥 Format the phone number FIRST
    String formattedPhone = rawPhone;
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '+254${formattedPhone.substring(1)}';
    } else if (!formattedPhone.startsWith('+')) {
      formattedPhone = '+254$formattedPhone';
    }

    // 🔥 1. Use the full login function to get the token immediately!
    // (Bypassing the forced SMS OTP for standard password logins)
    final error = await _apiClient.login(formattedPhone, password);

    if (error == null) {
      // 🔥 2. Fetch their profile to see if they are a Farmer or a Corporate Buyer
      final profileData = await _apiClient.getProfile();
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        String role = profileData?['role'] ?? 'farmer';
        await _apiClient.saveUserRole(role); 
        
        // 🔥 3. Route them perfectly based on their role!
        if (role == 'buyer') {
          Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (_) => const BuyerDashboard()), 
            (route) => false
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (_) => const HomeScreen()), 
            (route) => false
          );
        }
      }
    } else {
      // Password was wrong or network error
      setState(() => _isLoading = false);
      if (mounted) _showError(error);
    }
  }

  void _handleForgotPassword() async {
    final phone = _phoneController.text.trim();
    
    if (!RegExp(r'^0(7|1)\d{8}$').hasMatch(phone) && !phone.startsWith('+254')) {
      _showError("Please enter your registered phone number above first.");
      return;
    }

    setState(() => _isResettingPassword = true);

    String formattedPhone = phone;
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '+254${formattedPhone.substring(1)}';
    } else if (!formattedPhone.startsWith('+')) {
      formattedPhone = '+254$formattedPhone';
    }

    // Trigger Firebase SMS for Password Reset
    await _authService.sendPhoneOTP(
      phoneNumber: formattedPhone,
      onCodeSent: (verificationId) {
        setState(() => _isResettingPassword = false);
        if (mounted) {
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                verificationId: verificationId,
                phoneNumber: formattedPhone,
                isPasswordReset: true, 
              )
            )
          );
        }
      },
      onError: (errorMsg) {
        setState(() => _isResettingPassword = false);
        if (mounted) _showError(errorMsg);
      }
    );
  }

  // Google Sign-In Logic
  void _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    
    // 🔥 1. Call the updated service
    final result = await _authService.signInWithGoogle();

    if (result != null) {
      final userCredential = result['firebase_user'] as UserCredential;
      
      // 🔥 2. Grab the raw Google Token from the Map!
      final String? idToken = result['google_token'];
      
      if (idToken == null) {
        setState(() => _isGoogleLoading = false);
        // Use _showCustomSnackBar for register_screen and _showError for login_screen
        if (mounted) _showError('Failed to retrieve secure Google Token.');
        return;
      }

      // 🔥 3. Send the RAW Google token to FastAPI
      final apiStatus = await _apiClient.googleLogin(idToken: idToken);

      if (apiStatus == 'success') {
        final profileData = await _apiClient.getProfile();
        setState(() => _isGoogleLoading = false);

        if (mounted) {
          String role = profileData?['role'] ?? 'farmer';
          await _apiClient.saveUserRole(role); 
          
          if (role == 'buyer') {
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const BuyerDashboard()), (route) => false);
          } else {
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
          }
        }
      } else if (apiStatus == 'needs_profile') {
        setState(() => _isGoogleLoading = false);
        if (mounted) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const ProfileScreen(isNewUser: true)), (route) => false);
        }
      } else if (apiStatus == 'needs_phone') {
        setState(() => _isGoogleLoading = false);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GooglePhoneLinkScreen(
                idToken: idToken,
                name: userCredential.user!.displayName ?? 'Farmer',
              )
            )
          );
        }
      } else {
        setState(() => _isGoogleLoading = false);
        if (mounted) _showError(apiStatus ?? 'Authentication failed.');
      }
    } else {
      setState(() => _isGoogleLoading = false);
      if (mounted) _showError('Google Sign-In failed or was cancelled.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)), 
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Stack(
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.45,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade900, Colors.green.shade600],
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
                      FadeInDown(
                        duration: const Duration(milliseconds: 600),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)
                          ),
                          child: const Icon(LucideIcons.sprout, size: 55, color: Colors.white),
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
                      const SizedBox(height: 35),

                      FadeInUp(
                        delay: const Duration(milliseconds: 300),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 25, offset: const Offset(0, 10)),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  "Welcome Back",
                                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Log in to access your dashboard",
                                  style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 35),

                                _buildModernField(
                                  controller: _phoneController,
                                  label: "Phone Number",
                                  icon: LucideIcons.phone,
                                  inputType: TextInputType.phone,
                                  hint: "07XX XXX XXX",
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Required';
                                    if (!RegExp(r'^0(7|1)\d{8}$').hasMatch(value) && !value.startsWith('+254')) {
                                      return 'Invalid format (e.g., 07...)';
                                    }
                                    return null;
                                  }
                                ),
                                const SizedBox(height: 20),
                                
                                _buildModernField(
                                  controller: _passwordController,
                                  label: "Password",
                                  icon: LucideIcons.lock,
                                  isPassword: true,
                                  hint: "••••••••",
                                  validator: (value) => value!.isEmpty ? 'Required' : null,
                                ),
                                
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: (_isLoading || _isGoogleLoading || _isResettingPassword) ? null : _handleForgotPassword,
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                                    child: _isResettingPassword 
                                      ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(color: Colors.green, strokeWidth: 2))
                                      : Text(
                                          "Forgot Password?", 
                                          style: GoogleFonts.poppins(color: Colors.green.shade700, fontSize: 13, fontWeight: FontWeight.w600)
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 15),

                                // 🔥 PRIMARY LOGIN BUTTON
                                SizedBox(
                                  height: 55,
                                  child: ElevatedButton(
                                    onPressed: (_isLoading || _isGoogleLoading || _isResettingPassword) ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 0,
                                    ),
                                    child: _isLoading 
                                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                      : Text("Log In", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1.5)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text("or continue with", style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w500)),
                                    ),
                                    Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1.5)),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // 🔥 GOOGLE BUTTON
                                SizedBox(
                                  height: 55,
                                  child: OutlinedButton(
                                    onPressed: (_isLoading || _isGoogleLoading || _isResettingPassword) ? null : _handleGoogleSignIn,
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
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
                      
                      // 🔥 ELEGANT SECONDARY BUTTON FOR REGISTRATION
                      FadeInUp(
                        delay: const Duration(milliseconds: 400),
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()));
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
                            elevation: 2,
                            shadowColor: Colors.black.withOpacity(0.1)
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Don't have an account? ", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
                              Text(
                                "Create one here", 
                                style: GoogleFonts.poppins(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 13)
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
          ],
        ),
      ),
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword && _obscurePassword,
          keyboardType: inputType,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(icon, color: Colors.green.shade600, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(_obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff, color: Colors.grey.shade500, size: 20),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  )
                : null,
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.green.shade600, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}