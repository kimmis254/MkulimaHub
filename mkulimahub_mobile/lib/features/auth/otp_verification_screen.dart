import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/auth/auth_service.dart';
import 'package:mkulimahub_mobile/features/auth/create_new_password_screen.dart';
import 'package:mkulimahub_mobile/features/home/home_screen.dart';
import 'package:mkulimahub_mobile/features/home/profile_screen.dart';
import 'package:mkulimahub_mobile/features/buyer/buyer_dashboard.dart';
import 'package:mkulimahub_mobile/features/buyer/customer_profile_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  
  final Map<String, dynamic>? pendingRegistrationData; 
  final Map<String, dynamic>? pendingLoginData; 
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
  Timer? _timer;
  int _start = 60; 
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // 🔥 Listen to the controller to dynamically update our custom boxes
    _otpController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); 
    _otpController.dispose();
    super.dispose();
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

  void _startTimer() {
    setState(() {
      _start = 60;
      _canResend = false;
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          _canResend = true;
          timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  void _resendOTP() async {
    if (!_canResend) return;
    
    setState(() => _isLoading = true);
    
    await _authService.sendPhoneOTP(
      phoneNumber: widget.phoneNumber,
      onCodeSent: (newVerificationId) {
        setState(() => _isLoading = false);
        _showSnackBar("New code sent!", Colors.green.shade700);
        _startTimer(); 
      },
      onError: (errorMsg) {
        setState(() => _isLoading = false);
        _showSnackBar(errorMsg, Colors.redAccent);
      }
    );
  }

  void _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      _showSnackBar("Please enter the full 6-digit code.", Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    final userCredential = await _authService.verifyOTP(
      verificationId: widget.verificationId, 
      smsCode: code,
    );

    if (userCredential != null && userCredential.user != null) {
      
      if (widget.pendingRegistrationData != null) {
        final apiError = await _apiClient.register(widget.pendingRegistrationData!);
        
        if (apiError == null) {
           await _apiClient.login(
             widget.pendingRegistrationData!['phone_number'], 
             widget.pendingRegistrationData!['password']
           );
           
           setState(() => _isLoading = false);
           
           if (mounted) {
             String role = widget.pendingRegistrationData!['role'] ?? 'farmer';
             await _apiClient.saveUserRole(role); 
             
             if (role == 'buyer') {
             Navigator.pushAndRemoveUntil(
               context, 
               MaterialPageRoute(builder: (_) => const CustomerProfileScreen(isNewUser: true)), 
               (route) => false
             );
          } else {
             Navigator.pushAndRemoveUntil(
               context, 
               MaterialPageRoute(builder: (_) => const ProfileScreen(isNewUser: true)), 
               (route) => false
             );
          }
           }
        } else {
           setState(() => _isLoading = false);
           if (mounted) _showSnackBar(apiError, Colors.redAccent);
        }
        
      } else if (widget.is2FALogin && widget.pendingLoginData != null) {
            final error = await _apiClient.login(
              widget.pendingLoginData!['phone']!,
              widget.pendingLoginData!['password']!
            );

            if (error == null) {
              final profileData = await _apiClient.getProfile();
              String role = profileData?['role'] ?? 'farmer';
              await _apiClient.saveUserRole(role);

              if (mounted) {
                if (role == 'buyer') {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const BuyerDashboard()), (route) => false);
                } else {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
                }
              }
            } else {
              setState(() => _isLoading = false);
              if (mounted) _showError(error); 
            }
      } else if (widget.isPasswordReset) {
        setState(() => _isLoading = false);
        if (mounted) {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(
              builder: (_) => CreateNewPasswordScreen(
                phoneNumber: widget.phoneNumber,
                uid: userCredential.user!.uid,
              )
            )
          );
        }
      } else if (widget.pendingGoogleData != null) {
        final apiStatus = await _apiClient.googleRegister(
  idToken: widget.pendingGoogleData!['idToken'],
  phoneNumber: widget.pendingGoogleData!['phoneNumber'],
);

        if (apiStatus == 'needs_profile') {
          setState(() => _isLoading = false);
          if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const ProfileScreen(isNewUser: true)), (route) => false);
        } else if (apiStatus == 'success') {
          final profileData = await _apiClient.getProfile();
          setState(() => _isLoading = false);

          if (mounted) {
            String role = profileData?['role'] ?? 'farmer';
            if (role == 'buyer') {
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const BuyerDashboard()), (route) => false);
            } else {
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
            }
          }
        } else {
          setState(() => _isLoading = false);
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
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)), 
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  // 🔥 CUSTOM PREMIUM OTP BOX GENERATOR
  Widget _buildOtpBoxes() {
    String currentText = _otpController.text;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        // Determine the state of this specific box
        bool isFilled = index < currentText.length;
        bool isActive = index == currentText.length; // The box currently waiting for input
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 45,
          height: 55,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isFilled ? Colors.green.shade50 : (isActive ? Colors.white : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFilled ? Colors.green.shade400 : (isActive ? Colors.green.shade700 : Colors.grey.shade300),
              width: isActive ? 2 : 1,
            ),
            boxShadow: isActive 
                ? [BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))] 
                : [],
          ),
          child: Text(
            isFilled ? currentText[index] : "",
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green.shade900),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), 
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Pulse(
                        infinite: true,
                        duration: const Duration(seconds: 2),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15), 
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)
                          ),
                          child: const Icon(LucideIcons.shieldCheck, size: 50, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 30),
                      FadeInUp(
                        delay: const Duration(milliseconds: 200),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 25, offset: const Offset(0, 10)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                "Secure Verification",
                                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "We've sent a 6-digit security code to",
                                style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.phoneNumber,
                                style: GoogleFonts.poppins(color: Colors.green.shade700, fontSize: 15, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 35),
                              
                              // 🔥 THE MAGIC INVISIBLE TEXTFIELD TRICK
                              SizedBox(
                                height: 60,
                                child: Stack(
                                  children: [
                                    // 1. The visual boxes underneath
                                    Center(child: _buildOtpBoxes()),
                                    
                                    // 2. The completely transparent text field right on top catching the taps
                                    TextField(
                                      controller: _otpController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      maxLength: 6,
                                      showCursor: false, // Hide cursor
                                      style: const TextStyle(color: Colors.transparent, fontSize: 1), // Hide text
                                      decoration: const InputDecoration(
                                        counterText: "", // Hide character counter
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        fillColor: Colors.transparent,
                                      ),
                                      onChanged: (value) {
                                        if (value.length == 6) {
                                          FocusScope.of(context).unfocus(); 
                                          _verifyCode();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 35),
                              SizedBox(
                                height: 60,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _verifyCode,
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
                                        : Text("Authenticate", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.1)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 25),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Didn't receive the code? ", style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13)),
                                  GestureDetector(
                                    onTap: _canResend ? _resendOTP : null,
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 300),
                                      style: GoogleFonts.poppins(
                                        color: _canResend ? Colors.green.shade700 : Colors.grey.shade400, 
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 13
                                      ),
                                      child: Text(_canResend ? "Resend" : "Wait 00:${_start.toString().padLeft(2, '0')}"),
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
      ),
    );
  }
}