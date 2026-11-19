import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api/api_client.dart';

class BuyerCreateOrderScreen extends StatefulWidget {
  const BuyerCreateOrderScreen({super.key});

  @override
  State<BuyerCreateOrderScreen> createState() => _BuyerCreateOrderScreenState();
}

class _BuyerCreateOrderScreenState extends State<BuyerCreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiClient _apiClient = ApiClient();

  final TextEditingController _cropController = TextEditingController(text: "Maize");
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  // 🔥 THE DEADLINE CONTROLLER
  final TextEditingController _timeController = TextEditingController(text: "24");

  List<dynamic> _locationsData = [];
  List<String> _counties = [];
  List<String> _subCounties = [];
  List<String> _wards = [];

  String? _selectedCounty;
  String? _selectedSubCounty;
  String? _selectedWard;

  String _selectedUrgency = "High";
  bool _isLoading = false;
  double _totalValue = 0.0;

  final List<String> _popularCrops = [
    "Maize", "Beans", "Avocados", "Potatoes", "Onions", "Tomatoes", "Cabbage", "Carrots",
    "Spinach", "Kale (Sukuma)", "Bananas", "Mangoes", "Pineapples", "Watermelons",
    "Passion Fruits", "Green Grams", "Sorghum", "Millet", "Wheat", "Rice"
  ];

  @override
  void initState() {
    super.initState();
    _loadLocationData();
    _weightController.addListener(_calculateTotal);
    _priceController.addListener(_calculateTotal);
  }

  Future<void> _loadLocationData() async {
    try {
      final String response = await rootBundle.loadString('assets/data/kenya_locations.json');
      final data = await json.decode(response) as List<dynamic>;
      if (mounted) {
        setState(() {
          _locationsData = data;
          _counties = _locationsData.map((c) => c['county_name'].toString()).toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading locations: $e");
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _priceController.dispose();
    _cropController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    setState(() => _totalValue = weight * price);
  }

  void _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCounty == null || _selectedSubCounty == null || _selectedWard == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please select the County, Sub-County, and Ward.", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), backgroundColor: Colors.red.shade800));
      return;
    }

    setState(() => _isLoading = true);

    String detailedDelivery = "📍 Sub-County: $_selectedSubCounty\n🏘️ Ward: $_selectedWard\n🏢 Address: ${_addressController.text.trim()}\n📞 Phone: ${_contactController.text.trim()}";

    final requestData = {
      "crop_name": _cropController.text.trim(),
      "target_weight_kg": double.tryParse(_weightController.text) ?? 0.0,
      "price_per_kg": double.tryParse(_priceController.text) ?? 0.0,
      "county": _selectedCounty,
      "ward": detailedDelivery,
      "urgency": _selectedUrgency,
      "deadline_hours": int.tryParse(_timeController.text) ?? 24 // 🔥 PASSING THE DEADLINE
    };

    final error = await _apiClient.postBulkRequest(requestData);

    if (mounted) {
      setState(() => _isLoading = false);
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Success! Order broadcasted to farmers.", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), backgroundColor: Colors.teal.shade800));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), backgroundColor: Colors.red.shade800));
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
          backgroundColor: Colors.transparent, elevation: 0,
          leading: IconButton(icon: Icon(LucideIcons.arrowLeft, color: Colors.teal.shade900), onPressed: () => Navigator.pop(context)),
          title: Text("New Bulk Request", style: GoogleFonts.poppins(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 18)), centerTitle: true,
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
                      FadeInDown(child: Text("What are you looking to source today?", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.2))),
                      const SizedBox(height: 8),
                      FadeInDown(delay: const Duration(milliseconds: 100), child: Text("This will be broadcasted to all verified farmers and aggregation hubs.", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13))),
                      const SizedBox(height: 30),

                      FadeInUp(
                        delay: const Duration(milliseconds: 200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildModernField(controller: _cropController, label: "Specify Commodity", icon: LucideIcons.leaf, inputType: TextInputType.text, hint: "Type any crop name..."),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 35,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal, itemCount: _popularCrops.length,
                                itemBuilder: (context, index) {
                                  return GestureDetector(
                                    onTap: () => setState(() => _cropController.text = _popularCrops[index]),
                                    child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.center, decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.teal.shade200)), child: Text(_popularCrops[index], style: GoogleFonts.poppins(fontSize: 12, color: Colors.teal.shade800, fontWeight: FontWeight.w600))),
                                  );
                                },
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      FadeInUp(
                        delay: const Duration(milliseconds: 300),
                        child: Row(
                          children: [
                            Expanded(child: _buildModernField(controller: _weightController, label: "Target Weight (kg)", icon: LucideIcons.scale, inputType: TextInputType.number, hint: "e.g. 5000")),
                            const SizedBox(width: 15),
                            Expanded(child: _buildModernField(controller: _priceController, label: "Price per kg (KES)", icon: LucideIcons.banknote, inputType: TextInputType.number, hint: "e.g. 150")),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      FadeInUp(
                        delay: const Duration(milliseconds: 400),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Logistics & Handover", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 15),

                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                              child: Column(children: [
                                _buildDropdown("County", _selectedCounty, _counties, (val) {
                                  setState(() {
                                    _selectedCounty = val; _selectedSubCounty = null; _selectedWard = null; _wards = [];
                                    var countyObj = _locationsData.firstWhere((c) => c['county_name'] == val);
                                    var constituencies = countyObj['constituencies'] as List<dynamic>;
                                    _subCounties = constituencies.map((c) => c['constituency_name'].toString()).toList();
                                  });
                                }),
                                Divider(color: Colors.grey.shade200, height: 1),
                                _buildDropdown("Sub-County", _selectedSubCounty, _subCounties, (val) {
                                  setState(() {
                                    _selectedSubCounty = val; _selectedWard = null;
                                    var countyObj = _locationsData.firstWhere((c) => c['county_name'] == _selectedCounty);
                                    var constituencies = countyObj['constituencies'] as List<dynamic>;
                                    var constituencyObj = constituencies.firstWhere((c) => c['constituency_name'] == val);
                                    _wards = List<String>.from(constituencyObj['wards']);
                                  });
                                }),
                                Divider(color: Colors.grey.shade200, height: 1),
                                _buildDropdown("Ward", _selectedWard, _wards, (val) => setState(() => _selectedWard = val)),
                              ]),
                            ),

                            const SizedBox(height: 15),
                            _buildModernField(controller: _addressController, label: "Exact Delivery Address", icon: LucideIcons.building, inputType: TextInputType.text, hint: "e.g. Godown 4, Industrial Area"),
                            const SizedBox(height: 15),
                            _buildModernField(controller: _contactController, label: "Receiving Agent Phone", icon: LucideIcons.phone, inputType: TextInputType.phone, hint: "e.g. 0712345678"),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // 🔥 THE DEADLINE UI
                      FadeInUp(
                        delay: const Duration(milliseconds: 450),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Contract Deadline (Hours)", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    int current = int.tryParse(_timeController.text) ?? 24;
                                    if (current > 1) setState(() => _timeController.text = (current - 1).toString());
                                  },
                                  icon: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle), child: const Icon(LucideIcons.minus, size: 16)),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _timeController, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                                    decoration: InputDecoration(suffixText: "Hours", filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    int current = int.tryParse(_timeController.text) ?? 24;
                                    setState(() => _timeController.text = (current + 1).toString());
                                  },
                                  icon: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.teal.shade100, shape: BoxShape.circle), child: const Icon(LucideIcons.plus, size: 16, color: Colors.teal)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // 🔥 URGENCY
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
                                      margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(color: isSelected ? Colors.orange.shade50 : Colors.white, border: Border.all(color: isSelected ? Colors.orange : Colors.grey.shade200, width: 2), borderRadius: BorderRadius.circular(12)),
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
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))], borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Estimated Value", style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12)),
                        Text("KES ${_totalValue.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}", style: GoogleFonts.poppins(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 20)),
                      ],
                    ),
                    SizedBox(
                      height: 55, width: 160,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitOrder,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                        child: _isLoading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(LucideIcons.send, color: Colors.white, size: 18), const SizedBox(width: 8), Text("Post Order", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))]),
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

  Widget _buildDropdown(String label, String? val, List<String> items, Function(String?) changed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
              value: val, isExpanded: true, hint: Text(label, style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 14)),
              icon: const Icon(LucideIcons.chevronDown, size: 18, color: Colors.teal),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.poppins(fontSize: 14), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: items.isEmpty ? null : changed
          )
      ),
    );
  }

  Widget _buildModernField({required TextEditingController controller, required String label, required IconData icon, required TextInputType inputType, required String hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller, keyboardType: inputType, style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500), validator: (value) => value!.isEmpty ? 'Required' : null,
          decoration: InputDecoration(
            hintText: hint, hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13), prefixIcon: Icon(icon, color: Colors.teal.shade600, size: 20), filled: true, fillColor: Colors.white,
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