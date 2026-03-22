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
    if (!RegExp(r'^0(7|1)\d{8}$').hasMatch(phone) && !phone.startsWith('+254')) {
      _showSnackBar("Please enter a valid phone number (e.g., 07...)", Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    String formattedPhone = phone;
    if (formattedPhone.startsWith('0')) formattedPhone = '+254${formattedPhone.substring(1)}';
    else if (!formattedPhone.startsWith('+')) formattedPhone = '+254$formattedPhone';

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: GoogleFonts.poppins()), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(backgroundColor: Colors.green.shade800, elevation: 0, leading: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: Colors.white), onPressed: () => Navigator.pop(context))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeInDown(child: const Icon(LucideIcons.smartphone, size: 60, color: Colors.green)),
              const SizedBox(height: 20),
              FadeInDown(child: Text("Almost there, ${widget.name.split(' ')[0]}!", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              const SizedBox(height: 10),
              FadeInDown(child: Text("Please link your phone number to secure your MkulimaHub account.", style: GoogleFonts.poppins(color: Colors.grey[600]), textAlign: TextAlign.center)),
              const SizedBox(height: 40),
              
              FadeInUp(
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: "Phone Number", prefixIcon: Icon(LucideIcons.phone, color: Colors.green.shade700), border: InputBorder.none, contentPadding: const EdgeInsets.all(16)),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              FadeInUp(
                child: SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendOTP,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text("Send Code", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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