import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/features/buyer/buyer_checkout_screen.dart';

// 🔥 THE GLOBAL CART MANAGER: Stores all items across the app!
class CartManager {
  static final List<Map<String, dynamic>> items = [];
}

class BuyerCartScreen extends StatefulWidget {
  const BuyerCartScreen({super.key});

  @override
  State<BuyerCartScreen> createState() => _BuyerCartScreenState();
}

class _BuyerCartScreenState extends State<BuyerCartScreen> {
  final bool _isLoading = false;

  double get _subtotal {
    return CartManager.items.fold(0, (sum, item) => sum + (item['weightKg'] * item['pricePerKg']));
  }

  void _removeItem(String id) {
    setState(() {
      CartManager.items.removeWhere((item) => item['id'] == id);
    });
  }

  void _checkout() {
    if (CartManager.items.isEmpty) return;
    
    // 🔥 Pass the actual items to the massive new Checkout Screen!
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => BuyerCheckoutScreen(cartItems: CartManager.items)
      )
    ).then((_) => setState(() {})); // Refresh cart when returning
  }

  // 🔥 THE FIX: Smart Image Decoder that handles both Base64 and Web URLs
  Widget _buildCartImage(Map<String, dynamic> item) {
    String? imageStr = item['image']?.toString();
    
    // Fallback if the key was named 'image_base64' by accident during cart addition
    if (imageStr == null || imageStr.isEmpty) {
      imageStr = item['image_base64']?.toString();
    }

    if (imageStr == null || imageStr.isEmpty) {
      return Container(width: 80, height: 80, color: Colors.teal.shade50, child: const Icon(LucideIcons.imageOff, color: Colors.teal));
    }

    // Check if it is a Base64 string from the camera/gallery
    if (imageStr.startsWith('data:image') || imageStr.length > 200) {
      try {
        final base64String = imageStr.split(',').last;
        return Image.memory(base64Decode(base64String), width: 80, height: 80, fit: BoxFit.cover);
      } catch (e) {
        debugPrint("Error decoding Base64 image in cart: $e");
        return Container(width: 80, height: 80, color: Colors.teal.shade50, child: const Icon(LucideIcons.imageOff, color: Colors.teal));
      }
    }

    // Otherwise, assume it's a standard web URL
    return Image.network(
      imageStr,
      width: 80, height: 80, fit: BoxFit.cover,
      errorBuilder: (c, e, s) => Container(width: 80, height: 80, color: Colors.teal.shade50, child: const Icon(LucideIcons.imageOff, color: Colors.teal)),
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
          if (CartManager.items.isNotEmpty)
            IconButton(
              icon: Icon(LucideIcons.trash2, color: Colors.red.shade300),
              onPressed: () => setState(() => CartManager.items.clear()),
            )
        ],
      ),
      body: CartManager.items.isEmpty ? _buildEmptyCart() : _buildCartContent(),
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
        // ITEM LIST
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: CartManager.items.length,
            itemBuilder: (context, index) {
              final item = CartManager.items[index];
              return FadeInRight(
                delay: Duration(milliseconds: index * 50),
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
                      // 🔥 Item Image (Now uses the Smart Decoder)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildCartImage(item),
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

        // CHECKOUT SUMMARY FOOTER
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
                _buildReceiptRow("Cart Subtotal", _subtotal, isBold: true),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Proceed to Checkout", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.arrowRight, color: Colors.white, size: 18),
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

  Widget _buildReceiptRow(String label, double amount, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(color: isBold ? Colors.black87 : Colors.grey.shade600, fontSize: isBold ? 16 : 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(
          "KES ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}", 
          style: GoogleFonts.poppins(color: isBold ? Colors.teal.shade900 : Colors.black87, fontWeight: FontWeight.bold, fontSize: isBold ? 22 : 13)
        ),
      ],
    );
  }
}