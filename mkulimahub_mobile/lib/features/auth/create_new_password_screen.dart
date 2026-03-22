import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/auth/login_screen.dart';

class CreateNewPasswordScreen extends StatefulWidget {
  final String phoneNumber;
  final String uid;

  const CreateNewPasswordScreen({
    super.key, 
    required this.phoneNumber,
    required this.uid,
  });

  @override
  State<CreateNewPasswordScreen> createState() => _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  final _apiClient = ApiClient();
  bool _isLoading = false;

  // Password Rules State
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

  void _handleResetPassword() async {
    if (!_hasMinLength || !_hasNumber) {
      _showSnackBar("Password is too weak. Check the guidelines.", Colors.redAccent);
      return;
    }
    
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final error = await _apiClient.resetPassword(
      phone: widget.phoneNumber, 
      uid: widget.uid, 
      newPassword: _passwordController.text.trim()
    );

    setState(() => _isLoading = false);

    if (error == null) {
      if (mounted) {
        _showSnackBar("Password reset successfully! Please log in.", Colors.green.shade700);
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
      }
    } else {
      if (mounted) _showSnackBar(error, Colors.redAccent);
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
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeInDown(
                      duration: const Duration(milliseconds: 600),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(LucideIcons.lock, size: 50, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    FadeInDown(
                      delay: const Duration(milliseconds: 100),
                      child: Text(
                        "New Password",
                        style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    FadeInUp(
                      delay: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                "Create a new, strong password for your account.",
                                style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 30),

                              _buildModernField(
                                controller: _passwordController,
                                label: "New Password",
                                icon: LucideIcons.lock,
                                isPassword: true,
                                onChanged: _updatePasswordStatus, 
                              ),
                              
                              // Active Guidelines
                              Padding(
                                padding: const EdgeInsets.only(top: 10, left: 10, bottom: 20),
                                child: Row(
                                  children: [
                                    _buildGuideline("6+ Chars", _hasMinLength),
                                    const SizedBox(width: 15),
                                    _buildGuideline("1 Number", _hasNumber),
                                  ],
                                ),
                              ),

                              _buildModernField(
                                controller: _confirmPasswordController,
                                label: "Confirm Password",
                                icon: LucideIcons.checkCircle,
                                isPassword: true,
                                onChanged: (val) {
                                  setState(() => _passwordsMatch = val == _passwordController.text);
                                },
                                validator: (v) => v != _passwordController.text ? "Passwords do not match" : null,
                              ),
                              
                              if (_confirmPasswordController.text.isNotEmpty && !_passwordsMatch)
                                Padding(
                                  padding: const EdgeInsets.only(top: 5, left: 10, bottom: 10),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, size: 14, color: Colors.redAccent),
                                      const SizedBox(width: 5),
                                      Text("Passwords don't match yet", style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              
                              const SizedBox(height: 30),

                              SizedBox(
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleResetPassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  child: _isLoading 
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : Text("Save Password", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
          ),
        ],
      ),
    );
  }

  Widget _buildGuideline(String text, bool met) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: met ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: met ? Colors.green : Colors.grey.shade300)
      ),
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

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      onChanged: onChanged,
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