import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api/api_client.dart';
import 'package:mkulimahub_mobile/features/auth/auth_service.dart';
import 'package:mkulimahub_mobile/features/auth/otp_verification_screen.dart';
import 'package:mkulimahub_mobile/features/buyer/buyer_dashboard.dart';
import 'package:mkulimahub_mobile/features/buyer/customer_profile_screen.dart';
import 'package:mkulimahub_mobile/features/auth/google_phone_link_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BuyerRegistrationScreen extends StatefulWidget {
  const BuyerRegistrationScreen({super.key});

  @override
  State<BuyerRegistrationScreen> createState() => _BuyerRegistrationScreenState();
}

class _BuyerRegistrationScreenState extends State<BuyerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService(); 
  
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  // 🔥 Password Rules
  bool _hasMinLength = false;
  bool _hasNumber = false;
  bool _passwordsMatch = true;

  void _updatePasswordStatus(String value) {
    setState(() {
      _hasMinLength = value.length >= 6;
      _hasNumber = RegExp(r'\d').hasMatch(value);
      _passwordsMatch = value == _confirmPasswordController.text;
    });
  }

  void _registerCompany() async {
    if (!_hasMinLength || !_hasNumber) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password is too weak."), backgroundColor: Colors.red));
      return;
    }
    
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    String phone = _phoneController.text.trim();
    if (phone.startsWith('0')) {
      phone = '+254${phone.substring(1)}';
    } else if (!phone.startsWith('+')) {
      phone = '+254$phone';
    }

    await _authService.sendPhoneOTP(
      phoneNumber: phone,
      onCodeSent: (verificationId) {
        setState(() => _isLoading = false);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                verificationId: verificationId,
                phoneNumber: phone,
                pendingRegistrationData: {
                  'full_name': _companyController.text.trim(),
                  'phone_number': phone,
                  'password': _passwordController.text,
                  'role': 'buyer' 
                },
              ),
            ),
          );
        }
      },
      onError: (errorMsg) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
        }
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to retrieve secure Google Token.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
        return;
      }

      final apiStatus = await _apiClient.googleLogin(idToken: idToken, overrideRole: "buyer");

      setState(() => _isGoogleLoading = false);

      if (apiStatus == 'success') {
        if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const BuyerDashboard()), (route) => false);
      } else if (apiStatus == 'needs_profile') {
        if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const CustomerProfileScreen(isNewUser: true)), (route) => false);
      } else if (apiStatus == 'needs_phone') {
        if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => GooglePhoneLinkScreen(idToken: idToken, name: userCredential.user!.displayName ?? 'Customer', overrideRole: "buyer")));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiStatus ?? 'Authentication failed.'), backgroundColor: Colors.red));
      }
    } else {
      setState(() => _isGoogleLoading = false);
    }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: CustomScrollView(
          slivers: [
            // 🔥 PREMIUM CORPORATE HEADER
            SliverToBoxAdapter(
              child: Container(
                height: 280, width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade900, const Color(0xFF0A192F)]),
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
                        FadeInUp(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: const Icon(LucideIcons.shoppingBag, color: Colors.white, size: 30))),
                        const SizedBox(height: 15),
                        FadeInUp(delay: const Duration(milliseconds: 100), child: Text("Customer Account", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26))),
                        FadeInUp(delay: const Duration(milliseconds: 200), child: Text("Source directly from 10,000+ verified farmers.", style: GoogleFonts.poppins(color: Colors.blue.shade200, fontSize: 14))),
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
                      FadeInUp(delay: const Duration(milliseconds: 300), child: Text("Customer Details", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
                      const SizedBox(height: 20),
                      
                      FadeInUp(
                        delay: const Duration(milliseconds: 400),
                        child: _buildModernField(controller: _companyController, label: "Full Name or Business Name", icon: LucideIcons.briefcase, hint: "e.g. John Doe / Unga Group"),
                      ),
                      const SizedBox(height: 20),
                      
                      FadeInUp(
                        delay: const Duration(milliseconds: 500),
                        child: _buildModernField(controller: _phoneController, label: "Phone Number", icon: LucideIcons.phone, hint: "e.g. 0712345678", inputType: TextInputType.phone),
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
                            onPressed: (_isLoading || _isGoogleLoading) ? null : _registerCompany,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 5, shadowColor: Colors.blue.shade900.withOpacity(0.4)),
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
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.blue, strokeWidth: 2))
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
                            "By registering, you agree to MkulimaHub's Terms of Service and Escrow policies.",
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
      decoration: BoxDecoration(color: met ? Colors.blue.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: met ? Colors.blue : Colors.grey.shade300)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(met ? Icons.check : Icons.circle_outlined, size: 14, color: met ? Colors.blue.shade700 : Colors.grey),
          const SizedBox(width: 5),
          Text(text, style: GoogleFonts.poppins(fontSize: 11, color: met ? Colors.blue.shade800 : Colors.grey.shade600)),
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
            hintText: hint, hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13), prefixIcon: Icon(icon, color: Colors.blue.shade600, size: 20),
            suffixIcon: isPassword ? IconButton(icon: Icon(_obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff, color: Colors.grey.shade500, size: 20), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)) : null,
            filled: true, fillColor: Colors.grey.shade50, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.blue.shade600, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
          ),
        ),
      ],
    );
  }
}