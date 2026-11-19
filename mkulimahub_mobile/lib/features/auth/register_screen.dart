import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api/api_client.dart';
import 'package:mkulimahub_mobile/features/home/home_screen.dart';
import 'package:mkulimahub_mobile/features/home/profile_screen.dart';
import 'package:mkulimahub_mobile/features/auth/auth_service.dart';
import 'package:mkulimahub_mobile/features/auth/otp_verification_screen.dart';
import 'package:mkulimahub_mobile/features/auth/google_phone_link_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _apiClient = ApiClient();
  final _authService = AuthService();
  
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  // 🔥 Password Rules
  bool _hasMinLength = false;
  bool _hasNumber = false;
  bool _passwordsMatch = true;

  Future<Position?> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) _showCustomSnackBar("GPS is off. Using default location.", isError: true);
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) _showCustomSnackBar("Location denied. Using default.", isError: true);
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 10));
    } catch (e) {
      if (mounted) _showCustomSnackBar("GPS timeout. Using default location.", isError: true);
      return null;
    }
  }

  void _showCustomSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? LucideIcons.alertCircle : LucideIcons.checkCircle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: GoogleFonts.poppins(fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 6,
      ),
    );
  }

  void _updatePasswordStatus(String value) {
    setState(() {
      _hasMinLength = value.length >= 6;
      _hasNumber = RegExp(r'\d').hasMatch(value);
      _passwordsMatch = value == _confirmPasswordController.text;
    });
  }

  void _handleRegister() async {
    if (!_hasMinLength || !_hasNumber) {
      _showCustomSnackBar("Password is too weak. Check the guidelines.", isError: true);
      return;
    }
    
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final position = await _determinePosition();
    if (position == null) {
      setState(() => _isLoading = false);
      return; 
    }

    final userData = {
      "full_name": _nameController.text.trim(),
      "phone_number": _phoneController.text.trim(),
      "password": _passwordController.text.trim(),
      "role": "farmer",
      "latitude": position.latitude,
      "longitude": position.longitude
    };

    String formattedPhone = _phoneController.text.trim();
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '+254${formattedPhone.substring(1)}';
    } else if (!formattedPhone.startsWith('+')) {
      formattedPhone = '+254$formattedPhone'; 
    }

    await _authService.sendPhoneOTP(
      phoneNumber: formattedPhone,
      onCodeSent: (verificationId) {
        setState(() => _isLoading = false);
        if (mounted) {
           Navigator.push(context, MaterialPageRoute(builder: (_) => OtpVerificationScreen(verificationId: verificationId, phoneNumber: formattedPhone, pendingRegistrationData: userData)));
        }
      },
      onError: (errorMsg) {
        setState(() => _isLoading = false);
        if (mounted) _showCustomSnackBar(errorMsg, isError: true);
      }
    );
  }

  void _handleGoogleSignIn() async {
   setState(() => _isGoogleLoading = true);
    final result = await _authService.signInWithGoogle();

    if (result != null) {
      final userCredential = result['firebase_user'] as UserCredential;
      final String? idToken = result['google_token'];
      
      if (idToken == null) {
        setState(() => _isGoogleLoading = false);
        if (mounted) _showCustomSnackBar('Failed to retrieve secure Google Token.', isError: true);
        return;
      }

      final apiStatus = await _apiClient.googleLogin(idToken: idToken);
      setState(() => _isGoogleLoading = false);

      if (apiStatus == 'success') {
        if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
      } else if (apiStatus == 'needs_profile') {
        if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const ProfileScreen(isNewUser: true)), (route) => false);
      } else if (apiStatus == 'needs_phone') {
        if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => GooglePhoneLinkScreen(idToken: idToken, name: userCredential.user!.displayName ?? 'Farmer')));
      } else {
        if (mounted) _showCustomSnackBar(apiStatus ?? 'Authentication failed.', isError: true);
      }
    } else {
      setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: CustomScrollView(
          slivers: [
            // 🔥 PREMIUM FARMER HEADER
            SliverToBoxAdapter(
              child: Container(
                height: 280, width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.green.shade900, Colors.green.shade600]),
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(icon: const Icon(LucideIcons.arrowLeft, color: Colors.white), padding: EdgeInsets.zero, alignment: Alignment.centerLeft, onPressed: () => Navigator.pop(context)),
                        const Spacer(),
                        FadeInUp(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(15)), child: const Icon(LucideIcons.sprout, color: Colors.white, size: 30))),
                        const SizedBox(height: 15),
                        FadeInUp(delay: const Duration(milliseconds: 100), child: Text("Farmer Account", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26))),
                        FadeInUp(delay: const Duration(milliseconds: 200), child: Text("Join hubs, secure contracts, and grow.", style: GoogleFonts.poppins(color: Colors.green.shade100, fontSize: 14))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            SliverPadding(
              padding: const EdgeInsets.all(24.0),
              sliver: SliverToBoxAdapter(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeInUp(delay: const Duration(milliseconds: 300), child: Text("Personal Details", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
                      const SizedBox(height: 20),
                      
                      FadeInUp(
                        delay: const Duration(milliseconds: 400),
                        child: _buildModernField(controller: _nameController, label: "Full Name", icon: LucideIcons.user, hint: "e.g. John Kamau", validator: (v) => (v == null || v.trim().split(' ').length < 2) ? "Please enter at least two names" : null),
                      ),
                      const SizedBox(height: 20),
                      
                      FadeInUp(
                        delay: const Duration(milliseconds: 500),
                        child: _buildModernField(controller: _phoneController, label: "Phone Number", icon: LucideIcons.phone, hint: "e.g. 0712345678", inputType: TextInputType.phone, validator: (v) => (!RegExp(r'^(07|01)\d{8}$').hasMatch(v ?? '')) ? "Must be 10 digits (e.g. 07...)" : null),
                      ),
                      const SizedBox(height: 20),
                      
                      FadeInUp(
                        delay: const Duration(milliseconds: 600),
                        child: _buildModernField(controller: _passwordController, label: "Secure Password", icon: LucideIcons.lock, hint: "••••••••", isPassword: true, onChanged: _updatePasswordStatus),
                      ),
                      
                      // 🔥 PASSWORD CHECKLIST
                      Padding(
                        padding: const EdgeInsets.only(top: 10, left: 10, bottom: 20),
                        child: Row(
                          children: [
                            _buildGuideline("6+ Chars", _hasMinLength), const SizedBox(width: 15), _buildGuideline("1 Number", _hasNumber),
                          ],
                        ),
                      ),

                      FadeInUp(
                        delay: const Duration(milliseconds: 650),
                        child: _buildModernField(
                          controller: _confirmPasswordController, label: "Confirm Password", icon: LucideIcons.checkCircle, hint: "••••••••", isPassword: true,
                          onChanged: (val) => setState(() => _passwordsMatch = val == _passwordController.text),
                          validator: (v) => v != _passwordController.text ? "Passwords do not match" : null,
                        ),
                      ),
                      if (_confirmPasswordController.text.isNotEmpty && !_passwordsMatch)
                        Padding(
                          padding: const EdgeInsets.only(top: 5, left: 10),
                          child: Row(children: [const Icon(Icons.error_outline, size: 14, color: Colors.redAccent), const SizedBox(width: 5), Text("Passwords don't match", style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 12))]),
                        ),
                      
                      const SizedBox(height: 40),
                      
                      FadeInUp(
                        delay: const Duration(milliseconds: 700),
                        child: SizedBox(
                          height: 60, width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_isLoading || _isGoogleLoading) ? null : _handleRegister,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 5, shadowColor: Colors.green.shade900.withOpacity(0.4)),
                            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text("Create Account", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      FadeInUp(
                        delay: const Duration(milliseconds: 750),
                        child: Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1.5)),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text("or sign up with", style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 12))),
                            Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 🔥 GOOGLE BUTTON
                      FadeInUp(
                        delay: const Duration(milliseconds: 800),
                        child: SizedBox(
                          height: 55, width: double.infinity,
                          child: OutlinedButton(
                            onPressed: (_isLoading || _isGoogleLoading) ? null : _handleGoogleSignIn,
                            style: OutlinedButton.styleFrom(backgroundColor: Colors.white, side: BorderSide(color: Colors.grey.shade300, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            child: _isGoogleLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.green, strokeWidth: 2))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.network('https://img.icons8.com/color/48/000000/google-logo.png', height: 24),
                                      const SizedBox(width: 12),
                                      Text("Google", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      FadeInUp(
                        delay: const Duration(milliseconds: 850),
                        child: Center(
                          child: Text(
                            "GPS access is required for AI-powered hub matching.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGuideline(String text, bool met) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: met ? Colors.green.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: met ? Colors.green : Colors.grey.shade300)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(met ? Icons.check : Icons.circle_outlined, size: 14, color: met ? Colors.green.shade700 : Colors.grey),
          const SizedBox(width: 5),
          Text(text, style: GoogleFonts.poppins(fontSize: 11, color: met ? Colors.green.shade800 : Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildModernField({required TextEditingController controller, required String label, required IconData icon, String? hint, bool isPassword = false, TextInputType inputType = TextInputType.text, String? Function(String?)? validator, void Function(String)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller, obscureText: isPassword && _obscurePassword, keyboardType: inputType, onChanged: onChanged, style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500), validator: validator,
          decoration: InputDecoration(
            hintText: hint, hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13), prefixIcon: Icon(icon, color: Colors.green.shade600, size: 20),
            suffixIcon: isPassword ? IconButton(icon: Icon(_obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff, color: Colors.grey.shade500, size: 20), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)) : null,
            filled: true, fillColor: Colors.grey.shade50, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.green.shade600, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
          ),
        ),
      ],
    );
  }
}