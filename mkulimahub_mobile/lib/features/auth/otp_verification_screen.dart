import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/auth/auth_service.dart';
import 'package:mkulimahub_mobile/features/home/home_screen.dart';
import 'package:mkulimahub_mobile/features/home/profile_screen.dart';
import 'package:mkulimahub_mobile/features/auth/create_new_password_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  
  // Scenarios
  final Map<String, dynamic>? pendingRegistrationData; 
  final Map<String, dynamic>? pendingLoginData; // 🔥 For 2FA Login
  final bool is2FALogin; 
  final bool isPasswordReset;
  final Map<String, dynamic>? pendingGoogleData;

  const OtpVerificationScreen({
    super.key, 
    required this.verificationId, 
    required this.phoneNumber,
    this.pendingRegistrationData, 
    this.pendingLoginData,
    this.pendingGoogleData,
    this.is2FALogin = false,
    this.isPasswordReset = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _authService = AuthService();
  final _apiClient = ApiClient();
  
  bool _isLoading = false;

  void _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      _showSnackBar("Please enter the 6-digit code.", Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    // 1. Check the code with Firebase
    final userCredential = await _authService.verifyOTP(
      verificationId: widget.verificationId, 
      smsCode: code,
    );

    if (userCredential != null && userCredential.user != null) {
      // 🔥 FIREBASE SUCCESS! Route based on the scenario:
      
      if (widget.pendingRegistrationData != null) {
        // ==========================================
        // SCENARIO A: NEW USER REGISTRATION
        // ==========================================
        final apiError = await _apiClient.register(widget.pendingRegistrationData!);
        
        if (apiError == null) {
           await _apiClient.login(
             widget.pendingRegistrationData!['phone_number'], 
             widget.pendingRegistrationData!['password']
           );
           setState(() => _isLoading = false);
           if (mounted) {
             Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const ProfileScreen(isNewUser: true)), (route) => false);
           }
        } else {
           setState(() => _isLoading = false);
           if (mounted) _showSnackBar(apiError, Colors.redAccent);
        }
        
      } else if (widget.is2FALogin && widget.pendingLoginData != null) {
        // ==========================================
        // SCENARIO B: 2FA EXISTING USER LOGIN
        // ==========================================
        // OTP is correct, so perform the final actual login to get the token!
        final apiError = await _apiClient.login(
          widget.pendingLoginData!['phone'], 
          widget.pendingLoginData!['password']
        );

        setState(() => _isLoading = false);

        if (apiError == null) {
          if (mounted) {
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
          }
        } else {
          if (mounted) _showSnackBar(apiError, Colors.redAccent);
        }

      } else if (widget.isPasswordReset) {
        // ==========================================
        // SCENARIO C: PASSWORD RESET
        // ==========================================
        setState(() => _isLoading = false);
        if (mounted) {
          // 🔥 Successfully verified OTP, route to Create New Password
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(
              builder: (_) => CreateNewPasswordScreen(
                phoneNumber: widget.phoneNumber,
                uid: userCredential.user!.uid, // Send the verified Firebase UID!
              )
            )
          );
        }
      }
      else if (widget.pendingGoogleData != null) {
        // ==========================================
        // SCENARIO D: GOOGLE PHONE LINK REGISTRATION
        // ==========================================
        final apiStatus = await _apiClient.googleRegister(widget.pendingGoogleData!);
        setState(() => _isLoading = false);

        if (apiStatus == 'needs_profile') {
          if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const ProfileScreen(isNewUser: true)), (route) => false);
        } else if (apiStatus == 'success') {
          if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
        } else {
          if (mounted) _showSnackBar(apiStatus ?? "Failed to link phone.", Colors.redAccent);
        }
      }

    } else {
      setState(() => _isLoading = false);
      if (mounted) _showSnackBar("Invalid or expired code. Try again.", Colors.redAccent);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()), 
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(height: 10),

                    FadeInDown(
                      duration: const Duration(milliseconds: 600),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(LucideIcons.messageSquare, size: 50, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 25),

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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Verification",
                              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black87),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "We've sent a 6-digit code to",
                              style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              widget.phoneNumber,
                              style: GoogleFonts.poppins(color: Colors.green.shade800, fontSize: 14, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 30),

                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.green.shade200, width: 1.5),
                              ),
                              child: TextField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 6,
                                style: GoogleFonts.poppins(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                decoration: const InputDecoration(
                                  counterText: "", 
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                                ),
                                onChanged: (value) {
                                  if (value.length == 6) {
                                    FocusScope.of(context).unfocus(); 
                                    _verifyCode();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 30),

                            SizedBox(
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _verifyCode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: _isLoading 
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Text("Verify Code", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
                            const SizedBox(height: 24),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("Didn't receive the code? ", style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13)),
                                GestureDetector(
                                  onTap: () {
                                    _showSnackBar("Requesting new code...", Colors.blueGrey);
                                  },
                                  child: Text(
                                    "Resend", 
                                    style: GoogleFonts.poppins(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 13)
                                  ),
                                )
                              ],
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
    );
  }
}