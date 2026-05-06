import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';

class BuyerOrdersScreen extends StatefulWidget {
  const BuyerOrdersScreen({super.key});

  @override
  State<BuyerOrdersScreen> createState() => _BuyerOrdersScreenState();
}

class _BuyerOrdersScreenState extends State<BuyerOrdersScreen> {
  int _selectedTab = 0; 
  final ApiClient _apiClient = ApiClient();
  
  bool _isLoading = true;
  List<dynamic> _gatheringOrders = [];
  List<dynamic> _transitOrders = [];
  List<dynamic> _historyOrders = []; // 🔥 ADDED HISTORY

  @override
  void initState() {
    super.initState();
    _fetchLiveOrders();
  }

  Future<void> _fetchLiveOrders() async {
    setState(() => _isLoading = true);
    final data = await _apiClient.getBuyerDashboard();
    
    if (mounted) {
      if (data != null && data['contracts'] != null) {
        final List<dynamic> contracts = data['contracts'];
        
        setState(() {
          _gatheringOrders = contracts.where((c) => c['status'] == 'active').toList();
          _transitOrders = contracts.where((c) => c['status'] == 'fulfilled').toList();
          
          // 🔥 Pull the completed orders into history!
          _historyOrders = contracts.where((c) => c['status'] == 'completed').toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 25),
              decoration: BoxDecoration(color: Colors.teal.shade800, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)), boxShadow: [BoxShadow(color: Colors.teal.shade900.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))]),
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
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(LucideIcons.packageSearch, color: Colors.white, size: 24)),
                    ],
                  ),
                  const SizedBox(height: 25),
                  
                  Container(
                    height: 45,
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.15), borderRadius: BorderRadius.circular(25)),
                    child: Row(
                      children: [
                        _buildTab(0, "Gathering (${_gatheringOrders.length})"),
                        _buildTab(1, "Deliveries (${_transitOrders.length})"),
                        _buildTab(2, "History (${_historyOrders.length})"), // 🔥 Activate History Count
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),

          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.teal)))
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (_selectedTab == 0) {
                      if (_gatheringOrders.isEmpty) return _buildEmptyState("No active orders gathering.");
                      return _buildActiveOrderCard(_gatheringOrders[index], index);
                    }
                    if (_selectedTab == 1) {
                      if (_transitOrders.isEmpty) return _buildEmptyState("No active deliveries.");
                      return _buildTransitCard(_transitOrders[index], index);
                    }
                    if (_selectedTab == 2) {
                      if (_historyOrders.isEmpty) return _buildEmptyState("No completed orders yet.");
                      return _buildHistoryCard(_historyOrders[index], index);
                    }
                    return const SizedBox.shrink();
                  },
                  childCount: _selectedTab == 0 ? (_gatheringOrders.isEmpty ? 1 : _gatheringOrders.length) 
                            : _selectedTab == 1 ? (_transitOrders.isEmpty ? 1 : _transitOrders.length) 
                            : (_historyOrders.isEmpty ? 1 : _historyOrders.length),
                ),
              ),
            ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)), 
        ],
      ),
    );
  }

  Widget _buildTab(int index, String title) {
    bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(25), boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)] : []),
          child: Text(title, style: GoogleFonts.poppins(color: isSelected ? Colors.teal.shade900 : Colors.teal.shade100, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildActiveOrderCard(Map<String, dynamic> order, int index) {
    double progress = (order['progress_percentage'] ?? 0).toDouble();
    return FadeInUp(
      delay: Duration(milliseconds: index * 100),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)), child: Row(children: [Icon(LucideIcons.radioReceiver, size: 14, color: Colors.orange.shade700), const SizedBox(width: 6), Text("Broadcasting to Hubs", style: GoogleFonts.poppins(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.bold))])),
                Text("KES ${order['price_per_kg']}/kg", style: GoogleFonts.poppins(color: Colors.teal.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 15),
            Text(order['crop_name'] ?? 'Produce', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 4),
            Row(children: [Icon(LucideIcons.fileText, size: 14, color: Colors.grey.shade500), const SizedBox(width: 4), Text("Contract ID: #BR-${order['contract_id'].toString().padLeft(4, '0')}", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12))]),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("${order['pledged_weight_kg']} kg pledged", style: GoogleFonts.poppins(color: Colors.teal.shade700, fontWeight: FontWeight.bold, fontSize: 13)), Text("Target: ${order['target_weight_kg']} kg", style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12))]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, minHeight: 10, backgroundColor: Colors.teal.shade50, valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade500))),
          ],
        ),
      ),
    );
  }

  Widget _buildTransitCard(Map<String, dynamic> order, int index) {
    List<dynamic> roster = order['roster'] ?? [];
    int deliveredCount = roster.where((p) => p['status'] == 'delivered').length;
    bool needsInspection = deliveredCount > 0;

    return FadeInUp(
      delay: Duration(milliseconds: index * 100),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: needsInspection ? Colors.orange.shade200 : Colors.teal.shade100, width: 1.5), boxShadow: [BoxShadow(color: needsInspection ? Colors.orange.withOpacity(0.05) : Colors.teal.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: needsInspection ? Colors.orange.shade50 : Colors.teal.shade50, shape: BoxShape.circle), child: Icon(needsInspection ? LucideIcons.box : LucideIcons.truck, color: needsInspection ? Colors.orange.shade700 : Colors.teal.shade700)),
                const SizedBox(width: 15),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("${order['target_weight_kg']}kg of ${order['crop_name']}", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)), Text(needsInspection ? "$deliveredCount Drops Arrived!" : "In Fulfillment Pipeline", style: GoogleFonts.poppins(color: needsInspection ? Colors.orange.shade800 : Colors.teal.shade700, fontSize: 12, fontWeight: FontWeight.bold))])),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider(height: 1)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Total Escrow Bound", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)), Text("KES ${order['target_weight_kg'] * order['price_per_kg']}", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14))]),
                ElevatedButton(
                  onPressed: () => _showQASheet(order),
                  style: ElevatedButton.styleFrom(backgroundColor: needsInspection ? Colors.orange.shade600 : Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  child: Text(needsInspection ? "Inspect Goods" : "Delivery Log", style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // 🔥 NEW: HISTORY CARD
  Widget _buildHistoryCard(Map<String, dynamic> order, int index) {
    return FadeInUp(
      delay: Duration(milliseconds: index * 100),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.green.shade200), boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle), child: Icon(LucideIcons.checkCircle, color: Colors.green.shade700)),
                const SizedBox(width: 15),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("${order['target_weight_kg']}kg of ${order['crop_name']}", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)), Text("Contract Fully Closed", style: GoogleFonts.poppins(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold))])),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider(height: 1)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Total Capital Released", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)), Text("KES ${order['target_weight_kg'] * order['price_per_kg']}", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14))]),
                ElevatedButton(
                  onPressed: () => _showQASheet(order), // Allows view-only check
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  child: Text("View Log", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showQASheet(Map<String, dynamic> order) {
    List<dynamic> roster = order['roster'] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  Text("Escrow & Assurance Log", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Inspect delivered goods and authorize Escrow payouts.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 15),

                  Expanded(
                    child: ListView.builder(
                      itemCount: roster.length,
                      itemBuilder: (context, index) {
                        final member = roster[index];
                        final memberStatus = member['status'] ?? '';
                        final isDelivered = memberStatus == 'delivered';
                        final isPassed = memberStatus == 'paid'; // 🔥 Changed to 'paid'
                        final isFailed = memberStatus == 'rejected';
                        final inTransit = memberStatus == 'in_transit' || memberStatus == 'received';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: isPassed ? Colors.green.shade50 : (isFailed ? Colors.red.shade50 : Colors.white), border: Border.all(color: isPassed ? Colors.green.shade200 : (isFailed ? Colors.red.shade200 : Colors.grey.shade200)), borderRadius: BorderRadius.circular(16)),
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
                                        Text(member['farmer_name'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                        Text("Weight: ${member['actual_kg']} KG", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),
                                  if (isPassed)
                                    Text("Funds Released ✅", style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.bold))
                                  else if (isFailed)
                                    Text("Rejected ❌", style: GoogleFonts.poppins(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold))
                                  else if (inTransit)
                                    Text("Not Arrived", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500))
                                  else if (isDelivered)
                                    Text("Awaiting Review", style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.bold))
                                ],
                              ),
                              
                              if (isDelivered) ...[
                                const SizedBox(height: 15),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          setSheetState(() => member['status'] = 'paid');
                                          // 🔥 THE FIX: Release the funds! This auto-completes the contract on the backend!
                                          final error = await _apiClient.updateQAStatus(member['pledge_id'], 'paid', 'QA Passed. Escrow Released.');
                                          if (error != null && mounted) {
                                            setSheetState(() => member['status'] = 'delivered'); // revert
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                                          } else {
                                            _fetchLiveOrders();
                                          }
                                        },
                                        icon: const Icon(LucideIcons.banknote, size: 14),
                                        label: const Text("Approve & Release Funds", style: TextStyle(fontSize: 11)),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          setSheetState(() => member['status'] = 'rejected');
                                          final error = await _apiClient.updateQAStatus(member['pledge_id'], 'rejected', 'Failed Quality Check.');
                                          if (error != null && mounted) {
                                            setSheetState(() => member['status'] = 'delivered');
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                                          } else {
                                            _fetchLiveOrders();
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                        child: const Text("Reject", style: TextStyle(fontSize: 11)),
                                      ),
                                    )
                                  ],
                                )
                              ]
                            ],
                          ),
                        );
                      }
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
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