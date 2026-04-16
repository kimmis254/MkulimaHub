import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:intl/intl.dart';

class AddHarvestScreen extends StatefulWidget {
  const AddHarvestScreen({super.key});

  @override
  State<AddHarvestScreen> createState() => _AddHarvestScreenState();
}

class _AddHarvestScreenState extends State<AddHarvestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _priceController = TextEditingController();
  final _apiClient = ApiClient();
  
  bool _isLoading = false;
  double _estimatedValue = 0.0;

  final List<String> _crops = ['Maize 🌽', 'Beans 🫘', 'Mangoes 🥭', 'Green Grams 🌿', 'Avocado 🥑', 'Potatoes 🥔', 'Bananas 🍌'];
  String? _selectedCrop;

  @override
  void initState() {
    super.initState();
    // Add listeners to calculate revenue in real-time!
    _weightController.addListener(_calculateValue);
    _priceController.addListener(_calculateValue);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _calculateValue() {
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    setState(() {
      _estimatedValue = weight * price;
    });
  }

  void _submitHarvest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCrop == null) {
      // 🔥 UPDATED TO PREMIUM TOAST
      _showPremiumToast(context, "Please select a crop", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    // Clean up the emoji from the string
    final cleanCropName = _selectedCrop!.split(' ')[0];

    final harvestData = {
      "crop_name": cleanCropName,
      "weight_kg": double.parse(_weightController.text),
      "price_per_kg": double.parse(_priceController.text),
    };

    final error = await _apiClient.addHarvest(harvestData);

    setState(() => _isLoading = false);

    if (error == null) {
      if (mounted) {
        // 🔥 UPDATED TO PREMIUM TOAST
        _showPremiumToast(context, "Harvest Posted Successfully!");
        Navigator.pop(context, true); 
      }
    } else {
      if (mounted) {
        // 🔥 UPDATED TO PREMIUM TOAST
        _showPremiumToast(context, error, isError: true);
      }
    }
  }

  void _showPremiumToast(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(isError ? LucideIcons.alertCircle : LucideIcons.checkCircle, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message, 
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)
                )
              ),
            ],
          ),
        ),
        backgroundColor: isError ? Colors.red.shade800 : Colors.teal.shade800,
        behavior: SnackBarBehavior.floating,
        // 🔥 THIS MARGIN PUSHES IT TO THE MIDDLE OF THE SCREEN
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.45, // 45% up the screen!
          left: 24,
          right: 24,
        ),
        elevation: 15,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'en_US');

    return Scaffold(
      backgroundColor: Colors.grey.shade50, 
      body: Stack(
        children: [
          // 🔥 1. THE PREMIUM BACKGROUND HEADER
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green.shade900, Colors.green.shade700]
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
                        const SizedBox(width: 5),
                        Text("New Listing", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text("Reach thousands of verified buyers on the MkulimaHub network.", style: GoogleFonts.poppins(color: Colors.green.shade100, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🔥 2. THE FLOATING FORM CARD
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
                          
                          // Icon Header inside the card
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                              child: Icon(LucideIcons.sprout, size: 35, color: Colors.green.shade700),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            "What are you selling?",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 30),

                          // Crop Dropdown
                          _buildLabel("Crop Type"),
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
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  prefixIcon: Icon(LucideIcons.leaf, color: Colors.green.shade600, size: 20),
                                  prefixIconConstraints: const BoxConstraints(minWidth: 40),
                                ),
                                icon: Icon(LucideIcons.chevronDown, color: Colors.green.shade700, size: 20),
                                hint: Text("Select Crop", style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14)),
                                items: _crops.map((crop) {
                                  return DropdownMenuItem(value: crop, child: Text(crop, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.black87)));
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedCrop = val),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Weight and Price in a Row for better use of space
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel("Total Weight"),
                                    _buildPremiumField(
                                      controller: _weightController,
                                      hint: "0.0",
                                      icon: LucideIcons.scale,
                                      suffix: "KG",
                                      isNumber: true,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel("Price per KG"),
                                    _buildPremiumField(
                                      controller: _priceController,
                                      hint: "0.0",
                                      icon: LucideIcons.banknote,
                                      prefix: "KES ",
                                      isNumber: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // 🔥 Real-Time Revenue Calculator Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.blue.shade50, Colors.green.shade50]),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.shade100)
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(LucideIcons.calculator, size: 14, color: Colors.green.shade700),
                                        const SizedBox(width: 6),
                                        Text("Estimated Value", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text("Weight × Price", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600)),
                                  ],
                                ),
                                Text(
                                  "KES ${currencyFormat.format(_estimatedValue)}", 
                                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.green.shade800)
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          // 3. Submit Button
                          SizedBox(
                            height: 60,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submitHarvest,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [Colors.green.shade500, Colors.green.shade700]),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  child: _isLoading 
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(LucideIcons.uploadCloud, color: Colors.white, size: 22),
                                          const SizedBox(width: 10),
                                          Text("Publish to Market", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                        ],
                                      ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20), // Bottom padding
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

  Widget _buildPremiumField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? suffix,
    String? prefix,
    bool isNumber = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
          prefixIcon: Icon(icon, color: Colors.green.shade600, size: 20),
          prefixText: prefix,
          suffixText: suffix,
          prefixStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15),
          suffixStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade500, fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return "Required";
          if (isNumber && double.tryParse(v) == null) return "Invalid number";
          return null;
        },
      ),
    );
  }
}