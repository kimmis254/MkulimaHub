import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/auth/login_screen.dart';
import 'package:mkulimahub_mobile/features/home/home_screen.dart';
import 'package:mkulimahub_mobile/features/home/profile_screen.dart';
import 'package:mkulimahub_mobile/features/auth/auth_service.dart';

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
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, 
        timeLimit: const Duration(seconds: 10),  
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
          MaterialPageRoute(builder: (_) => ProfileScreen(isNewUser: true)),
          (route) => false
        );
      }
    } else {
      setState(() => _isLoading = false);
      if(mounted) _showCustomSnackBar(error, isError: true);
    }
  }

  // 🔥 Google Sign-In Logic for Registration
  void _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    
    final userCredential = await _authService.signInWithGoogle();

    if (userCredential != null && userCredential.user != null) {
      final error = await _apiClient.googleLogin(
        email: userCredential.user!.email ?? '',
        name: userCredential.user!.displayName ?? 'Farmer',
        uid: userCredential.user!.uid, 
      );

      setState(() => _isGoogleLoading = false);

      if (error == null) {
        // 🎉 Existing user returning! Go to Home.
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false
          );
        }
      } else if (error == 'needs_profile') {
        // 🔥 THE FIX: Route them directly to the Profile Screen!
        if (mounted) {
           Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (_) => const ProfileScreen(isNewUser: true)),
            (route) => false
          );
        }
      } else {
        if (mounted) _showCustomSnackBar(error, isError: true);
      }
    } else {
      setState(() => _isGoogleLoading = false);
      if (mounted) _showCustomSnackBar('Google Sign-In failed or was cancelled.', isError: true);
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
      body: Stack(
        children: [
          // Background Gradient Header
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
                    // Back Button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(height: 5),

                    // Header Text
                    FadeInDown(
                      duration: const Duration(milliseconds: 600),
                      child: Text(
                        "Join MkulimaHub",
                        style: GoogleFonts.poppins(
                          fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Main Form Floating Card
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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                "Create Account",
                                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black87),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Start your smart farming journey",
                                style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 30),

                              // Form Fields
                              _buildModernField(
                                controller: _nameController,
                                label: "Full Name",
                                icon: LucideIcons.user,
                                validator: (v) {
                                  if (v == null || v.trim().split(' ').length < 2) {
                                    return "Please enter at least two names";
                                  }
                                  return null;
                                }
                              ),
                              const SizedBox(height: 20),

                              _buildModernField(
                                controller: _phoneController,
                                label: "Phone Number",
                                icon: LucideIcons.phone,
                                inputType: TextInputType.phone,
                                validator: (value) {
                                  if (!RegExp(r'^(07|01)\d{8}$').hasMatch(value ?? '')) {
                                    return 'Must be 10 digits (e.g. 07...)';
                                  }
                                  return null;
                                }
                              ),
                              const SizedBox(height: 20),
                              
                              _buildModernField(
                                controller: _passwordController,
                                label: "Password",
                                icon: LucideIcons.lock,
                                isPassword: true,
                                onChanged: _updatePasswordStatus, 
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
                              
                              const SizedBox(height: 20),

                              // Register Button
                              SizedBox(
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: (_isLoading || _isGoogleLoading) ? null : _handleRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  child: _isLoading 
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : Text("Sign Up", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Divider OR
                              Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.grey[200], thickness: 1.5)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text("or sign up with", style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12)),
                                  ),
                                  Expanded(child: Divider(color: Colors.grey[200], thickness: 1.5)),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Google Sign-In Button
                              SizedBox(
                                height: 55,
                                child: OutlinedButton(
                                  onPressed: (_isLoading || _isGoogleLoading) ? null : _handleGoogleSignIn,
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade50,
                                    side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: _isGoogleLoading
                                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.green, strokeWidth: 2))
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Image.network(
                                              'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                                              height: 22,
                                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 30, color: Colors.black87),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              "Google",
                                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
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
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER: Guideline Chip ---
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

  // Refined Helper Widget for Cleaner Fields
  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: inputType,
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