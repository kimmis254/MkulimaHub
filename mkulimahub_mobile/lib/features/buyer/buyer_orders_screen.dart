import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class BuyerOrdersScreen extends StatefulWidget {
  const BuyerOrdersScreen({super.key});

  @override
  State<BuyerOrdersScreen> createState() => _BuyerOrdersScreenState();
}

class _BuyerOrdersScreenState extends State<BuyerOrdersScreen> {
  int _selectedTab = 0; // 0: Active, 1: In Transit, 2: History

  // 🔥 MOCK DATA: Active Bulk Requests (Waiting for farmers to pledge)
  final List<Map<String, dynamic>> _activeOrders = [
    {
      "crop": "Grade 1 Maize",
      "target": 5000,
      "pledged": 3450,
      "price": "KES 4,500/bag",
      "location": "Rift Valley Hub",
      "daysLeft": 3,
    },
    {
      "crop": "Red Onions",
      "target": 1000,
      "pledged": 200,
      "price": "KES 120/kg",
      "location": "Kajiado Hub",
      "daysLeft": 7,
    }
  ];

  // 🔥 MOCK DATA: In Transit
  final List<Map<String, dynamic>> _inTransitOrders = [
    {
      "crop": "Hass Avocados",
      "weight": 850,
      "driver": "Kamau N.",
      "plate": "KDF 492X",
      "eta": "Today, 4:30 PM",
      "status": "Approaching Nairobi"
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // 🔥 PREMIUM TEAL HEADER
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 25),
              decoration: BoxDecoration(
                color: Colors.teal.shade800,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)),
                boxShadow: [BoxShadow(color: Colors.teal.shade900.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Supply Chain", style: GoogleFonts.poppins(color: Colors.teal.shade200, fontSize: 13, fontWeight: FontWeight.w500)),
                          Text("My Orders", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26, letterSpacing: 0.5)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                        child: const Icon(LucideIcons.packageSearch, color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  
                  // 🔥 CUSTOM TAB BAR
                  Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        _buildTab(0, "Gathering"),
                        _buildTab(1, "In Transit"),
                        _buildTab(2, "History"),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),

          // 🔥 CONTENT AREA
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (_selectedTab == 0) return _buildActiveOrderCard(_activeOrders[index], index);
                  if (_selectedTab == 1) return _buildTransitCard(_inTransitOrders[index], index);
                  return _buildEmptyState("No past orders found.");
                },
                childCount: _selectedTab == 0 ? _activeOrders.length : (_selectedTab == 1 ? _inTransitOrders.length : 1),
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)), // Padding for bottom nav
        ],
      ),
    );
  }

  // ==========================================
  // UI WIDGETS
  // ==========================================

  Widget _buildTab(int index, String title) {
    bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)] : [],
          ),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              color: isSelected ? Colors.teal.shade900 : Colors.teal.shade100,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveOrderCard(Map<String, dynamic> order, int index) {
    double progress = order['pledged'] / order['target'];
    
    return FadeInUp(
      delay: Duration(milliseconds: index * 100),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Icon(LucideIcons.clock, size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Text("${order['daysLeft']} Days Left", style: GoogleFonts.poppins(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Text(order['price'], style: GoogleFonts.poppins(color: Colors.teal.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 15),
            Text(order['crop'], style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(LucideIcons.mapPin, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text("Aggregating at: ${order['location']}", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 20),
            
            // 🔥 CUSTOM PROGRESS BAR
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${order['pledged']} kg pledged", style: GoogleFonts.poppins(color: Colors.teal.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                Text("Target: ${order['target']} kg", style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.teal.shade50,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransitCard(Map<String, dynamic> order, int index) {
    return FadeInUp(
      delay: Duration(milliseconds: index * 100),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.teal.shade100, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
                  child: Icon(LucideIcons.truck, color: Colors.teal.shade700),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${order['weight']}kg of ${order['crop']}", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      Text(order['status'], style: GoogleFonts.poppins(color: Colors.orange.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Divider(height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Driver: ${order['driver']}", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)),
                    Text("Plate: ${order['plate']}", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
                  child: Text("Track GPS", style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Column(
          children: [
            Icon(LucideIcons.packageOpen, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 15),
            Text(message, style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}