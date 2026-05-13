import 'dart:convert';
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
  List<dynamic> _myPledges = [];

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
        _myPledges = data?.reversed.toList() ?? [];
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
          leading: IconButton(icon: Icon(LucideIcons.arrowLeft, color: Colors.green.shade900), onPressed: () => Navigator.pop(context)),
          title: Text("My Deliveries", style: GoogleFonts.poppins(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 18)), centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.green))
            : _myPledges.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.packageOpen, size: 60, color: Colors.grey.shade300),
              const SizedBox(height: 15),
              Text("No deliveries pending.", style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14)),
            ],
          ),
        )
            : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _myPledges.length,
            itemBuilder: (context, index) {
              final pledge = _myPledges[index];
              bool isDirectSale = pledge['type'] == 'Direct Sale';
              String status = pledge['status'] ?? 'pending';
              String deliveryMethod = pledge['delivery_method'] ?? 'Delivery';
              // 🔥 NEW: Extract the payment method so the UI knows how to act!
              String paymentMethod = pledge['payment_method'] ?? 'pay_now';

              return FadeInUp(
                delay: Duration(milliseconds: index * 100),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
                      border: Border.all(color: isDirectSale ? Colors.blue.shade100 : Colors.green.shade100)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                            color: isDirectSale ? Colors.blue.shade50 : Colors.green.shade50,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(isDirectSale ? LucideIcons.shoppingBag : LucideIcons.truck, size: 16, color: isDirectSale ? Colors.blue.shade700 : Colors.green.shade700),
                                const SizedBox(width: 8),
                                // 🔥 Show whether it's Escrow or POD in the header
                                Text(isDirectSale ? "Direct Sale • ${paymentMethod == 'pay_now' ? 'Escrow' : 'POD'}" : pledge['type'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: isDirectSale ? Colors.blue.shade800 : Colors.green.shade800)),
                              ],
                            ),
                            Text(pledge['id'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade700)),
                          ],
                        ),
                      ),

                      // BODY
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isDirectSale && status == 'rejected')
                              Text("0 ${pledge['unit']} of ${pledge['crop']} (No-Show)", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red.shade700, decoration: TextDecoration.lineThrough))
                            else if (!isDirectSale && pledge['actual_kg'] != null)
                              Text("Actual: ${pledge['actual_kg']} KG / Pledged: ${pledge['weight_kg']} KG of ${pledge['crop']}", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal.shade800))
                            else
                              Text("${pledge['weight_kg']} ${pledge['unit']} of ${pledge['crop']}", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),

                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Buyer: ${pledge['buyer']}", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
                                Text(status == 'rejected' || status == 'refunded' ? "Payout Hidden" : "KES ${pledge['expected_payout']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: status == 'rejected' || status == 'refunded' ? Colors.grey.shade400 : Colors.green.shade700, fontSize: 14)),
                              ],
                            ),

                            if (isDirectSale) ...[
                              const SizedBox(height: 15),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: Colors.blue.shade50.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.shade100)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(LucideIcons.map, size: 16, color: Colors.blue.shade800),
                                        const SizedBox(width: 8),
                                        Text(deliveryMethod == "Pickup" ? "Buyer Contact Intel" : "Delivery Logistics", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(LucideIcons.phone, size: 14, color: Colors.blue.shade600),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(pledge['buyer_phone'] ?? "N/A", style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.w600))),
                                      ],
                                    ),
                                    if (deliveryMethod == "Delivery") ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(LucideIcons.mapPin, size: 14, color: Colors.blue.shade600),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(pledge['buyer_address'] ?? "N/A", style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue.shade800))),
                                        ],
                                      ),
                                    ]
                                  ],
                                ),
                              ),

                              // Direct Order Dispute Box (Only shows if disputed)
                              if (status == 'disputed') ...[
                                const SizedBox(height: 15),
                                Container(
                                  padding: const EdgeInsets.all(16), width: double.infinity,
                                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade200)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [const Icon(LucideIcons.alertTriangle, color: Colors.red, size: 18), const SizedBox(width: 8), Text("Buyer Raised a Dispute", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red.shade900))]),
                                      const SizedBox(height: 10),
                                      Text('"${pledge['dispute_notes'] ?? 'No reason provided.'}"', style: GoogleFonts.poppins(fontStyle: FontStyle.italic, color: Colors.red.shade800, fontSize: 13)),
                                      const SizedBox(height: 10),
                                      if (pledge['dispute_image'] != null)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.memory(base64Decode(pledge['dispute_image'].split(',').last), height: 120, width: double.infinity, fit: BoxFit.cover),
                                        ),
                                      const SizedBox(height: 15),
                                      SizedBox(
                                          width: double.infinity,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () async {
                                                    setState(() => _isLoading = true);
                                                    final error = await _apiClient.updateDirectOrderStatus(pledge['order_id'], 'rejected');
                                                    if (error == null) _fetchMyDeliveries();
                                                    else { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red)); }
                                                  },
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red.shade700, side: BorderSide(color: Colors.red.shade300), elevation: 0),
                                                  child: Text("Accept Return & Cancel", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Call ${pledge['buyer_phone']} to resolve."))),
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, elevation: 0),
                                                  child: Text("Call Buyer", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                                                ),
                                              )
                                            ],
                                          )
                                      )
                                    ],
                                  ),
                                )
                              ]
                            ]
                            else ...[
                              // Bulk Contract Dispute UI
                              if (status == 'disputed' || status == 'rejected')
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          setState(() => _isLoading = true);
                                          // 🔥 THE FIX: Actually call the refund endpoint!
                                          final error = await _apiClient.refundPledge(pledge['pledge_id'] ?? pledge['id']);
                                          if (error == null) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Return Accepted. Escrow Refunded.")));
                                            _fetchMyDeliveries();
                                          } else {
                                            setState(() => _isLoading = false);
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red.shade700, side: BorderSide(color: Colors.red.shade300), elevation: 0),
                                        child: Text("Accept Return", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Call Coordinator to resolve."))),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, elevation: 0),
                                        child: Text("Contact Hub", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    )
                                  ],
                                )
                              else if (status == 'returning')
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      setState(() => _isLoading = true);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Goods returned. Buyer Refunded.")));
                                      setState(() => _isLoading = false);
                                    },
                                    icon: const Icon(LucideIcons.packageCheck, size: 16, color: Colors.white),
                                    label: Text("Goods Received (Refund Buyer)", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  ),
                                )
                              else if (status == 'paid' || status == 'completed')
                                  Container(
                                    padding: const EdgeInsets.all(12), alignment: Alignment.center,
                                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                                    child: Text("Payment Received ✅", style: GoogleFonts.poppins(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                                  )
                                else
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeliverySquadsScreen(targetSquadId: pledge['bulk_request_id']))),
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.green.shade700, side: BorderSide(color: Colors.green.shade300), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                      child: Text("View Squad Tracker", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                    ),
                                  )
                            ],

                            const SizedBox(height: 20),
                            const Divider(height: 1),
                            const SizedBox(height: 20),

                            // 🔥 THE BULLETPROOF FARMER STATE MACHINE FOR SOLO ORDERS
                            if (isDirectSale && status != 'disputed') ...[

                              // Pay Now: Waiting for Buyer to Pay upfront
                              if (paymentMethod == 'pay_now' && status == 'pending')
                                Container(
                                  padding: const EdgeInsets.all(12), alignment: Alignment.center,
                                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                                  child: Text("Awaiting Buyer Payment ⏳", style: GoogleFonts.poppins(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                                )

                              // 1. START DELIVERY (Doorstep only, regardless of payment method)
                              else if (deliveryMethod == "Delivery" && ((paymentMethod == 'pay_now' && status == 'processing') || (paymentMethod == 'pay_on_delivery' && status == 'pending')))
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      setState(() => _isLoading = true);
                                      final error = await _apiClient.updateDirectOrderStatus(pledge['order_id'], 'in_transit');
                                      if (error == null) _fetchMyDeliveries();
                                      else { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red)); }
                                    },
                                    icon: const Icon(LucideIcons.truck, size: 16, color: Colors.white),
                                    label: Text("Start Delivery Transit", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  ),
                                )

                              // 2. BUYER PICKUP INSTRUCTIONS (Farmer does nothing but wait)
                              else if (deliveryMethod == "Pickup" && (status == 'processing' || status == 'pending'))
                                  Container(
                                    padding: const EdgeInsets.all(12), alignment: Alignment.center,
                                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                                    child: Text("Awaiting Buyer Pickup 📍", style: GoogleFonts.poppins(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                                  )

                                // 3. MARK AS ARRIVED (Allows Buyer to Pay/Accept)
                                else if (status == 'in_transit')
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          setState(() => _isLoading = true);
                                          final error = await _apiClient.updateDirectOrderStatus(pledge['order_id'], 'delivered');
                                          if (error == null) _fetchMyDeliveries();
                                          else { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red)); }
                                        },
                                        icon: const Icon(LucideIcons.mapPin, size: 16, color: Colors.white),
                                        label: Text("Mark as Arrived (Ping Buyer)", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade600, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                      ),
                                    )

                                  // 4. WAITING FOR BUYER QA/PAYMENT
                                  else if (status == 'delivered')
                                      Container(
                                        padding: const EdgeInsets.all(12), alignment: Alignment.center,
                                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                                        child: Text(paymentMethod == 'pay_now' ? "Waiting for Buyer to Accept Goods ⏳" : "Waiting for Buyer to Pay via M-Pesa ⏳", style: GoogleFonts.poppins(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                                      )

                                    // 5. COMPLETED STATES
                                    else if (status == 'completed' || status == 'paid')
                                        Container(
                                          padding: const EdgeInsets.all(12), alignment: Alignment.center,
                                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                                          child: Text("Order Complete & Paid ✅", style: GoogleFonts.poppins(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                                        )
                                      else if (status == 'refunded' || status == 'rejected')
                                          Container(
                                            padding: const EdgeInsets.all(12), alignment: Alignment.center,
                                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                                            child: Text("Order Cancelled & Refunded", style: GoogleFonts.poppins(color: Colors.grey.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                                          )
                            ]
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            }
        )
    );
  }
}