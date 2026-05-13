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