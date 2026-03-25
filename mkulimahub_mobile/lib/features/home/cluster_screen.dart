import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/home/hub_chat_screen.dart'; 

class ClusterScreen extends StatefulWidget {
  const ClusterScreen({super.key});

  @override
  State<ClusterScreen> createState() => _ClusterScreenState();
}

class _ClusterScreenState extends State<ClusterScreen> {
  final ApiClient _apiClient = ApiClient();
  
  bool _isLoading = false;
  String _selectedCrop = 'All';
  final List<String> _crops = ['All', 'Mangoes', 'Maize', 'Beans'];
  
  List<dynamic> _hubs = [];
  List<dynamic> _pendingRequests = [];
  List<dynamic> _independentFarmers = []; 
  int _totalFarmersAnalyzed = 0;
  String? _errorMessage;
  
  // 🔥 In a real app, this would be fetched from the backend or shared preferences
  final String _currentUserId = "USER_123"; 
  String? _myClusterId; 

  @override
  void initState() {
    super.initState();
    _fetchClusters();
  }

  Future<void> _fetchClusters() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cropParam = _selectedCrop == 'All' ? null : _selectedCrop;
      
      // 🔥 1. Fetch everything concurrently for maximum speed
      final results = await Future.wait([
        _apiClient.getClusters(cropParam),
        _apiClient.getProfile(),
        _apiClient.getCoordinatorRequests(), // Will return empty if not a coordinator
      ]);

      final clusterData = results[0] as Map<String, dynamic>?;
      final profileData = results[1] as Map<String, dynamic>?;
      final pendingReqs = results[2] as List<dynamic>?;
      
