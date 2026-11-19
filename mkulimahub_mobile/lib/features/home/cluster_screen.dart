import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api/api_client.dart';
import 'package:mkulimahub_mobile/features/home/hub_chat_screen.dart';
import 'package:mkulimahub_mobile/features/home/receiving_dashboard.dart'; 
import 'package:mkulimahub_mobile/features/home/delivery_squads_screen.dart'; 
import 'package:mkulimahub_mobile/features/home/contracts_screen.dart';  
import 'package:mkulimahub_mobile/features/home/home_screen.dart';     

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
  List<dynamic> _activeSquads = []; 
  int _totalFarmersAnalyzed = 0;
  String? _errorMessage;
  
  Map<String, dynamic>? _currentUser;
  bool _isCoordinator = false;
  String? _myClusterId;
  int? _selectedSquadId;

  String? _electionStatus;
  bool _hasVoted = false;
  List<dynamic> _candidates = [];

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
      
      final results = await Future.wait([
        _apiClient.getClusters(cropParam),
        _apiClient.getProfile(),
        _apiClient.getCoordinatorRequests(), 
        _apiClient.getElectionBallot(), 
      ]);

      final clusterData = results[0] as Map<String, dynamic>?;
      final profileData = results[1] as Map<String, dynamic>?;
      final pendingReqs = results[2] as List<dynamic>?;
      final ballotData = results[3] as Map<String, dynamic>?;
      
      if (clusterData != null && mounted) {
        setState(() {
          _hubs = clusterData['hubs'] ?? [];
          _independentFarmers = clusterData['independent_farmers'] ?? [];
          _activeSquads = clusterData['active_squads'] ?? []; 
          _totalFarmersAnalyzed = clusterData['total_farmers_analyzed'] ?? 0;
          _pendingRequests = pendingReqs ?? [];
          _currentUser = profileData;

          if (_activeSquads.isNotEmpty) {
            if (_selectedSquadId == null || !_activeSquads.any((s) => s['id'] == _selectedSquadId)) {
              _selectedSquadId = _activeSquads.first['id'];
            }
          } else {
            _selectedSquadId = null;
          }
          
          if (ballotData != null) {
            _electionStatus = ballotData['status'];
            _hasVoted = ballotData['has_voted'] ?? false;
            _candidates = ballotData['candidates'] ?? [];
          }

          final myHubId = profileData?['hub_id'];
          if (myHubId != null) {
            final myHub = _hubs.firstWhere((h) => h['hub_id'] == myHubId, orElse: () => <String, dynamic>{});
            _myClusterId = myHub.isNotEmpty ? myHub['hub_name'] : "My Co-op Hub";
            _isCoordinator = myHub.isNotEmpty && myHub['coordinator_id'].toString() == _currentUser?['id'].toString();
          } else {
            _myClusterId = null; 
            _isCoordinator = false;
          }
          
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() { _errorMessage = "Failed to load network data."; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = "Connection error. Please try again."; _isLoading = false; });
    }
  }

  // 🔥 THE FIX: A dedicated function to run AI Clustering
  Future<void> _triggerManualClustering() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Booting up DBSCAN AI algorithm..."), duration: Duration(seconds: 2))
    );
    
    // 🔥 FIXED: Now it sends exactly what is selected, including "All"!
    final cropToCluster = _selectedCrop; 
    
    final error = await _apiClient.triggerAdminClustering(cropToCluster);
    
    if (!mounted) return;
    
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Clustering Complete! Hubs formed."), backgroundColor: Colors.green)
      );
      _fetchClusters(); 
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
    }
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
        title: Text("MkulimaHub Network", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          // 🔥 NEW: Highly visible Top-Right Button
          TextButton.icon(
            icon: const Icon(LucideIcons.cpu, color: Colors.white, size: 16), 
            label: Text("Run AI", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: _triggerManualClustering,
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(color: Colors.green.shade800, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Network Scale", style: GoogleFonts.poppins(color: Colors.green.shade200, fontSize: 12)),
                      Text("$_totalFarmersAnalyzed Active Farmers", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
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
                            if (_isCoordinator) FadeInDown(child: _buildCoordinatorBanner()),
                            if (_electionStatus == 'voting_active') FadeInDown(child: _buildElectionBanner()),

                            _buildMyStatusCard(),
                            const SizedBox(height: 25),

                            ...(() {
                              final filteredSquads = _activeSquads.where((squad) {
                                bool isInternalPool = squad['buyer_name'].toString().startsWith('Hub Pool:');
                                String hubNameClean = squad['buyer_name'].toString().replaceFirst("Hub Pool: ", "").trim();
                                bool isMyHubsPool = _myClusterId == hubNameClean;
                                return !(isInternalPool && !isMyHubsPool);
                              }).toList();

                              if (filteredSquads.isEmpty) return [const SizedBox.shrink()]; 

                              int currentSelection = filteredSquads.any((s) => s['id'] == _selectedSquadId) ? _selectedSquadId! : filteredSquads.first['id'];

                              return [
                                Row(
                                  children: [
                                    const Icon(LucideIcons.zap, color: Colors.orange, size: 20),
                                    const SizedBox(width: 8),
                                    Text("Active Delivery Squads", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                  ],
                                ),
                                Text("Select a team to view or join.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                                const SizedBox(height: 15),

                                Container(
                                  width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: currentSelection, isExpanded: true, icon: const Icon(LucideIcons.chevronDown, color: Colors.orange),
                                      items: filteredSquads.map<DropdownMenuItem<int>>((squad) {
                                        bool isInternalPool = squad['buyer_name'].toString().startsWith('Hub Pool:');
                                        String displayName = isInternalPool ? "${squad['target_weight_kg']}kg ${squad['crop_name']} (Internal Hub Pool)" : "${squad['target_weight_kg']}kg ${squad['crop_name']} for ${squad['buyer_name']}";
                                        return DropdownMenuItem<int>(value: squad['id'], child: Text(displayName, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis));
                                      }).toList(),
                                      onChanged: (int? newValue) { if (newValue != null) setState(() => _selectedSquadId = newValue); },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                Builder(
                                  builder: (context) {
                                    final selectedSquad = filteredSquads.firstWhere((s) => s['id'] == currentSelection);
                                    bool isInternalPool = selectedSquad['buyer_name'].toString().startsWith('Hub Pool:');
                                    String hubNameClean = selectedSquad['buyer_name'].toString().replaceFirst("Hub Pool: ", "").trim();

                                    final pledges = selectedSquad['pledges'] as List<dynamic>? ?? [];
                                    bool hasPledged = _currentUser != null && pledges.any((p) => p['farmer_id'].toString() == _currentUser?['id'].toString());
                                    bool isSquadCoordinator = selectedSquad['coordinator_id']?.toString() == _currentUser?['id']?.toString();
                                    bool canViewSquad = hasPledged || isSquadCoordinator;

                                    return FadeIn(
                                      key: ValueKey(currentSelection), 
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(color: canViewSquad ? Colors.purple.shade50 : (isInternalPool ? Colors.blue.shade50 : Colors.orange.shade50), border: Border.all(color: canViewSquad ? Colors.purple.shade200 : (isInternalPool ? Colors.blue.shade200 : Colors.orange.shade200)), borderRadius: BorderRadius.circular(16)),
                                        child: Row(
                                          children: [
                                            Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(canViewSquad ? LucideIcons.users : (isInternalPool ? LucideIcons.shield : LucideIcons.truck), color: canViewSquad ? Colors.purple : (isInternalPool ? Colors.blue.shade700 : Colors.orange))),
                                            const SizedBox(width: 15),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("Target: ${selectedSquad['target_weight_kg']}kg", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                                                  Text(canViewSquad ? (isSquadCoordinator ? "You manage this squad" : "You are in this squad") : "Open for pledges", style: GoogleFonts.poppins(fontSize: 12, color: canViewSquad ? Colors.purple.shade800 : (isInternalPool ? Colors.blue.shade800 : Colors.orange.shade800))),
                                                ],
                                              ),
                                            ),
                                            canViewSquad
                                                ? ElevatedButton(
                                                    onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => DeliverySquadsScreen(targetSquadId: selectedSquad['id']))); if (mounted) _fetchClusters(); },
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade600, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                                    child: Text("View", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                                  )
                                                : ElevatedButton(
      onPressed: () async {
        if (isInternalPool) await Navigator.push(context, MaterialPageRoute(builder: (_) => HubChatScreen(hubName: hubNameClean)));
        else await Navigator.push(context, MaterialPageRoute(builder: (_) => const ContractsScreen()));
        
        if (mounted) {
          _fetchClusters(); 
          dashboardKey.currentState?.loadDashboardData(); 
        }
      },
      style: ElevatedButton.styleFrom(backgroundColor: isInternalPool ? Colors.blue.shade600 : Colors.orange.shade600, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      child: Text(isInternalPool ? "Open Chat" : "Join", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
    )
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                ),
                                const SizedBox(height: 25),
                              ];
                            }()),
                            
                            if (_hubs.isNotEmpty) ...[
                              Text("Active Co-op Hubs", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                              const SizedBox(height: 15),
                              ..._hubs.asMap().entries.map((entry) => FadeInUp(delay: Duration(milliseconds: 100 * entry.key), child: _buildHubCard(entry.value))),
                            ] else ...[
                              Center(child: Padding(padding: const EdgeInsets.all(40.0), child: Text("No hubs found for $_selectedCrop.", style: GoogleFonts.poppins(color: Colors.grey))))
                            ],

                            const SizedBox(height: 30),

                            if (_independentFarmers.isNotEmpty) ...[
                              Divider(color: Colors.grey.shade300),
                              const SizedBox(height: 15),
                              
                              // 🔥 NEW: MASSIVE IN-BODY MANUAL CLUSTERING BUTTON
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Independent Farmers", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                      Text("Outside current hub radii", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _triggerManualClustering,
                                    icon: const Icon(LucideIcons.cpu, size: 14, color: Colors.white),
                                    label: Text("Run AI Tool", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                  )
                                ],
                              ),
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

  // --- Helper Widgets Below ---

  Widget _buildMyStatusCard() {
    bool isIndependent = _myClusterId == null; 

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isIndependent ? Colors.orange.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: isIndependent ? Colors.orange.shade200 : Colors.green.shade200)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isIndependent ? Colors.orange.shade100 : Colors.green.shade100, shape: BoxShape.circle), child: Icon(isIndependent ? LucideIcons.alertCircle : LucideIcons.checkCircle, color: isIndependent ? Colors.orange.shade700 : Colors.green.shade700)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Your Status", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                Text(isIndependent ? "Independent (Unclustered)" : "Member of $_myClusterId", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
              ],
            ),
          ),
          if (isIndependent)
            ElevatedButton(
              onPressed: _showNearbyHubsBottomSheet, 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade600, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: Size.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
          Pulse(infinite: true, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(LucideIcons.radar, size: 40, color: Colors.green))),
          const SizedBox(height: 25),
          Pulse(infinite: true, child: Text("DBSCAN AI is analyzing spatial\nfarmer density to create optimal hubs...", textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.green[700], fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildHubCard(Map<String, dynamic> hub) {
    int farmerCount = hub['farmer_count'] ?? 0;
    String hubName = hub['hub_name'] ?? 'Regional Hub';
    int hubId = hub['hub_id'];
    
    bool isMyHub = _currentUser?['hub_id'] == hubId;
    bool isIndependent = _currentUser?['hub_id'] == null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))], border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isMyHub ? Colors.green.shade50 : Colors.grey.shade50, borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
            child: Row(
              children: [
                Icon(isMyHub ? LucideIcons.mapPin : LucideIcons.shield, color: isMyHub ? Colors.green : Colors.grey, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hubName, style: GoogleFonts.poppins(color: isMyHub ? Colors.green.shade900 : Colors.grey.shade800, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(isMyHub ? "Your Hub" : "High Density Zone", style: GoogleFonts.poppins(color: isMyHub ? Colors.green.shade700 : Colors.grey.shade500, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: Row(
                    children: [
                      Icon(LucideIcons.users, size: 14, color: isMyHub ? Colors.green : Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text("$farmerCount", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isMyHub ? Colors.green.shade800 : Colors.grey.shade700)),
                    ],
                  ),
                )
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: isMyHub 
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showFarmersBottomSheet(hub),
                        icon: const Icon(LucideIcons.list, size: 16),
                        label: Text("View Members", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade700, side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => HubChatScreen(hubName: hubName))); if (mounted) _fetchClusters(); },
                        icon: const Icon(LucideIcons.messageSquare, size: 16, color: Colors.white),
                        label: Text("Co-op Chat", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: null, 
                        icon: const Icon(LucideIcons.lock, size: 16),
                        label: Text("Private Co-op", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(disabledForegroundColor: Colors.grey.shade400, side: BorderSide(color: Colors.grey.shade200), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                    if (isIndependent) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _sendJoinRequest(hubId),
                          icon: const Icon(LucideIcons.userPlus, size: 16, color: Colors.white),
                          label: Text("Request to Join", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade600, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        ),
                      ),
                    ]
                  ],
                ),
          )
        ],
      ),
    );
  }

  Widget _buildIndependentFarmerTile(Map<String, dynamic> farmer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.grey.shade100, child: Icon(LucideIcons.user, color: Colors.grey.shade500, size: 18)),
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
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  Text("$hubName Members", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text("Phone numbers are hidden for privacy. Use the Co-op Chat to communicate.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange.shade700)),
                  const SizedBox(height: 15),
                  
                  Expanded(
                    child: ListView.builder(
                      controller: controller, itemCount: farmers.length,
                      itemBuilder: (context, index) {
                        final f = farmers[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          leading: CircleAvatar(backgroundColor: Colors.green[50], child: Text(f['name'][0].toUpperCase(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                          title: Text(f['name'] ?? 'Unknown', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          subtitle: Text("${f['village'] ?? ''} • ${f['crops'] ?? ''}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
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
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return FutureBuilder<List<dynamic>?>(
          future: _apiClient.getNearbyHubs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: Colors.green)));
            if (snapshot.hasError || snapshot.data == null) return const SizedBox(height: 300, child: Center(child: Text("Failed to load nearby hubs.")));

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

            return Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  Text("Nearby Hubs", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Select a co-op to send a join request.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 15),
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
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(backgroundColor: Colors.green.shade100, child: const Icon(LucideIcons.mapPin, color: Colors.green)),
        title: Text(hub['hub_name'] ?? 'Unknown Hub', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text("${hub['distance_km']} km away • ${hub['crop']}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
        trailing: ElevatedButton(
          onPressed: () => _sendJoinRequest(hub['hub_id']),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade600, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: Text("Request", style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _sendJoinRequest(int hubId) async {
    Navigator.pop(context); 
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sending request..."), duration: Duration(seconds: 1)));
    final error = await _apiClient.joinHub(hubId);
    if (!mounted) return;

    if (error == null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Join request sent successfully!"), backgroundColor: Colors.green));
    else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
  }

  Widget _buildCoordinatorBanner() {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context, backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  Text("Coordinator Actions", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: const Icon(LucideIcons.users, color: Colors.blue)),
                    title: Text("Manage Join Requests", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    subtitle: Text("${_pendingRequests.length} pending approvals", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                    trailing: const Icon(LucideIcons.chevronRight, size: 16),
                    onTap: () { Navigator.pop(context); _showCoordinatorBottomSheet(); },
                  ),
                  Divider(color: Colors.grey.shade200),
                  
                  // 🔥 THE FIX: Give the Hub Admin their true power (Managing Hub Pools!)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(backgroundColor: Colors.green.shade50, child: const Icon(LucideIcons.store, color: Colors.green)),
                    title: Text("Manage Hub Pools", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    subtitle: Text("Create wholesale pools in Co-op Chat", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                    trailing: const Icon(LucideIcons.chevronRight, size: 16),
                    onTap: () { 
                      Navigator.pop(context); 
                      // Route them directly to their Hub Chat to post POOL_REQ commands
                      Navigator.push(context, MaterialPageRoute(builder: (_) => HubChatScreen(hubName: _myClusterId ?? "Co-op"))); 
                    },
                  ),
                ],
              ),
            );
          }
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade600]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(LucideIcons.shieldCheck, color: Colors.white)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("👑 Co-op Coordinator", style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue.shade100, fontWeight: FontWeight.bold)),
                  Text("Manage Hub Operations", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
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
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6, padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  Text("Manage Co-op Requests", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Review farmers who want to aggregate with your hub.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 15),
                  
                  if (_pendingRequests.isEmpty) const Expanded(child: Center(child: Text("All caught up! No pending requests.")))
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _pendingRequests.length,
                        itemBuilder: (context, index) {
                          final req = _pendingRequests[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
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
                                          if (error == null) { setSheetState(() => _pendingRequests.removeAt(index)); _fetchClusters(); }
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
                                            setSheetState(() => _pendingRequests.removeAt(index)); _fetchClusters(); 
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

  Widget _buildElectionBanner() {
    bool isEmpty = _candidates.isEmpty;
    return GestureDetector(
      onTap: _showElectionSheet,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.purple.shade800, Colors.deepPurple.shade600]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: Icon(isEmpty ? LucideIcons.megaphone : LucideIcons.vote, color: Colors.white)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("🏛️ Hub Democracy", style: GoogleFonts.poppins(fontSize: 12, color: Colors.purple.shade100, fontWeight: FontWeight.bold)),
                  Text(isEmpty ? "Step up as Coordinator!" : "Election in Progress", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                ],
              ),
            ),
            if (!isEmpty && !_hasVoted) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)), child: Text("Vote Now", style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))
            else const Icon(LucideIcons.chevronRight, color: Colors.white)
          ],
        ),
      ),
    );
  }

  void _showElectionSheet() {
    final TextEditingController pitchController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            bool hasPitched = _currentUser != null && _candidates.any((c) => c['farmer_id'] == _currentUser!['id']);

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8), padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 20),
                      Text("Hub Election", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("Vote for your Coordinator. First to >50% wins!", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 15),
                      
                      if (_hasVoted)
                        Container(
                          padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade200)),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.checkCircle, color: Colors.green, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text("You have securely cast your vote. Waiting for results...", style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade800))),
                            ],
                          ),
                        ),

                      if (_candidates.isNotEmpty) ...[
                        Text("Current Candidates:", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                        const SizedBox(height: 10),
                        ..._candidates.map((c) => Container(
                          margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(border: Border.all(color: Colors.purple.shade100), borderRadius: BorderRadius.circular(16), color: Colors.purple.shade50.withOpacity(0.3)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(backgroundColor: Colors.purple.shade100, child: const Icon(LucideIcons.user, color: Colors.purple)),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c['farmer_name'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text("${c['votes']} Votes Cast", style: GoogleFonts.poppins(color: Colors.purple.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  if (!_hasVoted)
                                    ElevatedButton(
                                      onPressed: () async {
                                        final error = await _apiClient.castVote(c['candidate_id']);
                                        if (mounted) {
                                          if (error == null) {
                                            Navigator.pop(context); _fetchClusters(); 
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vote cast successfully!"), backgroundColor: Colors.green));
                                          } else {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                                title: Row(children: [const Icon(LucideIcons.alertOctagon, color: Colors.red), const SizedBox(width: 10), Text("Wait a minute!", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16))]),
                                                content: Text(error, style: GoogleFonts.poppins()),
                                                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Got it", style: GoogleFonts.poppins(color: Colors.blue, fontWeight: FontWeight.bold)))]
                                              )
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                      child: const Text("Vote", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    )
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12), width: double.infinity,
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                                child: Text('"${c['pitch']}"', style: GoogleFonts.poppins(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.black87)),
                              )
                            ],
                          ),
                        )).toList(),
                      ],

                      const SizedBox(height: 10),

                      if (!hasPitched) ...[
                        const Divider(),
                        const SizedBox(height: 10),
                        Text("Want to lead? Pitch yourself!", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.blue.shade800, fontSize: 16)),
                        const SizedBox(height: 10),
                        TextField(
                          controller: pitchController, maxLines: 2, maxLength: 150,
                          decoration: InputDecoration(hintText: "E.g., I have a secure storehouse and a pickup truck. Vote for me!", hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isSubmitting ? null : () async {
                              if (pitchController.text.trim().isEmpty) return;
                              setSheetState(() => isSubmitting = true);
                              final error = await _apiClient.runForCoordinator(pitchController.text.trim());                              if (mounted) {
                                Navigator.pop(context);
                                if (error == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You are on the ballot!"), backgroundColor: Colors.green));
                                  _fetchClusters(); 
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text("Submit Candidacy", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        )
                      ] else if (_candidates.isNotEmpty) ...[
                        Center(child: Padding(padding: const EdgeInsets.only(top: 10), child: Text("You are running in this election! Good luck.", style: GoogleFonts.poppins(color: Colors.green.shade700, fontWeight: FontWeight.bold))))
                      ]
                    ],
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }
}