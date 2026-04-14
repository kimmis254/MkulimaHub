import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/auth/auth_service.dart';
import 'package:mkulimahub_mobile/features/auth/otp_verification_screen.dart';

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
  
  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService(); 
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _registerCompany() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    String phone = _phoneController.text.trim();
    if (phone.startsWith('0')) {
      phone = '+254${phone.substring(1)}';
    } else if (!phone.startsWith('+')) {
      phone = '+254$phone';
    }

    // 🔥 TRIGGER FIREBASE OTP INSTEAD OF REGISTERING IMMEDIATELY
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
                // Pass the data so the OTP screen can save it to the DB!
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

  @override
  void dispose() {
    _companyController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 🔥 PREMIUM CORPORATE HEADER
          SliverToBoxAdapter(
            child: Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Colors.blue.shade900, const Color(0xFF0A192F)]
                ),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      FadeInUp(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                          child: const Icon(LucideIcons.shoppingBag, color: Colors.white, size: 30),
                        ),
                      ),
                      const SizedBox(height: 15),
                      FadeInUp(
                        delay: const Duration(milliseconds: 100),
                        child: Text("Customer Account", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26)),
                      ),
                      FadeInUp(
                        delay: const Duration(milliseconds: 200),
                        child: Text("Source directly from 10,000+ verified farmers.", style: GoogleFonts.poppins(color: Colors.blue.shade200, fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // 🔥 REGISTRATION FORM
          SliverPadding(
            padding: const EdgeInsets.all(24.0),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeInUp(
                      delay: const Duration(milliseconds: 300),
                      child: Text("Customer Details", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ),
                    const SizedBox(height: 20),
                    
                    FadeInUp(
                      delay: const Duration(milliseconds: 400),
                      child: _buildCorporateField(
                        controller: _companyController,
                        label: "Full Name or Business Name",
                        icon: LucideIcons.briefcase,
                        hint: "e.g. John Doe / Unga Group",
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    FadeInUp(
                      delay: const Duration(milliseconds: 500),
                      child: _buildCorporateField(
                        controller: _phoneController,
                        label: "Phone Number",
                        icon: LucideIcons.phone,
                        hint: "e.g. 0712345678",
                        isPhone: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    FadeInUp(
                      delay: const Duration(milliseconds: 600),
                      child: _buildCorporateField(
                        controller: _passwordController,
                        label: "Secure Password",
                        icon: LucideIcons.lock,
                        hint: "••••••••",
                        isPassword: true,
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // 🔥 SUBMIT BUTTON
                    FadeInUp(
                      delay: const Duration(milliseconds: 700),
                      child: SizedBox(
                        height: 60,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _registerCompany,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 5,
                            shadowColor: Colors.blue.shade900.withOpacity(0.4)
                          ),
                          child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text("Create Account", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    FadeInUp(
                      delay: const Duration(milliseconds: 800),
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
    );
  }

  Widget _buildCorporateField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    bool isPhone = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: isPassword && _obscurePassword,
            keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
              prefixIcon: Icon(icon, color: Colors.blue.shade600, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(_obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff, color: Colors.grey.shade500, size: 20),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    )
                  : null,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return "This field is required";
              if (isPassword && value.length < 6) return "Password must be at least 6 characters";
              return null;
            },
          ),
        ),
      ],
    );
  }
}