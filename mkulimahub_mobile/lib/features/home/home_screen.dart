import 'dart:ui';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/home/add_harvest_screen.dart';
import 'package:mkulimahub_mobile/features/home/harvest_model.dart';
import 'package:mkulimahub_mobile/features/home/prediction_screen.dart';
import 'package:mkulimahub_mobile/features/home/profile_screen.dart';
import 'package:mkulimahub_mobile/features/home/cluster_screen.dart';
import 'package:mkulimahub_mobile/features/home/contracts_screen.dart';
import 'package:mkulimahub_mobile/features/home/ai_chat_screen.dart';

final GlobalKey<FarmerDashboardViewState> dashboardKey = GlobalKey<FarmerDashboardViewState>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      FarmerDashboardView(key: dashboardKey), // 🔥 Renamed and Revamped!
      const ClusterScreen(),                      
      const PredictionScreen(),                   
      const ContractsScreen(),                    
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, 
      backgroundColor: Colors.grey.shade50,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      
      // 🔥 THE UPGRADED PREMIUM GLASS NAV
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        height: 75,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.green.shade900.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, LucideIcons.layoutDashboard, "Home"),
                  _buildNavItem(1, LucideIcons.network, "Hubs"),
                  
                  // Center Action Button
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHarvestScreen()));
                      if (result == true) {
                        dashboardKey.currentState?.loadHarvests(); 
                        if (_selectedIndex != 0) setState(() => _selectedIndex = 0);
                      }
                    },
                    child: Container(
                      width: 55, height: 55,
                      margin: const EdgeInsets.only(bottom: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade700], begin: Alignment.topLeft, end: Alignment.bottomRight), 
                        shape: BoxShape.circle, 
                        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))]
                      ),
                      child: const Icon(LucideIcons.plus, color: Colors.white, size: 28),
                    ),
                  ),
                  
                  _buildNavItem(2, LucideIcons.lineChart, "Trends"),
                  _buildNavItem(3, LucideIcons.fileSignature, "Contracts"),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SizedBox.shrink(),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: Matrix4.translationValues(0, isSelected ? -2 : 0, 0),
              child: Icon(icon, color: isSelected ? Colors.green.shade700 : Colors.grey.shade400, size: isSelected ? 26 : 24),
            ),
            const SizedBox(height: 4),
            Text(
              label, 
              style: GoogleFonts.poppins(
                fontSize: 10, 
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, 
                color: isSelected ? Colors.green.shade800 : Colors.grey.shade500
              )
            )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🔥 THE NEW FARMER COMMAND CENTER
// ==========================================
class FarmerDashboardView extends StatefulWidget {
  const FarmerDashboardView({super.key});
  @override
  State<FarmerDashboardView> createState() => FarmerDashboardViewState();
}

class FarmerDashboardViewState extends State<FarmerDashboardView> {
  final ApiClient _apiClient = ApiClient();
  
  List<Harvest> _myHarvests = [];
  bool _isLoading = true;
  String _userName = "Farmer";

  // Mock data for Bulk Requests (Opportunities)
  final List<Map<String, dynamic>> _hotRequests = [
    {"buyer": "Unga Group Ltd", "crop": "Maize", "weight": "5,000 kg", "price": "KES 4,500/bag", "urgency": "High"},
    {"buyer": "City Restaurants", "crop": "Tomatoes", "weight": "200 kg", "price": "KES 80/kg", "urgency": "Medium"},
    {"buyer": "Export Co.", "crop": "Avocados", "weight": "1,000 kg", "price": "KES 150/kg", "urgency": "High"},
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    // Fetch Profile for the greeting
    final profile = await _apiClient.getProfile();
    if (profile != null && mounted) {
      setState(() => _userName = profile['full_name']?.split(' ')[0] ?? "Farmer");
    }

    await loadHarvests();
  }

  Future<void> loadHarvests() async {
    // In a real app, this should call an endpoint like /harvests/me
    // For now, we fetch all and pretend they belong to the farmer to show the UI
    final data = await _apiClient.getHarvests();
    if (mounted) {
      setState(() {
        _myHarvests = data;
        _isLoading = false;
      });
    }
  }

  String _formatCropName(String rawName) {
    if (rawName.isEmpty) return rawName;
    return rawName.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ').trim();
  }

