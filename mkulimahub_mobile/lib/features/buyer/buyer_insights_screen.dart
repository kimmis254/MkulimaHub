import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class BuyerInsightsScreen extends StatefulWidget {
  const BuyerInsightsScreen({super.key});

  @override
  State<BuyerInsightsScreen> createState() => _BuyerInsightsScreenState();
}

class _BuyerInsightsScreenState extends State<BuyerInsightsScreen> {
  // 🔥 MOCK DATA: Market Trends
  final List<Map<String, dynamic>> _priceTrends = [
    {"crop": "Grade 1 Maize", "price": "KES 4,500/bag", "change": "-2.4%", "isUp": false},
    {"crop": "Hass Avocados", "price": "KES 150/kg", "change": "+5.1%", "isUp": true},
    {"crop": "Red Onions", "price": "KES 120/kg", "change": "+1.2%", "isUp": true},
    {"crop": "Irish Potatoes", "price": "KES 3,200/bag", "change": "-4.5%", "isUp": false},
  ];

  // 🔥 MOCK DATA: Supply Hotspots
  final List<Map<String, dynamic>> _hotspots = [
    {"county": "Rift Valley (Eldoret)", "crop": "Maize", "volume": "High Supply", "color": Colors.green},
    {"county": "Central (Murang'a)", "crop": "Avocados", "volume": "Peak Harvest", "color": Colors.orange},
    {"county": "Eastern (Meru)", "crop": "Potatoes", "volume": "Moderate", "color": Colors.blue},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // 🔥 PREMIUM TEAL HEADER
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
              decoration: BoxDecoration(
                color: Colors.teal.shade800,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)),
                boxShadow: [BoxShadow(color: Colors.teal.shade900.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                        child: const Icon(LucideIcons.lineChart, color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 🔥 CONTENT AREA
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SECTION: LIVE PRICE TRENDS
                  Text("Live Price Index", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 15),
                  ...List.generate(_priceTrends.length, (index) {
                    final trend = _priceTrends[index];
                    return FadeInUp(
                      delay: Duration(milliseconds: index * 100),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade100),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: trend['isUp'] ? Colors.red.shade50 : Colors.green.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    trend['isUp'] ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                                    color: trend['isUp'] ? Colors.red.shade700 : Colors.green.shade700,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(trend['crop'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text(trend['price'], style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: trend['isUp'] ? Colors.red.shade50 : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                trend['change'],
                                style: GoogleFonts.poppins(
                                  color: trend['isUp'] ? Colors.red.shade700 : Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 25),

                  // SECTION: SUPPLY HOTSPOTS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Supply Hotspots", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      Text("Map View", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _hotspots.length,
                      itemBuilder: (context, index) {
                        final spot = _hotspots[index];
                        return FadeInRight(
                          delay: Duration(milliseconds: index * 100),
                          child: Container(
                            width: 220,
                            margin: const EdgeInsets.only(right: 15),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: spot['color'].shade100, width: 1.5),
                              boxShadow: [BoxShadow(color: spot['color'].withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Icon(LucideIcons.mapPin, color: spot['color'].shade400, size: 20),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: spot['color'].shade50, borderRadius: BorderRadius.circular(8)),
                                      child: Text(spot['volume'], style: GoogleFonts.poppins(color: spot['color'].shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
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
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)), // Space for bottom nav
        ],
      ),
    );
  }
}