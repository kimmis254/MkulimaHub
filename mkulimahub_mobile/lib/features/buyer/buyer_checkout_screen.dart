import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class BuyerCheckoutScreen extends StatefulWidget {
  final double totalAmount;

  const BuyerCheckoutScreen({super.key, required this.totalAmount});

  @override
  State<BuyerCheckoutScreen> createState() => _BuyerCheckoutScreenState();
}

class _BuyerCheckoutScreenState extends State<BuyerCheckoutScreen> {
  String _selectedPayment = "mpesa"; // 'mpesa' or 'bank'
  bool _isLoading = false;

  void _confirmCheckout() async {
    setState(() => _isLoading = true);

    // Simulate Payment Gateway / Escrow Lock delay
    await Future.delayed(const Duration(seconds: 3));

    setState(() => _isLoading = false);

    if (mounted) {
      // Show Success Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Icon(LucideIcons.shieldCheck, color: Colors.teal, size: 60),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Funds Secured!", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 10),
              Text(
                "Your payment of KES ${widget.totalAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} is safely locked in the MkulimaHub Escrow account. Transport has been dispatched.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close checkout
                  Navigator.pop(context); // Close cart (Back to Dashboard)
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text("Back to Dashboard", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        )
      );
    }
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
        title: Text("Secure Checkout", style: GoogleFonts.poppins(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔥 1. DELIVERY DESTINATION
                  FadeInDown(
                    child: Text("Delivery Destination", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                  const SizedBox(height: 12),
                  FadeInDown(
                    delay: const Duration(milliseconds: 100),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
                            child: Icon(LucideIcons.mapPin, color: Colors.teal.shade700),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Nairobi Central Warehouse", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text("Industrial Area, Enterprise Rd", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: Text("Edit", style: GoogleFonts.poppins(color: Colors.teal.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 🔥 2. PAYMENT METHODS
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: Text("Escrow Payment Method", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                  const SizedBox(height: 12),
                  
                  // M-Pesa Option
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: _buildPaymentOption(
                      id: "mpesa",
                      title: "M-Pesa B2B PayBill",
                      subtitle: "Instant Escrow Lock",
                      icon: LucideIcons.smartphone,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Bank Transfer Option
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: _buildPaymentOption(
                      id: "bank",
                      title: "Corporate Bank Transfer",
                      subtitle: "Takes 1-2 business days",
                      icon: LucideIcons.building,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 🔥 3. SECURITY BADGE
                  FadeInUp(
                    delay: const Duration(milliseconds: 500),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.shieldAlert, color: Colors.orange.shade700, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Funds are held securely in Escrow. The farmer is only paid after you verify the delivery quality.",
                              style: GoogleFonts.poppins(color: Colors.orange.shade900, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🔥 4. STICKY FOOTER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Total Amount", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14)),
                      Text(
                        "KES ${widget.totalAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}", 
                        style: GoogleFonts.poppins(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 24)
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _confirmCheckout,
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
                              Text("Confirm & Lock Escrow", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPaymentOption({required String id, required String title, required String subtitle, required IconData icon, required Color color}) {
    bool isSelected = _selectedPayment == id;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedPayment = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.grey.shade200, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            Icon(
              isSelected ? LucideIcons.checkCircle2 : LucideIcons.circle,
              color: isSelected ? color : Colors.grey.shade300,
              size: 24,
            )
          ],
        ),
      ),
    );
  }
}