  String _getImageForCrop(String cropName) {
    final name = cropName.toLowerCase();
    if (name.contains('maize') || name.contains('corn')) return 'https://images.unsplash.com/photo-1551754655-cd27e38d2076?w=500';
    if (name.contains('bean')) return 'https://images.unsplash.com/photo-1551489186-cf8726f514f8?w=500';
    if (name.contains('mango')) return 'https://images.unsplash.com/photo-1553279768-865429fa0078?w=500';
    if (name.contains('avocado')) return 'https://images.unsplash.com/photo-1523049673856-4287b33a18e0?w=500';
    return 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=500';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // 🔥 PREMIUM HEADER
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 35),
              decoration: BoxDecoration(
                color: Colors.green.shade800,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)),
                boxShadow: [BoxShadow(color: Colors.green.shade900.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          BouncyButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.white.withOpacity(0.2), 
                              child: const Icon(LucideIcons.user, color: Colors.white, size: 22)
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Good Morning,", style: GoogleFonts.poppins(color: Colors.green.shade200, fontSize: 12)),
                              Text(_userName, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                            ],
                          ),
                        ],
                      ),
                      BouncyButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen())),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                          child: const Icon(LucideIcons.bot, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  
                  // 🔥 QUICK STATS CARDS
                  Row(
                    children: [
                      _buildStatCard("Active Listings", "12", LucideIcons.layoutList),
                      const SizedBox(width: 15),
                      _buildStatCard("Pending Pledges", "3", LucideIcons.truck),
                    ],
                  )
                ],
              ),
            ),
          ),
          
          // 🔥 HOT BULK REQUESTS (Opportunities)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 25, bottom: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Hot Bulk Requests", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        Text("View All", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _hotRequests.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final req = _hotRequests[index];
                        return FadeInRight(
                          delay: Duration(milliseconds: index * 100),
                          child: Container(
                            width: 260,
                            margin: const EdgeInsets.only(right: 15),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.orange.shade100, width: 1.5),
                              boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                                      child: Text(req['urgency'] + " Priority", style: GoogleFonts.poppins(color: Colors.orange.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                    Icon(LucideIcons.flame, color: Colors.orange.shade400, size: 18),
                                  ],
                                ),
                                Text("${req['weight']} of ${req['crop']}", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(req['buyer'], style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                                    Text(req['price'], style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    ),
                  )
                ],
              ),
            ),
          ),

          // 🔥 MY ACTIVE LISTINGS HEADER
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 15, bottom: 15),
              child: Text("My Active Listings", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
          ),
          
          // 🔥 MY HARVEST GRID
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.green)))
          else if (_myHarvests.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      Icon(LucideIcons.store, size: 50, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text("You have no active listings.", style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14)),
                    ],
                  ),
                )
              )
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, 
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 15, 
                  mainAxisSpacing: 15
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final harvest = _myHarvests[index];
                  String cleanDisplayTitle = _formatCropName(harvest.cropName);

                  return FadeInUp(
                    delay: Duration(milliseconds: index * 50), 
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white, 
                        borderRadius: BorderRadius.circular(20), 
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
                        border: Border.all(color: Colors.grey.shade100)
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Stack(
                                children: [
                                  Image.network(
                                    _getImageForCrop(cleanDisplayTitle), 
                                    width: double.infinity, height: double.infinity, fit: BoxFit.cover, 
                                    errorBuilder: (c, e, s) => Container(color: Colors.green.shade50, child: const Center(child: Icon(LucideIcons.imageOff, color: Colors.green)))
                                  ),
                                  Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.3), Colors.transparent]))),
                                  Positioned(
                                    top: 8, right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)]),
                                      child: Icon(LucideIcons.edit2, size: 14, color: Colors.grey.shade600),
                                    ),
                                  )
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(cleanDisplayTitle, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text("${harvest.weightKg} kg available", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 11)),
                                    const Spacer(),
                                    Text("KES ${harvest.pricePerKg}/kg", style: GoogleFonts.poppins(color: Colors.green.shade700, fontWeight: FontWeight.w800, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }, childCount: _myHarvests.length),
              ),
            ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.green.shade100, size: 24),
            const SizedBox(height: 12),
            Text(value, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(title, style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade100)),
          ],
        ),
      ),
    );
  }
}

class BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  const BouncyButton({super.key, required this.child, required this.onPressed});
  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}
class _BouncyButtonState extends State<BouncyButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(_controller);
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTapDown: (_) => _controller.forward(), onTapUp: (_) { _controller.reverse(); widget.onPressed(); }, onTapCancel: () => _controller.reverse(), child: ScaleTransition(scale: _scaleAnimation, child: widget.child));
  }
}