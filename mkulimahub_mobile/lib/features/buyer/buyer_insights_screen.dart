import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';

class BuyerInsightsScreen extends StatefulWidget {
  const BuyerInsightsScreen({super.key});

  @override
  State<BuyerInsightsScreen> createState() => _BuyerInsightsScreenState();
}

class _BuyerInsightsScreenState extends State<BuyerInsightsScreen> {
  final ApiClient _apiClient = ApiClient();

  bool _isLoading = true;
  Map<String, dynamic> _metrics = {};
  List<dynamic> _priceTrends = [];
  List<dynamic> _hotspots = [];
  List<dynamic> _alerts = [];
  List<dynamic> _forecasts = [];

  final List<MaterialColor> _hotspotColors = [Colors.green, Colors.orange, Colors.blue, Colors.purple];

  @override
  void initState() {
    super.initState();
    _fetchInsights();
  }

  Future<void> _fetchInsights() async {
    setState(() => _isLoading = true);
    final data = await _apiClient.getBuyerInsights();

    if (mounted) {
      if (data != null) {
        setState(() {
          _metrics = data['metrics'] ?? {};
          _priceTrends = data['trends'] ?? [];
          _hotspots = data['hotspots'] ?? [];
          _alerts = data['alerts'] ?? [];
          _forecasts = data['forecasts'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _fetchInsights,
        color: Colors.teal.shade700,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 櫨 PREMIUM TEAL HEADER
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
                decoration: BoxDecoration(
                  color: Colors.teal.shade800,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)),
                  boxShadow: [BoxShadow(color: Colors.teal.shade900.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Market Intelligence", style: GoogleFonts.poppins(color: Colors.teal.shade200, fontSize: 13, fontWeight: FontWeight.w500)),
                        Text("Live Insights", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26, letterSpacing: 0.5)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                      child: const Icon(LucideIcons.radar, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
            ),

            if (_isLoading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.teal)))
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. PLATFORM SCALE (Always visible)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildKPICard("Network Hubs", _metrics['active_hubs'].toString(), LucideIcons.network, Colors.blue),
                          const SizedBox(width: 15),
                          _buildKPICard("Live Tonnage", _metrics['total_tonnage'] ?? "0 KG", LucideIcons.scale, Colors.orange),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // 2. SMART ALERTS (Dynamic based on supply)
                      if (_alerts.isNotEmpty) ...[
                        Text("AI Market Alerts", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 15),
                        ..._alerts.map((alert) => FadeInLeft(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: alert['type'] == 'opportunity' ? Colors.amber.shade50 : Colors.blue.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: alert['type'] == 'opportunity' ? Colors.amber.shade200 : Colors.blue.shade200)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(alert['type'] == 'opportunity' ? LucideIcons.zap : LucideIcons.info, color: alert['type'] == 'opportunity' ? Colors.amber.shade700 : Colors.blue.shade700),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(alert['title'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text(alert['desc'], style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        )),
                        const SizedBox(height: 10),
                      ],

                      // 3. LIVE PRICE TRENDS (Hides if empty)
                      if (_priceTrends.isNotEmpty) ...[
                        Text("Live Price Index", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 15),
                        ...List.generate(_priceTrends.length, (index) {
                          final trend = _priceTrends[index];
                          return FadeInUp(
                            delay: Duration(milliseconds: index * 100),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: trend['isUp'] ? Colors.green.shade50 : Colors.red.shade50, shape: BoxShape.circle), child: Icon(trend['isUp'] ? LucideIcons.trendingUp : LucideIcons.trendingDown, color: trend['isUp'] ? Colors.green.shade700 : Colors.red.shade700, size: 18)),
                                      const SizedBox(width: 15),
                                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(trend['crop'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)), Text(trend['price'], style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12))]),
                                    ],
                                  ),
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: trend['isUp'] ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(10)), child: Text(trend['change'], style: GoogleFonts.poppins(color: trend['isUp'] ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12)))
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 25),
                      ],

                      // 4. AI FORECASTS (Always shows if ML Models have run)
                      if (_forecasts.isNotEmpty) ...[
                        Text("Prophet AI 30-Day Forecast", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 15),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal, itemCount: _forecasts.length, physics: const BouncingScrollPhysics(),
                            itemBuilder: (context, index) {
                              final f = _forecasts[index];
                              bool isRising = f['trend'] == 'Rising';
                              return Container(
                                width: 180, margin: const EdgeInsets.only(right: 15), padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.purple.shade100, width: 1.5), boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(LucideIcons.brainCircuit, color: Colors.purple.shade400, size: 20), Icon(isRising ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight, color: isRising ? Colors.red : Colors.green, size: 16)]),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(f['crop'], style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                                        Text("Est: ${f['predicted_price']}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.purple.shade700, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 25),
                      ],

                      // 5. SUPPLY HOTSPOTS
                      if (_hotspots.isNotEmpty) ...[
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Supply Hotspots", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)), Text("Map View", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade700))]),
                        const SizedBox(height: 15),
                        SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), itemCount: _hotspots.length,
                            itemBuilder: (context, index) {
                              final spot = _hotspots[index];
                              final MaterialColor spotColor = _hotspotColors[spot['color_index'] % _hotspotColors.length];
                              return FadeInRight(
                                delay: Duration(milliseconds: index * 100),
                                child: Container(
                                  width: 220, margin: const EdgeInsets.only(right: 15), padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: spotColor.shade100, width: 1.5), boxShadow: [BoxShadow(color: spotColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Icon(LucideIcons.mapPin, color: spotColor.shade400, size: 20),
                                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: spotColor.shade50, borderRadius: BorderRadius.circular(8)), child: Text(spot['volume'], style: GoogleFonts.poppins(color: spotColor.shade800, fontSize: 10, fontWeight: FontWeight.bold))),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(spot['county'], style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          Text("Primary: ${spot['crop']}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  // Helper for Top KPIs
  Widget _buildKPICard(String title, String value, IconData icon, MaterialColor color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.shade100), boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color.shade400, size: 20),
            const SizedBox(height: 12),
            Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            Text(title, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}