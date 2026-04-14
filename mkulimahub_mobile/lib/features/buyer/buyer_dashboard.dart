import 'dart:ui';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/home/harvest_model.dart';
import 'package:mkulimahub_mobile/features/home/ai_chat_screen.dart';
import 'package:mkulimahub_mobile/features/buyer/customer_profile_screen.dart';
import 'package:mkulimahub_mobile/features/buyer/buyer_orders_screen.dart';
import 'package:mkulimahub_mobile/features/buyer/buyer_insights_screen.dart';
import 'package:mkulimahub_mobile/features/buyer/buyer_wallet_screen.dart';
import 'package:mkulimahub_mobile/features/buyer/buyer_create_order_screen.dart';
import 'package:mkulimahub_mobile/features/buyer/buyer_cart_screen.dart';


final GlobalKey<BuyerMarketplaceViewState> buyerMarketplaceKey = GlobalKey<BuyerMarketplaceViewState>();

class BuyerDashboard extends StatefulWidget {
  const BuyerDashboard({super.key});

  @override
  State<BuyerDashboard> createState() => _BuyerDashboardState();
}

class _BuyerDashboardState extends State<BuyerDashboard> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      BuyerMarketplaceView(key: buyerMarketplaceKey), // Tab 0: Market
      const BuyerOrdersScreen(),                      // Tab 1: 🔥 The real Orders & Tracking screen!
      const BuyerInsightsScreen(),                           // Tab 2: 🔥 The Market Intel AI!
      const BuyerWalletScreen(),                        // Tab 3: Financials (Placeholder for now)
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, 
      backgroundColor: Colors.grey.shade50,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      
      // 🔥 CUSTOMER PREMIUM GLASS NAV (TEAL THEME)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        height: 75,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.teal.shade900.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))],
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
                  _buildNavItem(0, LucideIcons.store, "Market"),
                  _buildNavItem(1, LucideIcons.package, "Orders"), 
                  
                  GestureDetector(
                    onTap: () async {
                      // 🔥 Send them to the creation screen!
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const BuyerCreateOrderScreen()));
                      
                      // If they successfully posted an order, switch them to the "Orders" tab
                      if (result == true) {
                        setState(() => _selectedIndex = 1);
                        // TODO: You can call a method here to refresh the Orders list from the API later
                      }
                    },
                    child: Container(
                      width: 55, height: 55,
                      margin: const EdgeInsets.only(bottom: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.teal.shade400, Colors.teal.shade700], begin: Alignment.topLeft, end: Alignment.bottomRight), 
                        shape: BoxShape.circle, 
                        boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))]
                      ),
                      child: const Icon(LucideIcons.filePlus, color: Colors.white, size: 28),
                    ),
                  ),
                  
                  _buildNavItem(2, LucideIcons.barChart3, "Insights"), 
                  _buildNavItem(3, LucideIcons.wallet, "Wallet"),      
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
              child: Icon(icon, color: isSelected ? Colors.teal.shade700 : Colors.grey.shade400, size: isSelected ? 26 : 24),
            ),
            const SizedBox(height: 4),
            Text(
              label, 
              style: GoogleFonts.poppins(
                fontSize: 10, 
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, 
                color: isSelected ? Colors.teal.shade800 : Colors.grey.shade500
              )
            )
          ],
        ),
      ),
    );
  }
}

class BuyerMarketplaceView extends StatefulWidget {
  const BuyerMarketplaceView({super.key});
  @override
  State<BuyerMarketplaceView> createState() => BuyerMarketplaceViewState();
}

class BuyerMarketplaceViewState extends State<BuyerMarketplaceView> {
  final ApiClient _apiClient = ApiClient();
  
  List<Harvest> _allHarvests = [];
  bool _isLoading = true;
  String _searchQuery = "";
  int _selectedCategoryIndex = 0;

