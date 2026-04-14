import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';

class ReceivingDashboard extends StatefulWidget {
  const ReceivingDashboard({super.key});

  @override
  State<ReceivingDashboard> createState() => _ReceivingDashboardState();
}

class _ReceivingDashboardState extends State<ReceivingDashboard> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  List<dynamic> _deliveries = [];

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
        _deliveries = data ?? [];
        _isLoading = false;
      });
    }
  }

  // 🔥 THE PREMIUM TOAST FUNCTION
  void _showPremiumToast(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(isError ? LucideIcons.alertCircle : LucideIcons.checkCircle, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message, 
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)
                )
              ),
            ],
          ),
        ),
        backgroundColor: isError ? Colors.red.shade800 : Colors.teal.shade800,
        behavior: SnackBarBehavior.floating,
        // 🔥 THIS MARGIN PUSHES IT TO THE MIDDLE OF THE SCREEN
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.45, // 45% up the screen!
          left: 24,
          right: 24,
        ),
        elevation: 15,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showProcessingSheet(Map<String, dynamic> delivery) {
    final TextEditingController weightController = TextEditingController(text: delivery['pledged_weight'].toString());
    final TextEditingController notesController = TextEditingController();
    bool isSubmitting = false;
    String? errorMessage; // 🔥 NEW: Holds in-form validation errors

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
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
                    Text("Process Drop-off", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text("Farmer: ${delivery['farmer_name']}", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14)),
                    const SizedBox(height: 25),
                    
                    Text("Scale Weight (KG)", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        suffixText: "KG",
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: const Icon(LucideIcons.scale, color: Colors.blue),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text("Quality Notes (Optional)", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: "E.g., Good quality, slightly high moisture...",
                        hintStyle: GoogleFonts.poppins(fontSize: 12),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 🔥 NEW: IN-FORM ERROR MESSAGE
                    if (errorMessage != null)
                      FadeIn(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
                          child: Row(
                            children: [
                              Icon(LucideIcons.alertTriangle, color: Colors.red.shade600, size: 18),
                              const SizedBox(width: 10),
                              Expanded(child: Text(errorMessage!, style: GoogleFonts.poppins(color: Colors.red.shade800, fontSize: 12, fontWeight: FontWeight.w600))),
                            ],
                          ),
                        ),
                      ),
                    
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSubmitting ? null : () async {
                              if (notesController.text.isEmpty) {
                                // Show error inside the sheet instead of a hidden toast!
                                setSheetState(() => errorMessage = "Please add a reason for rejection.");
                                return;
                              }
                              setSheetState(() {
                                errorMessage = null; // Clear previous errors
                                isSubmitting = true;
                              });
                              final error = await _apiClient.processDelivery(delivery['pledge_id'], "reject", null, notesController.text);
                              
                              if (mounted) {
                                Navigator.pop(context); // 1. Start closing the sheet
                                await Future.delayed(const Duration(milliseconds: 300)); // 2. Wait for it to slide off-screen
                                
                                if (error == null) {
                                  _showPremiumToast(context, "Delivery Rejected.", isError: true); // 3. Fire the toast!
                                  _fetchDeliveries();
                                } else {
                                  _showPremiumToast(context, error, isError: true);
                                }
                              }
                            },
                            icon: const Icon(LucideIcons.xCircle, color: Colors.red),
                            label: Text("Reject", style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isSubmitting ? null : () async {
                              double? finalWeight = double.tryParse(weightController.text);
                              if (finalWeight == null) {
                                setSheetState(() => errorMessage = "Please enter a valid weight.");
                                return;
                              }

                              setSheetState(() {
                                errorMessage = null;
                                isSubmitting = true;
                              });
                              final error = await _apiClient.processDelivery(delivery['pledge_id'], "receive", finalWeight, notesController.text);
                              
                              if (mounted) {
                                Navigator.pop(context); // 1. Start closing the sheet
                                await Future.delayed(const Duration(milliseconds: 300)); // 2. Wait for it to slide off-screen
                                
                                if (error == null) {
                                  _showPremiumToast(context, "Crop Received & Stored!"); // 3. Fire the toast!
                                  _fetchDeliveries();
                                } else {
                                  _showPremiumToast(context, error, isError: true);
                                }
                              }
                            },
                            icon: const Icon(LucideIcons.checkCircle, color: Colors.white),
                            label: Text("Accept", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    List<dynamic> pending = _deliveries.where((d) => d['status'] == 'pending_dropoff').toList();
    List<dynamic> completed = _deliveries.where((d) => d['status'] != 'pending_dropoff').toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
        centerTitle: true,
        title: Text("Hub Operations", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : RefreshIndicator(
              onRefresh: _fetchDeliveries,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text("Pending Drop-offs (${pending.length})", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  if (pending.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16)),
                      child: Center(child: Text("All caught up! No farmers waiting.", style: GoogleFonts.poppins(color: Colors.blue.shade800))),
                    )
                  else
                    ...pending.map((d) => FadeInLeft(child: _buildDeliveryCard(d, isPending: true))),

                  const SizedBox(height: 30),
                  
                  Text("Processed Today", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  if (completed.isEmpty)
                    Text("No crops processed yet.", style: GoogleFonts.poppins(color: Colors.grey))
                  else
                    ...completed.map((d) => _buildDeliveryCard(d, isPending: false)),
                ],
              ),
            ),
    );
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery, {required bool isPending}) {
    bool isRejected = delivery['status'] == 'rejected';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: isPending ? [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))] : [],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: isPending ? Colors.orange.shade50 : (isRejected ? Colors.red.shade50 : Colors.green.shade50),
          child: Icon(
            isPending ? LucideIcons.clock : (isRejected ? LucideIcons.xCircle : LucideIcons.checkCircle),
            color: isPending ? Colors.orange : (isRejected ? Colors.red : Colors.green),
          ),
        ),
        title: Text(delivery['farmer_name'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text("${delivery['pledged_weight']} kg • ${delivery['crop_name']}", style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 13)),
            if (!isPending)
              Text("Logged: ${delivery['actual_weight'] ?? delivery['pledged_weight']} kg", style: GoogleFonts.poppins(color: isRejected ? Colors.red : Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: isPending
            ? ElevatedButton(
                onPressed: () => _showProcessingSheet(delivery),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: Text("Process", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            : null,
      ),
    );
  }
}