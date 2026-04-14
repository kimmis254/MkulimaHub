import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class BuyerWalletScreen extends StatefulWidget {
  const BuyerWalletScreen({super.key});

  @override
  State<BuyerWalletScreen> createState() => _BuyerWalletScreenState();
}

class _BuyerWalletScreenState extends State<BuyerWalletScreen> {
  bool _obscureBalance = false;

  // 🔥 MOCK DATA: Transactions
  final List<Map<String, dynamic>> _transactions = [
    {
      "title": "Escrow Locked: Maize Order",
      "date": "Today, 10:42 AM",
      "amount": "- KES 45,000",
      "isCredit": false,
      "icon": LucideIcons.lock,
      "color": Colors.orange,
    },
    {
      "title": "M-Pesa Top Up",
      "date": "Yesterday, 3:15 PM",
      "amount": "+ KES 250,000",
      "isCredit": true,
      "icon": LucideIcons.arrowDownLeft,
      "color": Colors.green,
    },
    {
      "title": "Payout: Farmer Kamau",
      "date": "10 Apr 2026, 09:00 AM",
      "amount": "- KES 12,500",
      "isCredit": false,
      "icon": LucideIcons.arrowUpRight,
      "color": Colors.red,
    },
    {
      "title": "Escrow Released (Refund)",
      "date": "08 Apr 2026, 11:20 AM",
      "amount": "+ KES 5,000",
      "isCredit": true,
      "icon": LucideIcons.unlock,
      "color": Colors.teal,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // 🔥 TEAL HEADER & BALANCE CARD
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Background Header
                Container(
                  height: 240,
                  padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade800,
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Corporate Wallet", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 0.5)),
                          GestureDetector(
                            onTap: () => setState(() => _obscureBalance = !_obscureBalance),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                              child: Icon(_obscureBalance ? LucideIcons.eyeOff : LucideIcons.eye, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Overlapping Premium Balance Card
                Positioned(
                  top: 130,
                  left: 20,
                  right: 20,
                  child: FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.teal.shade900, Colors.teal.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.teal.shade900.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Available Balance", style: GoogleFonts.poppins(color: Colors.teal.shade100, fontSize: 13)),
                          const SizedBox(height: 5),
                          Text(
                            _obscureBalance ? "KES *******" : "KES 1,250,000", 
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32)
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(LucideIcons.shieldCheck, color: Colors.orange.shade300, size: 18),
                                    const SizedBox(width: 8),
                                    Text("Locked in Escrow", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                                Text(
                                  _obscureBalance ? "KES ****" : "KES 450,000", 
                                  style: GoogleFonts.poppins(color: Colors.orange.shade300, fontWeight: FontWeight.bold, fontSize: 14)
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🔥 QUICK ACTIONS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 110, left: 20, right: 20, bottom: 20), // Padding to account for the overlapping card
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionBtn(LucideIcons.plus, "Top Up", Colors.teal),
                  _buildActionBtn(LucideIcons.arrowRightLeft, "Transfer", Colors.blue),
                  _buildActionBtn(LucideIcons.receipt, "Invoices", Colors.orange),
                  _buildActionBtn(LucideIcons.history, "Statement", Colors.grey.shade700),
                ],
              ),
            ),
          ),

          // 🔥 TRANSACTIONS LIST
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Recent Activity", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text("See All", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final txn = _transactions[index];
                  return FadeInUp(
                    delay: Duration(milliseconds: index * 100),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade100),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (txn['color'] as Color).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(txn['icon'], color: txn['color'], size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(txn['title'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                                const SizedBox(height: 4),
                                Text(txn['date'], style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 11)),
                              ],
                            ),
                          ),
                          Text(
                            txn['amount'], 
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, 
                              fontSize: 14, 
                              color: txn['isCredit'] ? Colors.green.shade700 : Colors.black87
                            )
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: _transactions.length,
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 120)), // Padding for the floating nav bar
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }
}