      if (clusterData != null && mounted) {
        setState(() {
          _hubs = clusterData['hubs'] ?? [];
          _independentFarmers = clusterData['independent_farmers'] ?? [];
          _totalFarmersAnalyzed = clusterData['total_farmers_analyzed'] ?? 0;
          
          // 🔥 2. Set Coordinator Requests so the UI Banner shows up!
          _pendingRequests = pendingReqs ?? [];

          // 🔥 3. Dynamically set the exact Hub Status from the database!
          final myHubId = profileData?['hub_id'];
          
          if (myHubId != null) {
            // Find the name of the hub they belong to from the list
            final myHub = _hubs.firstWhere(
              (h) => h['hub_id'] == myHubId, 
              orElse: () => <String, dynamic>{}
            );
            _myClusterId = myHub.isNotEmpty ? myHub['hub_name'] : "My Co-op Hub";
          } else {
            _myClusterId = null; // Leaves them as Independent/Noise
          }
          
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
             _errorMessage = "Failed to load network data.";
             _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Connection error. Please try again.";
          _isLoading = false;
        });
      }
    }
  }

  // Helper to simulate finding the current user's status
  String? _findMyCluster() {
    // This is placeholder logic. 
    // Ideally, the backend just tells you: "You are in Cluster 3" or "You are Independent".
    return null; 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.green.shade800,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, 
        title: Text(
          "MkulimaHub Network",
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // 🔥 Header & Filter Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.green.shade800,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Network Scale", 
                        style: GoogleFonts.poppins(color: Colors.green.shade200, fontSize: 12)
                      ),
                      Text(
                        "$_totalFarmersAnalyzed Active Farmers", 
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCrop,
                      icon: const Icon(LucideIcons.filter, size: 16, color: Colors.green),
                      items: _crops.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCrop = val);
                          _fetchClusters();
                        }
                      },
                    ),
                  ),
                )
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading 
                ? _buildAILoadingState() 
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : RefreshIndicator(
                        color: Colors.green,
                        onRefresh: _fetchClusters,
                        child: ListView(
                          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 80),
                          children: [
                            if (_pendingRequests.isNotEmpty)
                              FadeInDown(child: _buildCoordinatorBanner()),

                            _buildMyStatusCard(),
                            const SizedBox(height: 25),

                            // 🔥 2. Show the Hubs
                            if (_hubs.isNotEmpty) ...[
                              Text("Active Co-op Hubs", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                              const SizedBox(height: 15),
                              ..._hubs.asMap().entries.map((entry) => FadeInUp(
                                delay: Duration(milliseconds: 100 * entry.key),
                                child: _buildHubCard(entry.value),
                              )),
                            ] else ...[
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(40.0),
                                  child: Text("No hubs found for $_selectedCrop.", style: GoogleFonts.poppins(color: Colors.grey)),
                                ),
                              )
                            ],

                            const SizedBox(height: 30),

                            // 🔥 3. Show Independent Farmers (Noise)
                            if (_independentFarmers.isNotEmpty) ...[
                              Divider(color: Colors.grey.shade300),
                              const SizedBox(height: 15),
                              Text("Independent Farmers", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                              Text("Outside current hub radii", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 15),
                              ..._independentFarmers.map((farmer) => _buildIndependentFarmerTile(farmer)),
                            ]
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // 🔥 NEW: Displays the user's current status and offers a "Join" button if they are independent
  Widget _buildMyStatusCard() {
    bool isIndependent = _myClusterId == null; // Assuming null means they are noise for now

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isIndependent ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isIndependent ? Colors.orange.shade200 : Colors.green.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isIndependent ? Colors.orange.shade100 : Colors.green.shade100,
              shape: BoxShape.circle
            ),
            child: Icon(
              isIndependent ? LucideIcons.alertCircle : LucideIcons.checkCircle, 
              color: isIndependent ? Colors.orange.shade700 : Colors.green.shade700
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Your Status", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                Text(
                  isIndependent ? "Independent (Unclustered)" : "Member of $_myClusterId", 
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)
                ),
              ],
            ),
          ),
          if (isIndependent)
            ElevatedButton(
              onPressed: _showNearbyHubsBottomSheet, // 🔥 THE FIX: Call the new function
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text("Join a Hub", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            )
        ],
      ),
    );
  }

  Widget _buildAILoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Pulse(
            infinite: true,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(LucideIcons.radar, size: 40, color: Colors.green),
            ),
          ),
          const SizedBox(height: 25),
          Pulse(
            infinite: true,
            child: Text(
              "DBSCAN AI is analyzing spatial\nfarmer density to create optimal hubs...",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.green[700], fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHubCard(Map<String, dynamic> hub) {
    int farmerCount = hub['farmer_count'] ?? 0;
    String hubName = hub['hub_name'] ?? 'Regional Hub';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.mapPin, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hubName, style: GoogleFonts.poppins(color: Colors.green.shade900, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text("High Density Zone", style: GoogleFonts.poppins(color: Colors.green.shade700, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.users, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text("$farmerCount", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                    ],
                  ),
                )
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showFarmersBottomSheet(hub),
                    icon: const Icon(LucideIcons.list, size: 16),
                    label: Text("View Members", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // 🔥 THIS IS THE FIX: Actually navigate to the chat screen
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => HubChatScreen(hubName: hubName))
                      );
                    },
                    icon: const Icon(LucideIcons.messageSquare, size: 16, color: Colors.white),
                    label: Text("Co-op Chat", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // 🔥 NEW: A stripped-down tile for independent farmers (no phone numbers!)
  Widget _buildIndependentFarmerTile(Map<String, dynamic> farmer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey.shade100,
            child: Icon(LucideIcons.user, color: Colors.grey.shade500, size: 18),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(farmer['name'] ?? 'Unknown Farmer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(farmer['crops'] ?? "No crops listed", style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade700)),
                Text("${farmer['village'] ?? 'Unknown Village'}, ${farmer['ward'] ?? 'Unknown Ward'}", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showFarmersBottomSheet(Map<String, dynamic> hub) {
    List<dynamic> farmers = hub['farmers'] ?? [];
    String hubName = hub['hub_name'] ?? 'Regional Hub';

    if (farmers.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 20),
                  Text("$hubName Members", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text("Phone numbers are hidden for privacy. Use the Co-op Chat to communicate.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange.shade700)),
                  const SizedBox(height: 15),
                  
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: farmers.length,
                      itemBuilder: (context, index) {
                        final f = farmers[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          leading: CircleAvatar(backgroundColor: Colors.green[50], child: Text(f['name'][0].toUpperCase(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                          title: Text(f['name'] ?? 'Unknown', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          subtitle: Text("${f['village'] ?? ''} • ${f['crops'] ?? ''}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                          // 🔥 Removed the trailing call button entirely
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }
  void _showNearbyHubsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      backgroundColor: Colors.white,
      builder: (context) {
        return FutureBuilder<List<dynamic>?>(
          future: _apiClient.getNearbyHubs(),
          builder: (context, snapshot) {
            
            // 1. Loading State
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator(color: Colors.green)),
              );
            }

            // 2. Error State
            if (snapshot.hasError || snapshot.data == null) {
              return const SizedBox(
                height: 300,
                child: Center(child: Text("Failed to load nearby hubs.")),
              );
            }

            // 3. Empty State (No hubs in their radius)
            final hubs = snapshot.data!;
            if (hubs.isEmpty) {
              return SizedBox(
                height: 300,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.mapPinOff, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 15),
                      Text("No active hubs near you yet.", style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                      Text("You might be the pioneer!", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              );
            }

            // 4. Success State (Show the Hubs!)
            return Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 20),
                  Text("Nearby Hubs", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Select a co-op to send a join request.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 15),
                  
                  // Map through the hubs returned from FastAPI
                  ...hubs.map((hub) => _buildNearbyHubTile(hub)).toList(),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildNearbyHubTile(Map<String, dynamic> hub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200)
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: const Icon(LucideIcons.mapPin, color: Colors.green),
        ),
        title: Text(hub['hub_name'] ?? 'Unknown Hub', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text("${hub['distance_km']} km away • ${hub['crop']}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
        trailing: ElevatedButton(
          onPressed: () => _sendJoinRequest(hub['hub_id']),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade600,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text("Request", style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _sendJoinRequest(int hubId) async {
    // 1. Close the bottom sheet immediately so the UI feels snappy
    Navigator.pop(context); 
    
    // 2. Show a loading indicator
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sending request..."), duration: Duration(seconds: 1)));
    
    // 3. Ping FastAPI
    final error = await _apiClient.joinHub(hubId);
    
    if (!mounted) return;

    // 4. Show the result
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Join request sent successfully!"), backgroundColor: Colors.green));
    } else {
      // If they already sent a request, FastAPI will return that message here
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
    }
  }
  Widget _buildCoordinatorBanner() {
    return GestureDetector(
      onTap: _showCoordinatorBottomSheet,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade600]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(LucideIcons.shieldCheck, color: Colors.white),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("👑 Co-op Coordinator", style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue.shade100, fontWeight: FontWeight.bold)),
                  Text(
                    "${_pendingRequests.length} Pending Join Requests", 
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: Colors.white)
          ],
        ),
      ),
    );
  }

  void _showCoordinatorBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  Text("Manage Co-op Requests", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Review farmers who want to aggregate with your hub.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 15),
                  
                  if (_pendingRequests.isEmpty)
                    const Expanded(child: Center(child: Text("All caught up! No pending requests.")))
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _pendingRequests.length,
                        itemBuilder: (context, index) {
                          final req = _pendingRequests[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(12)
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(backgroundColor: Colors.blue.shade50, child: const Icon(LucideIcons.user, color: Colors.blue, size: 18)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(req['farmer_name'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                          Text("${req['village']} • ${req['crops']}", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
                                          Text(req['farmer_phone'], style: GoogleFonts.poppins(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          final error = await _apiClient.respondToHubRequest(req['request_id'], "reject");
                                          if (error == null) {
                                            setSheetState(() => _pendingRequests.removeAt(index));
                                            _fetchClusters(); // Refresh data in background
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                        child: const Text("Decline"),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          final error = await _apiClient.respondToHubRequest(req['request_id'], "approve");
                                          if (error == null) {
                                            setSheetState(() => _pendingRequests.removeAt(index));
                                            _fetchClusters(); // Refresh data in background
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Farmer added to your Hub!"), backgroundColor: Colors.green));
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                        child: const Text("Approve"),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          }
        );
      }
    );
  }
}