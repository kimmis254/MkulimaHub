import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/home/delivery_squads_screen.dart';

class MyDeliveriesScreen extends StatefulWidget {
  final String? targetOrderId;
  const MyDeliveriesScreen({super.key, this.targetOrderId});

  @override
  State<MyDeliveriesScreen> createState() => _MyDeliveriesScreenState();
}

class _MyDeliveriesScreenState extends State<MyDeliveriesScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  List<dynamic> _deliveries = [];

  @override
  void initState() {
    super.initState();
    _fetchMyDeliveries();
  }

  Future<void> _fetchMyDeliveries() async {
    setState(() => _isLoading = true);
    final data = await _apiClient.getMyDeliveries();
    if (mounted) {
      setState(() {
        _deliveries = data?.reversed.toList() ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(LucideIcons.arrowLeft, color: Colors.teal.shade900), onPressed: () => Navigator.pop(context)),
        title: Text("My Deliveries & Orders", style: GoogleFonts.poppins(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 18)), centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _deliveries.isEmpty
          ? Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.packageOpen, size: 60, color: Colors.grey.shade300), const SizedBox(height: 15),
          Text("No active deliveries found.", style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14)),
        ],
      ))
          : RefreshIndicator(
        onRefresh: _fetchMyDeliveries,
        color: Colors.teal,
        child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _deliveries.length,
            itemBuilder: (context, index) {
              final order = _deliveries[index];
              bool isDirectSale = order['type'] == 'Direct Sale';
              String status = order['status'] ?? 'pending';
              double payout = (order['expected_payout'] ?? 0).toDouble();

              return FadeInUp(
                delay: Duration(milliseconds: index * 100),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: isDirectSale ? Colors.blue.shade50 : Colors.purple.shade50, borderRadius: BorderRadius.circular(10)),
                              child: Row(children: [Icon(isDirectSale ? LucideIcons.shoppingBag : LucideIcons.truck, size: 14, color: isDirectSale ? Colors.blue.shade700 : Colors.purple.shade700), const SizedBox(width: 6), Text(order['type'] ?? 'Order', style: GoogleFonts.poppins(color: isDirectSale ? Colors.blue.shade800 : Colors.purple.shade800, fontSize: 11, fontWeight: FontWeight.bold))])
                          ),
                          Text(order['id'] ?? '#0000', style: GoogleFonts.poppins(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text("${order['weight_kg']} ${order['unit']} of ${order['crop']}", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Row(children: [Icon(LucideIcons.user, size: 14, color: Colors.grey.shade500), const SizedBox(width: 6), Text("Buyer: ${order['buyer']}", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13))]),

                      // 🔥 THE FIX: SHOW DIRECT SALE BUYER DETAILS
                      if (isDirectSale) ...[
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [Icon(order['delivery_method'].toString().contains('Pickup') ? LucideIcons.store : LucideIcons.mapPin, size: 14, color: Colors.blue.shade800), const SizedBox(width: 8), Text(order['delivery_method']?.toString().contains('Pickup') == true ? "Pickup by Buyer" : "Delivery Destination", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue.shade900))]),
                              const SizedBox(height: 4),
                              Text(order['buyer_address'] ?? 'Address Pending', style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue.shade800)),
                              const SizedBox(height: 8),
                              Row(children: [Icon(LucideIcons.phone, size: 14, color: Colors.blue.shade800), const SizedBox(width: 8), Expanded(child: Text(order['buyer_phone'] ?? 'No Phone', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900)))]),
                            ],
                          ),
                        ),
                      ],

                      if (order['notes'] != null && order['notes'].toString().isNotEmpty) ...[
                        const SizedBox(height: 15),
                        Container(
                          width: double.infinity, padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.shade200)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(LucideIcons.info, size: 16, color: Colors.amber.shade800), const SizedBox(width: 8),
                              Expanded(child: Text(order['notes'], style: GoogleFonts.poppins(color: Colors.amber.shade900, fontSize: 12))),
                            ],
                          ),
                        )
                      ],

                      const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider(height: 1)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("Expected Payout", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)),
                            Text("KES $payout", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14))
                          ]),

                          // ACTION BUTTONS
                          if (status == 'disputed' || status == 'returning')
                            ElevatedButton(
                              onPressed: () async {
                                setState(() => _isLoading = true);
                                String? error;
                                if (isDirectSale) {
                                  error = await _apiClient.updateDirectOrderStatus(order['order_id'], 'refunded');
                                } else {
                                  error = await _apiClient.refundPledge(order['bulk_request_id']);
                                }
                                if (error == null) _fetchMyDeliveries();
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red.shade700, side: BorderSide(color: Colors.red.shade300), elevation: 0),
                              child: Text("Accept Return", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                            )
                          else if (status == 'completed' || status == 'paid')
                            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)), child: Text("Order Paid ✅", style: GoogleFonts.poppins(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12)))
                          else if (status == 'refunded' || status == 'rejected')
                              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: Text("Cancelled", style: GoogleFonts.poppins(color: Colors.grey.shade800, fontWeight: FontWeight.bold, fontSize: 12)))

                            // 🔥 THE FIX: DISPATCH BUTTONS FOR DIRECT SALES
                            else if (isDirectSale && (status == 'pending' || status == 'processing'))
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    setState(() => _isLoading = true);
                                    final error = await _apiClient.updateDirectOrderStatus(order['order_id'], 'in_transit');
                                    if (error == null) _fetchMyDeliveries();
                                    else {
                                      setState(() => _isLoading = false);
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                                    }
                                  },
                                  icon: const Icon(LucideIcons.truck, size: 14, color: Colors.white),
                                  label: Text("Dispatch", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                                )
                              else if (isDirectSale && status == 'in_transit')
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      setState(() => _isLoading = true);
                                      final error = await _apiClient.updateDirectOrderStatus(order['order_id'], 'delivered');
                                      if (error == null) _fetchMyDeliveries();
                                      else {
                                        setState(() => _isLoading = false);
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                                      }
                                    },
                                    icon: const Icon(LucideIcons.mapPin, size: 14, color: Colors.white),
                                    label: Text("Arrived", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                                  )
                                else if (isDirectSale && status == 'delivered')
                                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)), child: Text("Awaiting QA", style: GoogleFonts.poppins(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 11)))

                                  else if (!isDirectSale)
                                      ElevatedButton(
                                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeliverySquadsScreen(targetSquadId: order['bulk_request_id']))),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                                        child: Text("View Squad", style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      )
                                    else
                                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)), child: Text(status.toUpperCase(), style: GoogleFonts.poppins(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 11)))
                        ],
                      )
                    ],
                  ),
                ),
              );
            }
        ),
      ),
    );
  }
}