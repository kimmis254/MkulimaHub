import 'dart:convert';
import 'dart:ui';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/home/ai_chat_screen.dart';
import 'package:mkulimahub_mobile/features/buyer/customer_profile_screen.dart';
import 'package:mkulimahub_mobile/features/buyer/buyer_orders_screen.dart';
import 'package:mkulimahub_mobile/features/buyer/buyer_insights_screen.dart';
import 'package:mkulimahub_mobile/features/buyer/buyer_wallet_screen.dart';
import 'package:mkulimahub_mobile/features/buyer/buyer_create_order_screen.dart';
import 'package:mkulimahub_mobile/features/buyer/buyer_cart_screen.dart';

final GlobalKey<BuyerMarketplaceViewState> buyerMarketplaceKey = GlobalKey<BuyerMarketplaceViewState>();
final GlobalKey<BuyerOrdersScreenState> buyerOrdersKey = GlobalKey<BuyerOrdersScreenState>();

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
      BuyerMarketplaceView(key: buyerMarketplaceKey),
      BuyerOrdersScreen(key: buyerOrdersKey), 
      const BuyerOrdersScreen(),                      
      const BuyerInsightsScreen(),                    
      const BuyerWalletScreen(),                      
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, 
      backgroundColor: Colors.grey.shade50,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      
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
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const BuyerCreateOrderScreen()));
                      if (result == true) {
                        buyerOrdersKey.currentState?.fetchLiveOrders();
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
  
  List<dynamic> _allListings = [];
  List<dynamic> _hubPools = []; 
  bool _isLoading = true;
  String _searchQuery = "";
  int _selectedCategoryIndex = 0;
  
  String _userName = "Buyer";

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
    _loadMarketData();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) return "Good Morning,";
    if (hour >= 12 && hour < 17) return "Good Afternoon,";
    return "Good Evening,"; 
  }

  Future<void> _loadMarketData() async {
    setState(() => _isLoading = true);
    
    final profile = await _apiClient.getProfile();
    if (profile != null && mounted) {
      setState(() => _userName = profile['full_name']?.split(' ')[0] ?? "Buyer");
    }

    final results = await Future.wait([
      _apiClient.getMarketListings(),
      _apiClient.getHubMarketplace(), 
    ]);
    
    if (mounted) {
      setState(() {
        _allListings = results[0] as List<dynamic>;
        _hubPools = results[1] as List<dynamic>;
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

  List<dynamic> get _filteredListings {
    return _allListings.where((harvest) {
      final matchesSearch = harvest['crop_name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      bool matchesCategory = true;
      if (_selectedCategoryIndex != 0) { 
        final targetCategory = _categories[_selectedCategoryIndex]['name'];
        final detectedCategory = _getCategoryForCrop(harvest['crop_name']);
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

  Widget _buildListingImage(Map<String, dynamic> item, String fallbackCropName) {
    if (item['image_base64'] != null && item['image_base64'].toString().isNotEmpty) {
      try {
        final base64String = item['image_base64'].toString().split(',').last;
        return Image.memory(base64Decode(base64String), fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      } catch (e) {
        debugPrint("Image decode error: $e");
      }
    }
    return Image.network(_getImageForCrop(fallbackCropName), fit: BoxFit.cover, width: double.infinity, height: double.infinity);
  }

  void _showOrderSheet(Map<String, dynamic> listing) {
    final TextEditingController qtyController = TextEditingController(text: "1");

    List<dynamic> parsedUnits = [];
    if (listing['unit_pricing'] is String) {
      try { parsedUnits = jsonDecode(listing['unit_pricing']); } catch (_) {}
    } else if (listing['unit_pricing'] is List) {
      parsedUnits = listing['unit_pricing'];
    }
    List<Map<String, dynamic>> unitPricing = List<Map<String, dynamic>>.from(parsedUnits.map((e) => Map<String, dynamic>.from(e)));
    
    String selectedFormat = listing['is_selling_by_weight'] == true ? "weight" : (unitPricing.isNotEmpty ? unitPricing[0]['unit_name'] : "weight");
    
    double getPrice() {
      if (selectedFormat == "weight") return listing['price_per_kg'].toDouble();
      final u = unitPricing.firstWhere((element) => element['unit_name'] == selectedFormat, orElse: () => {'price': 0});
      return u['price'].toDouble();
    }

    double getKg() {
      if (selectedFormat == "weight") return 1.0;
      final u = unitPricing.firstWhere((element) => element['unit_name'] == selectedFormat, orElse: () => {'kg': 0});
      return u['kg'].toDouble();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            double currentQty = double.tryParse(qtyController.text) ?? 1;
            double totalCost = currentQty * getPrice();
            double totalKg = currentQty * getKg();

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  Text("Purchase ${listing['crop_name']}", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Seller: ${listing['farmer_name']} (${listing['county']})", style: GoogleFonts.poppins(fontSize: 12, color: Colors.teal.shade700, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  
                  Text("Select Format", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (listing['is_selling_by_weight'] == true)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: ChoiceChip(
                              label: Text("By the KG", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: selectedFormat == "weight" ? Colors.white : Colors.black87)),
                              selected: selectedFormat == "weight",
                              selectedColor: Colors.teal.shade600,
                              onSelected: (val) => setSheetState(() => selectedFormat = "weight"),
                            ),
                          ),
                        ...unitPricing.map((unit) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ChoiceChip(
                            label: Text(unit['unit_name'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: selectedFormat == unit['unit_name'] ? Colors.white : Colors.black87)),
                            selected: selectedFormat == unit['unit_name'],
                            selectedColor: Colors.teal.shade600,
                            onSelected: (val) => setSheetState(() => selectedFormat = unit['unit_name']),
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Text("Quantity", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (currentQty > 1) {
                            setSheetState(() => qtyController.text = (currentQty - 1).toStringAsFixed(0));
                          }
                        },
                        icon: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle), child: const Icon(LucideIcons.minus, size: 16)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                          onChanged: (val) => setSheetState(() {}),
                          decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setSheetState(() => qtyController.text = (currentQty + 1).toStringAsFixed(0));
                        },
                        icon: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.teal.shade100, shape: BoxShape.circle), child: const Icon(LucideIcons.plus, size: 16, color: Colors.teal)),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 25),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.teal.shade100)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Total Escrow", style: GoogleFonts.poppins(color: Colors.teal.shade800, fontSize: 12)),
                            Text("KES ${totalCost.toStringAsFixed(0)}", style: GoogleFonts.poppins(color: Colors.teal.shade900, fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text("Est. Load: ${totalKg.toStringAsFixed(0)} KG", style: GoogleFonts.poppins(color: Colors.teal.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (totalKg > listing['available_kg']) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Only ${listing['available_kg']} KG remaining!"), backgroundColor: Colors.red));
                          return;
                        }

                        // 🔥 THE FIX: Push data into the Global Cart Manager!
                        CartManager.items.add({
                          "id": listing['id'],
                          "type": "individual",
                          "crop": listing['crop_name'],
                          "farmer": listing['farmer_name'],
                          "location": listing['county'],
                          "weightKg": totalKg,
                          "pricePerKg": getPrice() / getKg(), // standardize logic
                          "image": listing['image_base64'] ?? _getImageForCrop(listing['crop_name']),
                          "format": selectedFormat,
                          "qty": currentQty
                        });

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added to Procurement Cart!"), backgroundColor: Colors.green));
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text("Add to Cart", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final individualHarvests = _filteredListings;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // 🔥 TEAL HEADER WITH SMART GREETING
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
                              Text(_getGreeting(), style: GoogleFonts.poppins(color: Colors.teal.shade200, fontSize: 12)),
                              Text(_userName, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
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
                              // 🔥 NAVIGATE TO THE GLOBAL CART
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
                ],
              ),
            ),
          ),
          
          if (_hubPools.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 15, left: 20, right: 20, bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Verified Hub Pools", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Text("Wholesale Ready", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                    )
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _hubPools.length,
                  itemBuilder: (context, index) => _buildBulkCard(_hubPools[index]),
                ),
              ),
            ),
          ],

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 25, left: 20, right: 20, bottom: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _searchQuery.isNotEmpty ? 'Search Results' : (_selectedCategoryIndex == 0 ? "Individual Farmers" : "${_categories[_selectedCategoryIndex]['name']} Available"), 
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
                  ),
                  Text("See All", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
                ],
              ),
            ),
          ),
          
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.teal)))
          else if (individualHarvests.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.shoppingBag, size: 50, color: Colors.grey.shade300),
                    const SizedBox(height: 10),
                    Text("No individual crops found.", style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 16)),
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
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 15, 
                  mainAxisSpacing: 15
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final harvest = individualHarvests[index];
                  String cleanDisplayTitle = _formatCropName(harvest['crop_name']);

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
                                  _buildListingImage(harvest, cleanDisplayTitle),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.3), Colors.transparent, Colors.transparent])
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 6,
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
                                        Text("${harvest['farmer_name']}", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Row(
                                          children: [
                                            Icon(LucideIcons.mapPin, size: 10, color: Colors.grey.shade500),
                                            const SizedBox(width: 4),
                                            Text("${harvest['county']}", style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w500)),
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
                                            Text("${harvest['available_kg']} ${harvest['unit_type']} Avail.", style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 9)),
                                            Text("KES ${harvest['price_per_kg']}", style: GoogleFonts.poppins(color: Colors.teal.shade700, fontWeight: FontWeight.w800, fontSize: 13)),
                                          ],
                                        ),
                                        BouncyButton(
                                          onPressed: () => _showOrderSheet(harvest), 
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
                }, childCount: individualHarvests.length),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildBulkCard(Map<String, dynamic> pool) {
    return FadeInRight(
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(right: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.teal.shade900, Colors.teal.shade700], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Stack(
          children: [
            Positioned(right: -20, bottom: -20, child: Icon(LucideIcons.packageCheck, size: 100, color: Colors.white.withOpacity(0.1))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.amber.shade400, borderRadius: BorderRadius.circular(10)),
                        child: Text("CO-OP VERIFIED", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.teal.shade900)),
                      ),
                      const Icon(LucideIcons.shieldCheck, color: Colors.white, size: 20),
                    ],
                  ),
                  Text(pool['hub_name'], style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(
                    children: [
                      const Icon(LucideIcons.scale, color: Colors.amber, size: 16),
                      const SizedBox(width: 8),
                      Text("${pool['available_weight_kg']} KG ${pool['crop']}", style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("KES ${pool['asking_price_per_kg']}/KG", style: GoogleFonts.poppins(color: Colors.amber.shade400, fontWeight: FontWeight.bold, fontSize: 16)),
                      GestureDetector(
                        onTap: () {
                          // 🔥 THE FIX: Push data into the Global Cart Manager!
                          CartManager.items.add({
                            "id": pool['id'] ?? "pool",
                            "type": "pool",
                            "crop": pool['crop'],
                            "farmer": pool['hub_name'],
                            "location": "Hub",
                            "weightKg": pool['available_weight_kg'].toDouble(),
                            "pricePerKg": pool['asking_price_per_kg'].toDouble(),
                            "image": _getImageForCrop(pool['crop']),
                            "format": "weight",
                            "qty": pool['available_weight_kg']
                          });

                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hub Pool added to Cart!"), backgroundColor: Colors.green));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                          child: Text("Add to Cart", style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🔥 BOUNCY BUTTON HELPER
// ==========================================
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
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child)
    );
  }
}