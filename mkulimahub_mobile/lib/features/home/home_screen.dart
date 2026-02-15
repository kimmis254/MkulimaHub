import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/home/add_harvest_screen.dart';
import 'package:mkulimahub_mobile/features/home/harvest_model.dart';
import 'package:mkulimahub_mobile/features/home/prediction_screen.dart';
import 'package:mkulimahub_mobile/features/home/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiClient _apiClient = ApiClient();
  late Future<List<Harvest>> _harvestsFuture;
  int _selectedIndex = 0;
  int _selectedCategoryIndex = 0;

  // Categories Data
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
    _loadHarvests();
  }

  void _loadHarvests() {
    setState(() {
      _harvestsFuture = _apiClient.getHarvests();
    });
  }

  String _getImageForCrop(String cropName) {
    final name = cropName.toLowerCase();
    if (name.contains('maize') || name.contains('corn')) {
      return 'https://images.unsplash.com/photo-1551754655-cd27e38d2076?w=500';
    } else if (name.contains('bean')) {
      return 'https://images.unsplash.com/photo-1551489186-cf8726f514f8?w=500';
    } else if (name.contains('mango')) {
      return 'https://images.unsplash.com/photo-1553279768-865429fa0078?w=500';
    } else if (name.contains('avocado')) {
      return 'https://images.unsplash.com/photo-1523049673856-4287b33a18e0?w=500';
    }
    return 'https://images.unsplash.com/photo-1566385101042-1a0aa0c1268c?w=500';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // --- APP BAR ---
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        
        // Profile Icon (Top Left)
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: BouncyButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
            child: CircleAvatar(
              backgroundColor: Colors.green[50],
              child: const Icon(LucideIcons.user, color: Colors.green, size: 20),
            ),
          ),
        ),

        // Title
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.sprout, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            Text(
              "MkulimaHub",
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),

        // Cart Icon (Top Right)
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: BouncyButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Cart feature coming soon!")),
                );
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.shoppingBag, color: Colors.black87, size: 20),
                  ),
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Text("2", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),

      // --- BODY ---
      body: CustomScrollView(
        slivers: [
          // 1. Search Bar & Categories
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "What are you craving?",
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
                        prefixIcon: const Icon(LucideIcons.search, color: Colors.green),
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.slidersHorizontal, color: Colors.green, size: 20),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Animated Categories List
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
                                border: Border.all(
                                  color: isSelected ? Colors.transparent : Colors.grey[200]!,
                                  width: 1.5
                                ),
                                boxShadow: isSelected 
                                  ? [BoxShadow(color: (cat['color'] as Color).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))]
                                  : [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    cat['icon'], 
                                    color: isSelected ? Colors.white : Colors.grey[600],
                                    size: isSelected ? 24 : 22,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    cat['name'],
                                    style: GoogleFonts.poppins(
                                      color: isSelected ? Colors.white : Colors.grey[600],
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Section Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Featured Harvests", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("See All", style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // 2. The Grid
          FutureBuilder<List<Harvest>>(
            future: _harvestsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SliverFillRemaining(child: Center(child: Text("No harvests yet. Add one!")));
              }

              final harvests = snapshot.data!;
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final harvest = harvests[index];
                      final displayName = harvest.cropName[0].toUpperCase() + harvest.cropName.substring(1).toLowerCase();
                      
                      return FadeInUp(
                        duration: const Duration(milliseconds: 500),
                        delay: Duration(milliseconds: index * 100),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                            ],
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  child: Image.network(
                                    _getImageForCrop(harvest.cropName),
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => Container(color: Colors.green[100], child: const Icon(LucideIcons.imageOff)),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1),
                                      Text("${harvest.weightKg}kg Available", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("KES ${harvest.pricePerKg}", style: GoogleFonts.poppins(color: Colors.green[800], fontWeight: FontWeight.bold)),
                                          const Row(children: [Icon(LucideIcons.star, size: 14, color: Colors.amber), Text("4.5", style: TextStyle(fontSize: 12))]),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: harvests.length,
                  ),
                ),
              );
            },
          ),
          
          // Extra space at bottom for scrolling past FAB
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),

      // --- FAB ---
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green[800],
        child: const Icon(LucideIcons.plus, color: Colors.white),
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHarvestScreen()));
          if (result == true) _loadHarvests();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // --- BOTTOM NAV ---
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green[800],
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 1) { 
             Navigator.push(context, MaterialPageRoute(builder: (_) => const PredictionScreen()));
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(LucideIcons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(LucideIcons.trendingUp), label: "Forecast"),
          BottomNavigationBarItem(icon: Icon(LucideIcons.shoppingCart), label: "Cart"),
          BottomNavigationBarItem(icon: Icon(LucideIcons.user), label: "Profile"),
        ],
      ),
    );
  } // <--- THIS BRACKET WAS LIKELY MISSING OR MISPLACED
}

// --- BOUNCY BUTTON CLASS (Must be OUTSIDE the _HomeScreenState class) ---
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}