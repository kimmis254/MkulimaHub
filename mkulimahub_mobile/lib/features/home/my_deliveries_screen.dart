import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/home/unattended_dropoff_screen.dart';

class MyDeliveriesScreen extends StatefulWidget {
  final String? targetOrderId; 
  const MyDeliveriesScreen({super.key, this.targetOrderId});

  @override
  State<MyDeliveriesScreen> createState() => _MyDeliveriesScreenState();
}

class _MyDeliveriesScreenState extends State<MyDeliveriesScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  List<dynamic> _myPledges = []; 

  @override
  void initState() {
    super.initState();
    _fetchMyDeliveries();
  }

  Future<void> _fetchMyDeliveries() async {
    final data = await _apiClient.getMyDeliveries();
    if (mounted) {
      setState(() {
        _myPledges = data?.reversed.toList() ?? []; 
        _isLoading = false;
      });
    }
  }
  Future<void> _handleStatusUpdate(int bulkRequestId, String newStatus) async {
    setState(() => _isLoading = true); // Show loading spinner
    final error = await _apiClient.updateSquadDeliveryStatus(bulkRequestId, newStatus);
    
    if (mounted) {
      if (error == null) {
        _fetchMyDeliveries(); // Refresh the screen to animate the timeline!
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Delivery status updated successfully!"), backgroundColor: Colors.green));
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    }
  }

  // Premium Button Builder for the Coordinator
  Widget _buildCoordinatorButton({required String title, required IconData icon, required MaterialColor color, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 18),
        label: Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.shade600,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          shadowColor: color.shade200
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // 🔥 Removed default AppBar in favor of a Custom Curved Header
      body: Column(
        children: [
          // 🔥 PREMIUM HEADER
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              left: 20, right: 20, bottom: 25, 
              top: MediaQuery.of(context).padding.top + 10 // Safe area clearance
            ),
            decoration: BoxDecoration(
              color: Colors.green.shade800,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.green.shade900.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 15),
                    Text("Logistics", style: GoogleFonts.poppins(color: Colors.green.shade100, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 10),
                Text("My Deliveries", style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                Text("Track your direct sales and bulk shipments.", style: GoogleFonts.poppins(color: Colors.green.shade50, fontSize: 13)),
              ],
            ),
          ),

          // 🔥 MAIN CONTENT
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
                            decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                            child: Icon(LucideIcons.packageSearch, size: 50, color: Colors.grey.shade400),
                          ),
                          const SizedBox(height: 15),
                          Text("No deliveries yet", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                          Text("Your active shipments will appear here.", style: GoogleFonts.poppins(color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _myPledges.length,
                      itemBuilder: (context, index) {
                        final pledge = _myPledges[index];
                        return FadeInUp(
                          delay: Duration(milliseconds: 100 * index),
                          child: _buildPremiumTrackingCard(pledge),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTrackingCard(Map<String, dynamic> pledge) {
    final status = pledge['status'] ?? 'pending';
    final isRejected = status == 'rejected';
    
    // 🔥 NEW: Check if it's a Bulk or Individual order (Assuming your backend sends a 'type' field, defaulting to Bulk)
    final String orderType = pledge['type'] ?? 'Bulk Contract'; 
    final bool isBulk = orderType.toLowerCase().contains('bulk');

    // Status Colors & Gradients
    Color primaryColor = Colors.orange;
    Color lightColor = Colors.orange.shade50;
    if (status == 'received') { primaryColor = Colors.blue; lightColor = Colors.blue.shade50; }
    if (status == 'in_transit') { primaryColor = Colors.purple; lightColor = Colors.purple.shade50; }
    if (status == 'delivered' || status == 'paid') { primaryColor = Colors.green; lightColor = Colors.green.shade50; }
    if (isRejected) { primaryColor = Colors.red; lightColor = Colors.red.shade50; }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))],
        border: Border.all(color: isRejected ? Colors.red.shade200 : Colors.grey.shade100, width: isRejected ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔥 Premium Header with Order Type Badge
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: lightColor,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔥 NEW: Dynamic Badge separating Bulk vs Direct Sales
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isBulk ? Colors.purple.shade100 : Colors.teal.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isBulk ? "Bulk Squad" : "Direct Sale", 
                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: isBulk ? Colors.purple.shade800 : Colors.teal.shade800)
                      ),
                    ),
                    Text("ID: #${pledge['id']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("Expected Payout", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
                    Text(
                      "KES ${pledge['expected_payout'] ?? 0}", 
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: isRejected ? Colors.red : Colors.green.shade700, decoration: isRejected ? TextDecoration.lineThrough : null)
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 🔥 Body: Crop Details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: primaryColor.withOpacity(0.15), shape: BoxShape.circle),
                      child: Icon(LucideIcons.package, color: primaryColor, size: 22),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${pledge['weight_kg'] ?? 0} ${pledge['unit'] ?? 'KG'} of ${pledge['crop'] ?? 'Produce'}", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text("Buyer: ${pledge['buyer'] ?? 'Unknown'}", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                // 🔥 Upgraded Timeline
                if (!isRejected) _buildModernTimeline(status),
                
                // =========================================================
                // 🔥 MOVED: SQUAD COORDINATOR CONTROLS (Right under timeline!)
                // =========================================================
                if (pledge['is_coordinator'] == true && !isRejected) ...[
                  const SizedBox(height: 25),

                  if (status == 'pledged' || status == 'gathering')
                    Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.shieldAlert, size: 16, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              Text("Awaiting Verification to Start Transit", style: GoogleFonts.poppins(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // 🔥 The Fallback for Hub Pools if the Admin is missing
                        _buildCoordinatorButton(
                          title: "Admin Absent? Digital Drop-off",
                          icon: LucideIcons.camera,
                          color: Colors.red,
                          onTap: () async {
                            // (Ensure you have imported unattended_dropoff_screen.dart at the top!)
                            final didSubmit = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => UnattendedDropoffScreen(
                                squadId: pledge['bulk_request_id'],
                                cropName: pledge['crop'] ?? 'Produce',
                              ))
                            );
                            if (didSubmit == true && mounted) _fetchMyDeliveries();
                          },
                        )
                      ]
                    )
                  else if (status == 'pending_audit')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.clock, size: 16, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Text("Awaiting Hub Admin Audit", style: GoogleFonts.poppins(color: Colors.red.shade800, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  else if (status == 'received')
                    // 🔥 ISSUE 2 FIXED: Only when VERIFIED can they start the journey!
                    _buildCoordinatorButton(
                      title: "Start Journey to Buyer",
                      icon: LucideIcons.truck,
                      color: Colors.purple,
                      onTap: () => _handleStatusUpdate(pledge['bulk_request_id'], 'in_transit'),
                    )
                  else if (status == 'in_transit')
                    _buildCoordinatorButton(
                      title: "Confirm Arrival at Buyer",
                      icon: LucideIcons.mapPin,
                      color: Colors.green,
                      onTap: () => _handleStatusUpdate(pledge['bulk_request_id'], 'delivered'),
                    )
                  else if (status == 'delivered')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.clock, size: 16, color: Colors.grey.shade500),
                          const SizedBox(width: 8),
                          Text("Waiting for Buyer Verification", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  else if (status == 'paid' || status == 'completed')
                     Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.checkCheck, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text("Mission Accomplished", style: GoogleFonts.poppins(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                ],
                // =========================================================
                
                // Notes Section (This now sits safely BELOW the buttons!)
                if (pledge['notes'] != null && pledge['notes'].toString().isNotEmpty) ...[
                  if (!isRejected) const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isRejected ? Colors.red.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isRejected ? Colors.red.shade200 : Colors.blue.shade100)
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(isRejected ? LucideIcons.alertTriangle : LucideIcons.info, size: 16, color: isRejected ? Colors.red : Colors.blue.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(pledge['notes'], style: GoogleFonts.poppins(fontSize: 12, color: isRejected ? Colors.red.shade900 : Colors.blue.shade900, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  )
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildModernTimeline(String currentStatus) {
    int currentIndex = 0; // Default to pending/drop-off
    if (currentStatus == 'received') currentIndex = 1;
    if (currentStatus == 'in_transit') currentIndex = 2;
    if (currentStatus == 'delivered' || currentStatus == 'fulfilled') currentIndex = 3;
    if (currentStatus == 'paid') currentIndex = 4;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModernTimelineStep("Drop-off", LucideIcons.store, currentIndex >= 0, currentIndex == 0, true),
        _buildModernTimelineStep("Hub", LucideIcons.home, currentIndex >= 1, currentIndex == 1, true),
        _buildModernTimelineStep("Transit", LucideIcons.truck, currentIndex >= 2, currentIndex == 2, true),
        _buildModernTimelineStep("Paid", LucideIcons.wallet, currentIndex >= 4, currentIndex == 4, false),
      ],
    );
  }

  Widget _buildModernTimelineStep(String label, IconData icon, bool isPassed, bool isActive, bool showLine) {
    Color nodeColor = isPassed ? Colors.green.shade500 : Colors.grey.shade200;
    if (isActive) nodeColor = Colors.blue.shade600;

    Widget nodeIcon = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? Colors.blue.shade600 : (isPassed ? Colors.green.shade500 : Colors.grey.shade100),
        shape: BoxShape.circle,
        border: isActive ? null : Border.all(color: isPassed ? Colors.green.shade600 : Colors.grey.shade300, width: 1.5),
        boxShadow: isActive ? [BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))] : [],
      ),
      child: Icon(
        isPassed && !isActive ? LucideIcons.check : icon, // Show a checkmark if passed!
        size: 14, 
        color: isActive || isPassed ? Colors.white : Colors.grey.shade400
      ),
    );

    // Make the active step pulse slightly!
    if (isActive) {
      nodeIcon = Pulse(infinite: true, child: nodeIcon);
    }

    return Expanded(
      child: Column(
        children: [
          Row(
            children: [
              // Left Line
              Expanded(child: Container(height: 3, color: isPassed ? Colors.green.shade400 : Colors.transparent)),
              
              nodeIcon,
              
              // Right Line
              Expanded(child: Container(height: 3, color: showLine ? (isPassed && !isActive ? Colors.green.shade400 : Colors.grey.shade200) : Colors.transparent)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label, 
            style: GoogleFonts.poppins(
              fontSize: 10, 
              fontWeight: isActive ? FontWeight.bold : FontWeight.w600, 
              color: isActive ? Colors.blue.shade800 : (isPassed ? Colors.green.shade700 : Colors.grey.shade500)
            )
          ),
        ],
      ),
    );
  }
}