import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api/api_client.dart';

class FarmerWalletScreen extends StatefulWidget {
  const FarmerWalletScreen({super.key});

  @override
  State<FarmerWalletScreen> createState() => _FarmerWalletScreenState();
}

class _FarmerWalletScreenState extends State<FarmerWalletScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  bool _obscureBalance = false;

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

  // 🔥 THE NEW WITHDRAWAL MODAL
  void _showWithdrawModal() {
    final TextEditingController amountController = TextEditingController();
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
                      Text("Withdraw to M-Pesa", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text("Available to withdraw: KES ${_available.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontSize: 13, color: Colors.teal.shade700, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 20),

                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                            labelText: "Amount (KES)",
                            prefixIcon: const Icon(LucideIcons.banknote),
                            filled: true, fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : () async {
                            final amount = double.tryParse(amountController.text);
                            if (amount == null || amount <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid amount")));
                              return;
                            }
                            if (amount > _available) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient available balance!"), backgroundColor: Colors.red));
                              return;
                            }

                            setSheetState(() => isSubmitting = true);
                            final error = await _apiClient.withdrawFunds(amount);

                            if (mounted) {
                              Navigator.pop(context);
                              if (error == null) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("KES ${amount.toStringAsFixed(0)} withdrawn successfully!"), backgroundColor: Colors.green));
                                _fetchWallet();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: isSubmitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text("Confirm Withdrawal", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.2))),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade800, elevation: 0,
        title: Text("My Earnings", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)), centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchWallet,
        color: Colors.teal,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // MAIN BALANCE CARD
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.teal.shade800, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.teal.shade900.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))]),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Total Balance", style: GoogleFonts.poppins(color: Colors.teal.shade100, fontSize: 14)),
                      GestureDetector(
                        onTap: () => setState(() => _obscureBalance = !_obscureBalance),
                        child: Icon(_obscureBalance ? LucideIcons.eyeOff : LucideIcons.eye, color: Colors.teal.shade200, size: 20),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text("KES ", style: GoogleFonts.poppins(color: Colors.teal.shade200, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(_obscureBalance ? "****" : _total.toStringAsFixed(0), style: GoogleFonts.poppins(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.teal.shade700, borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [Icon(LucideIcons.checkCircle, color: Colors.teal.shade100, size: 14), const SizedBox(width: 5), Text("Available", style: GoogleFonts.poppins(color: Colors.teal.shade100, fontSize: 12))]),
                              const SizedBox(height: 5),
                              Text(_obscureBalance ? "****" : "KES ${_available.toStringAsFixed(0)}", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.teal.shade700, borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [Icon(LucideIcons.lock, color: Colors.orange.shade300, size: 14), const SizedBox(width: 5), Text("Escrow", style: GoogleFonts.poppins(color: Colors.teal.shade100, fontSize: 12))]),
                              const SizedBox(height: 5),
                              Text(_obscureBalance ? "****" : "KES ${_escrow.toStringAsFixed(0)}", style: GoogleFonts.poppins(color: Colors.orange.shade300, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 🔥 ACTION BUTTONS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionBtn(LucideIcons.arrowDownToLine, "Withdraw", Colors.teal.shade700, _showWithdrawModal),
                _buildActionBtn(LucideIcons.history, "History", Colors.blue.shade700, () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transaction history coming soon.")));
                }),
                _buildActionBtn(LucideIcons.barChart2, "Analytics", Colors.purple.shade700, () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Earnings analytics coming soon.")));
                }),
              ],
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