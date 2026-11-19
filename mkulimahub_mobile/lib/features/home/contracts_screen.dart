import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api/api_client.dart';
import 'package:mkulimahub_mobile/features/home/delivery_squads_screen.dart';
import 'package:mkulimahub_mobile/features/home/my_deliveries_screen.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  final ApiClient _apiClient = ApiClient();

  bool _isLoading = true;
  List<dynamic> _contracts = [];
  int? _currentUserId;
  String _selectedFilter = 'All';
  String _userCounty = 'Your Area'; // For the Geofence UI
  List<String> _filters = ['All'];

  @override
  void initState() {
    super.initState();
    _fetchContracts();
  }

  // 🔥 TIMER PARSER
  String _getTimeRemaining(String? deadlineIso) {
    if (deadlineIso == null) return "No Deadline";
    try {
      DateTime deadline = DateTime.parse(deadlineIso).toLocal();
      Duration diff = deadline.difference(DateTime.now());
      if (diff.isNegative) return "Expired";
      int hours = diff.inHours;
      if (hours > 24) return "${hours ~/ 24}d ${hours % 24}h";
      return "${hours}h";
    } catch (e) {
      return "No Deadline";
    }
  }

  Future<void> _fetchContracts() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _apiClient.getContracts(),
      _apiClient.getProfile(),
    ]);

    if (mounted) {
      setState(() {
        _contracts = (results[0] as List<dynamic>?) ?? [];
        final profile = results[1] as Map<String, dynamic>?;
        if (profile != null) {
          _currentUserId = profile['id'];
          _userCounty = profile['county'] ?? 'Your Area';
        }

        Set<String> uniqueCrops = {'All'};
        for (var contract in _contracts) {
          if (contract['crop_name'] != null) {
            uniqueCrops.add(contract['crop_name'].toString());
          }
        }
        _filters = uniqueCrops.toList();

        if (!_filters.contains(_selectedFilter)) {
          _selectedFilter = 'All';
        }

        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredContracts {
    // 🔥 THE GEOFENCE FIX: First, strictly filter out contracts that don't match the farmer's county
    List<dynamic> geoFiltered = _contracts.where((c) {
      // If the farmer hasn't set their profile county yet, show them everything as a fallback
      if (_userCounty == 'Your Area' || _userCounty.isEmpty) return true;

      String contractCounty = c['county']?.toString() ?? '';

      // Case-insensitive match to prevent capitalization bugs (e.g., "Nairobi" vs "nairobi")
      return contractCounty.trim().toLowerCase() == _userCounty.trim().toLowerCase();
    }).toList();

    // 2. Next, apply the Dropdown Crop Filter to the Geofenced list
    List<dynamic> filteredList = _selectedFilter == 'All'
        ? List.from(geoFiltered)
        : geoFiltered.where((c) => c['crop_name'].toString().toLowerCase() == _selectedFilter.toLowerCase()).toList();

    // 3. Sort them so unfulfilled contracts appear at the top
    filteredList.sort((a, b) {
      double targetA = (a['target_weight_kg'] ?? 1.0).toDouble();
      double pledgedA = (a['total_pledged'] ?? 0).toDouble();
      if (a['pledges'] != null) {
        pledgedA = 0;
        for (var p in a['pledges']) pledgedA += (p['pledged_weight_kg'] ?? 0).toDouble();
      }
      bool isFulfilledA = pledgedA >= targetA;

      double targetB = (b['target_weight_kg'] ?? 1.0).toDouble();
      double pledgedB = (b['total_pledged'] ?? 0).toDouble();
      if (b['pledges'] != null) {
        pledgedB = 0;
        for (var p in b['pledges']) pledgedB += (p['pledged_weight_kg'] ?? 0).toDouble();
      }
      bool isFulfilledB = pledgedB >= targetB;

      if (isFulfilledA == isFulfilledB) return 0;
      return isFulfilledA ? 1 : -1;
    });

    return filteredList;
  }

  void _showPledgeBottomSheet(int contractId, String cropName, double targetWeight, double currentProgress) {
    final TextEditingController weightController = TextEditingController();
    bool isSubmitting = false;
    double remainingAmount = targetWeight - currentProgress;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setSheetState) {
                return Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                              child: const Icon(LucideIcons.leaf, color: Colors.orange),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Pledge $cropName", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                                  Text("Remaining needed: ${remainingAmount.toStringAsFixed(0)} kg", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),

                        Text("How much are you contributing?", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),

                        TextField(
                          controller: weightController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: "Enter amount...",
                            suffixText: "KG",
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.green.shade600, width: 2)),
                            prefixIcon: const Icon(LucideIcons.scale, color: Colors.green),
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
                                backgroundColor: Colors.green.shade50,
                                side: BorderSide(color: Colors.green.shade200),
                                onPressed: () {
                                  int current = int.tryParse(weightController.text) ?? 0;
                                  weightController.text = (current + amount).toString();
                                },
                              ),
                            )).toList(),
                          ),
                        ),
                        const SizedBox(height: 30),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isSubmitting ? null : () async {
                              final double? weight = double.tryParse(weightController.text);
                              if (weight == null || weight <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a valid weight")));
                                return;
                              }
                              if (weight > remainingAmount) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("You cannot pledge more than the remaining amount (${remainingAmount.toStringAsFixed(0)} kg)")));
                                return;
                              }

                              setSheetState(() => isSubmitting = true);
                              final error = await _apiClient.createPledge(contractId, weight);

                              if (error == null && context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pledge added to contract!"), backgroundColor: Colors.green));
                                _fetchContracts();
                              } else if (context.mounted) {
                                setSheetState(() => isSubmitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? "Error"), backgroundColor: Colors.red));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: isSubmitting
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text("Confirm Contribution", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        )
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
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 40),
            decoration: BoxDecoration(
              color: Colors.green.shade800,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Bulk Contracts", style: GoogleFonts.poppins(color: Colors.green.shade100, fontSize: 14)),
                          Text("Fulfill orders, maximize profit.", style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(LucideIcons.truck, color: Colors.white),
                        tooltip: "My Delivery Squads",
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyDeliveriesScreen()));
                        },
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                // 🔥 GEOFENCE INDICATOR
                Row(
                  children: [
                    Icon(LucideIcons.mapPin, size: 12, color: Colors.green.shade300),
                    const SizedBox(width: 6),
                    Text("Only showing contracts matching $_userCounty", style: GoogleFonts.poppins(color: Colors.green.shade200, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 20),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      bool isSelected = _selectedFilter == filter;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilter = filter),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.green.shade700,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? Colors.transparent : Colors.green.shade600),
                          ),
                          child: Text(
                              filter,
                              style: GoogleFonts.poppins(
                                  color: isSelected ? Colors.green.shade900 : Colors.white,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 13
                              )
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                )
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : RefreshIndicator(
              color: Colors.green,
              onRefresh: _fetchContracts,
              child: _filteredContracts.isEmpty
              // 🔥 FIX: Empty state is now scrollable, allowing pull-to-refresh even when empty!
                  ? CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  ),
                ],
              )
                  : ListView.builder(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _filteredContracts.length,
                itemBuilder: (context, index) {
                  final contract = _filteredContracts[index];

                  final targetWeight = (contract['target_weight_kg'] ?? 1.0).toDouble();
                  double totalPledged = (contract['total_pledged'] ?? 0).toDouble();
                  if (contract['pledges'] != null) {
                    totalPledged = 0;
                    for (var p in contract['pledges']) {
                      totalPledged += (p['pledged_weight_kg'] ?? 0).toDouble();
                    }
                  }

                  double progress = totalPledged / targetWeight;
                  if (progress > 1.0) progress = 1.0;

                  bool hasPledged = contract['has_pledged'] == true;
                  if (contract['pledges'] != null && _currentUserId != null) {
                    hasPledged = (contract['pledges'] as List<dynamic>).any((p) => p['farmer_id'] == _currentUserId);
                  }

                  return FadeInUp(
                    delay: Duration(milliseconds: 100 * index),
                    child: _buildPremiumContractCard(contract, totalPledged, targetWeight, progress, hasPledged),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumContractCard(Map<String, dynamic> contract, double totalPledged, double targetWeight, double progress, bool hasPledged) {
    bool isFulfilled = progress >= 1.0;

    // 🔥 DISPLAY TIMER
    String timeLeft = _getTimeRemaining(contract['deadline_time']);
    bool isUrgent = timeLeft == "Expired" || (timeLeft.contains("h") && !timeLeft.contains("d"));

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))],
        border: Border.all(color: isFulfilled ? Colors.green.shade300 : Colors.grey.shade100, width: isFulfilled ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.blue.shade50,
                            child: Icon(LucideIcons.building, size: 16, color: Colors.blue.shade700),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              contract['buyer_name'] ?? 'Corporate Buyer',
                              style: GoogleFonts.poppins(color: Colors.grey.shade800, fontSize: 14, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: isUrgent ? Colors.red.shade50 : Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Icon(LucideIcons.clock, size: 12, color: isUrgent ? Colors.red.shade700 : Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text(timeLeft, style: GoogleFonts.poppins(color: isUrgent ? Colors.red.shade800 : Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(contract['crop_name'] ?? 'Crop', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                    Text("KES ${contract['price_per_kg']}/kg", style: GoogleFonts.poppins(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(LucideIcons.mapPin, size: 14, color: Colors.grey),
                    const SizedBox(width: 5),
                    // 🔥 THE CLEANUP FIX: Only display the County on the public feed!
                    Text("Destination: ${contract['county'] ?? 'Kenya'}", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Fulfillment Pool", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    Text("${(progress * 100).toStringAsFixed(0)}%", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: isFulfilled ? Colors.green : Colors.black87)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    color: isFulfilled ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${totalPledged.toStringAsFixed(0)} kg pledged", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
                    Text("${targetWeight.toStringAsFixed(0)} kg target", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),
          ),

          Row(
            children: List.generate(30, (index) => Expanded(
              child: Container(color: index % 2 == 0 ? Colors.transparent : Colors.grey.shade300, height: 1),
            )),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: _buildDynamicActionButton(contract, hasPledged, isFulfilled, targetWeight, totalPledged, timeLeft == "Expired"),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDynamicActionButton(Map<String, dynamic> contract, bool hasPledged, bool isFulfilled, double targetWeight, double totalPledged, bool isExpired) {
    if (hasPledged) {
      return ElevatedButton.icon(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => DeliverySquadsScreen(targetSquadId: contract['id'])));
        },
        icon: const Icon(LucideIcons.users, size: 18, color: Colors.white),
        label: Text("View Delivery Squad", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade600, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
      );
    } else if (isFulfilled) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(LucideIcons.checkCircle, size: 18, color: Colors.grey),
        label: Text("Contract Fulfilled", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey.shade500)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
      );
    } else if (isExpired) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(LucideIcons.xCircle, size: 18, color: Colors.grey),
        label: Text("Time Expired", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey.shade500)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: () => _showPledgeBottomSheet(contract['id'], contract['crop_name'], targetWeight, totalPledged),
        icon: const Icon(LucideIcons.truck, size: 18, color: Colors.white),
        label: Text("Pledge to Fulfill", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
            child: Icon(LucideIcons.clipboardList, size: 50, color: Colors.green.shade300),
          ),
          const SizedBox(height: 20),
          Text("No contracts found.", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 10),
          Text(
              "Check back later or change your\ncrop filters to see more opportunities.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey.shade500)
          ),
        ],
      ),
    );
  }
}