import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:animate_do/animate_do.dart';

class DeliverySquadsScreen extends StatefulWidget {
  const DeliverySquadsScreen({super.key});

  @override
  State<DeliverySquadsScreen> createState() => _DeliverySquadsScreenState();
}

class _DeliverySquadsScreenState extends State<DeliverySquadsScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  List<dynamic> _myPledges = [];

  @override
  void initState() {
    super.initState();
    _loadMyPledges();
  }

  Future<void> _loadMyPledges() async {
    setState(() => _isLoading = true);
    final data = await _apiClient.getMyPledges(); 
    if (mounted) {
      setState(() {
        _myPledges = data;
        _isLoading = false;
      });
    }
  }

  // 🔥 NEW: Beautiful Voting Bottom Sheet
  // 🔥 UPGRADED: Dynamic Squad Voting Bottom Sheet
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      // 🔥 Removed default AppBar to match the custom curved header style!
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
                Text("Active Deliveries", style: GoogleFonts.poppins(color: Colors.green.shade100, fontSize: 14)),
                Text("Your Fulfillment Squads", style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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
                        String cropName = bulkRequest['crop_name'] ?? 'Crop';
                        String county = bulkRequest['county'] ?? 'Unknown Location';
                        
                        double targetWeight = (bulkRequest['target_weight_kg'] ?? 0).toDouble();
                        double pricePerKg = (bulkRequest['price_per_kg'] ?? 0).toDouble();
                        double pledgedWeight = (pledge['pledged_weight_kg'] ?? 0).toDouble();

                        // Calculate visual progress (Assuming for UI purposes until backend sends total)
                        double progress = (pledgedWeight * 3) / targetWeight; 
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
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: Colors.orange.shade200,
                                            child: Icon(LucideIcons.building, color: Colors.orange.shade800, size: 14),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(buyerName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                                        ],
                                      ),
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
                                      Text("${targetWeight}kg of $cropName", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
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
                                              Text("${(progress * 100).toStringAsFixed(0)}%", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
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
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("My Pledge", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                                              Text("$pledgedWeight KG", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade700)),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text("Est. Payout", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                                              Text("KES ${pledgedWeight * pricePerKg}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal.shade700)),
                                            ],
                                          ),
                                        ],
                                      ),
                                      
                                      const SizedBox(height: 20),
                                      
                                      // 🔥 DYNAMIC ACTION BUTTONS
                                      if (isVotingPhase)
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () => _showVotingSheet(bulkRequest),
                                            icon: const Icon(LucideIcons.vote, color: Colors.white, size: 16),
                                            label: Text("Elect Squad Coordinator", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.purple.shade600,
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              elevation: 0
                                            ),
                                          ),
                                        )
                                      else if (isCoordinator)
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: () {},
                                            icon: const Icon(LucideIcons.userCheck, color: Colors.green, size: 16),
                                            label: Text("Drop-off Coordinator Elected", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.green.shade700,
                                              side: BorderSide(color: Colors.green.shade300, width: 2),
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                            ),
                                          ),
                                        )
                                      else
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: null,
                                            icon: const Icon(LucideIcons.users, color: Colors.grey, size: 16),
                                            label: Text("Waiting for more farmers...", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.grey.shade200,
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
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