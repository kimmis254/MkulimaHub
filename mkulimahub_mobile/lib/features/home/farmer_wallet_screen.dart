import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';

class FarmerWalletScreen extends StatefulWidget {
  const FarmerWalletScreen({super.key});

  @override
  State<FarmerWalletScreen> createState() => _FarmerWalletScreenState();
}

class _FarmerWalletScreenState extends State<FarmerWalletScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;

  double _available = 0.0;
  double _escrow = 0.0;
  double _total = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchWallet();
  }

  Future<void> _fetchWallet() async {
    setState(() => _isLoading = true);
    final data = await _apiClient.getFarmerWallet();
    if (mounted) {
      if (data != null) {
        setState(() {
          _available = (data['available_balance'] ?? 0).toDouble();
          _escrow = (data['escrow_balance'] ?? 0).toDouble();
          _total = (data['total_balance'] ?? 0).toDouble();
        });
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.green.shade800,
        elevation: 0,
        title: Text("My Finances", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchWallet,
        color: Colors.green,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.green))
            : ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            // 1. TOTAL PORTFOLIO VALUE
            FadeInDown(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.green.shade800, Colors.teal.shade900], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Column(
                  children: [
                    Text("Total Portfolio Value", style: GoogleFonts.poppins(color: Colors.green.shade100, fontSize: 14)),
                    const SizedBox(height: 10),
                    Text("KES ${_total.toStringAsFixed(0)}", style: GoogleFonts.poppins(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.shieldCheck, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text("MkulimaHub Secured Ledger", style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // 2. THE PSYCHOLOGICAL LOOP (Escrow vs Available)
            FadeInUp(
              delay: const Duration(milliseconds: 100),
              child: Row(
                children: [
                  // AVAILABLE CASH
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade200), boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle), child: Icon(LucideIcons.checkCircle, color: Colors.green.shade700, size: 18)),
                              const SizedBox(width: 10),
                              Text("Available", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Text("KES ${_available.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _available > 0 ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("M-Pesa Withdrawal Initiated!"))) : null,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, disabledBackgroundColor: Colors.grey.shade300, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                              child: Text("Withdraw", style: GoogleFonts.poppins(color: _available > 0 ? Colors.white : Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),

                  // ESCROW / LOCKED
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.shade200), boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle), child: Icon(LucideIcons.lock, color: Colors.orange.shade700, size: 18)),
                              const SizedBox(width: 10),
                              Text("In Escrow", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Text("KES ${_escrow.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("These funds are secured. Deliver the goods to unlock them."))),
                              style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.orange.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              child: Text("Secured", style: GoogleFonts.poppins(color: Colors.orange.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blue.shade100)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.info, color: Colors.blue.shade700),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("How Escrow Works", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                          const SizedBox(height: 5),
                          Text("When a buyer pays for your produce, the funds are instantly locked in Escrow. Once the buyer receives and approves the delivery, the funds instantly move to your Available Balance for withdrawal.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue.shade800)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}