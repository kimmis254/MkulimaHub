import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:intl/intl.dart';

class CreateContractScreen extends StatefulWidget {
  const CreateContractScreen({super.key});

  @override
  State<CreateContractScreen> createState() => _CreateContractScreenState();
}

class _CreateContractScreenState extends State<CreateContractScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _priceController = TextEditingController();
  final _countyController = TextEditingController();
  final _wardController = TextEditingController();
  final _apiClient = ApiClient();
  
  bool _isLoading = false;
  double _totalCapital = 0.0;

  final List<String> _crops = ['Maize', 'Beans', 'Wheat', 'Sorghum', 'Rice', 'Potatoes'];
  String? _selectedCrop;

  @override
  void initState() {
    super.initState();
    _weightController.addListener(_calculateCapital);
    _priceController.addListener(_calculateCapital);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _priceController.dispose();
    _countyController.dispose();
    _wardController.dispose();
    super.dispose();
  }

  void _calculateCapital() {
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    setState(() {
      _totalCapital = weight * price;
    });
  }

  void _submitContract() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCrop == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a target crop.")));
      return;
    }

    setState(() => _isLoading = true);

    final payload = {
      "crop_name": _selectedCrop,
      "target_weight_kg": double.parse(_weightController.text),
      "price_per_kg": double.parse(_priceController.text),
      "county": _countyController.text.trim(),
      "ward": _wardController.text.trim().isEmpty ? null : _wardController.text.trim(),
    };

    final error = await _apiClient.createBulkContract(payload);

    setState(() => _isLoading = false);

    if (error == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Contract broadcasted to the Hub Network!"), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true); 
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? "Error"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'en_US');

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          // ENTERPRISE HEADER
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Colors.blue.shade900, const Color(0xFF0A192F)]
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text("Draft Bulk Contract", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text("Broadcast your volume requirements to AI-clustered farming hubs.", style: GoogleFonts.poppins(color: Colors.blue.shade100, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // FLOATING FORM CARD
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 120.0),
              child: FadeInUp(
                duration: const Duration(milliseconds: 400),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(35), topRight: Radius.circular(35)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildLabel("Target Crop"),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200)
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButtonFormField<String>(
                                value: _selectedCrop,
                                decoration: InputDecoration(border: InputBorder.none, prefixIcon: Icon(LucideIcons.leaf, color: Colors.blue.shade600, size: 20), prefixIconConstraints: const BoxConstraints(minWidth: 40)),
                                icon: Icon(LucideIcons.chevronDown, color: Colors.blue.shade700, size: 20),
                                hint: Text("Select Commodity", style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14)),
                                items: _crops.map((crop) => DropdownMenuItem(value: crop, child: Text(crop, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.black87)))).toList(),
                                onChanged: (val) => setState(() => _selectedCrop = val),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel("Target Volume (KG)"),
                                    _buildPremiumField(controller: _weightController, hint: "10,000", icon: LucideIcons.truck, isNumber: true),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel("Price per KG (KES)"),
                                    _buildPremiumField(controller: _priceController, hint: "0.0", icon: LucideIcons.banknote, isNumber: true),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel("Target County"),
                                    _buildPremiumField(controller: _countyController, hint: "E.g., Nakuru", icon: LucideIcons.mapPin),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel("Ward (Optional)"),
                                    _buildPremiumField(controller: _wardController, hint: "Any", icon: LucideIcons.map),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // CAPITAL COMMITMENT CARD
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.blue.shade50, Colors.indigo.shade50]),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.blue.shade100)
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(LucideIcons.briefcase, size: 14, color: Colors.blue.shade700),
                                        const SizedBox(width: 6),
                                        Text("Capital Commitment", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text("Total Escrow Required", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600)),
                                  ],
                                ),
                                Text(
                                  "KES ${currencyFormat.format(_totalCapital)}", 
                                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.blue.shade800)
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          // SUBMIT BUTTON
                          SizedBox(
                            height: 60,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submitContract,
                              style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [Colors.blue.shade600, Colors.blue.shade800]),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  child: _isLoading 
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(LucideIcons.rss, color: Colors.white, size: 22),
                                          const SizedBox(width: 10),
                                          Text("Broadcast to Network", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                        ],
                                      ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30), 
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
    );
  }

  Widget _buildPremiumField({required TextEditingController controller, required String hint, required IconData icon, bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
          prefixIcon: Icon(icon, color: Colors.blue.shade600, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return "Required";
          if (isNumber && double.tryParse(v) == null) return "Invalid";
          return null;
        },
      ),
    );
  }
}