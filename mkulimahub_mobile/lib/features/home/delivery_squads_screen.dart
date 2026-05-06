import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:animate_do/animate_do.dart';
import 'package:mkulimahub_mobile/features/home/squad_chat_screen.dart';
import 'package:mkulimahub_mobile/features/home/unattended_dropoff_screen.dart';

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
  int? _currentUserId; 

  @override
  void initState() {
    super.initState();
    _loadMyPledges();
  }

  Future<void> _loadMyPledges() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([_apiClient.getMyPledges(), _apiClient.getProfile()]);
    if (mounted) {
      setState(() {
        final data = results[0] as List<dynamic>;
        final profile = results[1] as Map<String, dynamic>?;
        if (profile != null) _currentUserId = profile['id'];
        if (widget.targetSquadId != null) {
          _myPledges = data.where((p) => p['bulk_request'] != null && p['bulk_request']['id'] == widget.targetSquadId).toList();
        } else {
          _myPledges = data;
        }
        _isLoading = false;
      });
    }
  }

  // --- Voting Sheet (Kept exactly as is) ---
  void _showVotingSheet(Map<String, dynamic> bulkRequest) {
    final TextEditingController pitchController = TextEditingController();
    bool isSubmitting = false;
    List<dynamic> candidates = bulkRequest['candidates'] ?? [];
    bool hasVoted = bulkRequest['has_voted'] ?? false;
    bool hasPitched = _currentUserId != null && candidates.any((c) => c['farmer_id'] == _currentUserId); 

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
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
                    mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle), child: const Icon(LucideIcons.vote, color: Colors.purple)),
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
                          padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade200)),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.checkCircle, color: Colors.green, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text("You have securely cast your vote. Waiting for the winner...", style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade800))),
                            ],
                          ),
                        ),
                      if (candidates.isNotEmpty) ...[
                        Text("Current Candidates:", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                        const SizedBox(height: 10),
                        ...candidates.map((c) => Container(
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
                                            _loadMyPledges(); 
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
                                padding: const EdgeInsets.all(12), width: double.infinity,
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                                child: Text('"${c['pitch'] ?? 'I will ensure safe delivery!'}"', style: GoogleFonts.poppins(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.black87)),
                              )
                            ],
                          ),
                        )).toList(),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.alertCircle, color: Colors.orange, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text("No candidates yet! First person to pitch gets a major advantage.", style: GoogleFonts.poppins(fontSize: 11, color: Colors.orange.shade800))),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 25),
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
                            filled: true, fillColor: Colors.grey.shade50,
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
                                  _loadMyPledges(); 
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You are on the ballot!"), backgroundColor: Colors.green));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade600, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text("Submit Candidacy", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
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
  
  // --- Edit Pledge Sheet (Kept exactly as is) ---
  void _showEditPledgeSheet(int pledgeId, double currentWeight) {
    final TextEditingController weightController = TextEditingController(text: currentWeight.toStringAsFixed(0));
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 20),
                    Text("Manage Your Pledge", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: weightController, keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: "Pledged Weight (KG)", filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
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
                              _loadMyPledges(); 
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pledge updated!"), backgroundColor: Colors.green));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text("Update Weight", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () async {
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
    required String title, required IconData icon, required List<Color> gradientColors, required VoidCallback? onTap, bool isPulsing = false,
  }) {
    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 200), width: double.infinity,
      decoration: BoxDecoration(
        gradient: onTap == null ? null : LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        color: onTap == null ? Colors.grey.shade200 : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: onTap == null ? [] : [BoxShadow(color: gradientColors.last.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 6))]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: onTap == null ? Colors.grey.shade400 : Colors.white, size: 18),
                const SizedBox(width: 10),
                Flexible(child: Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1)),
              ],
            ),
          ),
        ),
      ),
    );
    return isPulsing ? Pulse(duration: const Duration(seconds: 2), child: button) : button;  
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity, padding: EdgeInsets.only(left: 20, right: 20, bottom: 20, top: MediaQuery.of(context).padding.top + 20),
            decoration: BoxDecoration(color: Colors.green.shade800, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.targetSquadId != null ? "Squad Details" : "Active Deliveries", style: GoogleFonts.poppins(color: Colors.green.shade100, fontSize: 14)),
                Text(widget.targetSquadId != null ? "Contract Fulfillment" : "Your Fulfillment Squads", style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text("Coordinate with other farmers to hit bulk targets.", style: GoogleFonts.poppins(color: Colors.green.shade50, fontSize: 12)),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : _myPledges.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle), child: Icon(LucideIcons.truck, size: 50, color: Colors.green.shade300)),
                          const SizedBox(height: 15),
                          Text("No Active Deliveries", style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade800, fontWeight: FontWeight.bold)),
                          Text("Pledge to a Corporate Request to join a squad.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16), // Reduced padding for breathing room
                      itemCount: _myPledges.length,
                      itemBuilder: (context, index) {
                        final pledge = _myPledges[index];
                        final bulkRequest = pledge['bulk_request'] ?? {}; 
                        String squadStatus = bulkRequest['squad_status'] ?? 'unknown';
                        String buyerName = bulkRequest['buyer_name'] ?? 'Unknown Buyer';
                        String cropName = bulkRequest['crop_name'] ?? 'Crop';
                        String county = bulkRequest['county'] ?? 'Unknown Location';
                        
                        bool isHubPool = buyerName.toLowerCase().contains('hub pool'); 
                        bool isCoordinator = bulkRequest['coordinator_id'] == _currentUserId;

                        double targetWeight = (bulkRequest['target_weight_kg'] ?? 0).toDouble();
                        double pricePerKg = (bulkRequest['price_per_kg'] ?? 0).toDouble();
                        double totalSquadWeight = 0;
                        
                        bool allReceived = true;
                        String transitState = 'active';

                        if (bulkRequest['squad_roster'] != null) {
                          var roster = bulkRequest['squad_roster'] as List;
                          if (roster.isNotEmpty) {
                             transitState = roster[0]['status'] ?? 'active';
                          }
                          for (var member in roster) {
                             totalSquadWeight += (member['pledge_kg'] ?? 0).toDouble();
                             String s = member['status'] ?? 'unknown';
                             if (s != 'received' && s != 'in_transit' && s != 'delivered' && s != 'completed' && s != 'paid') {
                               allReceived = false;
                             }
                          }
                        } else {
                          totalSquadWeight = (pledge['pledged_weight_kg'] ?? 0).toDouble();
                          allReceived = false;
                        }
                        
                        double progress = targetWeight > 0 ? (totalSquadWeight / targetWeight) : 0; 
                        if (progress > 1.0) progress = 1.0;

                        return FadeInUp(
                          delay: Duration(milliseconds: index * 100),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))], border: Border.all(color: Colors.grey.shade200)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // TOP STATUS BAR
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(LucideIcons.building, color: Colors.orange.shade800, size: 14),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(buyerName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.orange.shade900), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10), 
                                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Text(squadStatus.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade700)))
                                    ],
                                  ),
                                ),
                                
                                Padding(
                                  padding: const EdgeInsets.all(16.0), // Reduced from 20
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // CONTRACT DETAILS
                                      Text("Contract #BR-${bulkRequest['id'].toString().padLeft(4, '0')}", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                                      const SizedBox(height: 4),
                                      Text("${targetWeight}kg of $cropName", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 12),

                                      // 🔥 CLEAN STACKED INFO TO PREVENT OVERFLOW
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text("Price per KG:", style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade800)),
                                                Text("KES $pricePerKg", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text("Total Value:", style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade800)),
                                                Text("KES ${targetWeight * pricePerKg}", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                                              ],
                                            ),
                                            const Divider(height: 16),
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Icon(LucideIcons.mapPin, size: 14, color: Colors.green.shade700),
                                                const SizedBox(width: 5),
                                                Expanded(child: Text("Deliver to: $county", style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w500))),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // DELIVERY INTEL CARD
                                      if (!isHubPool) ...[
                                        const SizedBox(height: 15),
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(LucideIcons.map, size: 16, color: Colors.blue.shade800),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text("Delivery Logistics Intel", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.blue.shade900))),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                (bulkRequest['ward'] != null && bulkRequest['ward'].toString().isNotEmpty) 
                                                    ? bulkRequest['ward'] 
                                                    : "No exact address provided. Use chat to confirm.", 
                                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue.shade800, height: 1.5)
                                              ),
                                              if (!isCoordinator) ...[
                                                const SizedBox(height: 10),
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(LucideIcons.lock, size: 12, color: Colors.blue.shade700),
                                                    const SizedBox(width: 6),
                                                    Expanded(child: Text("Master dispatch controls unlock for the Coordinator.", style: GoogleFonts.poppins(fontSize: 10, color: Colors.blue.shade700, fontStyle: FontStyle.italic))),
                                                  ],
                                                )
                                              ]
                                            ],
                                          ),
                                        )
                                      ],

                                      const SizedBox(height: 20),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text("Squad Progress", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                              Text("${totalSquadWeight.toStringAsFixed(0)} / ${targetWeight.toStringAsFixed(0)} KG", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: Colors.grey.shade100, color: Colors.orange.shade400)),
                                        ],
                                      ),
                                      
                                      const Divider(height: 30),
                                      Text("Squad Roster", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                                      const SizedBox(height: 10),
                                      
                                      if (bulkRequest['squad_roster'] != null)
                                        ...((bulkRequest['squad_roster'] as List).map((member) {
                                          bool isMe = member['farmer_id'] == _currentUserId; 
                                          String memberStatus = member['status'] ?? 'unknown';

                                          String pendingLabel = isHubPool ? "Awaiting Admin ⏳" : "Awaiting Coordinator ⏳";
                                          String verifiedLabel = isHubPool ? "Verified ✅" : "Verified ✅";

                                          // 🔥 CLEAN REDESIGNED ROSTER TILE TO PREVENT CRUSHING
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 12),
                                            decoration: BoxDecoration(
                                              color: isMe ? Colors.green.shade50 : Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: isMe ? Colors.green.shade300 : Colors.grey.shade200, width: isMe ? 1.5 : 1),
                                            ),
                                            child: Material(
                                              color: Colors.transparent, 
                                              child: InkWell(
                                                onTap: isMe ? () => _showEditPledgeSheet(member['pledge_id'], member['pledge_kg'].toDouble()) : null,
                                                borderRadius: BorderRadius.circular(16),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(12),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      // ROW 1: Avatar, Name, Status Badge
                                                      Row(
                                                        crossAxisAlignment: CrossAxisAlignment.center,
                                                        children: [
                                                          CircleAvatar(radius: 16, backgroundColor: isMe ? Colors.green.shade200 : Colors.grey.shade100, child: Icon(LucideIcons.user, size: 16, color: isMe ? Colors.green.shade800 : Colors.grey.shade600)),
                                                          const SizedBox(width: 10),
                                                          Expanded(
                                                            child: Text(
                                                              isMe ? "You" : member['name'], 
                                                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: isMe ? Colors.green.shade900 : Colors.black87),
                                                              maxLines: 1, overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          // Status Badge Top Right
                                                          if (isMe) ...[
                                                            if (memberStatus == 'pending_audit') Text("Awaiting Approval ⏳", style: GoogleFonts.poppins(fontSize: 10, color: Colors.orange.shade700, fontWeight: FontWeight.bold))
                                                            else if (memberStatus == 'received') Text("Verified ✅", style: GoogleFonts.poppins(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold))
                                                            else if (memberStatus == 'in_transit' || memberStatus == 'delivered' || memberStatus == 'completed' || memberStatus == 'paid') Text("Dispatched 🚚", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700))
                                                          ] else ...[
                                                            if (memberStatus == 'pending_audit') Text(pendingLabel, style: GoogleFonts.poppins(fontSize: 10, color: Colors.orange.shade700, fontWeight: FontWeight.bold))
                                                            else if (memberStatus == 'received') Text(verifiedLabel, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700))
                                                            else if (memberStatus == 'in_transit' || memberStatus == 'delivered' || memberStatus == 'completed' || memberStatus == 'paid') Text("Dispatched 🚚", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700))
                                                            else Text("Waiting Drop-off", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500))
                                                          ]
                                                        ],
                                                      ),
                                                      const SizedBox(height: 10),
                                                      
                                                      // ROW 2: Weight and Payout
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text("${member['pledge_kg']} KG Contributed", style: GoogleFonts.poppins(fontSize: 11, color: isMe ? Colors.teal.shade800 : Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                                          Text(isMe ? "Payout: KES ${member['payout_kes']}" : "Payout Hidden", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11, color: isMe ? Colors.green.shade800 : Colors.grey.shade400)),
                                                        ],
                                                      ),

                                                      // ROW 3: Actions (Delegate, Handover)
                                                      if (!isMe && !isHubPool && isCoordinator) ...[
                                                        const SizedBox(height: 10),
                                                        GestureDetector(
                                                          onTap: () async {
                                                            bool confirm = await showDialog(
                                                              context: context,
                                                              builder: (ctx) => AlertDialog(
                                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                                title: const Text("Pass the Crown? 👑"),
                                                                content: Text("Make ${member['name']} the new Squad Coordinator?"),
                                                                actions: [
                                                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                                                                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade600), child: const Text("Yes, Delegate", style: TextStyle(color: Colors.white)))
                                                                ]
                                                              )
                                                            ) ?? false;
                                                            if (confirm) {
                                                              final error = await _apiClient.delegateCoordinator(bulkRequest['id'], member['farmer_id']);
                                                              if (mounted) {
                                                                if (error == null) {
                                                                  _loadMyPledges(); 
                                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Leadership delegated!"), backgroundColor: Colors.green));
                                                                } else {
                                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                                                                }
                                                              }
                                                            }
                                                          },
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                            decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                                                            child: Text("👑 Delegate Leadership", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade700))
                                                          ),
                                                        )
                                                      ],

                                                      // COORDINATOR APPROVE BUTTON
                                                      if (isCoordinator && !isHubPool && (memberStatus == 'pledged' || memberStatus == 'gathering' || memberStatus == 'pending_audit')) ...[
                                                        const SizedBox(height: 10),
                                                        SizedBox(
                                                          width: double.infinity,
                                                          child: ElevatedButton.icon(
                                                            onPressed: () async {
                                                              setState(() { member['status'] = 'received'; });
                                                              final error = await _apiClient.updatePledgeStatus(member['pledge_id'], 'received');
                                                              if (mounted) {
                                                                if (error == null) {
                                                                  _loadMyPledges(); 
                                                                } else {
                                                                  setState(() { member['status'] = memberStatus; }); 
                                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                                                                }
                                                              }
                                                            },
                                                            icon: const Icon(LucideIcons.clipboardCheck, size: 14, color: Colors.white),
                                                            label: Text("Verify & Receive Goods", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                                            style: ElevatedButton.styleFrom(
                                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                                              backgroundColor: Colors.teal.shade600, elevation: 0,
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                                            ),
                                                          ),
                                                        )
                                                      ] else if (isMe && !isCoordinator && (memberStatus == 'pledged' || memberStatus == 'gathering')) ...[
                                                        // NORMAL DROP OFF BUTTONS
                                                        const SizedBox(height: 10),
                                                        Column(
                                                          children: [
                                                            SizedBox(
                                                              width: double.infinity,
                                                              child: OutlinedButton.icon(
                                                                onPressed: () async {
                                                                  setState(() { member['status'] = 'pending_audit'; });
                                                                  final error = await _apiClient.updatePledgeStatus(member['pledge_id'], 'pending_audit');
                                                                  if (mounted) {
                                                                    if (error == null) {
                                                                      _loadMyPledges(); 
                                                                    } else {
                                                                      setState(() { member['status'] = 'pledged'; });
                                                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                                                                    }
                                                                  }
                                                                },
                                                                icon: const Icon(LucideIcons.userCheck, size: 14),
                                                                label: Text("Handed Over (In Person)", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                                                                style: OutlinedButton.styleFrom(
                                                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                                                  foregroundColor: Colors.green.shade700, side: BorderSide(color: Colors.green.shade300),
                                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(height: 6),
                                                            SizedBox(
                                                              width: double.infinity,
                                                              child: ElevatedButton.icon(
                                                                onPressed: () async {
                                                                  final didSubmit = await Navigator.push(context, MaterialPageRoute(builder: (_) => UnattendedDropoffScreen(squadId: bulkRequest['id'], cropName: cropName)));
                                                                  if (didSubmit == true && mounted) {
                                                                    setState(() { member['status'] = 'pending_audit'; });
                                                                    _loadMyPledges();
                                                                  }
                                                                },
                                                                icon: const Icon(LucideIcons.camera, size: 14),
                                                                label: Text("Digital Drop-off", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                                                                style: ElevatedButton.styleFrom(
                                                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                                                  backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, elevation: 0,
                                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        )
                                                      ]
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        })),

                                      const SizedBox(height: 25),

                                      _buildPremiumButton(
                                        title: "Open Squad Chat", icon: LucideIcons.messageCircle, gradientColors: [Colors.teal.shade500, Colors.teal.shade800],
                                        onTap: () { showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => SquadChatSheet(bulkRequestId: bulkRequest['id'])); },
                                      ),
                                      const SizedBox(height: 15),

                                      if (squadStatus == 'fulfilled' || transitState == 'completed' || transitState == 'paid')
                                        _buildPremiumButton(title: "Contract Completed", icon: LucideIcons.checkCircle, gradientColors: [Colors.green.shade400, Colors.green.shade700], onTap: null)
                                      else if (isCoordinator && !isHubPool && allReceived && (transitState == 'received' || squadStatus == 'active' && transitState != 'in_transit' && transitState != 'delivered'))
                                        _buildPremiumButton(
                                          title: "Dispatch Truck", 
                                          icon: LucideIcons.truck, 
                                          gradientColors: [Colors.blue.shade500, Colors.blue.shade800], 
                                          onTap: () async {
                                              final error = await _apiClient.updateSquadStatus(bulkRequest['id'], 'in_transit');
                                              if (error == null) _loadMyPledges();
                                          },
                                          isPulsing: true
                                        )
                                      else if (isCoordinator && !isHubPool && transitState == 'in_transit')
                                        _buildPremiumButton(
                                          title: "Mark as Delivered", 
                                          icon: LucideIcons.mapPin, 
                                          gradientColors: [Colors.indigo.shade500, Colors.indigo.shade800], 
                                          onTap: () async {
                                              final error = await _apiClient.updateSquadStatus(bulkRequest['id'], 'delivered');
                                              if (error == null) _loadMyPledges();
                                          },
                                          isPulsing: true
                                        )
                                      else if (squadStatus == 'active' && !allReceived)
                                        _buildPremiumButton(title: "Loading Truck...", icon: LucideIcons.loader, gradientColors: [Colors.orange.shade400, Colors.orange.shade700], onTap: null)
                                      else if (squadStatus == 'active' && transitState == 'in_transit')
                                        _buildPremiumButton(title: "Squad is in Transit", icon: LucideIcons.truck, gradientColors: [Colors.blue.shade400, Colors.blue.shade700], onTap: null)
                                      else if (squadStatus == 'active' && transitState == 'delivered')
                                        _buildPremiumButton(title: "Awaiting Buyer QA", icon: LucideIcons.search, gradientColors: [Colors.teal.shade400, Colors.teal.shade700], onTap: null)
                                      else if (squadStatus == 'voting')
                                        _buildPremiumButton(title: "Elect Squad Coordinator", icon: LucideIcons.vote, gradientColors: [Colors.purple.shade400, Colors.deepPurple.shade700], onTap: () => _showVotingSheet(bulkRequest), isPulsing: true)
                                      else if (squadStatus == 'gathering')
                                        _buildPremiumButton(title: "Waiting for more farmers...", icon: LucideIcons.users, gradientColors: [Colors.grey.shade300, Colors.grey.shade400], onTap: null),
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