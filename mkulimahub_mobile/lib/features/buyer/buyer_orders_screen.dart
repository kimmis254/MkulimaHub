import 'dart:convert';
import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';

class BuyerOrdersScreen extends StatefulWidget {
  const BuyerOrdersScreen({super.key});

  @override
  // 🔥 THE FIX: Removed the underscore to make the State public!
  State<BuyerOrdersScreen> createState() => BuyerOrdersScreenState();
}

// 🔥 THE FIX: Removed the underscore to make the State public!
class BuyerOrdersScreenState extends State<BuyerOrdersScreen> {
  int _selectedTab = 0; 
  final ApiClient _apiClient = ApiClient();
  final _picker = ImagePicker();
  
  bool _isLoading = true;
  List<dynamic> _gatheringOrders = [];
  List<dynamic> _transitOrders = [];
  List<dynamic> _historyOrders = []; 

  @override
  void initState() {
    super.initState();
    fetchLiveOrders(); // Updated method name
  }

  // 🔥 THE FIX: Made this method public so the Dashboard can call it!
  Future<void> fetchLiveOrders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final data = await _apiClient.getBuyerDashboard();
    
    if (mounted) {
      if (data != null) {
        final List<dynamic> contracts = data['contracts'] ?? [];
        final List<dynamic> directOrders = data['direct_orders'] ?? [];
        
        setState(() {
          _gatheringOrders = [
            ...contracts.where((c) => c['status'] == 'active'),
            ...directOrders.where((o) => o['status'] == 'pending').map((o) => {...o as Map<String,dynamic>, 'is_direct': true})
          ];

          _transitOrders = [
            ...contracts.where((c) => c['status'] == 'fulfilled'),
            ...directOrders.where((o) => o['status'] == 'in_transit' || o['status'] == 'delivered' || o['status'] == 'disputed').map((o) => {...o as Map<String,dynamic>, 'is_direct': true})
          ];

          _historyOrders = [
            ...contracts.where((c) => c['status'] == 'completed'),
            ...directOrders.where((o) => o['status'] == 'paid' || o['status'] == 'completed' || o['status'] == 'rejected').map((o) => {...o as Map<String,dynamic>, 'is_direct': true})
          ];

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
      // 🔥 THE FIX: Added Pull-to-Refresh!
      body: RefreshIndicator(
        onRefresh: fetchLiveOrders,
        color: Colors.teal.shade700,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Required for pull-to-refresh
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
                          _buildTab(2, "History (${_historyOrders.length})"), 
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
                        final item = _gatheringOrders[index];
                        if (item['is_direct'] == true) return _buildDirectOrderCard(item, index, "Preparing Order", Colors.orange);
                        return _buildActiveOrderCard(item, index);
                      }
                      if (_selectedTab == 1) {
                        if (_transitOrders.isEmpty) return _buildEmptyState("No active deliveries.");
                        final item = _transitOrders[index];
                        if (item['is_direct'] == true) return _buildDirectTransitCard(item, index);
                        return _buildTransitCard(item, index);
                      }
                      if (_selectedTab == 2) {
                        if (_historyOrders.isEmpty) return _buildEmptyState("No completed orders yet.");
                        final item = _historyOrders[index];
                        if (item['is_direct'] == true) return _buildDirectOrderCard(item, index, "Closed Archival", Colors.green);
                        return _buildHistoryCard(item, index);
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

  // ==========================================
  // DIRECT CART ORDERS
  // ==========================================
  Widget _buildDirectOrderCard(Map<String, dynamic> order, int index, String label, MaterialColor color) {
    return FadeInUp(
      delay: Duration(milliseconds: index * 100),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: color.shade200), boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)), child: Row(children: [Icon(LucideIcons.shoppingBag, size: 14, color: Colors.blue.shade700), const SizedBox(width: 6), Text("Direct Purchase", style: GoogleFonts.poppins(color: Colors.blue.shade800, fontSize: 11, fontWeight: FontWeight.bold))])),
                Text(label, style: GoogleFonts.poppins(color: color.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 15),
            Text("${order['quantity']} ${order['unit']} of ${order['crop_name']}", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 4),
            Row(children: [Icon(LucideIcons.user, size: 14, color: Colors.grey.shade500), const SizedBox(width: 6), Text(order['farmer_name'], style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13))]),
            const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider(height: 1)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Total Price", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)), Text("KES ${order['total_price']}", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16))]),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectTransitCard(Map<String, dynamic> order, int index) {
    String deliveryMethod = order['delivery_method'] ?? 'Delivery';
    bool isDisputed = order['status'] == 'disputed';
    bool needsInspection = order['status'] == 'in_transit' || order['status'] == 'delivered' || deliveryMethod == 'Pickup';

    return FadeInUp(
      delay: Duration(milliseconds: index * 100),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: isDisputed ? Colors.red.shade200 : Colors.blue.shade200, width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDisputed ? Colors.red.shade50 : Colors.blue.shade50, shape: BoxShape.circle), child: Icon(isDisputed ? LucideIcons.alertTriangle : (deliveryMethod == "Pickup" ? LucideIcons.store : LucideIcons.truck), color: isDisputed ? Colors.red.shade700 : Colors.blue.shade700)),
                const SizedBox(width: 15),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("${order['quantity']} ${order['unit']} of ${order['crop_name']}", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)), Text(isDisputed ? "Dispute Active" : (deliveryMethod == "Pickup" ? "Ready for Pickup" : "In Transit to You"), style: GoogleFonts.poppins(color: isDisputed ? Colors.red.shade800 : Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.bold))])),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider(height: 1)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Total Price", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)), Text("KES ${order['total_price']}", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14))]),
                ElevatedButton(
                  onPressed: needsInspection && !isDisputed ? () => _showDirectOrderQA(order) : null,
                  style: ElevatedButton.styleFrom(backgroundColor: isDisputed ? Colors.grey.shade300 : Colors.orange.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  child: Text(isDisputed ? "Waiting on Farmer" : "Inspect & Pay", style: GoogleFonts.poppins(color: isDisputed ? Colors.grey.shade600 : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showDirectOrderQA(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Text("Inspect Delivery", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
              Text("Did you receive the goods from ${order['farmer_name']}?", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    final error = await _apiClient.updateDirectOrderQA(order['order_id'], 'paid');
                    if (error == null) fetchLiveOrders();
                    else { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red)); }
                  },
                  icon: const Icon(LucideIcons.checkCircle, color: Colors.white),
                  label: Text("Everything Looks Good! Release KES ${order['total_price']}", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity, height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showDisputeSheet(order);
                  },
                  icon: const Icon(LucideIcons.alertTriangle, color: Colors.red),
                  label: Text("Reject & Raise Dispute", style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              )
            ],
          ),
        );
      }
    );
  }

  void _showDisputeSheet(Map<String, dynamic> order) {
    final TextEditingController reasonController = TextEditingController();
    File? disputeImage;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  Text("Raise a Dispute", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: reasonController, maxLines: 3,
                    decoration: InputDecoration(hintText: "Explain the issue (e.g. Spoiled produce, short weight)...", filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 15),
                  GestureDetector(
                    onTap: () async {
                      final pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
                      if (pickedFile != null) setSheetState(() => disputeImage = File(pickedFile.path));
                    },
                    child: Container(
                      height: 120, width: double.infinity,
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade200, style: BorderStyle.solid), image: disputeImage != null ? DecorationImage(image: FileImage(disputeImage!), fit: BoxFit.cover) : null),
                      child: disputeImage == null 
                        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(LucideIcons.camera, color: Colors.red.shade400, size: 30), const SizedBox(height: 8), Text("Tap to take a photo of the issue", style: GoogleFonts.poppins(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.w600))])
                        : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        if (reasonController.text.isEmpty) return;
                        setSheetState(() => isSubmitting = true);
                        String? base64img;
                        if (disputeImage != null) base64img = "data:image/jpeg;base64,${base64Encode(await disputeImage!.readAsBytes())}";

                        final error = await _apiClient.disputeDirectOrder(order['order_id'], reasonController.text, base64img);
                        if (mounted) {
                          Navigator.pop(context);
                          if (error == null) {
                            fetchLiveOrders();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dispute sent to the farmer."), backgroundColor: Colors.orange));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : Text("Submit Dispute to Farmer", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      }
    );
  }

  // ==========================================
  // BULK CONTRACT CARDS
  // ==========================================
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
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)), child: Row(children: [Icon(LucideIcons.radioReceiver, size: 14, color: Colors.orange.shade700), const SizedBox(width: 6), Text("Contract Broadcasting", style: GoogleFonts.poppins(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.bold))])),
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
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("${order['target_weight_kg']}kg of ${order['crop_name']}", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)), Text(needsInspection ? "$deliveredCount Drops Arrived!" : "Contract Fulfillment Pipeline", style: GoogleFonts.poppins(color: needsInspection ? Colors.orange.shade800 : Colors.teal.shade700, fontSize: 12, fontWeight: FontWeight.bold))])),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider(height: 1)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Total Escrow Bound", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)), Text("KES ${order['target_weight_kg'] * order['price_per_kg']}", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14))]),
                ElevatedButton(
                  onPressed: () => _showContractQASheet(order),
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
                  onPressed: () => _showContractQASheet(order), 
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

  void _showContractQASheet(Map<String, dynamic> order) {
    List<dynamic> roster = order['roster'] ?? [];
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85, padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  Text("Escrow & Assurance Log", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),

                  Expanded(
                    child: ListView.builder(
                      itemCount: roster.length,
                      itemBuilder: (context, index) {
                        final member = roster[index];
                        final memberStatus = member['status'] ?? '';
                        final isDelivered = memberStatus == 'delivered';
                        final isPassed = memberStatus == 'paid'; 
                        final isFailed = memberStatus == 'rejected';

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
                                  if (isPassed) Text("Funds Released ✅", style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.bold))
                                  else if (isFailed) Text("Rejected ❌", style: GoogleFonts.poppins(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold))
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
                                          final error = await _apiClient.updateQAStatus(member['pledge_id'], 'paid', 'QA Passed.');
                                          if (error != null) setSheetState(() => member['status'] = 'delivered');
                                          fetchLiveOrders();
                                        },
                                        icon: const Icon(LucideIcons.banknote, size: 14), label: const Text("Approve & Release Funds", style: TextStyle(fontSize: 11)),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white),
                                      ),
                                    ),
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