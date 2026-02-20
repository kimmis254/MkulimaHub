import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';

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

  // Added Emojis for better visual cues
  final List<String> _crops = ['Maize 🌽', 'Beans 🫘', 'Mangoes 🥭', 'Green Grams 🌿', 'Avocado 🥑', 'Potatoes 🥔', 'Bananas 🍌'];
  String? _selectedCrop;

  void _submitHarvest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCrop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a crop"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Clean up the emoji from the string before sending to backend
    // e.g., "Maize 🌽" -> "Maize"
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Harvest Posted Successfully!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); 
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Consistent light background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "New Listing",
          style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Animation
              FadeInDown(
                duration: const Duration(milliseconds: 600),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.sprout, size: 40, color: Colors.green[700]),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              FadeInDown(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  "What are you selling?",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 5),
              FadeInDown(
                delay: const Duration(milliseconds: 150),
                child: Text(
                  "Fill in the details below to reach buyers.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
                ),
              ),
              const SizedBox(height: 30),

              // 2. Form Fields (Staggered Animation)
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: Column(
                  children: [
                    // Crop Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCrop,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            icon: Icon(LucideIcons.carrot, color: Colors.green[700], size: 20),
                          ),
                          hint: Text("Select Crop", style: GoogleFonts.poppins(color: Colors.grey[400])),
                          items: _crops.map((crop) {
                            return DropdownMenuItem(value: crop, child: Text(crop, style: GoogleFonts.poppins()));
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedCrop = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Weight Input
                    _buildModernField(
                      controller: _weightController,
                      label: "Total Weight",
                      icon: LucideIcons.scale,
                      suffix: "kg",
                      isNumber: true,
                    ),
                    const SizedBox(height: 20),

                    // Price Input
                    _buildModernField(
                      controller: _priceController,
                      label: "Price per Kg",
                      icon: LucideIcons.banknote,
                      prefix: "KES ",
                      isNumber: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // 3. Submit Button
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitHarvest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                      shadowColor: Colors.green.withOpacity(0.4),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.uploadCloud, color: Colors.white),
                            const SizedBox(width: 10),
                            Text("Post Harvest", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Widget for Clean Fields
  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? suffix,
    String? prefix,
    bool isNumber = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
          prefixIcon: Icon(icon, color: Colors.green[700], size: 20),
          prefixText: prefix,
          suffixText: suffix,
          prefixStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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