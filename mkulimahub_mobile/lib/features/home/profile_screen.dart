import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/auth/login_screen.dart';
import 'package:mkulimahub_mobile/features/home/home_screen.dart'; // Import Home
import 'package:mkulimahub_mobile/core/kenya_locations.dart';

class ProfileScreen extends StatefulWidget {
  final bool isNewUser;
  const ProfileScreen({super.key, this.isNewUser = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiClient _apiClient = ApiClient();
  final _picker = ImagePicker();
  
  late bool _isEditing;

  // Controllers
  final _bioController = TextEditingController();
  final _cropsController = TextEditingController();
  final _villageController = TextEditingController();

  // Location State
  String? _selectedCounty;
  String? _selectedSubCounty;
  String? _selectedWard;
  
  File? _profileImage;
  bool _isLoading = false;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.isNewUser;
    _loadProfile();
  }

  void _loadProfile() async {
    setState(() => _isLoading = true);
    final data = await _apiClient.getProfile();
    
    // DEBUG: Print exactly what the backend gave us
    print("---------------- PROFILE DATA RECEIVED ----------------");
    print(data); 
    print("-------------------------------------------------------");

    setState(() {
      _isLoading = false;
      if (data != null) {
        _profileData = data;
        
        // 1. TEXT FIELDS
        _bioController.text = data['bio'] ?? "";
        _cropsController.text = data['main_crops'] ?? "";
        _villageController.text = data['village'] ?? ""; // Check if key matches backend
        
        // 2. LOCATION DROPDOWNS (The Tricky Part)
        // We ensure the values exist in our KenyaLocations list before setting them
        // to avoid "Value not in range" errors.
        
        final backendCounty = data['county']; // Check key spelling (e.g. 'County' vs 'county')
        if (backendCounty != null && KenyaLocations.getCounties().contains(backendCounty)) {
          _selectedCounty = backendCounty;
          
          // Now try to set Sub-County
          final backendSub = data['sub_county']; // Check key: 'sub_county' vs 'subCounty'
          final validSubCounties = KenyaLocations.getSubCounties(_selectedCounty!);
          
          if (backendSub != null && validSubCounties.contains(backendSub)) {
            _selectedSubCounty = backendSub;
            
            // Now try to set Ward
            final backendWard = data['ward'];
            final validWards = KenyaLocations.getWards(_selectedSubCounty!);
            
            if (backendWard != null) {
               // Since Wards are generic in our static file, we just accept the value
               // or check if it exists if you have a real list.
               _selectedWard = backendWard;
            }
          }
        }
      }
    });
  }

  Future<void> _saveProfile() async {
    // Validation
    if (_selectedCounty == null || _selectedSubCounty == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select your County and Sub-County"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      "bio": _bioController.text,
      "main_crops": _cropsController.text,
      "county": _selectedCounty,
      "sub_county": _selectedSubCounty,
      "ward": _selectedWard,
      "village": _villageController.text,
    };

    final error = await _apiClient.updateProfile(data);

    if (error == null) {
      // --- CRITICAL FIX: Redirect Logic ---
      if (widget.isNewUser) {
        // 1. If New User -> Go to Home
        if (mounted) {
           Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false
          );
        }
      } else {
        // 2. If Existing User -> Just switch to View Mode
        await _apiClient.getProfile(); // Refresh Data
        _loadProfile(); 
        setState(() {
          _isLoading = false;
          _isEditing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!"), backgroundColor: Colors.green));
        }
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine Title based on context
    String title = "My Profile";
    if (widget.isNewUser) title = "Create Profile";
    else if (_isEditing) title = "Edit Profile";

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: !widget.isNewUser, 
        leading: (!widget.isNewUser) 
          ? IconButton(icon: const Icon(LucideIcons.arrowLeft, color: Colors.black), onPressed: () => Navigator.pop(context)) 
          : null,
        title: Text(title, style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          // SETTINGS ICON (Visible only in View Mode)
          if (!_isEditing)
             IconButton(
              icon: const Icon(LucideIcons.settings, color: Colors.black),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Settings Coming Soon!"))),
            ),
          
          // CANCEL BUTTON (Visible only if editing an existing profile)
          if (_isEditing && !widget.isNewUser)
            IconButton(
              icon: const Icon(LucideIcons.x, color: Colors.red),
              onPressed: () => setState(() => _isEditing = false),
            )
        ],
      ),
      body: _isLoading && _profileData == null && !widget.isNewUser
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // 1. PROFILE PICTURE
                  _buildProfileImage(),
                  const SizedBox(height: 30),

                  // 2. CONTENT SWITCHER
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isEditing ? _buildEditForm() : _buildViewMode(),
                  ),
                ],
              ),
            ),
    );
  }

  // --- VIEW MODE (Clean Cards) ---
  Widget _buildViewMode() {
    // SAFE STRING HELPERS
    final location = (_profileData?['county'] != null) 
        ? "${_profileData?['village'] ?? ''}, ${_profileData?['county']}"
        : "Location not set";

    return Column(
      key: const ValueKey("view"),
      children: [
        Text(
          _profileData?['full_name'] ?? "Farmer",
          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          location,
          style: GoogleFonts.poppins(color: Colors.grey[600]),
        ),
        const SizedBox(height: 30),
        
        _buildInfoCard("About", _profileData?['bio'] ?? "No bio added yet."),
        _buildInfoCard("Crops", _profileData?['main_crops'] ?? "No crops listed."),
        
        // Detailed Location Card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Detailed Location", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 5),
            
            // Safe Display Logic
            _buildLocationRow("County", _profileData?['county']),
            _buildLocationRow("Sub-County", _profileData?['sub_county']), // Check snake_case
            _buildLocationRow("Ward", _profileData?['ward']),
            _buildLocationRow("Village", _profileData?['village']),
          ]),
        ),

        const SizedBox(height: 20),
        
        // EDIT BUTTON
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            icon: const Icon(LucideIcons.edit3, color: Colors.white),
            label: const Text("Edit Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            onPressed: () => setState(() => _isEditing = true),
          ),
        ),
        
        const SizedBox(height: 15),
        
        // LOGOUT BUTTON
        TextButton.icon(
           icon: const Icon(LucideIcons.logOut, color: Colors.red),
           label: const Text("Log Out", style: TextStyle(color: Colors.red)),
           onPressed: () async {
             await _apiClient.logout();
             if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
           },
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // --- EDIT MODE (Modern Form) ---
  Widget _buildEditForm() {
    return Column(
      key: const ValueKey("edit"),
      children: [
        FadeInDown(child: _buildSectionTitle("About You")),
        const SizedBox(height: 10),
        _buildModernField(_bioController, "Bio", LucideIcons.fileText, maxLines: 3, hint: "Tell buyers about your farm..."),
        
        const SizedBox(height: 30),
        FadeInDown(delay: const Duration(milliseconds: 100), child: _buildSectionTitle("Farm Location")),
        const SizedBox(height: 10),
        
        // Location Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(children: [
             _buildDropdown("County", _selectedCounty, KenyaLocations.getCounties(), (val) {
               setState(() { _selectedCounty = val; _selectedSubCounty = null; _selectedWard = null; });
             }),
             const Divider(),
             _buildDropdown("Sub-County", _selectedSubCounty, _selectedCounty == null ? [] : KenyaLocations.getSubCounties(_selectedCounty!), (val) {
               setState(() { _selectedSubCounty = val; _selectedWard = null; });
             }),
             const Divider(),
             _buildDropdown("Ward", _selectedWard, _selectedSubCounty == null ? [] : KenyaLocations.getWards(_selectedSubCounty!), (val) => setState(() => _selectedWard = val)),
             const Divider(),
             TextField(
                controller: _villageController,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  labelText: "Village",
                  prefixIcon: Icon(LucideIcons.mapPin, color: Colors.green[700], size: 18),
                  border: InputBorder.none,
                ),
             )
          ]),
        ),

        const SizedBox(height: 30),
        FadeInDown(delay: const Duration(milliseconds: 200), child: _buildSectionTitle("Farming Details")),
        const SizedBox(height: 10),
        _buildModernField(_cropsController, "Main Crops", LucideIcons.sprout, hint: "Maize, Beans, etc."),

        const SizedBox(height: 40),
        
        // SAVE BUTTON
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[800],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 4,
              shadowColor: Colors.green.withOpacity(0.3)
            ),
            child: _isLoading 
              ? const CircularProgressIndicator(color: Colors.white) 
              : Text(widget.isNewUser ? "Create Profile" : "Save Changes", style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // --- HELPERS ---
  Widget _buildProfileImage() {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10)]),
          child: CircleAvatar(
            radius: 55,
            backgroundColor: Colors.green[50],
            backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
            child: _profileImage == null ? Icon(LucideIcons.user, size: 40, color: Colors.green[700]) : null,
          ),
        ),
        if (_isEditing)
          Positioned(
            bottom: 0, right: 0,
            child: GestureDetector(
              onTap: () async {
                final img = await _picker.pickImage(source: ImageSource.gallery);
                if (img != null) setState(() => _profileImage = File(img.path));
              },
              child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: const Icon(LucideIcons.camera, color: Colors.white, size: 18)),
            ),
          )
      ],
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildSectionTitle(String title) => Align(alignment: Alignment.centerLeft, child: Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])));
  
  Widget _buildModernField(TextEditingController c, String label, IconData icon, {int maxLines = 1, String? hint}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: TextField(
        controller: c, maxLines: maxLines, 
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
          labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: Colors.green[700], size: 20), 
          border: InputBorder.none, 
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)
        )
      ),
    );
  }

  Widget _buildDropdown(String label, String? val, List<String> items, Function(String?) changed) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: val, isExpanded: true, 
        hint: Text(label, style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 14)), 
        icon: const Icon(LucideIcons.chevronDown, size: 18, color: Colors.grey),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.poppins(fontSize: 14)))).toList(), 
        onChanged: changed
      )
    );
  }
  Widget _buildLocationRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Text("$label: ", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(value ?? "Not set", style: GoogleFonts.poppins(color: Colors.black87, fontSize: 13)),
        ],
      ),
    );
  }
}
