import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/features/auth/auth_service.dart';
import 'package:mkulimahub_mobile/features/auth/otp_verification_screen.dart';

class GooglePhoneLinkScreen extends StatefulWidget {
  final String idToken;
  final String name;
  final String? overrideRole; 

  const GooglePhoneLinkScreen({
    super.key,
    required this.idToken,
    required this.name,
    this.overrideRole, 
  });

  @override
  State<GooglePhoneLinkScreen> createState() => _GooglePhoneLinkScreenState();
}

class _GooglePhoneLinkScreenState extends State<GooglePhoneLinkScreen> {
  final _phoneController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  void _submitPhone() async {
    String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid phone number"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

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
                // 🔥 THE FIX: Removed the invalid parameter and securely packed the Google ID inside the map!
                pendingRegistrationData: {
                  'google_id_token': widget.idToken,
                  if (widget.overrideRole != null) 'role': widget.overrideRole,
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
  Widget build(BuildContext context) {
    // Determine theme colors based on role
    Color primaryColor = widget.overrideRole == 'buyer' ? Colors.blue.shade800 : Colors.green.shade700;
    Color lightColor = widget.overrideRole == 'buyer' ? Colors.blue.shade50 : Colors.green.shade50;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: primaryColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                FadeInDown(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: lightColor, shape: BoxShape.circle),
                    child: Icon(LucideIcons.smartphone, size: 50, color: primaryColor),
                  ),
                ),
                const SizedBox(height: 30),
                FadeInUp(
                  delay: const Duration(milliseconds: 100),
                  child: Text("Link Your Phone", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 10),
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: Text("Welcome ${widget.name.split(' ')[0]}! Please enter your phone number to secure your account and enable SMS alerts.", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600, height: 1.5), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 40),
                FadeInUp(
                  delay: const Duration(milliseconds: 300),
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: "Phone Number",
                      hintText: "e.g. 0712345678",
                      prefixIcon: Icon(LucideIcons.phone, color: primaryColor),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryColor, width: 2)),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                FadeInUp(
                  delay: const Duration(milliseconds: 400),
                  child: SizedBox(
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitPhone,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text("Send Verification Code", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}