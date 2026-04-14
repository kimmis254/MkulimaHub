import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/features/buyer/buyer_checkout_screen.dart';

class BuyerCartScreen extends StatefulWidget {
  const BuyerCartScreen({super.key});

  @override
  State<BuyerCartScreen> createState() => _BuyerCartScreenState();
}

class _BuyerCartScreenState extends State<BuyerCartScreen> {
  // 🔥 MOCK DATA: Items in the cart
  List<Map<String, dynamic>> _cartItems = [
    {
      "id": "1",
      "crop": "Hass Avocados",
      "farmer": "Kamau N.",
      "location": "Murang'a",
      "weightKg": 500,
      "pricePerKg": 150,
      "image": "https://images.unsplash.com/photo-1523049673856-4287b33a18e0?w=500"
    },
    {
      "id": "2",
      "crop": "Red Onions",
      "farmer": "Sarah M.",
      "location": "Kajiado",
      "weightKg": 200,
      "pricePerKg": 120,
      "image": "https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=500"
    }
  ];

  bool _isLoading = false;

  double get _subtotal {
    return _cartItems.fold(0, (sum, item) => sum + (item['weightKg'] * item['pricePerKg']));
  }

  double get _logisticsFee {
    // Flat transport rate calculation (Mock logic: KES 10 per kg)
    return _cartItems.fold(0, (sum, item) => sum + (item['weightKg'] * 10));
  }

  double get _total => _subtotal + _logisticsFee;

  void _removeItem(String id) {
    setState(() {
      _cartItems.removeWhere((item) => item['id'] == id);
    });
  }

  void _checkout() {
    if (_cartItems.isEmpty) return;
    
    // 🔥 Send the total amount to the premium Checkout Screen
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => BuyerCheckoutScreen(totalAmount: _total)
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: Colors.teal.shade900),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Procurement Cart", style: GoogleFonts.poppins(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          if (_cartItems.isNotEmpty)
            IconButton(
              icon: Icon(LucideIcons.trash2, color: Colors.red.shade300),
              onPressed: () => setState(() => _cartItems.clear()),
            )
        ],
      ),
      body: _cartItems.isEmpty ? _buildEmptyCart() : _buildCartContent(),
    );
  }

  Widget _buildEmptyCart() {
    return FadeIn(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
              child: Icon(LucideIcons.shoppingCart, size: 60, color: Colors.teal.shade200),
            ),
            const SizedBox(height: 20),
            Text("Your cart is empty", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            Text("Browse the market to find fresh produce.", style: GoogleFonts.poppins(color: Colors.grey.shade500)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
              ),
              child: Text("Browse Market", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCartContent() {
    return Column(
      children: [
        // 🔥 ITEM LIST
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _cartItems.length,
            itemBuilder: (context, index) {
              final item = _cartItems[index];
              return FadeInRight(
                delay: Duration(milliseconds: index * 100),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      // Item Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          item['image'], 
                          width: 80, height: 80, fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(width: 80, height: 80, color: Colors.teal.shade50, child: const Icon(LucideIcons.imageOff, color: Colors.teal)),
                        ),
                      ),
                      const SizedBox(width: 15),
                      // Item Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['crop'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                            const SizedBox(height: 2),
                            Text("${item['farmer']} • ${item['location']}", style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 11)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                  child: Text("${item['weightKg']} kg", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                                ),
                                Text(
                                  "KES ${(item['weightKg'] * item['pricePerKg']).toStringAsFixed(0)}", 
                                  style: GoogleFonts.poppins(color: Colors.teal.shade700, fontWeight: FontWeight.bold, fontSize: 14)
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Remove Button
                      IconButton(
                        icon: Icon(LucideIcons.xCircle, color: Colors.grey.shade400),
                        onPressed: () => _removeItem(item['id']),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // 🔥 CHECKOUT SUMMARY FOOTER
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(35), topRight: Radius.circular(35))
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildReceiptRow("Subtotal", _subtotal),
                const SizedBox(height: 10),
                _buildReceiptRow("Logistics & Aggregation", _logisticsFee),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Total to Escrow", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    Text(
                      "KES ${_total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}", 
                      style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal.shade900)
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _checkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading 
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.lock, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text("Secure Checkout", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                  ),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildReceiptRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
        Text(
          "KES ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}", 
          style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)
        ),
      ],
    );
  }
}