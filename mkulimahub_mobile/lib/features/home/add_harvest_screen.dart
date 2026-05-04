import 'dart:convert';
import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';

class AddHarvestScreen extends StatefulWidget {
  const AddHarvestScreen({super.key});

  @override
  State<AddHarvestScreen> createState() => _AddHarvestScreenState();
}

class _AddHarvestScreenState extends State<AddHarvestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiClient = ApiClient();
  final _picker = ImagePicker();
  
  bool _isLoading = false;
  File? _cropImage;

  // Selling Options
  bool _sellByWeight = true;
  bool _sellByUnit = false;

  // Dynamic Units
  List<Map<String, dynamic>> _addedUnits = []; 

  // Controllers
  final _baseKgController = TextEditingController();
  final _pricePerKgController = TextEditingController();
  final _pricePerUnitController = TextEditingController();
  final _kgPerUnitController = TextEditingController();

  // Smart Crop Data
  final List<String> _crops = ['Maize 🌽', 'Beans 🫘', 'Mangoes 🥭', 'Avocado 🥑', 'Potatoes 🥔', 'Bananas 🍌', 'Tomatoes 🍅'];
  String? _selectedCrop;
  String? _selectedUnit;

  // Smart Dictionary: Maps crops to their standard retail units in Kenya
  final Map<String, List<String>> _cropUnits = {
    'Maize 🌽': ['Bag (90kg)', 'Gorogoro (2kg)', 'Cob'],
    'Beans 🫘': ['Bag (90kg)', 'Gorogoro (2kg)'],
    'Mangoes 🥭': ['Piece', 'Crate', 'Net'],
    'Avocado 🥑': ['Piece', 'Crate', 'Net'],
    'Potatoes 🥔': ['Bag (50kg)', 'Bucket'],
    'Bananas 🍌': ['Bunch', 'Piece'],
    'Tomatoes 🍅': ['Crate', 'Bucket', 'Net'],
  };

  Future<void> _pickImage() async {
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text("Upload Crop Photo", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPhotoOption(
                  icon: LucideIcons.camera, 
                  label: "Camera", 
                  onTap: () async {
                    Navigator.pop(ctx);
                    final pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 60);
                    if (pickedFile != null && mounted) setState(() => _cropImage = File(pickedFile.path));
                  }
                ),
                _buildPhotoOption(
                  icon: LucideIcons.image, 
                  label: "Gallery", 
                  onTap: () async {
                    Navigator.pop(ctx);
                    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
                    if (pickedFile != null && mounted) setState(() => _cropImage = File(pickedFile.path));
                  }
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      )
    );
  }

  Widget _buildPhotoOption({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle, border: Border.all(color: Colors.green.shade200)),
            child: Icon(icon, color: Colors.green.shade700, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey.shade700))
        ],
      ),
    );
  }

  void _submitHarvest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCrop == null) {
      _showPremiumToast("Please select a crop", isError: true);
      return;
    }
    if (_cropImage == null) {
      _showPremiumToast("Please upload a photo of your produce", isError: true);
      return;
    }
    if (!_sellByWeight && !_sellByUnit) {
      _showPremiumToast("Select at least one way to sell (Weight or Unit)", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    String cleanCropName = _selectedCrop!.split(' ')[0];
    String? imageBase64 = base64Encode(await _cropImage!.readAsBytes());

    final harvestData = {
      "crop_name": cleanCropName,
      "base_inventory_kg": double.tryParse(_baseKgController.text) ?? 0,
      "is_selling_by_weight": _sellByWeight,
      "price_per_kg": _sellByWeight ? (double.tryParse(_pricePerKgController.text) ?? 0) : null,
      "unit_pricing": _addedUnits, 
      "image_base64": "data:image/jpeg;base64,$imageBase64"
    };

    final error = await _apiClient.addHarvest(harvestData);

    setState(() => _isLoading = false);

    if (error == null) {
      if (mounted) {
        _showPremiumToast("Harvest Posted to Marketplace!");
        Navigator.pop(context, true); 
      }
    } else {
      if (mounted) _showPremiumToast(error, isError: true);
    }
  }

  void _showPremiumToast(String message, {bool isError = false}) {
    // 1. Instantly hide the keyboard so the screen returns to normal size
    FocusManager.instance.primaryFocus?.unfocus();

    // 2. Clear any existing snackbars so they don't pile up
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? LucideIcons.alertCircle : LucideIcons.checkCircle, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade800 : Colors.teal.shade800,
        behavior: SnackBarBehavior.floating,
        // 🔥 3. SAFE MARGIN: Standard bottom padding. Flutter will automatically push it up if the keyboard is open!
        margin: const EdgeInsets.only(bottom: 30, left: 24, right: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50, 
      appBar: AppBar(
        backgroundColor: Colors.green.shade800,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("Post to Marketplace", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              // 1. THE PHOTO UPLOADER
              Text("Crop Photo", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _cropImage == null ? Colors.green.shade200 : Colors.green.shade600, width: 2, style: BorderStyle.solid),
                    image: _cropImage != null ? DecorationImage(image: FileImage(_cropImage!), fit: BoxFit.cover) : null,
                  ),
                  child: _cropImage == null 
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.camera, size: 40, color: Colors.green.shade400),
                            const SizedBox(height: 8),
                            Text("Tap to upload photo", style: GoogleFonts.poppins(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 25),

              // 2. CROP & MASTER INVENTORY
              _buildLabel("What are you selling?"),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCrop,
                    decoration: InputDecoration(border: InputBorder.none, prefixIcon: Icon(LucideIcons.leaf, color: Colors.green.shade600, size: 20), prefixIconConstraints: const BoxConstraints(minWidth: 40)),
                    icon: Icon(LucideIcons.chevronDown, color: Colors.green.shade700, size: 20),
                    hint: Text("Select Crop", style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14)),
                    items: _crops.map((crop) => DropdownMenuItem(value: crop, child: Text(crop, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black87)))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCrop = val;
                        _selectedUnit = _cropUnits[val!]?.first; 
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _buildLabel("Total Harvest Weight (Important for math tracking)"),
              _buildPremiumField(controller: _baseKgController, hint: "E.g. 500", icon: LucideIcons.scale, suffix: "KG", isNumber: true),
              const SizedBox(height: 30),

              // 3. SELLING CONFIGURATIONS
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.shade100)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("How will customers buy this?", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    Text("Enable one or both options.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 15),

                    // OPTION A: SELL BY WEIGHT
                    SwitchListTile(
                      title: Text("Sell by the KG", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text("Wholesale or large orders", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
                      activeColor: Colors.green,
                      value: _sellByWeight,
                      onChanged: (val) => setState(() => _sellByWeight = val),
                    ),
                    if (_sellByWeight) ...[
                      const SizedBox(height: 10),
                      _buildPremiumField(controller: _pricePerKgController, hint: "0.0", icon: LucideIcons.banknote, prefix: "KES ", suffix: "per KG", isNumber: true),
                    ],

                    const Divider(height: 30),

                    // OPTION B: SELL BY UNIT (Smart Dropdown!)
                    SwitchListTile(
                      title: Text("Sell by Custom Units", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text("Add options like Bags, Buckets, or Pieces.", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
                      activeColor: Colors.green,
                      value: _sellByUnit,
                      onChanged: (val) => setState(() => _sellByUnit = val),
                    ),
                    
                    if (_sellByUnit) ...[
                      const SizedBox(height: 10),

                      // Display the units they have already added!
                      if (_addedUnits.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _addedUnits.map((unit) {
                            return Chip(
                              label: Text("${unit['unit_name']} - KES ${unit['price']} (${unit['kg']}kg)", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                              backgroundColor: Colors.orange.shade50,
                              side: BorderSide(color: Colors.orange.shade200),
                              deleteIcon: const Icon(LucideIcons.xCircle, size: 16, color: Colors.red),
                              onDeleted: () {
                                setState(() => _addedUnits.remove(unit));
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 15),
                      ],

                      // The Input Form to add a new unit
                      if (_selectedCrop != null && _cropUnits.containsKey(_selectedCrop)) ...[
                        _buildLabel("Select Unit Type"),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid)), // FIXED DASH ERROR
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedUnit,
                                    isExpanded: true,
                                    hint: const Text("Choose..."),
                                    items: _cropUnits[_selectedCrop]!.map((u) => DropdownMenuItem(value: u, child: Text(u, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)))).toList(),
                                    onChanged: (val) => setState(() => _selectedUnit = val),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    _buildLabel("Price per Unit"),
                                    _buildPremiumField(controller: _pricePerUnitController, hint: "0.0", icon: LucideIcons.tag, prefix: "KES ", isNumber: true),
                                  ])),
                                  const SizedBox(width: 10),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    _buildLabel("Est. KG per Unit"),
                                    _buildPremiumField(controller: _kgPerUnitController, hint: "0.5", icon: LucideIcons.scale, suffix: "KG", isNumber: true),
                                  ])),
                                ],
                              ),
                              const SizedBox(height: 15),
                              
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    if (_selectedUnit == null || _pricePerUnitController.text.isEmpty || _kgPerUnitController.text.isEmpty) {
                                      _showPremiumToast("Please fill all unit fields", isError: true);
                                      return;
                                    }
                                    setState(() {
                                      _addedUnits.add({
                                        "unit_name": _selectedUnit,
                                        "price": double.parse(_pricePerUnitController.text),
                                        "kg": double.parse(_kgPerUnitController.text),
                                      });
                                      _pricePerUnitController.clear();
                                      _kgPerUnitController.clear();
                                    });
                                  },
                                  icon: const Icon(LucideIcons.plusCircle, size: 16),
                                  label: Text("Add Pricing Tier", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange.shade700, 
                                    side: BorderSide(color: Colors.orange.shade300),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Text("Please select a crop above to see custom unit options.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange.shade800)),
                        )
                      ]
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // SUBMIT BUTTON
              SizedBox(
                height: 60,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitHarvest,
                  icon: _isLoading ? const SizedBox.shrink() : const Icon(LucideIcons.uploadCloud, color: Colors.white),
                  label: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text("Publish to Marketplace", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
    );
  }

  Widget _buildPremiumField({required TextEditingController controller, required String hint, required IconData icon, String? suffix, String? prefix, bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
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
          return null;
        },
      ),
    );
  }
}