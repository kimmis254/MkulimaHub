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
      setState(() {
        _squadDeliveries = data ?? [];
        _isLoading = false;
      });
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
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("Receiving Station", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.green))
        : _squadDeliveries.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                color: Colors.green,
                onRefresh: _fetchDeliveries,
                child: ListView.builder(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 80),
                  itemCount: _squadDeliveries.length,
                  itemBuilder: (context, index) {
                    return FadeInUp(
                      delay: Duration(milliseconds: 100 * index),
                      child: _buildAggregatedTruckCard(_squadDeliveries[index]),
                    );
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
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
            child: Icon(LucideIcons.warehouse, size: 60, color: Colors.green.shade200),
          ),
          const SizedBox(height: 20),
          Text("No Incoming Trucks", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 5),
          Text("There are no delivery squads\nheaded to your co-op right now.", textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildAggregatedTruckCard(Map<String, dynamic> squad) {
    final status = squad['status'];
    final isArrived = status == 'delivered'; 
    final isProcessed = status == 'received'; 
    final isPendingAudit = status == 'pending_audit'; // 🔥 NEW STATE

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: isProcessed ? Colors.green.shade200 : (isPendingAudit ? Colors.red.shade200 : Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔥 PREMIUM HEADER
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isProcessed 
                  ? LinearGradient(colors: [Colors.green.shade50, Colors.green.shade100])
                  : isPendingAudit 
                      ? LinearGradient(colors: [Colors.red.shade50, Colors.red.shade100]) // 🔥 Red for Audit!
                      : (isArrived 
                          ? LinearGradient(colors: [Colors.orange.shade50, Colors.orange.shade100])
                          : LinearGradient(colors: [Colors.blue.shade50, Colors.blue.shade100])),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(
                    isProcessed ? LucideIcons.checkCircle : isPendingAudit ? LucideIcons.shieldAlert : (isArrived ? LucideIcons.mapPin : LucideIcons.truck), 
                    color: isProcessed ? Colors.green : isPendingAudit ? Colors.red.shade700 : (isArrived ? Colors.orange.shade700 : Colors.blue.shade700)
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isProcessed ? "Verified & Stored" : isPendingAudit ? "Audit Required" : (isArrived ? "Waiting at the Gate" : "Currently In Transit"), 
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: isProcessed ? Colors.green.shade900 : isPendingAudit ? Colors.red.shade900 : Colors.black87)
                      ),
                      Text(isPendingAudit ? "Unattended Drop-off Evidence Submitted" : "Squad ID: #BLK-${squad['squad_id'].toString().padLeft(4, '0')}", style: GoogleFonts.poppins(fontSize: 12, color: isPendingAudit ? Colors.red.shade700 : Colors.grey.shade700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 🔥 SQUAD DETAILS
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Wrap the entire left side in Expanded so it shrinks instead of overflowing!
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.userCircle, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              // 2. Wrap inner text in Expanded with an ellipsis
                              Expanded(
                                child: Text("Driver (Coordinator)", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          Text(squad['coordinator_name'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              "👥 Aggregated from ${squad['farmer_count']} Farmers", 
                              style: GoogleFonts.poppins(fontSize: 10, color: Colors.purple.shade700, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis, // Add ellipsis just in case
                            ),
                          )
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 10), // Add a safe buffer between left and right!
                    
                    // 3. The right side stays its natural size
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Expected Cargo", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                        Text("${squad['total_pledged']} kg", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green.shade700)),
                        Text(squad['crop_name'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),

                // 🔥 ACTION BUTTONS
                if (isProcessed)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Center(
                      child: Text("Successfully weighed at ${squad['total_actual']} kg", style: GoogleFonts.poppins(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  )
                else if (isPendingAudit)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAuditSheet(squad), // 🔥 Launches the Evidence Viewer!
                      icon: const Icon(LucideIcons.camera, color: Colors.white, size: 18),
                      label: Text("Review Evidence & Approve", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        shadowColor: Colors.red.shade200
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showWeighingScaleSheet(squad),
                      icon: const Icon(LucideIcons.scale, color: Colors.white, size: 18),
                      label: Text(isArrived ? "Weigh Entire Truck" : "Prepare for Arrival", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isArrived ? Colors.orange.shade600 : Colors.blue.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        shadowColor: isArrived ? Colors.orange.shade200 : Colors.blue.shade200
                      ),
                    ),
                  )
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showWeighingScaleSheet(Map<String, dynamic> squad) {
    final TextEditingController weightController = TextEditingController(text: squad['total_pledged'].toString());
    final TextEditingController notesController = TextEditingController();
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 20),
                      Text("Quality Control", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("Verify the physical delivery from ${squad['coordinator_name']}'s truck.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 15),
                      
                      // Auto-Math Explainer
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.shade100)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(LucideIcons.info, color: Colors.blue, size: 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Any differences in weight will be automatically split between the ${squad['farmer_count']} farmers using a fair pro-rata algorithm.", 
                                style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue.shade800)
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Scale Input
                      Text("Actual Weight on Scale (KG)", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: "E.g., 500.5",
                          prefixIcon: const Icon(LucideIcons.scale, color: Colors.green),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.green)),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Notes Input
                      Text("Inspection Notes (Optional)", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: "E.g., Moisture content is optimal.",
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting ? null : () async {
                                setSheetState(() => isSubmitting = true);
                                final error = await _apiClient.processDelivery(squad['squad_id'], 'reject', null, notesController.text.trim());
                                if (mounted) {
                                  Navigator.pop(context);
                                  if (error == null) {
                                    _fetchDeliveries();
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Entire Squad Rejected."), backgroundColor: Colors.red));
                                  }
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: isSubmitting ? null : () async {
                                final actualWeight = double.tryParse(weightController.text.trim());
                                if (actualWeight == null) return;

                                setSheetState(() => isSubmitting = true);
                                final error = await _apiClient.processDelivery(squad['squad_id'], 'receive', actualWeight, notesController.text.trim());
                                
                                if (mounted) {
                                  Navigator.pop(context);
                                  if (error == null) {
                                    _fetchDeliveries();
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Delivery Verified successfully!"), backgroundColor: Colors.green));
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 4,
                              ),
                              child: isSubmitting 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("Verify Delivery", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      )
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
  void _showAuditSheet(Map<String, dynamic> squad) {
    final TextEditingController weightController = TextEditingController(text: squad['total_pledged'].toString());
    final TextEditingController notesController = TextEditingController();
    bool isSubmitting = false;

    // Helper to decode Base64 safely
    Widget buildEvidenceImage(String? base64String) {
      if (base64String == null || base64String.isEmpty) return const Center(child: Text("Image missing"));
      try {
        final pureBase64 = base64String.split(',').last; // Strip the 'data:image/jpeg;base64,' prefix
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(base64Decode(pureBase64), fit: BoxFit.cover, width: double.infinity, height: 150),
        );
      } catch (e) {
        return const Center(child: Text("Error loading image"));
      }
    }

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
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 20),
                      Text("Unattended Drop-off Audit", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                      Text("Review the evidence submitted by ${squad['coordinator_name']}.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 20),
                      
                      // The Photos
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Scale Reading", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(height: 5),
                                buildEvidenceImage(squad['evidence_scale']),
                              ],
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Secure Storage", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(height: 5),
                                buildEvidenceImage(squad['evidence_crop']),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 25),
                      const Divider(),
                      const SizedBox(height: 15),

                      // Verification Input
                      Text("Verify Weight (KG) from Photo", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.scale, color: Colors.green),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.green)),
                        ),
                      ),
                      const SizedBox(height: 15),
                      
                      TextField(
                        controller: notesController,
                        decoration: InputDecoration(
                          hintText: "Audit Notes (E.g., Photos verified.)",
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Approve Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isSubmitting ? null : () async {
                            final actualWeight = double.tryParse(weightController.text.trim());
                            if (actualWeight == null) return;

                            setSheetState(() => isSubmitting = true);
                            
                            // 🔥 Uses the EXACT same powerful endpoint to trigger the Pro-Rata math and release funds!
                            final error = await _apiClient.processDelivery(squad['squad_id'], 'receive', actualWeight, notesController.text.trim());
                            
                            if (mounted) {
                              Navigator.pop(context);
                              if (error == null) {
                                _fetchDeliveries();
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Audit Approved! Funds Released."), backgroundColor: Colors.green));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                              }
                            }
                          },
                          icon: const Icon(LucideIcons.checkCircle, color: Colors.white),
                          label: Text("Approve & Release Funds", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      )
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