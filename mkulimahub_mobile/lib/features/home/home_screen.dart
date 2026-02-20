import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/home/add_harvest_screen.dart';
import 'package:mkulimahub_mobile/features/home/harvest_model.dart';
import 'package:mkulimahub_mobile/features/home/prediction_screen.dart';
import 'package:mkulimahub_mobile/features/home/profile_screen.dart';

// --- 1. THE MAIN SHELL (Holds the Nav Bar) ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // 1. CREATE A KEY TO CONTROL THE MARKETPLACE VIEW
  // This acts like a remote control for the list of harvests
  final GlobalKey<MarketplaceViewState> _marketplaceKey = GlobalKey();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      // 2. ASSIGN THE KEY HERE
      MarketplaceView(key: _marketplaceKey),      // 0: Home
      const Center(child: Text("Map Screen Coming Soon!")), // 1: Map
      const PredictionScreen(),     // 2: Forecast
      const Center(child: Text("AI Chatbot Coming Soon!")), // 3: Chatbot
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The Body switches based on index
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      // --- CUSTOM FLOATING NAV BAR (Always Visible) ---
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, LucideIcons.home, "Home"),
            _buildNavItem(1, LucideIcons.mapPin, "Map"),
            
            // Middle "Add" Button
            GestureDetector(
              onTap: () async {
                // 3. WAIT FOR RESULT
                // We pause here until the user closes the Add Screen
                final result = await Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const AddHarvestScreen())
                );

                // 4. IF SUCCESS (result == true), REFRESH THE LIST
                if (result == true) {
                  print("Harvest Added! Refreshing list...");
                  _marketplaceKey.currentState?.loadHarvests(); // <--- MAGIC HAPPENS HERE
                  
                  // Optional: Switch back to home tab to see the new item
                  if (_selectedIndex != 0) {
                    setState(() => _selectedIndex = 0);
                  }
                }
              },
              child: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: Colors.green[800],
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))
                  ]
                ),
                child: const Icon(LucideIcons.plus, color: Colors.white, size: 28),
              ),
            ),
            
            _buildNavItem(2, LucideIcons.trendingUp, "Trends"),
            _buildNavItem(3, LucideIcons.bot, "Ask AI"),
          ],
        ),
      ),
      bottomNavigationBar: const SizedBox.shrink(), // Hide default
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isSelected 
          ? BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(15))
          : const BoxDecoration(color: Colors.transparent),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: Matrix4.translationValues(0, isSelected ? -2 : 0, 0),
              child: Icon(icon, color: isSelected ? Colors.green[800] : Colors.grey, size: 24),
            ),
            if (isSelected) 
              FadeInUp(
                duration: const Duration(milliseconds: 200),
                child: Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green[800])),
              )
          ],
        ),
      ),
    );
  }
}

// --- 2. MARKETPLACE VIEW (The Grid & Search) ---
class MarketplaceView extends StatefulWidget {
  // Added Key support so HomeScreen can identify this widget
  const MarketplaceView({super.key});

  @override
  // Changed from _MarketplaceViewState to MarketplaceViewState (Public)
  State<MarketplaceView> createState() => MarketplaceViewState();
}

// 5. PUBLIC STATE CLASS
class MarketplaceViewState extends State<MarketplaceView> {
  final ApiClient _apiClient = ApiClient();
  late Future<List<Harvest>> _harvestsFuture;
  int _selectedCategoryIndex = 0;

  final List<Map<String, dynamic>> _categories = [
    {"name": "All", "icon": LucideIcons.layoutGrid, "color": Colors.green},
    {"name": "Veg", "icon": LucideIcons.carrot, "color": Colors.orange},
    {"name": "Fruits", "icon": LucideIcons.apple, "color": Colors.red},
    {"name": "Grains", "icon": LucideIcons.wheat, "color": Colors.amber},
    {"name": "Dairy", "icon": LucideIcons.egg, "color": Colors.blue},
    {"name": "Meat", "icon": LucideIcons.beef, "color": Colors.brown},
  ];

  @override
  void initState() {
    super.initState();
    loadHarvests();
  }

  // 6. PUBLIC REFRESH METHOD
  void loadHarvests() {
    setState(() {
      _harvestsFuture = _apiClient.getHarvests();
    });
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: BouncyButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: CircleAvatar(
              backgroundColor: Colors.green[50],
              child: const Icon(LucideIcons.user, color: Colors.green, size: 20),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.sprout, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            Text("MkulimaHub", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 22)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: BouncyButton(
              onPressed: () {},
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                child: const Icon(LucideIcons.shoppingBag, color: Colors.black87, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Search & Categories
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "What are you craving?",
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
                        prefixIcon: const Icon(LucideIcons.search, color: Colors.green),
                        suffixIcon: const Icon(LucideIcons.slidersHorizontal, color: Colors.green),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Categories List
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategoryIndex == index;
                        return FadeInRight(
                          delay: Duration(milliseconds: index * 100),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedCategoryIndex = index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 16, bottom: 10),
                              padding: EdgeInsets.symmetric(horizontal: isSelected ? 20 : 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? cat['color'] : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isSelected ? Colors.transparent : Colors.grey[200]!, width: 1.5),
                                boxShadow: isSelected ? [BoxShadow(color: (cat['color'] as Color).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))] : [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(cat['icon'], color: isSelected ? Colors.white : Colors.grey[600], size: isSelected ? 24 : 22),
                                  const SizedBox(height: 5),
                                  Text(cat['name'], style: GoogleFonts.poppins(color: isSelected ? Colors.white : Colors.grey[600], fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Fresh Arrivals", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                      Row(children: [Text("See All", style: GoogleFonts.poppins(color: Colors.green[700], fontWeight: FontWeight.bold)), const SizedBox(width: 4), const Icon(LucideIcons.arrowRight, size: 16, color: Colors.green)]),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Grid
          FutureBuilder<List<Harvest>>(
            future: _harvestsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const SliverFillRemaining(child: Center(child: Text("No harvests yet.")));
              
              final harvests = snapshot.data!;
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 16, mainAxisSpacing: 16),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final harvest = harvests[index];
                    final displayName = harvest.cropName.length > 1 
                        ? harvest.cropName[0].toUpperCase() + harvest.cropName.substring(1).toLowerCase()
                        : harvest.cropName;

                    return FadeInUp(
                      delay: Duration(milliseconds: index * 100),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Stack(
                                  children: [
                                    Image.network(_getImageForCrop(harvest.cropName), width: double.infinity, height: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.green[50])),
                                    Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle), child: const Icon(LucideIcons.heart, size: 16, color: Colors.redAccent)))
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(displayName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1),
                                        Text("${harvest.weightKg}kg Available", style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12)),
                                      ]),
                                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                        Text("KES ${harvest.pricePerKg}", style: GoogleFonts.poppins(color: Colors.green[800], fontWeight: FontWeight.w700, fontSize: 16)),
                                        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)), child: const Icon(LucideIcons.plus, color: Colors.white, size: 16))
                                      ])
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }, childCount: harvests.length),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)), // Space for Floating Nav
        ],
      ),
    );
  }
}

// --- BOUNCY BUTTON ---
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
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) { _controller.reverse(); widget.onPressed(); },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}