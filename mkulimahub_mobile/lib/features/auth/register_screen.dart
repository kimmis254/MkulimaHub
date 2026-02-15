import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/home/home_screen.dart';
import 'package:geolocator/geolocator.dart'; 

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
  final _confirmPasswordController = TextEditingController(); // Standard Practice

  // Hardcoded location (Makueni Center) for now
  final double _latitude = -1.800;
  final double _longitude = 37.600;

  final _apiClient = ApiClient();
  bool _isLoading = false;

Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if GPS is on
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enable GPS Location services.')));
      return null;
    }

    // 2. Check Permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied')));
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')));
      return null;
    }

    // 3. Get Position
    return await Geolocator.getCurrentPosition();
  }
  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // --- NEW: GET REAL LOCATION ---
    final position = await _determinePosition();
    
    if (position == null) {
      setState(() => _isLoading = false);
      return; // Stop if we can't get location
    }
    // -----------------------------

    // 1. Prepare Data (Using Real Coordinates!)
    final userData = {
      "full_name": _nameController.text.trim(),
      "phone_number": _phoneController.text.trim(),
      "password": _passwordController.text.trim(),
      "role": "farmer",
      "latitude": position.latitude,  // <--- Real Data
      "longitude": position.longitude // <--- Real Data
    };

    // 2. Call Register API
    final error = await _apiClient.register(userData);

    if (error == null) {
      // Auto-Login
      await _apiClient.login(_phoneController.text.trim(), _passwordController.text.trim());
      
      setState(() => _isLoading = false);
      
      if (mounted) {
         Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false
        );
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: Center(
        // FIX #2: Scrollable
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey, // FIX #5: Validation
            child: Column(
              children: [
                Text("Join MkulimaHub", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                
                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person)),
                  validator: (v) => v!.length < 3 ? "Name too short" : null,
                ),
                const SizedBox(height: 15),

                // Phone
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: "Phone Number", prefixIcon: Icon(Icons.phone)),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (!RegExp(r'^0(7|1)\d{8}$').hasMatch(value ?? '')) {
                      return 'Enter valid Kenyan number (07...)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Password
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock)),
                  obscureText: true,
                  validator: (v) => v!.length < 6 ? "Password must be 6+ chars" : null,
                ),
                const SizedBox(height: 15),
                
                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(labelText: "Confirm Password", prefixIcon: Icon(Icons.lock_outline)),
                  obscureText: true,
                  validator: (v) {
                    if (v != _passwordController.text) return "Passwords do not match";
                    return null;
                  },
                ),
                const SizedBox(height: 25),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Register", style: TextStyle(color: Colors.white, fontSize: 18)),
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