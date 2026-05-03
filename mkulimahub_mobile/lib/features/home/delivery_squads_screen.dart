import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:animate_do/animate_do.dart';
import 'package:mkulimahub_mobile/features/home/my_deliveries_screen.dart';
import 'package:mkulimahub_mobile/features/home/squad_chat_screen.dart';
import 'package:mkulimahub_mobile/features/home/unattended_dropoff_screen.dart';
import 'dart:convert';


class DeliverySquadsScreen extends StatefulWidget {
  final int? targetSquadId;
  
  const DeliverySquadsScreen({super.key, this.targetSquadId});

  @override
  State<DeliverySquadsScreen> createState() => _DeliverySquadsScreenState();
}

class _DeliverySquadsScreenState extends State<DeliverySquadsScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  List<dynamic> _myPledges = [];
  
  // 🔥 1. Add this variable to store the logged-in user's ID
  int? _currentUserId; 

  @override
  void initState() {
    super.initState();
    _loadMyPledges();
  }

  Future<void> _loadMyPledges() async {
    setState(() => _isLoading = true);
    
    // 🔥 2. Fetch the pledges AND the user's profile at the exact same time!
    final results = await Future.wait([
      _apiClient.getMyPledges(),
      _apiClient.getProfile(),
    ]);
    
    if (mounted) {
      setState(() {
        final data = results[0] as List<dynamic>;
        final profile = results[1] as Map<String, dynamic>?;

        // Save the user's ID!
        if (profile != null) {
          _currentUserId = profile['id'];
        }

        if (widget.targetSquadId != null) {
          _myPledges = data.where((p) => p['bulk_request'] != null && p['bulk_request']['id'] == widget.targetSquadId).toList();
        } else {
          _myPledges = data;
        }
        _isLoading = false;
      });
    }
  }

  void _showVotingSheet(Map<String, dynamic> bulkRequest) {
    final TextEditingController pitchController = TextEditingController();
    bool isSubmitting = false;
    
    // Extract election data from the bulkRequest (FastAPI will need to send this!)
    List<dynamic> candidates = bulkRequest['candidates'] ?? [];
    bool hasVoted = bulkRequest['has_voted'] ?? false;
    // Assuming you have _currentUser loaded in state, or use a dummy check for now
    bool hasPitched = false; 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle),
                            child: const Icon(LucideIcons.vote, color: Colors.purple),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Squad Election", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text("Elect a coordinator for ${bulkRequest['buyer_name']}.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      if (hasVoted)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade200)),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.checkCircle, color: Colors.green, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text("You have securely cast your vote. Waiting for the winner...", style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade800))),
                            ],
                          ),
                        ),

                      // 🔥 List Current Candidates
                      if (candidates.isNotEmpty) ...[
                        Text("Current Candidates:", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                        const SizedBox(height: 10),
                        ...candidates.map((c) => Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.purple.shade100),
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.purple.shade50.withOpacity(0.3)
                          ),
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
                                        Text(c['farmer_name'] ?? 'Candidate', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text("${c['votes'] ?? 0} Votes Cast", style: GoogleFonts.poppins(color: Colors.purple.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  if (!hasVoted)
                                    ElevatedButton(
                                      onPressed: () async {
                                        final error = await _apiClient.castSquadVote(bulkRequest['id'], c['candidate_id']);
                                        if (mounted) {
                                          Navigator.pop(context);
                                          if (error == null) {
                                            _loadMyPledges(); // Refresh screen
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vote cast successfully!"), backgroundColor: Colors.green));
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
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
                                padding: const EdgeInsets.all(12),
                                width: double.infinity,
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                                child: Text('"${c['pitch'] ?? 'I will ensure safe delivery!'}"', style: GoogleFonts.poppins(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.black87)),
                              )
                            ],
                          ),
                        )).toList(),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.alertCircle, color: Colors.orange, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "No candidates yet! First person to pitch gets a major advantage.",
                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.orange.shade800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 25),

                      // 🔥 Submit a Pitch (If they haven't pitched yet)
                      if (!hasPitched) ...[
                        const Divider(),
                        const SizedBox(height: 10),
                        Text("Run for Coordinator", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 10),
                        TextField(
                          controller: pitchController,
                          decoration: InputDecoration(
                            hintText: "E.g., I have a secure storehouse. Vote for me!",
                            hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isSubmitting ? null : () async {
                              if (pitchController.text.trim().isEmpty) return;
                              setSheetState(() => isSubmitting = true);
                              
                              final error = await _apiClient.runForSquadCoordinator(bulkRequest['id'], pitchController.text.trim());
                              
                              if (mounted) {
                                Navigator.pop(context);
                                if (error == null) {
                                  _loadMyPledges(); // Refresh screen
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You are on the ballot!"), backgroundColor: Colors.green));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSubmitting 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text("Submit Candidacy", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
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
  Widget buildEvidenceImage(String? base64String) {
    if (base64String == null || base64String.isEmpty) return const Center(child: Text("Image missing"));
    try {
      final pureBase64 = base64String.split(',').last; 
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(base64Decode(pureBase64), fit: BoxFit.cover, width: double.infinity, height: 150),
      );
    } catch (e) {
      return const Center(child: Text("Error loading image"));
    }
  }
  void _showEditPledgeSheet(int pledgeId, double currentWeight) {
    final TextEditingController weightController = TextEditingController(text: currentWeight.toStringAsFixed(0));
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 20),
                    Text("Manage Your Pledge", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    
                    TextField(
                      controller: weightController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Pledged Weight (KG)",
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : () async {
                          final double? newWeight = double.tryParse(weightController.text);
                          if (newWeight == null || newWeight <= 0) return;

                          setSheetState(() => isSubmitting = true);
                          final error = await _apiClient.updatePledge(pledgeId, newWeight);
                          
                          if (mounted) {
                            Navigator.pop(context);
                            if (error == null) {
                              _loadMyPledges(); // Refresh screen!
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pledge updated!"), backgroundColor: Colors.green));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isSubmitting 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text("Update Weight", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () async {
                          // Show confirmation dialog before deleting
                          bool confirm = await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Cancel Pledge?"),
                              content: const Text("Are you sure you want to withdraw from this squad?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red))),
                              ],
                            )
                          ) ?? false;

                          if (confirm) {
                            setSheetState(() => isSubmitting = true);
                            final error = await _apiClient.deletePledge(pledgeId);
                            if (mounted) {
                              Navigator.pop(context);
                              if (error == null) {
                                _loadMyPledges();
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pledge removed."), backgroundColor: Colors.red));
                              }
                            }
                          }
                        },
                        icon: const Icon(LucideIcons.trash2, color: Colors.red, size: 16),
                        label: Text("Cancel My Pledge", style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildPremiumButton({
    required String title,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback? onTap,
    bool isPulsing = false,
  }) {
    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: onTap == null ? null : LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        color: onTap == null ? Colors.grey.shade200 : null,
        borderRadius: BorderRadius.circular(16),
        // Add a soft glowing drop-shadow that matches the gradient!
        boxShadow: onTap == null ? [] : [
          BoxShadow(color: gradientColors.last.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 6))
        ]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: onTap == null ? Colors.grey.shade400 : Colors.white, size: 18),
                const SizedBox(width: 10),
                Flexible( 
                child: Text(
                  title,
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis, // Adds '...' if it's too long
                  maxLines: 1, // Forces it to stay on one line
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );

    // If it's a critical action, add a soft pulse animation!
return isPulsing ? Pulse(duration: const Duration(seconds: 2), child: button) : button;  
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,

      body: Column(
        children: [
          // 🔥 Premium Custom Curved Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(left: 20, right: 20, bottom: 20, top: MediaQuery.of(context).padding.top + 20),
            decoration: BoxDecoration(
              color: Colors.green.shade800,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔥 Dynamic Titles!
                Text(widget.targetSquadId != null ? "Squad Details" : "Active Deliveries", style: GoogleFonts.poppins(color: Colors.green.shade100, fontSize: 14)),
                Text(widget.targetSquadId != null ? "Contract Fulfillment" : "Your Fulfillment Squads", style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text("Coordinate with other farmers to hit bulk targets.", style: GoogleFonts.poppins(color: Colors.green.shade50, fontSize: 12)),
              ],
            ),
          ),

          // 🔥 Main Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : _myPledges.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(25),
                            decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                            child: Icon(LucideIcons.truck, size: 50, color: Colors.green.shade300),
                          ),
                          const SizedBox(height: 15),
                          Text("No Active Deliveries", style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade800, fontWeight: FontWeight.bold)),
                          Text("Pledge to a Corporate Request to join a squad.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _myPledges.length,
                      itemBuilder: (context, index) {
                        final pledge = _myPledges[index];
                        final bulkRequest = pledge['bulk_request'] ?? {}; 
                        
                        String squadStatus = bulkRequest['squad_status'] ?? 'unknown';
                        bool isVotingPhase = squadStatus == 'voting';
                        bool isCoordinator = bulkRequest['coordinator_id'] != null;
                        
                        String buyerName = bulkRequest['buyer_name'] ?? 'Unknown Buyer';
                        bool isInternalPool = buyerName.toLowerCase().contains('hub pool');
                        String cropName = bulkRequest['crop_name'] ?? 'Crop';
                        String county = bulkRequest['county'] ?? 'Unknown Location';
                        
                        double targetWeight = (bulkRequest['target_weight_kg'] ?? 0).toDouble();
                        double pricePerKg = (bulkRequest['price_per_kg'] ?? 0).toDouble();
                        double myPledgedWeight = (pledge['pledged_weight_kg'] ?? 0).toDouble();

                        // 🔥 THE FIX: Calculate the REAL total weight from the squad roster!
                        double totalSquadWeight = 0;
                        if (bulkRequest['squad_roster'] != null) {
                          for (var member in bulkRequest['squad_roster']) {
                            totalSquadWeight += (member['pledge_kg'] ?? 0).toDouble();
                          }
                        } else {
                          totalSquadWeight = myPledgedWeight; // Fallback
                        }

                        // Calculate the true progress percentage
                        double progress = targetWeight > 0 ? (totalSquadWeight / targetWeight) : 0; 
                        if (progress > 1.0) progress = 1.0;

                        return FadeInUp(
                          delay: Duration(milliseconds: index * 100),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
                              border: Border.all(color: Colors.grey.shade200)
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 🔥 HEADER
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // 1. 🔥 First Expanded: Protects the Status Badge from getting pushed off screen
                                      Expanded(
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: Colors.orange.shade200,
                                              child: Icon(LucideIcons.building, color: Colors.orange.shade800, size: 14),
                                            ),
                                            const SizedBox(width: 8),
                                            // 2. 🔥 Second Expanded: Chops the long text with '...'
                                            Expanded(
                                              child: Text(
                                                buyerName, 
                                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis, // The magic cut-off!
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      const SizedBox(width: 10), // Safe buffer zone
                                      
                                      // The Status Badge (Safe and sound on the right!)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                        child: Text(squadStatus.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                                      )
                                    ],
                                  ),
                                ),
                                // 🔥 BODY
                                Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Added the exact Contract ID
                                      Text("Contract #BR-${bulkRequest['id'].toString().padLeft(4, '0')}", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                                      const SizedBox(height: 4),
                                      
                                      Text("${targetWeight}kg of $cropName", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      
                                      // Added Price Per KG and Total Value
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                                            child: Text("KES $pricePerKg / kg", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                                          ),
                                          const SizedBox(width: 10),
                                          Text("Total: KES ${targetWeight * pricePerKg}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      Row(
                                        children: [
                                          const Icon(LucideIcons.mapPin, size: 14, color: Colors.grey),
                                          const SizedBox(width: 5),
                                          Text("Deliver to: $county", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                      const SizedBox(height: 20),

                                      // 🔥 SQUAD PROGRESS BAR
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text("Squad Progress", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                              // 🔥 Show the exact KG!
                                              Text("${totalSquadWeight.toStringAsFixed(0)} / ${targetWeight.toStringAsFixed(0)} KG", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: LinearProgressIndicator(
                                              value: progress,
                                              minHeight: 8,
                                              backgroundColor: Colors.grey.shade100,
                                              color: Colors.orange.shade400,
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      const Divider(height: 30),
                                      // 🔥 NEW: SQUAD ROSTER SECTION
                                      Text("Squad Roster", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                                      const SizedBox(height: 10),
                                      
                                      // Map through the team members sent from the backend
                                      if (bulkRequest['squad_roster'] != null)
                                        ...((bulkRequest['squad_roster'] as List).map((member) {
                                          bool isMe = member['farmer_id'] == _currentUserId; 
                                          
                                          return AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            margin: const EdgeInsets.only(bottom: 10),
                                            decoration: BoxDecoration(
                                              // Modern soft gradient for the user, flat crisp white for others
                                              gradient: isMe 
                                                ? LinearGradient(colors: [Colors.green.shade50, Colors.teal.shade50], begin: Alignment.topLeft, end: Alignment.bottomRight) 
                                                : null,
                                              color: isMe ? null : Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: isMe ? Colors.green.shade300 : Colors.grey.shade100, 
                                                width: isMe ? 1.5 : 1
                                              ),
                                              // A soft floating glow for the user's card
                                              boxShadow: isMe ? [
                                                BoxShadow(color: Colors.green.shade700.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))
                                              ] : [],
                                            ),
                                            child: Material(
                                              color: Colors.transparent, // Ensures the ripple shows on top of the gradient!
                                              child: InkWell(
                                                onTap: isMe ? () => _showEditPledgeSheet(pledge['id'], member['pledge_kg'].toDouble()) : null,
                                                borderRadius: BorderRadius.circular(16),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(14),
                                                  child: Row(
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 18, // Slightly larger for a premium feel
                                                        backgroundColor: isMe ? Colors.green.shade200 : Colors.orange.shade50,
                                                        child: Icon(LucideIcons.user, size: 18, color: isMe ? Colors.green.shade800 : Colors.orange.shade400),
                                                      ),
                                                      const SizedBox(width: 15),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Text(
                                                                  isMe ? "You" : member['name'], 
                                                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: isMe ? Colors.green.shade900 : Colors.black87),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                                if (isMe) ...[
                                                                  const SizedBox(width: 6),
                                                                  Icon(LucideIcons.edit2, size: 14, color: Colors.green.shade700)
                                                                ]
                                                              ],
                                                            ),
                                                            const SizedBox(height: 2),
                                                            Text(
                                                              "${member['pledge_kg']} KG Contributed", 
                                                              style: GoogleFonts.poppins(fontSize: 12, color: isMe ? Colors.teal.shade800 : Colors.grey.shade500, fontWeight: FontWeight.w500)
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Column(
                                                        crossAxisAlignment: CrossAxisAlignment.end,
                                                        children: [
                                                          if (isMe) ...[
                                                            Text("Est. Payout", style: GoogleFonts.poppins(fontSize: 10, color: Colors.teal.shade600, fontWeight: FontWeight.w600)),
                                                            Text("KES ${member['payout_kes']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green.shade800)),
                                                          ] else ...[
                                                            // 🔥 THE COORDINATOR'S AUDIT BUTTON
                                                            if (bulkRequest['coordinator_id'] == _currentUserId) ...[
                                                              // We need to find this specific farmer's pledge status from the main array
                                                              Builder(
                                                                builder: (ctx) {
                                                                  // Find the specific pledge dictionary for this member
                                                                  final memberPledge = _myPledges.firstWhere((p) => p['bulk_request']['id'] == bulkRequest['id'] && p['farmer_id'] == member['farmer_id'], orElse: () => null);
                                                                  final memberStatus = memberPledge != null ? memberPledge['status'] : 'unknown';
                                                                  final notes = memberPledge != null ? memberPledge['notes'] : '';

                                                                  if (memberStatus == 'pending_audit' && notes.toString().startsWith("EVIDENCE_LOG|")) {
                                                                     return ElevatedButton.icon(
                                                                       onPressed: () {
                                                                         // Extract the photos
                                                                         final parts = notes.split('|');
                                                                         final scalePhoto = parts.length > 1 ? parts[1] : null;
                                                                         final cropPhoto = parts.length > 2 ? parts[2] : null;
                                                                         
                                                                         // Launch a quick dialog to view and approve!
                                                                         showDialog(
                                                                           context: context,
                                                                           builder: (ctx) => AlertDialog(
                                                                             title: const Text("Verify Drop-off"),
                                                                             content: Column(
                                                                               mainAxisSize: MainAxisSize.min,
                                                                               children: [
                                                                                 Text("Did ${member['name']} drop this off at your location?"),
                                                                                 const SizedBox(height: 10),
                                                                                 Row(
                                                                                   children: [
                                                                                     Expanded(child: buildEvidenceImage(scalePhoto)),
                                                                                     const SizedBox(width: 10),
                                                                                     Expanded(child: buildEvidenceImage(cropPhoto)),
                                                                                   ]
                                                                                 )
                                                                               ]
                                                                             ),
                                                                             actions: [
                                                                               TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                                                               ElevatedButton(
                                                                                 onPressed: () async {
                                                                                   // Update their specific pledge to received!
                                                                                   await _apiClient.updatePledgeStatus(memberPledge['id'], 'received');
                                                                                   if (mounted) {
                                                                                     Navigator.pop(ctx);
                                                                                     _loadMyPledges();
                                                                                   }
                                                                                 }, 
                                                                                 style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                                                                 child: const Text("Approve Drop-off")
                                                                               )
                                                                             ]
                                                                           )
                                                                         );
                                                                       },
                                                                       icon: const Icon(LucideIcons.camera, size: 12),
                                                                       label: const Text("Review Evidence", style: TextStyle(fontSize: 10)),
                                                                       style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0), minimumSize: const Size(0, 30)),
                                                                     );
                                                                  } else if (memberStatus == 'received') {
                                                                    return Text("Verified ✅", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700));
                                                                  } else {
                                                                    return Text("Waiting Drop-off", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500));
                                                                  }
                                                                }
                                                              )
                                                            ] else ...[
                                                              Text("Payout", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                                                              Text("Hidden", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade300)),
                                                            ]
                                                          ]
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        })),

                                      const SizedBox(height: 25),

                                      _buildPremiumButton(
                                        title: "Open Squad Chat",
                                        icon: LucideIcons.messageCircle,
                                        gradientColors: [Colors.teal.shade500, Colors.teal.shade800],
                                        onTap: () {
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (context) => SquadChatSheet(bulkRequestId: bulkRequest['id']),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 15),
                                      
                                      // 🔥 DYNAMIC ACTION BUTTONS (Bulletproof Builder Pattern)
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        child: Builder(
                                          builder: (context) {
                                            // 1. Contract is Done
                                            if (squadStatus == 'fulfilled') {
                                              return _buildPremiumButton(
                                                title: "Contract Completed",
                                                icon: LucideIcons.checkCircle,
                                                gradientColors: [Colors.green.shade400, Colors.green.shade700],
                                                onTap: null, 
                                              );
                                            } 
                                            // 2. Squad is Driving
                                            else if (squadStatus == 'active') {
                                        // A. Are you the Coordinator / Hub Admin?
                                        if (bulkRequest['coordinator_id'] == _currentUserId) {
                                           if (pledge['status'] == 'pledged' || pledge['status'] == 'gathering') {
                                             // They MUST wait for goods to be verified!
                                             return Column(
                                               children: [
                                                 Container(
                                                   width: double.infinity,
                                                   padding: const EdgeInsets.symmetric(vertical: 14),
                                                   decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                                                   child: Center(child: Text("⚠️ Goods must be Verified to Unlock Transit", style: GoogleFonts.poppins(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 11))),
                                                 ),
                                                 const SizedBox(height: 10),
                                                 _buildPremiumButton(
                                                   title: isInternalPool ? "Admin Absent? Digital Drop-off" : "Wait for Farmers to Arrive",
                                                   icon: isInternalPool ? LucideIcons.camera : LucideIcons.clock,
                                                   gradientColors: [Colors.red.shade400, Colors.red.shade700],
                                                   onTap: isInternalPool ? () async {
                                                     final didSubmit = await Navigator.push(context, MaterialPageRoute(builder: (_) => UnattendedDropoffScreen(squadId: bulkRequest['id'], cropName: cropName)));
                                                     if (didSubmit == true && mounted) _loadMyPledges();
                                                   } : null,
                                                 )
                                               ]
                                             );
                                           } else if (pledge['status'] == 'pending_audit') {
                                             return _buildPremiumButton(title: "Awaiting Admin Audit...", icon: LucideIcons.shieldAlert, gradientColors: [Colors.grey.shade400, Colors.grey.shade600], onTap: null);
                                           } else if (pledge['status'] == 'received') {
                                             // 🔥 ISSUE 1 FIXED: When received, transit is UNLOCKED!
                                             return _buildPremiumButton(
                                               title: "Start Journey to Buyer", icon: LucideIcons.truck, gradientColors: [Colors.purple.shade400, Colors.purple.shade700], isPulsing: true,
                                               onTap: () async { await _apiClient.updateSquadStatus(bulkRequest['id'], 'in_transit'); _loadMyPledges(); },
                                             );
                                           } else if (pledge['status'] == 'in_transit') {
                                             return _buildPremiumButton(
                                               title: "Confirm Arrival at Buyer", icon: LucideIcons.mapPin, gradientColors: [Colors.green.shade400, Colors.green.shade700],
                                               onTap: () async { await _apiClient.updateSquadStatus(bulkRequest['id'], 'delivered'); _loadMyPledges(); },
                                             );
                                           } else if (pledge['status'] == 'delivered') {
                                             return _buildPremiumButton(title: "Waiting for Buyer Verification...", icon: LucideIcons.clock, gradientColors: [Colors.grey.shade400, Colors.grey.shade600], onTap: null);
                                           } else {
                                             return _buildPremiumButton(title: "Contract Completed", icon: LucideIcons.checkCircle, gradientColors: [Colors.green.shade400, Colors.green.shade700], onTap: null);
                                            }
                                        }
                                        // B. Normal Farmer View
                                        else {
                                           if (isInternalPool) {
                                             return _buildPremiumButton(
                                               title: "Message Driver to Coordinate", icon: LucideIcons.messageCircle, gradientColors: [Colors.teal.shade400, Colors.teal.shade600],
                                               onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => SquadChatSheet(bulkRequestId: bulkRequest['id'])), 
                                             );
                                           } else {
                                             // Corporate Contract Normal Farmer
                                             if (pledge['status'] == 'pledged' || pledge['status'] == 'gathering') {
                                               return Column(
                                                 children: [
                                                   _buildPremiumButton(
                                                     title: "Message Coordinator", icon: LucideIcons.messageCircle, gradientColors: [Colors.teal.shade400, Colors.teal.shade600],
                                                     onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => SquadChatSheet(bulkRequestId: bulkRequest['id'])), 
                                                   ),
                                                   const SizedBox(height: 10),
                                                   _buildPremiumButton(
                                                     title: "Coordinator Absent? Digital Drop-off", icon: LucideIcons.camera, gradientColors: [Colors.red.shade400, Colors.red.shade700],
                                                     onTap: () async {
                                                       final didSubmit = await Navigator.push(context, MaterialPageRoute(builder: (_) => UnattendedDropoffScreen(squadId: bulkRequest['id'], cropName: cropName)));
                                                       if (didSubmit == true && mounted) _loadMyPledges();
                                                     }, 
                                                   ),
                                                 ]
                                               );
                                             } else if (pledge['status'] == 'pending_audit') {
                                               return _buildPremiumButton(title: "Waiting for Coordinator Audit...", icon: LucideIcons.clock, gradientColors: [Colors.grey.shade400, Colors.grey.shade600], onTap: null);
                                             } else if (pledge['status'] == 'received') {
                                               return _buildPremiumButton(title: "Verified by Coordinator ✅", icon: LucideIcons.checkCircle, gradientColors: [Colors.green.shade400, Colors.green.shade600], onTap: null);
                                             } else {
                                               return _buildPremiumButton(title: "Squad In Transit to Buyer", icon: LucideIcons.truck, gradientColors: [Colors.blue.shade400, Colors.blue.shade600], onTap: null);
                                             }
                                           }
                                        }
                                      }
                                            // 3. Squad is Voting
                                            else if (squadStatus == 'voting') {
                                              return _buildPremiumButton(
                                                title: "Elect Squad Coordinator",
                                                icon: LucideIcons.vote,
                                                gradientColors: [Colors.purple.shade400, Colors.deepPurple.shade700],
                                                onTap: () => _showVotingSheet(bulkRequest),
                                                isPulsing: true,
                                              );
                                            } 
                                            // 4. Squad is Gathering
                                            else {
                                              return _buildPremiumButton(
                                                title: "Waiting for more farmers...",
                                                icon: LucideIcons.users,
                                                gradientColors: [Colors.grey.shade300, Colors.grey.shade400],
                                                onTap: null, 
                                              );
                                            }
                                          }
                                        ),
                                      )
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        );
                      }
                    ),
          ),
        ],
      ),
    );
  }
}