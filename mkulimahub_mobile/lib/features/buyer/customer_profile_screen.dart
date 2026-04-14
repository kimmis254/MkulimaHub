import 'dart:convert';
import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/buyer/buyer_dashboard.dart';
import 'package:mkulimahub_mobile/features/home/settings_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  final bool isNewUser;
  const CustomerProfileScreen({super.key, this.isNewUser = false});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final ApiClient _apiClient = ApiClient();
  final _picker = ImagePicker();
  
  late bool _isEditing;

  final _bioController = TextEditingController();
  final _villageController = TextEditingController();

  List<dynamic> _locationsData = []; 
  List<String> _counties = [];
  List<String> _subCounties = [];
  List<String> _wards = [];

  String? _selectedCounty;
  String? _selectedSubCounty;
  String? _selectedWard;

  File? _profileImage;
  bool _isLoading = false;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    // Default to editing ONLY if they are a brand new user onboarding
    _isEditing = widget.isNewUser;
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    await _loadLocationData();
    if (!widget.isNewUser) {
      await _loadProfile();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLocationData() async {
    try {
      final String response = await rootBundle.loadString('assets/data/kenya_locations.json');
      final data = await json.decode(response) as List<dynamic>;
      setState(() {
        _locationsData = data;
        _counties = _locationsData.map((c) => c['county_name'].toString()).toList();
      });
    } catch (e) {
      print("Error loading locations JSON: $e");
    }
  }

  Future<void> _loadProfile() async {
    final data = await _apiClient.getProfile();
    
    setState(() {
      _isLoading = false;

      if (data != null) {
        _profileData = data;
        
        _bioController.text = data['bio'] ?? "";
        _villageController.text = data['village'] ?? ""; 
        
        final backendCounty = data['county']; 
        if (backendCounty != null && _counties.contains(backendCounty)) {
          _selectedCounty = backendCounty;
          
          var countyObj = _locationsData.firstWhere((c) => c['county_name'] == backendCounty);
          var constituencies = countyObj['constituencies'] as List<dynamic>;
          _subCounties = constituencies.map((c) => c['constituency_name'].toString()).toList();
          
          final backendSub = data['sub_county']; 
          if (backendSub != null && _subCounties.contains(backendSub)) {
            _selectedSubCounty = backendSub;
            
            var constituencyObj = constituencies.firstWhere((c) => c['constituency_name'] == backendSub);
            _wards = List<String>.from(constituencyObj['wards']);
            
            final backendWard = data['ward'];
            if (backendWard != null && _wards.contains(backendWard)) {
               _selectedWard = backendWard;
            }
          }
        }
      }
    });
  }

  Future<void> _saveProfile() async {
    if (_selectedCounty == null || _selectedSubCounty == null) {
      if (mounted) _showSnackBar("Please select your County and Sub-County", Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      "bio": _bioController.text,
      "county": _selectedCounty,
      "sub_county": _selectedSubCounty,
      "ward": _selectedWard,
      "village": _villageController.text,
    };

    final error = await _apiClient.updateProfile(data);

    if (error == null) {
      if (widget.isNewUser) {
        if (mounted) {
           Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (_) => const BuyerDashboard()),
            (route) => false
          );
        }
      } else {
        await _loadProfile(); 
        setState(() {
          _isLoading = false;
          _isEditing = false;
        });
        if (mounted) _showSnackBar("Logistics Profile Updated!", Colors.teal.shade700);
      }
    } else {
      setState(() => _isLoading = false);
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
    String title = widget.isNewUser ? "Logistics Setup" : (_isEditing ? "Edit Logistics" : "My Profile");

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading && _profileData == null && !widget.isNewUser
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Stack(
              children: [
                // 🔥 PREMIUM TEAL BACKGROUND
                Container(
                  height: MediaQuery.of(context).size.height * 0.35,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade900, Colors.teal.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                
                SafeArea(
                  child: Column(
                    children: [
                      // Custom AppBar Area
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (!widget.isNewUser)
                              IconButton(
                                icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              )
                            else
                              const SizedBox(width: 48), 
                            
                            Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            
                            if (!_isEditing)
                              IconButton(
                                icon: const Icon(LucideIcons.settings, color: Colors.white),
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                                },
                              )
                            else if (_isEditing && !widget.isNewUser)
                              IconButton(
                                icon: const Icon(LucideIcons.x, color: Colors.white),
                                onPressed: () => setState(() => _isEditing = false),
                              )
                            else
                              const SizedBox(width: 48), 
                          ],
                        ),
                      ),
                      
                      // Scrollable Content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 40, top: 20),
                          child: Column(
                            children: [
                              _buildProfileImage(),
                              const SizedBox(height: 30),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: _isEditing ? _buildEditForm() : _buildViewMode(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildViewMode() {
    final location = (_profileData?['county'] != null) 
        ? "${_profileData?['village'] ?? ''}, ${_profileData?['county']}"
        : "Location not set";

    return Column(
      key: const ValueKey("view"),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name & Location Header inside a floating card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            children: [
              Text(_profileData?['full_name'] ?? "Customer", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.mapPin, size: 16, color: Colors.teal.shade700),
                  const SizedBox(width: 6),
                  Text(location, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        
        _buildInfoCard("Business Details", _profileData?['bio'] ?? "No details added yet.", LucideIcons.store),
        
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 25),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                Icon(LucideIcons.truck, size: 18, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                Text("Primary Delivery Location", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildLocationRow("County", _profileData?['county']),
            _buildLocationRow("Sub-County", _profileData?['sub_county']),
            _buildLocationRow("Ward", _profileData?['ward']),
            _buildLocationRow("Landmark", _profileData?['village']),
          ]),
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      key: const ValueKey("edit"),
      children: [
        FadeInDown(child: _buildSectionTitle("Business Info")),
        const SizedBox(height: 10),
        _buildModernField(_bioController, "Business Type & Details", LucideIcons.store, maxLines: 3, hint: "E.g. Wholesaler looking for fresh veg..."),
        
        const SizedBox(height: 30),
        FadeInDown(delay: const Duration(milliseconds: 100), child: _buildSectionTitle("Logistics / Drop-off")),
        const SizedBox(height: 10),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(children: [
             _buildDropdown("County", _selectedCounty, _counties, (val) {
               setState(() { 
                 _selectedCounty = val; 
                 _selectedSubCounty = null; 
                 _selectedWard = null; 
                 _wards = [];
                 
                 var countyObj = _locationsData.firstWhere((c) => c['county_name'] == val);
                 var constituencies = countyObj['constituencies'] as List<dynamic>;
                 _subCounties = constituencies.map((c) => c['constituency_name'].toString()).toList();
               });
             }),
             Divider(color: Colors.grey.shade200, height: 1),
             _buildDropdown("Sub-County", _selectedSubCounty, _subCounties, (val) {
               setState(() { 
                 _selectedSubCounty = val; 
                 _selectedWard = null; 
                 
                 var countyObj = _locationsData.firstWhere((c) => c['county_name'] == _selectedCounty);
                 var constituencies = countyObj['constituencies'] as List<dynamic>;
                 var constituencyObj = constituencies.firstWhere((c) => c['constituency_name'] == val);
                 _wards = List<String>.from(constituencyObj['wards']);
               });
             }),
             Divider(color: Colors.grey.shade200, height: 1),
             _buildDropdown("Ward", _selectedWard, _wards, (val) => setState(() => _selectedWard = val)),
             Divider(color: Colors.grey.shade200, height: 1),
             TextFormField(
                controller: _villageController,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  labelText: "Estate / Landmark",
                  labelStyle: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
                  prefixIcon: Icon(LucideIcons.mapPin, color: Colors.teal[700], size: 18),
                  border: InputBorder.none,
                ),
             )
          ]),
        ),

        const SizedBox(height: 40),
        
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[800],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 4,
              shadowColor: Colors.teal.withOpacity(0.3)
            ),
            child: _isLoading 
              ? const CircularProgressIndicator(color: Colors.white) 
              : Text(widget.isNewUser ? "Complete Setup" : "Save Changes", style: GoogleFonts.poppins(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle, 
            border: Border.all(color: Colors.white, width: 4), 
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
          ),
          child: CircleAvatar(
            radius: 55,
            backgroundColor: Colors.white,
            backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
            child: _profileImage == null ? Icon(LucideIcons.building2, size: 45, color: Colors.teal.shade200) : null,
          ),
        ),
        if (_isEditing)
          Positioned(
            bottom: 0, 
            right: 0,
            child: GestureDetector(
              onTap: () async {
                final img = await _picker.pickImage(source: ImageSource.gallery);
                if (img != null) setState(() => _profileImage = File(img.path));
              },
              child: Container(
                padding: const EdgeInsets.all(10), 
                decoration: BoxDecoration(color: Colors.teal.shade700, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), 
                child: const Icon(LucideIcons.camera, color: Colors.white, size: 16)
              ),
            ),
          )
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.teal.shade700),
            const SizedBox(width: 8),
            Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Text(value, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700, height: 1.5)),
      ]),
    );
  }

  Widget _buildSectionTitle(String title) => Align(alignment: Alignment.centerLeft, child: Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)));
  
  Widget _buildModernField(TextEditingController c, String label, IconData icon, {int maxLines = 1, String? hint}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(15), 
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: c, maxLines: maxLines, 
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
          labelStyle: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.teal[700], size: 20), 
          border: InputBorder.none, 
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)
        )
      ),
    );
  }

  Widget _buildDropdown(String label, String? val, List<String> items, Function(String?) changed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: val, isExpanded: true, 
          hint: Text(label, style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 14)), 
          icon: const Icon(LucideIcons.chevronDown, size: 18, color: Colors.grey),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.poppins(fontSize: 14), overflow: TextOverflow.ellipsis))).toList(), 
          onChanged: items.isEmpty ? null : changed
        )
      ),
    );
  }
  
  Widget _buildLocationRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
          Text(value ?? "Not set", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }
}