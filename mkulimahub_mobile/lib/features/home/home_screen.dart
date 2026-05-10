import 'dart:convert'; 
import 'dart:ui';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/home/add_harvest_screen.dart';
import 'package:mkulimahub_mobile/features/home/prediction_screen.dart';
import 'package:mkulimahub_mobile/features/home/profile_screen.dart';
import 'package:mkulimahub_mobile/features/home/cluster_screen.dart';
import 'package:mkulimahub_mobile/features/home/contracts_screen.dart';
import 'package:mkulimahub_mobile/features/home/ai_chat_screen.dart';
import 'package:mkulimahub_mobile/features/home/my_deliveries_screen.dart';
import 'package:mkulimahub_mobile/features/home/delivery_squads_screen.dart';
import 'package:mkulimahub_mobile/features/home/farmer_wallet_screen.dart';

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
      FarmerDashboardView(key: dashboardKey), 
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
                  
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHarvestScreen()));
                      if (result == true) {
                        dashboardKey.currentState?.loadDashboardData(); 
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

class FarmerDashboardView extends StatefulWidget {
  const FarmerDashboardView({super.key});
  @override
  State<FarmerDashboardView> createState() => FarmerDashboardViewState();
}

class FarmerDashboardViewState extends State<FarmerDashboardView> {
  final ApiClient _apiClient = ApiClient();
  
  List<dynamic> _myListings = []; 
  List<dynamic> _activeBulkRequests = []; 
  List<dynamic> _mySquadsAndPools = []; 
  
  bool _isLoading = true;
  String _userName = "Farmer";

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) return "Good Morning,";
    if (hour >= 12 && hour < 17) return "Good Afternoon,";
    return "Good Evening,"; 
  }

  Future<void> loadDashboardData() async {
    setState(() => _isLoading = true);
    
    final profile = await _apiClient.getProfile();
    if (profile != null && mounted) {
      setState(() => _userName = profile['full_name']?.split(' ')[0] ?? "Farmer");
    }

    final results = await Future.wait([
      _apiClient.getMyHarvests(),
      _apiClient.getActiveBulkRequests(),
      _apiClient.getMyPledges(),
    ]);

    if (mounted) {
      setState(() {
        _myListings = results[0] as List<dynamic>;
        final bulkData = results[1] as List<dynamic>;
        final pledgesData = results[2] as List<dynamic>;
        
        // 🔥 FIX 1: Map all contracts the farmer has ALREADY joined
        Map<int, dynamic> myActiveSquads = {};
        for (var p in pledgesData) {
           final br = p['bulk_request'];
           if (br == null) continue;
           
           final status = p['status']?.toString().toLowerCase() ?? '';
           final isCompleted = status == 'completed' || status == 'paid';
           
           if (!isCompleted) {
              myActiveSquads[br['id']] = p; 
           }
        }

        // 🔥 FIX 2: Check for unpledged Hub Pools (to move them to the bottom grid instead of hot requests)
        for (var req in bulkData) {
           final isPool = req['buyer_name'].toString().toLowerCase().contains('hub pool');
           if (isPool && !myActiveSquads.containsKey(req['id'])) {
              myActiveSquads[req['id']] = {
                 "bulk_request": req,
                 "pledged_weight_kg": req['total_pledged'] ?? 0.0,
                 "status": "gathering" 
              };
           }
        }

        // 🔥 FIX 3: Hot Bulk Requests ONLY show Corporate Contracts you haven't joined yet
        _activeBulkRequests = bulkData.where((req) {
           if (myActiveSquads.containsKey(req['id'])) return false; 
           
           double target = (req['target_weight_kg'] ?? 1).toDouble();
           double pledged = (req['total_pledged'] ?? 0).toDouble();
           return pledged < target; 
        }).toList();

        _mySquadsAndPools = myActiveSquads.values.toList();
        _isLoading = false;
      });
    }
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
    if (name.contains('avocado')) return 'https://images.unsplash.com/photo-1519996529931-28324d5a630e?w=500'; 
    return 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=500';
  }

  void _showPledgeSheet(Map<String, dynamic> request) {
    final TextEditingController weightController = TextEditingController();
    bool isSubmitting = false;

    double targetWeight = (request['target_weight_kg'] ?? 1.0).toDouble();
    double totalPledged = (request['total_pledged'] ?? 0).toDouble();
    double remainingAmount = targetWeight - totalPledged;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  Text("Join Delivery Squad", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Remaining needed: ${remainingAmount.toStringAsFixed(0)} kg", style: GoogleFonts.poppins(fontSize: 14, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  Text("How much can you contribute?", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: "Pledge Weight (KG)", filled: true, fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 15),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [50, 100, 200, 500].map((amount) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ActionChip(
                          label: Text("+$amount kg", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                          backgroundColor: Colors.green.shade50, side: BorderSide(color: Colors.green.shade200),
                          onPressed: () {
                            double current = double.tryParse(weightController.text) ?? 0;
                            weightController.text = (current + amount).toStringAsFixed(0);
                          },
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        final double? weight = double.tryParse(weightController.text);
                        if (weight == null || weight <= 0) return;
                        if (weight > remainingAmount) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("You cannot pledge more than the remaining limit (${remainingAmount.toStringAsFixed(0)} kg)"), backgroundColor: Colors.red));
                          return;
                        }
                        setSheetState(() => isSubmitting = true);
                        final error = await _apiClient.createPledge(request['id'], weight);
                        if (mounted) {
                          Navigator.pop(context);
                          if (error == null) {
                            loadDashboardData();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pledged successfully!"), backgroundColor: Colors.green));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade600, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text("Confirm Pledge", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildEditableCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required TextEditingController controller,
    String? suffix,
    String? prefix,
    required MaterialColor color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade100, width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.shade50, shape: BoxShape.circle),
            child: Icon(icon, color: color.shade700, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                if (subtitle != null)
                  Text(subtitle, style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 15),
          SizedBox(
            width: 110,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: color.shade900),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                prefixText: prefix,
                suffixText: suffix,
                filled: true,
                fillColor: color.shade50.withOpacity(0.6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showManageListingSheet(Map<String, dynamic> listing) {
    final TextEditingController inventoryController = TextEditingController(text: (listing['available_kg'] ?? 0).toString());
    final TextEditingController wholesalePriceController = TextEditingController(text: (listing['price_per_kg'] ?? 0).toString());
    
    List<dynamic> parsedUnits = [];
    if (listing['unit_pricing'] is String) {
      try { 
        String safeJson = listing['unit_pricing'].toString().replaceAll("'", '"');
        parsedUnits = jsonDecode(safeJson); 
      } catch (e) {
        debugPrint("JSON Parse Error: $e");
      }
    } else if (listing['unit_pricing'] is List) {
      parsedUnits = listing['unit_pricing'];
    }
    
    List<Map<String, dynamic>> unitPricing = List<Map<String, dynamic>>.from(parsedUnits.map((e) => Map<String, dynamic>.from(e)));
    
    final Map<String, TextEditingController> unitPriceControllers = {};
    for (var unit in unitPricing) {
      unitPriceControllers[unit['unit_name']] = TextEditingController(text: unit['price'].toString());
    }

    bool isSubmitting = false;
    String cleanDisplayTitle = _formatCropName(listing['crop_name'] ?? 'Produce');
    List<dynamic> orders = listing['orders'] ?? [];

    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.88, 
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 20),
                    
                    Container(
                      height: 120, width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.black),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildListingImage(listing, listing['crop_name'] ?? ''), 
                            Container(color: Colors.black.withOpacity(0.4)),
                            Center(child: Text(cleanDisplayTitle, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    Text("Manage Inventory", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 10),
                    _buildEditableCard(
                      title: "Available Stock",
                      subtitle: "Total weight remaining",
                      icon: LucideIcons.boxes,
                      controller: inventoryController,
                      suffix: " KG",
                      color: Colors.green
                    ),
                    const SizedBox(height: 15),

                    Text("Edit Selling Formats", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 10),
                    
                    if (listing['is_selling_by_weight'] == true)
                      _buildEditableCard(
                        title: "Wholesale Rate",
                        subtitle: "Per Kilogram",
                        icon: LucideIcons.scale,
                        controller: wholesalePriceController,
                        prefix: "KES ",
                        color: Colors.blue
                      ),
                    
                    ...unitPricing.map((unit) {
                      String uName = unit['unit_name'];
                      return _buildEditableCard(
                        title: uName,
                        subtitle: "Equivalent to ${unit['kg']} KG",
                        icon: LucideIcons.boxSelect,
                        controller: unitPriceControllers[uName]!,
                        prefix: "KES ",
                        color: Colors.orange
                      );
                    }),
                    
                    const SizedBox(height: 20),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting ? null : () async {
                          setSheetState(() => isSubmitting = true);
                          
                          final newInventory = double.tryParse(inventoryController.text) ?? 0;
                          final newWholesalePrice = double.tryParse(wholesalePriceController.text);
                          
                          List<Map<String, dynamic>> updatedUnits = [];
                          for (var unit in unitPricing) {
                            updatedUnits.add({
                              "unit_name": unit['unit_name'],
                              "kg": unit['kg'],
                              "price": double.tryParse(unitPriceControllers[unit['unit_name']]!.text) ?? unit['price'],
                            });
                          }

                          final error = await _apiClient.updateMarketListing(listing['id'], newInventory, newWholesalePrice, updatedUnits);
                          
                          if (mounted) {
                            Navigator.pop(context);
                            if (error == null) {
                              loadDashboardData(); 
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Listing updated successfully!"), backgroundColor: Colors.green));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                            }
                          }
                        },
                        icon: const Icon(LucideIcons.save, size: 16, color: Colors.white), 
                        label: Text("Save Changes", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      ),
                    ),
                    const SizedBox(height: 35),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Active Orders", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)), child: Text("${orders.length} Pending", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.orange.shade800, fontSize: 12)))
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    if (orders.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20), width: double.infinity, decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                        child: Text("No orders for this listing yet.", textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey.shade500)),
                      )
                    else
                      ...orders.map((order) => Container(
                        margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.shade200)),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.orange.shade50, child: const Icon(LucideIcons.user, color: Colors.orange)),
                          title: Text(order['buyer_name'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text("Requested: ${order['quantity']} ${order['type']}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                          trailing: const Icon(LucideIcons.chevronRight, color: Colors.grey),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => MyDeliveriesScreen(targetOrderId: "ORD-${order['id'].toString().padLeft(4, '0')}")));
                          },
                        ),
                      )),
                      
                    const SizedBox(height: 30),
                    Center(
                      child: TextButton.icon(
                        onPressed: () async {
                          bool confirm = await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Delete Listing?"),
                              content: const Text("Are you sure you want to permanently remove this listing from the marketplace?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes, Delete", style: TextStyle(color: Colors.red))),
                              ]
                            )
                          ) ?? false;
                          
                          if (confirm) {
                            Navigator.pop(context); 
                            
                            final error = await _apiClient.deleteMarketListing(listing['id']);
                            if (mounted) {
                               if (error == null) {
                                 loadDashboardData(); 
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Listing removed from market."), backgroundColor: Colors.red));
                               } else {
                                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                               }
                            }
                          }
                        },
                        icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.red), 
                        label: Text("Remove Listing (Sold out/Spoiled)", style: GoogleFonts.poppins(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: loadDashboardData,
        color: Colors.green,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Important!
          slivers: [
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
                            child: CircleAvatar(radius: 22, backgroundColor: Colors.white.withOpacity(0.2), child: const Icon(LucideIcons.user, color: Colors.white, size: 22)),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_getGreeting(), style: GoogleFonts.poppins(color: Colors.green.shade200, fontSize: 12)),
                              Text(_userName, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // 🔥 NEW: The Wallet Button!
                          BouncyButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FarmerWalletScreen())),
                            child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                                child: const Icon(LucideIcons.wallet, color: Colors.white, size: 22)
                            ),
                          ),
                          const SizedBox(width: 10),

                          // 🔥 UPDATED: Delivery icon changed to a Truck!
                          BouncyButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyDeliveriesScreen())),
                            child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), shape: BoxShape.circle),
                                child: const Icon(LucideIcons.truck, color: Colors.orangeAccent, size: 22)
                            ),
                          ),
                          const SizedBox(width: 10),

                          // AI Chat Button
                          BouncyButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen())),
                            child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                                child: const Icon(LucideIcons.bot, color: Colors.white, size: 22)
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      _buildStatCard("Active Market", _myListings.length.toString(), LucideIcons.layoutList),
                      const SizedBox(width: 15),
                      _buildStatCard("Active Squads", _mySquadsAndPools.length.toString(), LucideIcons.users),
                    ],
                  )
                ],
              ),
            ),
          ),
          
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
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContractsScreen())),
                          child: Text("View All", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  if (_isLoading)
                    const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: Colors.green)))
                  else if (_activeBulkRequests.isEmpty)
                     Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16)), child: Text("No corporate requests posted yet today.", style: GoogleFonts.poppins(color: Colors.orange.shade800), textAlign: TextAlign.center)),
                    )
                  else
                    SizedBox(
                      height: 185, 
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _activeBulkRequests.length, physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final req = _activeBulkRequests[index];
                          String urgency = req['urgency'] ?? 'Medium';
                          Color uBgColor = urgency == 'High' ? Colors.red.shade50 : (urgency == 'Medium' ? Colors.orange.shade50 : Colors.green.shade50);
                          Color uTextColor = urgency == 'High' ? Colors.red.shade800 : (urgency == 'Medium' ? Colors.orange.shade800 : Colors.green.shade800);
                          IconData uIcon = urgency == 'High' ? LucideIcons.flame : (urgency == 'Medium' ? LucideIcons.clock : LucideIcons.leaf);

                          return FadeInRight(
                            delay: Duration(milliseconds: index * 100),
                            child: GestureDetector(
                              onTap: () => _showPledgeSheet(req),
                              child: Container(
                                width: 260, margin: const EdgeInsets.only(right: 15), padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.shade100, width: 1.5), boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: uBgColor, borderRadius: BorderRadius.circular(8)), child: Text("$urgency Priority", style: GoogleFonts.poppins(color: uTextColor, fontSize: 10, fontWeight: FontWeight.bold))),
                                        Icon(uIcon, color: uTextColor.withOpacity(0.7), size: 18),
                                      ],
                                    ),
                                    Text("${req['target_weight_kg']}kg of ${req['crop_name']}", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text(req['buyer_name'] ?? 'Buyer', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                        Text("KES ${req['price_per_kg']}/kg", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity, height: 38,
                                      child: ElevatedButton(
                                        onPressed: () => _showPledgeSheet(req),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade50, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                        child: Text("Join Squad", style: GoogleFonts.poppins(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                    )
                                  ],
                                ),
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

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 15, bottom: 15),
              child: Text("My Market & Active Squads", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
          ),
          
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.green)))
          else if (_myListings.isEmpty && _mySquadsAndPools.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      Icon(LucideIcons.store, size: 50, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text("You have no active listings or squads.", style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14)),
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
                  crossAxisCount: 2, childAspectRatio: 0.70, crossAxisSpacing: 15, mainAxisSpacing: 15
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  
                  if (index < _myListings.length) {
                    final listing = _myListings[index];
                    String cleanDisplayTitle = _formatCropName(listing['crop_name'] ?? 'Crop');
                    final currentInventory = listing['available_kg'] ?? listing['weight_kg'] ?? 0;
                    final unit = listing['unit_type'] ?? 'KG';
                    final price = listing['price_per_unit'] ?? listing['price_per_kg'] ?? 0;
                    bool hasNewOrder = (listing['orders_count'] ?? 0) > 0;

                    return FadeInUp(
                      delay: Duration(milliseconds: index * 50), 
                      child: InkWell(
                        onTap: () => _showManageListingSheet(listing),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(20), 
                            boxShadow: [BoxShadow(color: hasNewOrder ? Colors.orange.withOpacity(0.3) : Colors.black.withOpacity(0.04), blurRadius: hasNewOrder ? 20 : 15, offset: const Offset(0, 8))],
                            border: Border.all(color: hasNewOrder ? Colors.orange.shade400 : Colors.grey.shade100, width: hasNewOrder ? 2 : 1)
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
                                      _buildListingImage(listing, listing['crop_name'] ?? ''), 
                                      Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.3), Colors.transparent]))),
                                      Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)]), child: Icon(LucideIcons.edit2, size: 14, color: Colors.grey.shade600))),
                                      if (hasNewOrder)
                                        Positioned(
                                          top: 8, left: 8,
                                          child: Pulse(
                                            infinite: true,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: Colors.orange.shade600, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.5), blurRadius: 5)]),
                                              child: Row(children: [const Icon(LucideIcons.bellRing, size: 10, color: Colors.white), const SizedBox(width: 4), Text("New Order!", style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))]),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(cleanDisplayTitle, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Text("$currentInventory $unit available", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 11)),
                                        const Spacer(),
                                        Text("KES $price/$unit", style: GoogleFonts.poppins(color: Colors.green.shade700, fontWeight: FontWeight.w800, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  } 
                  else {
                    final poolData = _mySquadsAndPools[index - _myListings.length];
                    final bulkRequest = poolData['bulk_request'] ?? {};
                    
                    String cropName = _formatCropName(bulkRequest['crop_name'] ?? 'Produce');
                    double targetWeight = (bulkRequest['target_weight_kg'] ?? 0).toDouble();
                    double price = (bulkRequest['price_per_kg'] ?? 0).toDouble();
                    
                    final isPool = bulkRequest['buyer_name'].toString().toLowerCase().contains('hub pool');
                    final badgeColor = isPool ? Colors.purple : Colors.blue;
                    final badgeIcon = isPool ? LucideIcons.users : LucideIcons.building;
                    final badgeText = isPool ? "Hub Pool" : "Corp Squad";

                    double totalSquadWeight = 0;
                    if (bulkRequest['squad_roster'] != null) {
                      for (var member in bulkRequest['squad_roster']) totalSquadWeight += (member['pledge_kg'] ?? 0).toDouble();
                    } else {
                      totalSquadWeight = (poolData['pledged_weight_kg'] ?? 0).toDouble();
                    }
                    
                    double progress = targetWeight > 0 ? (totalSquadWeight / targetWeight) : 0;
                    if (progress > 1.0) progress = 1.0;

                    return FadeInUp(
                      delay: Duration(milliseconds: index * 50), 
                      child: InkWell(
                        onTap: () async {
                           await Navigator.push(context, MaterialPageRoute(builder: (_) => DeliverySquadsScreen(targetSquadId: bulkRequest['id'])));
                           loadDashboardData(); 
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(20), 
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
                            border: Border.all(color: badgeColor.shade100, width: 1.5)
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
                                      Image.network(_getImageForCrop(cropName), fit: BoxFit.cover, width: double.infinity, height: double.infinity), 
                                      Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.4), Colors.transparent]))),
                                      
                                      Positioned(
                                        top: 8, left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: badgeColor.shade600, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: badgeColor.withOpacity(0.3), blurRadius: 5)]),
                                          child: Row(children: [Icon(badgeIcon, size: 10, color: Colors.white), const SizedBox(width: 4), Text(badgeText, style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(cropName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 6),
                                        
                                        Text("${totalSquadWeight.toStringAsFixed(0)} / ${targetWeight.toStringAsFixed(0)} KG", style: GoogleFonts.poppins(color: badgeColor.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 3),
                                        ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: badgeColor.shade50, color: badgeColor.shade400)),
                                        
                                        const Spacer(),
                                        Text("KES $price/KG", style: GoogleFonts.poppins(color: Colors.green.shade700, fontWeight: FontWeight.w800, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                }, childCount: _myListings.length + _mySquadsAndPools.length),
              ),
            ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.2))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.green.shade100, size: 24), const SizedBox(height: 12),
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