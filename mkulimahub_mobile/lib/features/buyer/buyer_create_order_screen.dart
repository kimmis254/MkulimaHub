import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart'; // 🔥 Ensure you have this import!

class BuyerCreateOrderScreen extends StatefulWidget {
  const BuyerCreateOrderScreen({super.key});

  @override
  State<BuyerCreateOrderScreen> createState() => _BuyerCreateOrderScreenState();
}

class _BuyerCreateOrderScreenState extends State<BuyerCreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiClient _apiClient = ApiClient(); // 🔥 Initialized ApiClient
  
  // Form State
  String _selectedCrop = "Maize";
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String _selectedCounty = "Nairobi";
  String _selectedUrgency = "High"; // 🔥 Added Urgency State
  bool _isLoading = false;

  // Dynamic Calculator State
  double _totalValue = 0.0;

  final List<String> _popularCrops = ["Maize", "Beans", "Avocados", "Potatoes", "Onions", "Tomatoes"];
  final List<String> _counties = ["Nairobi", "Mombasa", "Nakuru", "Uasin Gishu", "Meru", "Machakos"];

  @override
  void initState() {
    super.initState();
    // Listen to changes to calculate total value live!
    _weightController.addListener(_calculateTotal);
    _priceController.addListener(_calculateTotal);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    setState(() {
      _totalValue = weight * price;
    });
  }

  // 🔥 COMPLETELY REWRITTEN TO TALK TO FASTAPI
  void _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    // Build the payload matching the BulkRequestCreate schema
    final requestData = {
      "crop_name": _selectedCrop,
      "target_weight_kg": double.tryParse(_weightController.text) ?? 0.0,
      "price_per_kg": double.tryParse(_priceController.text) ?? 0.0,
      "county": _selectedCounty,
      "urgency": _selectedUrgency,
    };

    // Send it to the backend
    final error = await _apiClient.postBulkRequest(requestData);

    if (mounted) {
      setState(() => _isLoading = false);

      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Success! Order broadcasted to farmers.", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.teal.shade800,
            behavior: SnackBarBehavior.floating,
          )
        );
        Navigator.pop(context, true); // Go back and tell Dashboard to refresh
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: Colors.teal.shade900),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text("New Bulk Request", style: GoogleFonts.poppins(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔥 HEADER
                      FadeInDown(
                        child: Text("What are you looking to source today?", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.2)),
                      ),
                      const SizedBox(height: 8),
                      FadeInDown(
                        delay: const Duration(milliseconds: 100),
                        child: Text("This will be broadcasted to all verified farmers and aggregation hubs.", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
                      ),
                      const SizedBox(height: 30),

                      // 🔥 CROP SELECTION
                      FadeInUp(
                        delay: const Duration(milliseconds: 200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Select Commodity", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _popularCrops.map((crop) {
                                bool isSelected = _selectedCrop == crop;
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedCrop = crop),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.teal.shade700 : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: isSelected ? Colors.teal.shade700 : Colors.grey.shade300),
                                      boxShadow: isSelected ? [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                                    ),
                                    child: Text(
                                      crop,
                                      style: GoogleFonts.poppins(
                                        color: isSelected ? Colors.white : Colors.grey.shade700,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // 🔥 TARGET WEIGHT & PRICE
                      FadeInUp(
                        delay: const Duration(milliseconds: 300),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildModernField(
                                controller: _weightController,
                                label: "Target Weight (kg)",
                                icon: LucideIcons.scale,
                                inputType: TextInputType.number,
                                hint: "e.g. 5000",
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: _buildModernField(
                                controller: _priceController,
                                label: "Price per kg (KES)",
                                icon: LucideIcons.banknote,
                                inputType: TextInputType.number,
                                hint: "e.g. 150",
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),

                      // 🔥 DELIVERY DESTINATION
                      FadeInUp(
                        delay: const Duration(milliseconds: 400),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Delivery Destination", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCounty,
                                  isExpanded: true,
                                  icon: Icon(LucideIcons.chevronDown, color: Colors.teal.shade700),
                                  style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                                  onChanged: (String? newValue) {
                                    setState(() => _selectedCounty = newValue!);
                                  },
                                  items: _counties.map<DropdownMenuItem<String>>((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Row(
                                        children: [
                                          Icon(LucideIcons.mapPin, size: 18, color: Colors.grey.shade400),
                                          const SizedBox(width: 10),
                                          Text(value),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),

                      // 🔥 URGENCY SELECTOR (NEW!)
                      FadeInUp(
                        delay: const Duration(milliseconds: 500),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Urgency Level", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                            const SizedBox(height: 10),
                            Row(
                              children: ["High", "Medium", "Low"].map((level) {
                                bool isSelected = _selectedUrgency == level;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedUrgency = level),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.orange.shade50 : Colors.white,
                                        border: Border.all(color: isSelected ? Colors.orange : Colors.grey.shade200, width: 2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(level, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isSelected ? Colors.orange.shade800 : Colors.grey.shade500)),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 100), // Scroll padding
                    ],
                  ),
                ),
              ),
            ),

            // 🔥 STICKY BOTTOM BAR (Total Calculator & Submit)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Estimated Value", style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12)),
                        Text(
                          "KES ${_totalValue.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}", 
                          style: GoogleFonts.poppins(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 20)
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 55,
                      width: 160,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isLoading 
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(LucideIcons.send, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text("Post Order", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Helper for text inputs
  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextInputType inputType,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: inputType,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
          validator: (value) => value!.isEmpty ? 'Required' : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(icon, color: Colors.teal.shade600, size: 20),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.teal.shade600, width: 2)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}