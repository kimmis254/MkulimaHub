import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';

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
  int _totalFarmersAnalyzed = 0;
  String? _errorMessage;

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
      final data = await _apiClient.getClusters(_selectedCrop);
      setState(() {
        _hubs = data['hubs'] ?? [];
        _totalFarmersAnalyzed = data['total_farmers_analyzed'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "AI Sourcing Hubs",
          style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // --- TOP FILTER SECTION ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Sourcing: $_totalFarmersAnalyzed Farmers", 
                    style: GoogleFonts.poppins(color: Colors.grey[600], fontWeight: FontWeight.w500)
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!)
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCrop,
                      icon: const Icon(LucideIcons.filter, size: 16, color: Colors.green),
                      items: _crops.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.poppins(fontSize: 14)))).toList(),
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
          
          // --- MAIN CONTENT ---
          Expanded(
            child: _isLoading 
                ? _buildAILoadingState() 
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : _hubs.isEmpty
                        ? Center(child: Text("No hubs found for this crop.", style: GoogleFonts.poppins(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(24),
                            itemCount: _hubs.length,
                            itemBuilder: (context, index) {
                              return FadeInUp(
                                delay: Duration(milliseconds: 100 * index),
                                child: _buildHubCard(_hubs[index]),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  // --- THE AI LOADING ANIMATION ---
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

  // --- THE HUB CARD ---
  Widget _buildHubCard(Map<String, dynamic> hub) {
    int farmerCount = hub['farmer_count'] ?? 0;
    List<dynamic> farmersList = hub['farmers'] ?? []; 
    
    return GestureDetector(
      onTap: () => _showFarmersBottomSheet(farmersList),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Graphic Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.green[800]!, Colors.green[600]!]),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.map, color: Colors.white, size: 28),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(hub['hub_name'] ?? 'Regional Hub', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("High Density Zone", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom Info Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Available Farmers", style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(LucideIcons.users, size: 16, color: Colors.black87),
                          const SizedBox(width: 6),
                          Text("$farmerCount Farmers", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () => _showFarmersBottomSheet(farmersList),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[50],
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text("View List", style: GoogleFonts.poppins(color: Colors.blue[800], fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- THE EXPANDABLE FARMER LIST ---
  void _showFarmersBottomSheet(List<dynamic> farmers) {
    if (farmers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No farmer details available.")));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.5, 
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Farmers in this Hub", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.builder(
                  itemCount: farmers.length,
                  itemBuilder: (context, index) {
                    final f = farmers[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(backgroundColor: Colors.green[100], child: const Icon(LucideIcons.user, color: Colors.green)),
                      title: Text(f['name'] ?? 'Unknown', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      subtitle: Text("${f['village'] ?? ''} • ${f['crops'] ?? ''}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                      trailing: IconButton(
                        icon: const Icon(LucideIcons.phone, color: Colors.blue),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Calling ${f['phone']}...")));
                        },
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
}