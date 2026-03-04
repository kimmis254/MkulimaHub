import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  final ApiClient _apiClient = ApiClient();
  
  bool _isLoading = true;
  List<dynamic> _contracts = [];

  @override
  void initState() {
    super.initState();
    _fetchContracts();
  }

  Future<void> _fetchContracts() async {
    setState(() => _isLoading = true);
    final data = await _apiClient.getContracts();
    setState(() {
      _contracts = data;
      _isLoading = false;
    });
  }

  void _showPledgeDialog(int contractId, String cropName, double targetWeight) {
    final TextEditingController weightController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("Pledge $cropName", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("How many kilograms can you commit to this contract?", style: GoogleFonts.poppins(fontSize: 14)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: weightController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Weight in KG",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(LucideIcons.scale, color: Colors.green),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    final double? weight = double.tryParse(weightController.text);
                    if (weight == null || weight <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a valid weight")));
                      return;
                    }

                    setDialogState(() => isSubmitting = true);
                    
                    final error = await _apiClient.createPledge(contractId, weight);
                    
                    if (error == null && context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pledge successful!"), backgroundColor: Colors.green));
                      _fetchContracts(); 
                    } else if (context.mounted) {
                      setDialogState(() => isSubmitting = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? "Error"), backgroundColor: Colors.red));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: isSubmitting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text("Confirm Pledge", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, 
        title: Text("Open Contracts", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : _contracts.isEmpty
              ? Center(child: Text("No open contracts at the moment.", style: GoogleFonts.poppins(color: Colors.grey)))
              : RefreshIndicator(
                  color: Colors.green,
                  onRefresh: _fetchContracts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _contracts.length,
                    itemBuilder: (context, index) {
                      final contract = _contracts[index];
                      
                      final targetWeight = contract['target_weight_kg'] ?? 1.0;
                      final pledges = contract['pledges'] as List<dynamic>? ?? [];
                      
                      double totalPledged = 0;
                      for (var p in pledges) {
                        totalPledged += (p['pledged_weight_kg'] ?? 0);
                      }
                      
                      double progress = totalPledged / targetWeight;
                      if (progress > 1.0) progress = 1.0;

                      return FadeInUp(
                        delay: Duration(milliseconds: 100 * index),
                        child: _buildContractCard(contract, totalPledged, targetWeight, progress),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildContractCard(Map<String, dynamic> contract, double totalPledged, double targetWeight, double progress) {
    bool isFulfilled = progress >= 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: isFulfilled ? Colors.green.withOpacity(0.5) : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                child: Text(contract['buyer_name'] ?? 'Corporate Buyer', style: GoogleFonts.poppins(color: Colors.blue[800], fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              Text("KES ${contract['price_per_kg']}/kg", style: GoogleFonts.poppins(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 15),
          Text("Needed: ${contract['crop_name']}", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          Row(
            children: [
              const Icon(LucideIcons.mapPin, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text("${contract['ward'] ?? ''}, ${contract['county']}", style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13)),
            ],
          ),
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Pool Progress", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
              Text("${totalPledged.toStringAsFixed(0)} / ${targetWeight.toStringAsFixed(0)} kg", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey[200],
              color: isFulfilled ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isFulfilled ? null : () => _showPledgeDialog(contract['id'], contract['crop_name'], targetWeight),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFulfilled ? Colors.grey[300] : Colors.green[800],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                isFulfilled ? "Contract Fulfilled" : "Pledge Harvest",
                style: GoogleFonts.poppins(color: isFulfilled ? Colors.grey[600] : Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
    );
  }
}