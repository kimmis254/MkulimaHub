import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';


class MyDeliveriesScreen extends StatefulWidget {
  const MyDeliveriesScreen({super.key});

  @override
  State<MyDeliveriesScreen> createState() => _MyDeliveriesScreenState();
}

class _MyDeliveriesScreenState extends State<MyDeliveriesScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  List<dynamic> _myPledges = []; // 🔥 Now it starts empty!

  @override
  void initState() {
    super.initState();
    _fetchMyDeliveries();
  }

  // 🔥 The new function to fetch real data
  Future<void> _fetchMyDeliveries() async {
    final data = await _apiClient.getMyDeliveries();
    if (mounted) {
      setState(() {
        // Reverse the list so the newest pledges show up at the top
        _myPledges = data?.reversed.toList() ?? []; 
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text("My Deliveries", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      // 🔥 Add a loading spinner and an empty state
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.green))
        : _myPledges.isEmpty
            ? Center(child: Text("You haven't made any pledges yet.", style: GoogleFonts.poppins(color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _myPledges.length,
                itemBuilder: (context, index) {
                  final pledge = _myPledges[index];
                  return FadeInUp(
                    delay: Duration(milliseconds: 100 * index),
                    child: _buildTrackingCard(pledge),
                  );
                },
              ),
    );
  }

  Widget _buildTrackingCard(Map<String, dynamic> pledge) {
    final status = pledge['status'];
    final isRejected = status == 'rejected';
    
    // Status colors
    Color statusColor = Colors.orange;
    if (status == 'received') statusColor = Colors.blue;
    if (status == 'in_transit') statusColor = Colors.purple;
    if (status == 'delivered' || status == 'paid') statusColor = Colors.green;
    if (isRejected) statusColor = Colors.red;

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
          // Header: ID and Payout
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isRejected ? Colors.red.shade50 : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Tracking ID", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
                    Text(pledge['id'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("Expected Payout", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
                    Text(
                      "KES ${pledge['expected_payout']}", 
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: isRejected ? Colors.red : Colors.green.shade700, decoration: isRejected ? TextDecoration.lineThrough : null)
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Body: Crop Details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(LucideIcons.packageOpen, color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${pledge['weight_kg']} kg of ${pledge['crop']}", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text("Buyer: ${pledge['buyer']}", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                // THE TIMELINE
                if (!isRejected) _buildTimeline(status),
                
                // NOTES SECTION
                if (pledge['notes'] != null) ...[
                  if (!isRejected) const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
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
                          child: Text(pledge['notes'], style: GoogleFonts.poppins(fontSize: 12, color: isRejected ? Colors.red.shade900 : Colors.blue.shade900)),
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

  Widget _buildTimeline(String currentStatus) {
    int currentIndex = 0;
    if (currentStatus == 'received') currentIndex = 1;
    if (currentStatus == 'in_transit') currentIndex = 2;
    if (currentStatus == 'delivered') currentIndex = 3;
    if (currentStatus == 'paid') currentIndex = 4;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimelineStep("Drop-off", LucideIcons.store, currentIndex >= 0, currentIndex == 0, true),
        _buildTimelineStep("Hub", LucideIcons.home, currentIndex >= 1, currentIndex == 1, true),
        _buildTimelineStep("Transit", LucideIcons.truck, currentIndex >= 2, currentIndex == 2, true),
        _buildTimelineStep("Paid", LucideIcons.wallet, currentIndex >= 4, currentIndex == 4, false),
      ],
    );
  }

  Widget _buildTimelineStep(String label, IconData icon, bool isPassed, bool isActive, bool showLine) {
    Color color = isPassed ? Colors.green : Colors.grey.shade300;
    if (isActive) color = Colors.blue.shade600;

    return Expanded(
      child: Column(
        children: [
          Row(
            children: [
              // Left Line (Invisible for first item, otherwise colored based on past status)
              Expanded(child: Container(height: 3, color: isPassed ? color : Colors.transparent)),
              
              // The Dot/Icon
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : color,
                  shape: BoxShape.circle,
                  border: isActive ? Border.all(color: color, width: 3) : null,
                ),
                child: Icon(icon, size: 14, color: isActive ? color : Colors.white),
              ),
              
              // Right Line (Colored if the NEXT step is passed)
              Expanded(child: Container(height: 3, color: showLine ? (isPassed && !isActive ? Colors.green : Colors.grey.shade200) : Colors.transparent)),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? Colors.blue.shade800 : Colors.grey.shade600)),
        ],
      ),
    );
  }
}