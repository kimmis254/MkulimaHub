import 'dart:convert';
import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:geolocator/geolocator.dart'; 

import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/home/home_screen.dart';
import 'package:mkulimahub_mobile/features/home/settings_screen.dart'; 

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

  final _bioController = TextEditingController();
  final _cropsController = TextEditingController();
  final _villageController = TextEditingController();

  List<dynamic> _locationsData = []; 
  List<String> _counties = [];
  List<String> _subCounties = [];
  List<String> _wards = [];

  String? _selectedCounty;
  String? _selectedSubCounty;
  String? _selectedWard;
  
  bool _isAtFarm = false;
  double? _latitude;
  double? _longitude;
  bool _isFetchingGps = false;

  File? _profileImage;
  bool _isLoading = false;
  Map<String, dynamic>? _profileData;
  
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
        
        if (mounted) _showSnackBar("✅ Farm GPS captured successfully!", Colors.green.shade700);
      } else {
        if (mounted) _showSnackBar("GPS Permission Denied.", Colors.redAccent);
      }
    } catch (e) {
      if (mounted) _showSnackBar("Failed to get GPS: $e", Colors.redAccent);
    } finally {
      setState(() => _isFetchingGps = false);
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoadingPledges = true);
    
    final data = await _apiClient.getProfile();
    final pledges = await _apiClient.getMyPledges(); 
    
    setState(() {
      _isLoading = false;
      _isLoadingPledges = false;
      _myPledges = pledges; 

      if (data != null) {
        _profileData = data;
        
        _bioController.text = data['bio'] ?? "";
        _cropsController.text = data['main_crops'] ?? "";
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
           Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
        }
      } else {
        await _loadProfile(); 
        setState(() {
          _isLoading = false;
          _isEditing = false;
        });
        if (mounted) _showSnackBar("Profile Updated!", Colors.green.shade700);
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
    String title = widget.isNewUser ? "Create Profile" : (_isEditing ? "Edit Profile" : "My Profile");

    // 🔥 THE FIX: Prevent hardware back button if it's a new user
    return PopScope(
      canPop: !widget.isNewUser,
      onPopInvoked: (didPop) {
        if (!didPop && widget.isNewUser) {
          _showSnackBar("Please complete your farm setup to continue.", Colors.orange.shade700);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: _isLoading && _profileData == null && !widget.isNewUser
            ? const Center(child: CircularProgressIndicator(color: Colors.green))
            : Stack(
                children: [
                  Container(
                    height: MediaQuery.of(context).size.height * 0.35,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.green.shade900, Colors.green.shade500], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (!widget.isNewUser)
                                IconButton(icon: const Icon(LucideIcons.arrowLeft, color: Colors.white), onPressed: () => Navigator.pop(context))
                              else
                                const SizedBox(width: 48), 
                              
                              Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                              
                              if (!_isEditing)
                                IconButton(icon: const Icon(LucideIcons.settings, color: Colors.white), onPressed: () { /* Settings Screen */ })
                              else if (_isEditing && !widget.isNewUser)
                                IconButton(icon: const Icon(LucideIcons.x, color: Colors.white), onPressed: () => setState(() => _isEditing = false))
                              else
                                const SizedBox(width: 48), 
                            ],
                          ),
                        ),
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
              Text(_profileData?['full_name'] ?? "Farmer", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.mapPin, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 6),
                  Text(location, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        
        _buildInfoCard("About", _profileData?['bio'] ?? "No bio added yet.", LucideIcons.user),
        _buildInfoCard("Main Crops", _profileData?['main_crops'] ?? "No crops listed.", LucideIcons.sprout),
        
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 25),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                Icon(LucideIcons.map, size: 18, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text("Detailed Location", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildLocationRow("County", _profileData?['county']),
            _buildLocationRow("Sub-County", _profileData?['sub_county']),
            _buildLocationRow("Ward", _profileData?['ward']),
            _buildLocationRow("Village", _profileData?['village']),
          ]),
        ),

        Text("My Active Contracts", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 15),
        
        _isLoadingPledges 
            ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.green)))
            : _myPledges.isEmpty
                ? Container(
                    width: double.infinity, padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        Icon(LucideIcons.fileText, size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text("No active pledges yet.", style: GoogleFonts.poppins(color: Colors.grey.shade600), textAlign: TextAlign.center),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: _myPledges.length,
                    itemBuilder: (context, index) {
                      final pledge = _myPledges[index];
                      // 🔥 THE FIX: Properly extract the nested bulk_request data!
                      final bulkReq = pledge['bulk_request'] ?? {};
                      final cropName = bulkReq['crop_name'] ?? 'Produce';
                      final buyerName = bulkReq['buyer_name'] ?? 'Unknown Buyer';
                      final pricePerKg = (bulkReq['price_per_kg'] ?? 0).toDouble();
                      final weight = (pledge['pledged_weight_kg'] ?? 0).toDouble();
                      final payout = weight * pricePerKg;
                      final status = pledge['status'] ?? 'unknown';

                      // 🔥 Dynamic UI Styling based on Enterprise Status pipeline
                      String statusText = "Pending Drop-off";
                      Color bgColor = Colors.orange.shade50;
                      Color textColor = Colors.orange.shade800;
                      IconData statusIcon = LucideIcons.packageOpen;

                      if (status == 'pending_audit') {
                        statusText = "Awaiting Audit";
                        bgColor = Colors.amber.shade50;
                        textColor = Colors.amber.shade800;
                        statusIcon = LucideIcons.clock;
                      } else if (status == 'received') {
                        statusText = "Verified at Hub";
                        bgColor = Colors.blue.shade50;
                        textColor = Colors.blue.shade800;
                        statusIcon = LucideIcons.shieldCheck;
                      } else if (status == 'in_transit') {
                        statusText = "In Transit";
                        bgColor = Colors.purple.shade50;
                        textColor = Colors.purple.shade800;
                        statusIcon = LucideIcons.truck;
                      } else if (status == 'delivered') {
                        statusText = "Awaiting Payout";
                        bgColor = Colors.teal.shade50;
                        textColor = Colors.teal.shade800;
                        statusIcon = LucideIcons.mapPin;
                      } else if (status == 'completed' || status == 'paid') {
                        statusText = "Paid";
                        bgColor = Colors.green.shade50;
                        textColor = Colors.green.shade800;
                        statusIcon = LucideIcons.checkCircle;
                      } else if (status == 'rejected') {
                        statusText = "Rejected/No-Show";
                        bgColor = Colors.red.shade50;
                        textColor = Colors.red.shade800;
                        statusIcon = LucideIcons.xCircle;
                      }

                      return FadeInUp(
                        delay: Duration(milliseconds: 100 * index),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(statusIcon, size: 16, color: textColor),
                                        const SizedBox(width: 6),
                                        Text(statusText, style: GoogleFonts.poppins(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    Text("KES $payout", style: GoogleFonts.poppins(color: textColor, fontSize: 14, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                                      child: Icon(LucideIcons.leaf, color: Colors.green.shade700, size: 20),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("${weight}kg of $cropName", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(LucideIcons.building, size: 12, color: Colors.grey.shade500),
                                              const SizedBox(width: 4),
                                              Expanded(child: Text(buyerName, style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
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
                  labelText: "Village / Landmark", labelStyle: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
                  prefixIcon: Icon(LucideIcons.mapPin, color: Colors.green[700], size: 18), border: InputBorder.none,
                ),
             )
          ]),
        ),

        const SizedBox(height: 30),

        FadeInDown(delay: const Duration(milliseconds: 150), child: _buildSectionTitle("AI Clustering Precision")),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isAtFarm ? Colors.green.shade50 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _isAtFarm ? Colors.green.withOpacity(0.3) : Colors.blue.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: Text("Are you currently at your farm?", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text("Boost your visibility by capturing your exact GPS coordinates for bulk buyers.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
                value: _isAtFarm,
                activeColor: Colors.green.shade700,
                contentPadding: EdgeInsets.zero,
                onChanged: (bool value) {
                  setState(() {
                    _isAtFarm = value;
                    if (!value) { _latitude = null; _longitude = null; }
                  });
                },
              ),
              if (_isAtFarm) ...[
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isFetchingGps ? null : _captureFarmGPS,
                    icon: _isFetchingGps 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(LucideIcons.target, color: _latitude != null ? Colors.green.shade800 : Colors.white, size: 18),
                    label: Text(_latitude != null ? "GPS Captured Successfully!" : "Tap to Capture Exact GPS", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _latitude != null ? Colors.green.shade800 : Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _latitude != null ? Colors.green.shade100 : Colors.green.shade700,
                      elevation: _latitude != null ? 0 : 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        _buildModernField(_cropsController, "Main Crops", LucideIcons.sprout, hint: "E.g. Maize, Beans, Potatoes"),

        const SizedBox(height: 40),
        
        SizedBox(
          width: double.infinity, height: 55,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveProfile,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 4, shadowColor: Colors.green.withOpacity(0.3)),
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(widget.isNewUser ? "Create Profile" : "Save Changes", style: GoogleFonts.poppins(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
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
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))]),
          child: CircleAvatar(
            radius: 55, backgroundColor: Colors.white,
            backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
            child: _profileImage == null ? Icon(LucideIcons.user, size: 45, color: Colors.green.shade200) : null,
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
              child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.shade700, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(LucideIcons.camera, color: Colors.white, size: 16)),
            ),
          )
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      width: double.infinity, margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 18, color: Colors.green.shade700), const SizedBox(width: 8), Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87))]),
        const SizedBox(height: 12), const Divider(height: 1), const SizedBox(height: 12),
        Text(value, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700, height: 1.5)),
      ]),
    );
  }

  Widget _buildSectionTitle(String title) => Align(alignment: Alignment.centerLeft, child: Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)));
  
  Widget _buildModernField(TextEditingController c, String label, IconData icon, {int maxLines = 1, String? hint}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: TextField(
        controller: c, maxLines: maxLines, style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(labelText: label, hintText: hint, hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13), labelStyle: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13), prefixIcon: Icon(icon, color: Colors.green[700], size: 20), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16))
      ),
    );
  }

  Widget _buildDropdown(String label, String? val, List<String> items, Function(String?) changed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: val, isExpanded: true, hint: Text(label, style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 14)), icon: const Icon(LucideIcons.chevronDown, size: 18, color: Colors.grey),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.poppins(fontSize: 14), overflow: TextOverflow.ellipsis))).toList(), onChanged: items.isEmpty ? null : changed
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