import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'dart:convert';

class ReceivingDashboard extends StatefulWidget {
  const ReceivingDashboard({super.key});

  @override
  State<ReceivingDashboard> createState() => _ReceivingDashboardState();
}

class _ReceivingDashboardState extends State<ReceivingDashboard> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  List<dynamic> _squadDeliveries = [];

  @override
  void initState() {
    super.initState();
    _fetchDeliveries();
  }

  Future<void> _fetchDeliveries() async {
    setState(() => _isLoading = true);
    final data = await _apiClient.getHubDeliveries();
    
    if (mounted) {
      List<dynamic> sortedData = data ?? [];
      
      // 🔥 THE FIX: Sort 'Awaiting Approval' to the very top!
      sortedData.sort((a, b) {
        bool aPending = a['status'] == 'pending_audit';
        bool bPending = b['status'] == 'pending_audit';
        
        if (aPending && !bPending) return -1; // A jumps to top
        if (!aPending && bPending) return 1;  // B jumps to top
        
        // Otherwise, sort by newest squad ID first
        int aId = a['squad_id'] ?? 0;
        int bId = b['squad_id'] ?? 0;
        return bId.compareTo(aId); 
      });

      setState(() {
        _squadDeliveries = sortedData;
        _isLoading = false;
      });
    }
  }

  Widget buildEvidenceImage(String? base64String) {
    if (base64String == null || base64String.isEmpty) return const Center(child: Text("Image missing"));
    try {
      final pureBase64 = base64String.split(',').last; 
      return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(base64Decode(pureBase64), fit: BoxFit.cover, width: double.infinity, height: 150));
    } catch (e) {
      return const Center(child: Text("Error loading image"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.green.shade800, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: Colors.white),
        title: Text("Receiving Station", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.green))
        : _squadDeliveries.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                color: Colors.green, onRefresh: _fetchDeliveries,
                child: ListView.builder(
                  padding: const EdgeInsets.all(20), itemCount: _squadDeliveries.length,
                  itemBuilder: (context, index) {
                    return FadeInUp(delay: Duration(milliseconds: 100 * index), child: _buildAggregatedTruckCard(_squadDeliveries[index]));
                  },
                ),
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle), child: Icon(LucideIcons.warehouse, size: 60, color: Colors.green.shade200)),
          const SizedBox(height: 20),
          Text("No Incoming Produce", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 5),
          Text("All active Hub Pools are currently empty.", textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildAggregatedTruckCard(Map<String, dynamic> squad) {
    final status = squad['status'];
    final isProcessed = status == 'received'; 
    final isPendingAudit = status == 'pending_audit'; 

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: isProcessed ? Colors.green.shade200 : (isPendingAudit ? Colors.red.shade200 : Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isProcessed ? Colors.green.shade50 : (isPendingAudit ? Colors.red.shade50 : Colors.blue.shade50),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(isProcessed ? LucideIcons.checkCircle : isPendingAudit ? LucideIcons.shieldAlert : LucideIcons.box, color: isProcessed ? Colors.green : isPendingAudit ? Colors.red.shade700 : Colors.blue.shade700),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isProcessed ? "All Goods Verified" : isPendingAudit ? "Action Required" : "Receiving in Progress", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: isProcessed ? Colors.green.shade900 : isPendingAudit ? Colors.red.shade900 : Colors.black87)),
                      Text("Pool ID: #BLK-${squad['squad_id'].toString().padLeft(4, '0')}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Active Contributors", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                        Text("${squad['farmer_count']} Farmers", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Actual Hub Inventory", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                        Text("${squad['total_actual']} / ${squad['total_pledged']} kg", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green.shade700)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                Text("Individual Drop-offs", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 15),
                
                ...((squad['roster'] as List? ?? []).map((member) {
                  final memberStatus = member['status'];
                  final isRejected = memberStatus == 'rejected';
                  final isReceived = memberStatus == 'received' || memberStatus == 'in_transit' || memberStatus == 'delivered' || memberStatus == 'completed' || memberStatus == 'paid';
                  final isPendingAudit = memberStatus == 'pending_audit';
                  final hasEvidence = member['notes'].toString().startsWith("EVIDENCE_LOG|");

                  return Container(
                    margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isRejected ? Colors.grey.shade50 : (isReceived ? Colors.green.shade50 : Colors.white),
                      border: Border.all(color: isRejected ? Colors.grey.shade300 : (isReceived ? Colors.green.shade300 : Colors.grey.shade200)),
                      borderRadius: BorderRadius.circular(16)
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(backgroundColor: Colors.blue.shade50, child: const Icon(LucideIcons.user, color: Colors.blue)),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(member['farmer_name'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, decoration: isRejected ? TextDecoration.lineThrough : null)),
                                  Text("Pledged: ${member['pledged_kg']} KG", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            if (isReceived)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("Verified ✅", style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                                  Text("Actual: ${member['actual_kg']} KG", style: GoogleFonts.poppins(fontSize: 11, color: Colors.green.shade900)),
                                ],
                              )
                            else if (isRejected)
                              Text("No-Show", style: GoogleFonts.poppins(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold))
                          ],
                        ),
                        
                        if (!isReceived && !isRejected) ...[
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              if (isPendingAudit && hasEvidence)
                                Expanded(flex: 2, child: ElevatedButton.icon(onPressed: () => _showAuditDialog(member, null), icon: const Icon(LucideIcons.camera, size: 14), label: const Text("Evidence"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white)))
                              else
                                Expanded(flex: 2, child: ElevatedButton.icon(onPressed: () => _showManualReceiveDialog(member, null), icon: const Icon(LucideIcons.scale, size: 14), label: const Text("Weigh"), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600, foregroundColor: Colors.white))),
                              const SizedBox(width: 10),
                              Expanded(child: OutlinedButton(onPressed: () async { await _apiClient.updatePledgeStatus(member['pledge_id'], 'rejected'); _fetchDeliveries(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Farmer marked as No-Show."), backgroundColor: Colors.red)); }, style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text("No-Show", style: TextStyle(fontSize: 11))))
                            ],
                          )
                        ]
                      ],
                    ),
                  );
                }))
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showManualReceiveDialog(Map<String, dynamic> member, StateSetter? setSheetState) {
    final TextEditingController weightController = TextEditingController(text: member['pledged_kg'].toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Receive ${member['farmer_name']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Pledged: ${member['pledged_kg']} KG", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(controller: weightController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Actual KG on Scale", prefixIcon: Icon(LucideIcons.scale)))
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final actualWeight = double.tryParse(weightController.text);
              if (actualWeight != null) {
                await _apiClient.receiveLineItem(member['pledge_id'], actualWeight, "Physically received at Hub.");
                if (mounted) { 
                  Navigator.pop(ctx); 
                  if (setSheetState != null) { setSheetState(() { member['status'] = 'received'; member['actual_kg'] = actualWeight; }); } 
                  else { setState(() { member['status'] = 'received'; member['actual_kg'] = actualWeight; }); }
                  _fetchDeliveries(); 
                }
              }
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("Confirm Weight")
          )
        ]
      )
    );
  }

  void _showAuditDialog(Map<String, dynamic> member, StateSetter? setSheetState) {
    final parts = member['notes'].toString().split('|');
    final scalePhoto = parts.length > 1 ? parts[1] : null;
    final cropPhoto = parts.length > 2 ? parts[2] : null;
    final TextEditingController weightController = TextEditingController(text: member['pledged_kg'].toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Audit ${member['farmer_name']}"),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [Expanded(child: buildEvidenceImage(scalePhoto)), const SizedBox(width: 10), Expanded(child: buildEvidenceImage(cropPhoto))]),
                const SizedBox(height: 15),
                TextField(controller: weightController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Verify Exact KG", prefixIcon: Icon(LucideIcons.checkCircle)))
              ]
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final actualWeight = double.tryParse(weightController.text);
              if (actualWeight != null) {
                await _apiClient.receiveLineItem(member['pledge_id'], actualWeight, "Digital Drop-off Approved.");
                if (mounted) { 
                  Navigator.pop(ctx);
                  if (setSheetState != null) { setSheetState(() { member['status'] = 'received'; member['actual_kg'] = actualWeight; }); } 
                  else { setState(() { member['status'] = 'received'; member['actual_kg'] = actualWeight; }); }
                  _fetchDeliveries(); 
                }
              }
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("Approve")
          )
        ]
      )
    );
  }
}