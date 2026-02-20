import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/auth/login_screen.dart';
import 'package:mkulimahub_mobile/features/home/home_screen.dart';
import 'package:mkulimahub_mobile/features/home/profile_screen.dart';


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
  bool _isLoading = false;

  // --- PASSWORD RULES STATE ---
  bool _hasMinLength = false;
  bool _hasNumber = false;
  bool _passwordsMatch = true;

  // --- GEOLOCATION LOGIC ---
  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) _showCustomSnackBar("GPS is off. Using default location.", isError: true);
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) _showCustomSnackBar("Location denied. Using default.", isError: true);
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      // --- FIX: ADD TIMEOUT ---
      // This prevents the "Stuck Loading" issue if GPS is weak
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // 'High' can be slow
        timeLimit: const Duration(seconds: 10),   // Give up after 10 seconds
      );
    } catch (e) {
      if (mounted) _showCustomSnackBar("GPS timeout. Using default location.", isError: true);
      return null;
    }
  }

  // --- MODERN SNACKBAR ---
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

  void _handleRegister() async {
    // 1. Check Password Rules explicitly before submitting
    if (!_hasMinLength || !_hasNumber) {
      _showCustomSnackBar("Password is too weak. Check the guidelines.", isError: true);
      return;
    }
    
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // 2. Get Location
    final position = await _determinePosition();
    
    if (position == null) {
      setState(() => _isLoading = false);
      return; 
    }

    // 3. Prepare Data
    final userData = {
      "full_name": _nameController.text.trim(),
      "phone_number": _phoneController.text.trim(),
      "password": _passwordController.text.trim(),
      "role": "farmer",
      "latitude": position.latitude,
      "longitude": position.longitude
    };

    // 4. Call API
    final error = await _apiClient.register(userData);

    if (error == null) {
      await _apiClient.login(_phoneController.text.trim(), _passwordController.text.trim());
      
      setState(() => _isLoading = false);
      
      if (mounted) {
         // --- REDIRECT TO PROFILE (Force Edit Mode) ---
         Navigator.pushAndRemoveUntil(
          context, 
          // Pass 'isNewUser: true' so they can't go back without saving
          MaterialPageRoute(builder: (_) =>  ProfileScreen(isNewUser: true)),
          (route) => false
        );
      }
    }
  }
  // --- PASSWORD CHECKER LOGIC ---
  void _updatePasswordStatus(String value) {
    setState(() {
      _hasMinLength = value.length >= 6;
      _hasNumber = RegExp(r'\d').hasMatch(value);
      _passwordsMatch = value == _confirmPasswordController.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Header
                FadeInDown(
                  duration: const Duration(milliseconds: 600),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.userPlus, size: 50, color: Colors.green[700]),
                  ),
                ),
                const SizedBox(height: 20),
                
                FadeInDown(
                  delay: const Duration(milliseconds: 100),
                  child: Text(
                    "Join MkulimaHub",
                    style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 40),
                
                // 2. Form Fields
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      // NAME (Full Name Enforced)
                      _buildModernField(
                        controller: _nameController,
                        label: "Full Name",
                        hint: "e.g. Jane Kuria",
                        icon: LucideIcons.user,
                        validator: (v) {
                          if (v == null || v.trim().split(' ').length < 2) {
                            return "Please enter at least two names";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // PHONE (Strict 10 Digits)
                      _buildModernField(
                        controller: _phoneController,
                        label: "Phone Number",
                        hint: "e.g. 0712345678",
                        icon: LucideIcons.phone,
                        inputType: TextInputType.phone,
                        validator: (value) {
                          if (!RegExp(r'^(07|01)\d{8}$').hasMatch(value ?? '')) {
                            return 'Must be 10 digits (e.g. 07...)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // PASSWORD (With Active Checker)
                      _buildModernField(
                        controller: _passwordController,
                        label: "Password",
                        icon: LucideIcons.lock,
                        isPassword: true,
                        onChanged: _updatePasswordStatus, // <--- Listen to typing
                      ),
                      
                      // Active Guidelines Checklist
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

                      // CONFIRM PASSWORD
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
                      
                      // Active Match Indicator
                      if (_confirmPasswordController.text.isNotEmpty && !_passwordsMatch)
                        Padding(
                          padding: const EdgeInsets.only(top: 5, left: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, size: 14, color: Colors.red),
                              const SizedBox(width: 5),
                              Text("Passwords don't match yet", style: GoogleFonts.poppins(color: Colors.red, fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // 3. Register Button
                FadeInUp(
                  delay: const Duration(milliseconds: 400),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[800],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                        shadowColor: Colors.green.withOpacity(0.4),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Create Account", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(width: 10),
                              const Icon(LucideIcons.arrowRight, color: Colors.white, size: 20),
                            ],
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // 4. Back to Login
                FadeInUp(
                  delay: const Duration(milliseconds: 500),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already a member? ", style: GoogleFonts.poppins(color: Colors.grey[600])),
                      GestureDetector(
                        onTap: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                        },
                        child: Text(
                          "Log In", 
                          style: GoogleFonts.poppins(color: Colors.green[700], fontWeight: FontWeight.bold)
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPER: Guideline Chip ---
  Widget _buildGuideline(String text, bool met) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: met ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: met ? Colors.green : Colors.grey[300]!)
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(met ? Icons.check : Icons.circle_outlined, size: 14, color: met ? Colors.green[700] : Colors.grey),
          const SizedBox(width: 5),
          Text(text, style: GoogleFonts.poppins(fontSize: 11, color: met ? Colors.green[800] : Colors.grey[600])),
        ],
      ),
    );
  }

  // --- WIDGET HELPER: Clean Fields ---
  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: inputType,
        onChanged: onChanged,
        style: GoogleFonts.poppins(fontSize: 14),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
          prefixIcon: Icon(icon, color: Colors.green[700], size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          // Clean error styling
          errorStyle: GoogleFonts.poppins(color: Colors.red[400], fontSize: 11),
        ),
      ),
    );
  }
}