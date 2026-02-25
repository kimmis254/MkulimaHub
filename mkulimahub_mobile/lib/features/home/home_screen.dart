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

final GlobalKey<MarketplaceViewState> marketplaceKey = GlobalKey<MarketplaceViewState>();

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
      MarketplaceView(key: marketplaceKey), 
      const ClusterScreen(),                      
      const PredictionScreen(),                   
      const ContractsScreen(),                    
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // This allows the marketplace to scroll UNDER the floating nav
      body: IndexedStack(index: _selectedIndex, children: _screens),
      
      // THE NEW SLEEK FLOATING GLASS NAV
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // The magic blur effect
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5), // Dark transparent tint
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1), // Subtle glassy edge
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, LucideIcons.home, "Home"),
                  _buildNavItem(1, LucideIcons.mapPin, "Hubs"),
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHarvestScreen()));
                      if (result == true) {
                        marketplaceKey.currentState?.loadHarvests(); 
                        if (_selectedIndex != 0) setState(() => _selectedIndex = 0);
                      }
                    },
                    child: Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: Colors.green, 
                        shape: BoxShape.circle, 
                        boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
                      ),
                      child: const Icon(LucideIcons.plus, color: Colors.black, size: 28),
                    ),
                  ),
                  _buildNavItem(2, LucideIcons.trendingUp, "Trends"),
                  _buildNavItem(3, LucideIcons.fileText, "Contracts"),
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
      child: Container(
        color: Colors.transparent, 
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: Matrix4.translationValues(0, isSelected ? -3 : 0, 0),
              // White icons when unselected, Neon Green when selected
              child: Icon(icon, color: isSelected ? Colors.green : Colors.black, size: 24),
            ),
            if (isSelected) FadeInUp(duration: const Duration(milliseconds: 200), child: Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)))
          ],
        ),
      ),
    );
  }
}

class MarketplaceView extends StatefulWidget {
  const MarketplaceView({super.key});
  @override
  State<MarketplaceView> createState() => MarketplaceViewState();
}

class MarketplaceViewState extends State<MarketplaceView> {
  final ApiClient _apiClient = ApiClient();
  
  List<Harvest> _allHarvests = [];
  bool _isLoading = true;
  String _searchQuery = "";
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

  Future<void> loadHarvests() async {
    setState(() => _isLoading = true);
    final data = await _apiClient.getHarvests();
    if (mounted) {
      setState(() {
        _allHarvests = data;
        _isLoading = false;
      });
    }
  }

  String _getCategoryForCrop(String cropName) {
    final name = cropName.toLowerCase();
    if (name.contains('maize') || name.contains('wheat') || name.contains('rice') || name.contains('grain')) return 'Grains';
    if (name.contains('mango') || name.contains('avocado') || name.contains('apple') || name.contains('banana') || name.contains('fruit')) return 'Fruits';
    if (name.contains('bean') || name.contains('carrot') || name.contains('cabbage') || name.contains('tomato') || name.contains('potato') || name.contains('veg')) return 'Veg';
    if (name.contains('milk') || name.contains('egg') || name.contains('cheese') || name.contains('dairy')) return 'Dairy';
    if (name.contains('beef') || name.contains('chicken') || name.contains('meat') || name.contains('pork')) return 'Meat';
    return 'Other'; 
  }

  List<Harvest> get _filteredHarvests {
    return _allHarvests.where((harvest) {
      final matchesSearch = harvest.cropName.toLowerCase().contains(_searchQuery.toLowerCase());
      bool matchesCategory = true;
      if (_selectedCategoryIndex != 0) { 
        final targetCategory = _categories[_selectedCategoryIndex]['name'];
        final detectedCategory = _getCategoryForCrop(harvest.cropName);
        matchesCategory = detectedCategory == targetCategory;
      }
      return matchesSearch && matchesCategory;
    }).toList();
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
    final displayHarvests = _filteredHarvests;

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
            child: CircleAvatar(backgroundColor: Colors.green[50], child: const Icon(LucideIcons.user, color: Colors.green, size: 20)),
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
            padding: const EdgeInsets.only(right: 8.0),
            child: BouncyButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Shopping Cart coming soon!"))),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                child: const Icon(LucideIcons.shoppingBag, color: Colors.black87, size: 20),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: BouncyButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen()));
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green[100], shape: BoxShape.circle),
                child: Icon(LucideIcons.bot, color: Colors.green[800], size: 22),
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5))]),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: "Search for crops, hubs...", 
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14), 
                        prefixIcon: const Icon(LucideIcons.search, color: Colors.green), 
                        border: InputBorder.none, 
                        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20)
                      )
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal, itemCount: _categories.length, physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategoryIndex == index;
                        return FadeInRight(
                          delay: Duration(milliseconds: index * 100),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedCategoryIndex = index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300), margin: const EdgeInsets.only(right: 16, bottom: 10), padding: EdgeInsets.symmetric(horizontal: isSelected ? 20 : 12, vertical: 12),
                              decoration: BoxDecoration(color: isSelected ? cat['color'] : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? Colors.transparent : Colors.grey[200]!, width: 1.5), boxShadow: isSelected ? [BoxShadow(color: (cat['color'] as Color).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))] : []),
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(cat['icon'], color: isSelected ? Colors.white : Colors.grey[600], size: isSelected ? 24 : 22), const SizedBox(height: 5), Text(cat['name'], style: GoogleFonts.poppins(color: isSelected ? Colors.white : Colors.grey[600], fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 12))]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _searchQuery.isNotEmpty ? 'Search Results' : (_selectedCategoryIndex == 0 ? "Fresh Arrivals" : "${_categories[_selectedCategoryIndex]['name']} Available"), 
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.green)))
          else if (displayHarvests.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  "No crops found matching your filters.", 
                  style: GoogleFonts.poppins(color: Colors.grey)
                )
              )
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 16, mainAxisSpacing: 16),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final harvest = displayHarvests[index];
                  
                  bool isBulk = harvest.cropName.contains('Pool)');
                  String rawTitle = harvest.cropName;
                  
                  if (isBulk) {
                    int start = harvest.cropName.indexOf('(');
                    if (start != -1) {
                      rawTitle = harvest.cropName.substring(0, start).trim();
                    }
                  }

                  String cleanDisplayTitle = _formatCropName(rawTitle);

                  return FadeInUp(
                    delay: Duration(milliseconds: index * 50), 
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
                                  Image.network(_getImageForCrop(cleanDisplayTitle), width: double.infinity, height: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.green[50], child: const Center(child: Icon(LucideIcons.imageOff, color: Colors.green)))),
                                  
                                  if (isBulk)
                                    Positioned(
                                      top: 8, left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.orange[700], borderRadius: BorderRadius.circular(8)),
                                        child: Row(
                                          children: [
                                            const Icon(LucideIcons.users, size: 12, color: Colors.white),
                                            const SizedBox(width: 4),
                                            Text("BULK HUB", style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
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
                                      Text(cleanDisplayTitle, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1),
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
                }, childCount: displayHarvests.length),
              ),
            ),
          
          // Extra padding so items don't hide under the floating nav!
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
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