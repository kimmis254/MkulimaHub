import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/features/auth/auth_service.dart';
import 'package:mkulimahub_mobile/features/auth/otp_verification_screen.dart';

class GooglePhoneLinkScreen extends StatefulWidget {
  final String email;
  final String name;
  final String uid;

  const GooglePhoneLinkScreen({super.key, required this.email, required this.name, required this.uid});

  @override
  State<GooglePhoneLinkScreen> createState() => _GooglePhoneLinkScreenState();
}

class _GooglePhoneLinkScreenState extends State<GooglePhoneLinkScreen> {
  final _phoneController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  void _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^0(7|1)\d{8}$').hasMatch(phone) && !phone.startsWith('+254') && phone.length < 9) {
      _showSnackBar("Please enter a valid phone number", Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    String formattedPhone = phone;
    // Handle formats
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '+254${formattedPhone.substring(1)}';
    } else if (formattedPhone.startsWith('7') || formattedPhone.startsWith('1')) {
      formattedPhone = '+254$formattedPhone';
    } else if (!formattedPhone.startsWith('+')) {
      formattedPhone = '+254$formattedPhone';
    }

    await _authService.sendPhoneOTP(
      phoneNumber: formattedPhone,
      onCodeSent: (verificationId) {
        setState(() => _isLoading = false);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                verificationId: verificationId,
                phoneNumber: formattedPhone,
                // 🔥 Pass all Google + Phone data so OTP screen can register them!
                pendingGoogleData: {
                  'email': widget.email,
                  'full_name': widget.name,
                  'google_uid': widget.uid,
                  'phone_number': formattedPhone
                },
              )
            )
          );
        }
      },
      onError: (errorMsg) {
        setState(() => _isLoading = false);
        if (mounted) _showSnackBar(errorMsg, Colors.redAccent);
      }
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)), 
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔥 Custom Floating Back Button
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 10),
                child: IconButton(
                  icon: const Icon(LucideIcons.arrowLeft, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade50,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 🔥 Premium Hero Graphic
                        FadeInDown(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.green.shade100, width: 2)
                              ),
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Icon(LucideIcons.smartphone, size: 50, color: Colors.green.shade700),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: const Icon(LucideIcons.link2, size: 16, color: Colors.blue),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // 🔥 Enhanced Typography
                        FadeInDown(
                          delay: const Duration(milliseconds: 100),
                          child: Text(
                            "Almost there, \n${widget.name.split(' ')[0]}!", 
                            style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2, color: Colors.black87), 
                            textAlign: TextAlign.center
                          )
                        ),
                        const SizedBox(height: 12),
                        FadeInDown(
                          delay: const Duration(milliseconds: 200),
                          child: Text(
                            "Secure your MkulimaHub account by linking your active M-PESA phone number.", 
                            style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14), 
                            textAlign: TextAlign.center
                          )
                        ),
                        const SizedBox(height: 40),
                        
                        // 🔥 Modern Input Field
                        FadeInUp(
                          delay: const Duration(milliseconds: 300),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200, width: 1.5),
                            ),
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                              decoration: InputDecoration(
                                hintText: "712 345 678",
                                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontWeight: FontWeight.w500, letterSpacing: 1.5),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.phone, color: Colors.green.shade600, size: 20),
                                      const SizedBox(width: 10),
                                      Text("+254", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(width: 10),
                                      Container(height: 24, width: 1.5, color: Colors.grey.shade300),
                                    ],
                                  ),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 18),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // 🔥 Gradient Premium Button (Matches OTP Screen)
                        FadeInUp(
                          delay: const Duration(milliseconds: 400),
                          child: SizedBox(
                            height: 60,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _sendOTP,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [Colors.green.shade600, Colors.green.shade800]),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  child: _isLoading 
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text("Send Code", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.1)),
                                          const SizedBox(width: 8),
                                          const Icon(LucideIcons.arrowRight, color: Colors.white, size: 18),
                                        ],
                                      ),
                                ),
                              ),
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
      ),
    );
  }
}