  final List<Map<String, dynamic>> _categories = [
    {"name": "All", "icon": LucideIcons.layoutGrid, "color": Colors.teal},
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
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // 🔥 TEAL HEADER
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 25),
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
                      Row(
                        children: [
                          BouncyButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerProfileScreen())),
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
                              Text("Welcome back,", style: GoogleFonts.poppins(color: Colors.teal.shade200, fontSize: 12)),
                              Text("Customer", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          BouncyButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen()));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                              child: const Icon(LucideIcons.bot, color: Colors.white, size: 22),
                            ),
                          ),
                          const SizedBox(width: 10),
                          BouncyButton(
                            onPressed: () {
                              // 🔥 Send the buyer to the Cart!
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const BuyerCartScreen()));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: Icon(LucideIcons.shoppingBag, color: Colors.teal.shade800, size: 22),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 25),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(20), 
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]
                    ),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: "Search local markets...", 
                        hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14), 
                        prefixIcon: const Icon(LucideIcons.search, color: Colors.teal), 
                        border: InputBorder.none, 
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20)
                      )
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 25, left: 20, right: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Explore Sources", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 15),
                  SizedBox(
                    height: 95,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal, 
                      itemCount: _categories.length, 
                      physics: const BouncingScrollPhysics(),
                      clipBehavior: Clip.none,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategoryIndex == index;
                        return FadeInRight(
                          delay: Duration(milliseconds: index * 50),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedCategoryIndex = index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300), 
                              margin: const EdgeInsets.only(right: 15, bottom: 10), 
                              padding: EdgeInsets.symmetric(horizontal: isSelected ? 22 : 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? cat['color'] : Colors.white, 
                                borderRadius: BorderRadius.circular(24), 
                                border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade200, width: 1.5), 
                                boxShadow: isSelected ? [BoxShadow(color: (cat['color'] as Color).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))] : []
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center, 
                                children: [
                                  Icon(cat['icon'], color: isSelected ? Colors.white : Colors.grey.shade500, size: isSelected ? 26 : 22), 
                                  const SizedBox(height: 6), 
                                  Text(cat['name'], style: GoogleFonts.poppins(color: isSelected ? Colors.white : Colors.grey.shade600, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 12))
                                ]
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _searchQuery.isNotEmpty ? 'Search Results' : (_selectedCategoryIndex == 0 ? "Fresh Arrivals" : "${_categories[_selectedCategoryIndex]['name']} Available"), 
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
                      ),
                      Text("See All", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
                    ],
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),
          
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.teal)))
          else if (displayHarvests.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.shoppingBag, size: 50, color: Colors.grey.shade300),
                    const SizedBox(height: 10),
                    Text("No crops found.", style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 16)),
                  ],
                )
              )
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, 
                  childAspectRatio: 0.68,
                  crossAxisSpacing: 15, 
                  mainAxisSpacing: 15
                ),
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
                      decoration: BoxDecoration(
                        color: Colors.white, 
                        borderRadius: BorderRadius.circular(24), 
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
                        border: Border.all(color: Colors.grey.shade100)
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
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
                                    errorBuilder: (c, e, s) => Container(color: Colors.teal.shade50, child: const Center(child: Icon(LucideIcons.imageOff, color: Colors.teal)))
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.3), Colors.transparent, Colors.transparent])
                                    ),
                                  ),
                                  
                                  if (isBulk)
                                    Positioned(
                                      top: 10, left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(10)),
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
                              flex: 5,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start, 
                                      children: [
                                        Text(cleanDisplayTitle, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(LucideIcons.scale, size: 12, color: Colors.grey.shade500),
                                            const SizedBox(width: 4),
                                            Text("${harvest.weightKg} kg", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ]
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("Price", style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 10)),
                                            Text("KES ${harvest.pricePerKg}", style: GoogleFonts.poppins(color: Colors.teal.shade700, fontWeight: FontWeight.w800, fontSize: 15)),
                                          ],
                                        ),
                                        BouncyButton(
                                          onPressed: () {}, 
                                          child: Container(
                                            padding: const EdgeInsets.all(8), 
                                            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)), 
                                            child: const Icon(LucideIcons.plus, color: Colors.white, size: 18)
                                          ),
                                        )
                                      ]
                                    )
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

// ==========================================
// 🔥 PLACEHOLDER FOR WALLET (Kept at the bottom)
// ==========================================

class BuyerWalletView extends StatelessWidget {
  const BuyerWalletView({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.wallet, size: 60, color: Colors.teal.shade200),
          const SizedBox(height: 16),
          Text("Financials & Escrow", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
          Text("Manage your balance and view invoices.", style: GoogleFonts.poppins(color: Colors.grey)),
        ],
      )
    );
  }
}