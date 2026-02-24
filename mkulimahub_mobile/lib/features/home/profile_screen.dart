import 'dart:convert';
import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:geolocator/geolocator.dart'; // NEW: GPS Package
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/auth/login_screen.dart';
import 'package:mkulimahub_mobile/features/home/home_screen.dart'; 

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

  // --- Location State ---
  List<dynamic> _locationsData = []; 
  List<String> _counties = [];
  List<String> _subCounties = [];
  List<String> _wards = [];

  String? _selectedCounty;
  String? _selectedSubCounty;
  String? _selectedWard;
  
  // --- Smart GPS State ---
  bool _isAtFarm = false;
  double? _latitude;
  double? _longitude;
  bool _isFetchingGps = false;

  File? _profileImage;
  bool _isLoading = false;
  Map<String, dynamic>? _profileData;
  
  // --- NEW: Pledges State ---
  bool _isLoadingPledges = true;
  List<dynamic> _myPledges = [];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.isNewUser;
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    await _loadLocationData();
    await _loadProfile();
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

  Future<void> _captureFarmGPS() async {
    setState(() => _isFetchingGps = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Farm GPS captured successfully!"), backgroundColor: Colors.green));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("GPS Permission Denied."), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to get GPS: $e"), backgroundColor: Colors.red));
    } finally {
      setState(() => _isFetchingGps = false);
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoadingPledges = true);
    
    final data = await _apiClient.getProfile();
    final pledges = await _apiClient.getMyPledges(); // Fetch pledges
    
    setState(() {
      _isLoading = false;
      _isLoadingPledges = false;
      _myPledges = pledges; // Save pledges

      if (data != null) {
        _profileData = data;
        
        _bioController.text = data['bio'] ?? "";
        _cropsController.text = data['main_crops'] ?? "";
        _villageController.text = data['village'] ?? ""; 
        
        // Safe cascading load from JSON
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
      "latitude": _latitude,
      "longitude": _longitude,
    };

    final error = await _apiClient.updateProfile(data);

    if (error == null) {
      if (widget.isNewUser) {
        if (mounted) {
           Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false
          );
        }
      } else {
        await _loadProfile(); 
        setState(() {
          _isLoading = false;
          _isEditing = false;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!"), backgroundColor: Colors.green));
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.isNewUser ? "Create Profile" : (_isEditing ? "Edit Profile" : "My Profile");

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
          if (!_isEditing)
             IconButton(
              icon: const Icon(LucideIcons.settings, color: Colors.black),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Settings Coming Soon!"))),
            ),
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
                  _buildProfileImage(),
                  const SizedBox(height: 30),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isEditing ? _buildEditForm() : _buildViewMode(),
                  ),
                ],
              ),
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
        Center(child: Text(_profileData?['full_name'] ?? "Farmer", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold))),
        Center(child: Text(location, style: GoogleFonts.poppins(color: Colors.grey[600]))),
        const SizedBox(height: 30),
        
        _buildInfoCard("About", _profileData?['bio'] ?? "No bio added yet."),
        _buildInfoCard("Crops", _profileData?['main_crops'] ?? "No crops listed."),
        
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 25),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Detailed Location", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 5),
            _buildLocationRow("County", _profileData?['county']),
            _buildLocationRow("Sub-County", _profileData?['sub_county']),
            _buildLocationRow("Ward", _profileData?['ward']),
            _buildLocationRow("Village", _profileData?['village']),
          ]),
        ),

        // --- NEW: MY ACTIVE PLEDGES SECTION ---
        Text("My Active Contracts", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 10),
        
        _isLoadingPledges 
            ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.green)))
            : _myPledges.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 25),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
                    child: Text("You haven't pledged to any contracts yet.", style: GoogleFonts.poppins(color: Colors.grey), textAlign: TextAlign.center),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 25),
                    itemCount: _myPledges.length,
                    itemBuilder: (context, index) {
                      final pledge = _myPledges[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
                              child: const Icon(LucideIcons.checkCircle, color: Colors.green),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("${pledge['pledged_weight_kg']}kg ${pledge['crop_name']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text("For: ${pledge['buyer_name']}", style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(20)),
                              child: Text(pledge['status'], style: GoogleFonts.poppins(color: Colors.blue[800], fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                      );
                    },
                  ),

        const SizedBox(height: 10),
        
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
        
        Center(
          child: TextButton.icon(
             icon: const Icon(LucideIcons.logOut, color: Colors.red),
             label: const Text("Log Out", style: TextStyle(color: Colors.red)),
             onPressed: () async {
               await _apiClient.logout();
               if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
             },
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

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
        
        // --- Dynamic Cascading Location Card ---
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(15),
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
             const Divider(),
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
             const Divider(),
             _buildDropdown("Ward", _selectedWard, _wards, (val) => setState(() => _selectedWard = val)),
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

        // --- Smart GPS Toggle ---
        FadeInDown(delay: const Duration(milliseconds: 150), child: _buildSectionTitle("AI Clustering Precision")),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: Text("Are you currently at your farm?", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text("Boost your visibility by capturing your exact GPS coordinates for bulk buyers.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
                value: _isAtFarm,
                activeColor: Colors.green,
                contentPadding: EdgeInsets.zero,
                onChanged: (bool value) {
                  setState(() {
                    _isAtFarm = value;
                    if (!value) {
                      _latitude = null;
                      _longitude = null;
                    }
                  });
                },
              ),
              if (_isAtFarm) ...[
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isFetchingGps ? null : _captureFarmGPS,
                    icon: _isFetchingGps 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(LucideIcons.mapPin, color: Colors.white),
                    label: Text(
                      _latitude != null ? "GPS Captured Successfully" : "Tap to Capture Exact GPS", 
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _latitude != null ? Colors.green[800] : Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),

        const SizedBox(height: 30),
        FadeInDown(delay: const Duration(milliseconds: 200), child: _buildSectionTitle("Farming Details")),
        const SizedBox(height: 10),
        _buildModernField(_cropsController, "Main Crops", LucideIcons.sprout, hint: "Maize, Beans, etc."),

        const SizedBox(height: 40),
        
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
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.poppins(fontSize: 14), overflow: TextOverflow.ellipsis))).toList(), 
        onChanged: items.isEmpty ? null : changed
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