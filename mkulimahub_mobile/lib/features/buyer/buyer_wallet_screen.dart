import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';

class BuyerWalletScreen extends StatefulWidget {
  const BuyerWalletScreen({super.key});

  @override
  State<BuyerWalletScreen> createState() => _BuyerWalletScreenState();
}

class _BuyerWalletScreenState extends State<BuyerWalletScreen> {
  final ApiClient _apiClient = ApiClient();

  bool _obscureBalance = false;
  bool _isLoading = true;

  double _availableBalance = 0.0;
  double _escrowBalance = 0.0;
  double _totalBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchWallet();
  }

  Future<void> _fetchWallet() async {
    setState(() => _isLoading = true);
    final data = await _apiClient.getBuyerWallet();
    if (mounted) {
      if (data != null) {
        setState(() {
          _availableBalance = (data['available_balance'] ?? 0).toDouble();
          _escrowBalance = (data['escrow_balance'] ?? 0).toDouble();
          _totalBalance = (data['total_balance'] ?? 0).toDouble();
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
                      Text("Available to withdraw: KES ${_availableBalance.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontSize: 13, color: Colors.teal.shade700, fontWeight: FontWeight.w600)),
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
                            if (amount > _availableBalance) {
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
      body: RefreshIndicator(
        onRefresh: _fetchWallet,
        color: Colors.teal,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
                decoration: BoxDecoration(color: Colors.teal.shade800, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Capital & Finance", style: GoogleFonts.poppins(color: Colors.teal.shade200, fontSize: 13)),
                            Text("My Wallet", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26)),
                          ],
                        ),
                        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(LucideIcons.wallet, color: Colors.white, size: 24)),
                      ],
                    ),
                    const SizedBox(height: 30),

                    if (_isLoading)
                      const Center(child: CircularProgressIndicator(color: Colors.white))
                    else
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.teal.shade700, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.teal.shade600, width: 2)),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Total Assets", style: GoogleFonts.poppins(color: Colors.teal.shade100, fontSize: 14)),
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
                                Text(_obscureBalance ? "****" : _totalBalance.toStringAsFixed(0), style: GoogleFonts.poppins(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Divider(color: Colors.white24),
                            const SizedBox(height: 15),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [Icon(LucideIcons.checkCircle, color: Colors.teal.shade200, size: 14), const SizedBox(width: 6), Text("Available Balance", style: GoogleFonts.poppins(color: Colors.teal.shade100, fontSize: 12))]),
                                    const SizedBox(height: 5),
                                    Text(_obscureBalance ? "****" : "KES ${_availableBalance.toStringAsFixed(0)}", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                Container(height: 40, width: 1, color: Colors.white24),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(children: [Icon(LucideIcons.lock, color: Colors.orange.shade300, size: 14), const SizedBox(width: 6), Text("Escrow Holds", style: GoogleFonts.poppins(color: Colors.teal.shade100, fontSize: 12))]),
                                    const SizedBox(height: 5),
                                    Text(_obscureBalance ? "****" : "KES ${_escrowBalance.toStringAsFixed(0)}", style: GoogleFonts.poppins(color: Colors.orange.shade300, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              ],
                            )
                          ],
                        ),
                      )
                  ],
                ),
              ),
            ),

            // 🔥 ACTION BUTTONS ADDED HERE
            if (!_isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 25, bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionBtn(LucideIcons.arrowDownToLine, "Withdraw", Colors.teal.shade700, _showWithdrawModal),
                      _buildActionBtn(LucideIcons.arrowUpFromLine, "Top Up", Colors.blue.shade700, () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Top up is handled via checkout pages.")));
                      }),
                      _buildActionBtn(LucideIcons.history, "History", Colors.purple.shade700, () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transaction history coming soon.")));
                      }),
                    ],
                  ),
                ),
              ),

            SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverToBoxAdapter(
                  child: FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.shade200)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.shieldCheck, color: Colors.orange.shade700),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Buyer Protection Escrow", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                                const SizedBox(height: 5),
                                Text("Funds in Escrow are locked. If you reject goods or a farmer brings less weight than promised, the difference is instantly refunded back to your Available Balance.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange.shade800)),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                )
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}