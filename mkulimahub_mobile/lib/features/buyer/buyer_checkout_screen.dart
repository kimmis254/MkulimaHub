import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/buyer/buyer_cart_screen.dart';

class BuyerCheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;

  const BuyerCheckoutScreen({super.key, required this.cartItems});

  @override
  State<BuyerCheckoutScreen> createState() => _BuyerCheckoutScreenState();
}

class _BuyerCheckoutScreenState extends State<BuyerCheckoutScreen> {
  final ApiClient _apiClient = ApiClient();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  
  // Logistics & Calculations
  String _deliveryMethod = "doorstep"; // 'doorstep' or 'pickup'
  double _discountAmount = 0.0;
  final TextEditingController _voucherController = TextEditingController();

  // Address Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  // 🔥 Smart Location Data State
  List<dynamic> _locationsData = []; 
  List<String> _counties = [];
  List<String> _subCounties = [];
  List<String> _wards = [];

  String? _selectedCounty;
  String? _selectedSubCounty;
  String? _selectedWard;

  // Payment Options
  String _paymentMode = "pay_now"; // 'pay_now' or 'pay_on_delivery'
  String _payNowMethod = "mpesa"; // 'mpesa' or 'card'
  String _podMethod = "mobile_money"; // 'mobile_money', 'bank_transfer', 'cash'

  double get _subtotal => widget.cartItems.fold(0, (sum, item) => sum + (item['weightKg'] * item['pricePerKg']));
  double get _serviceFee => _subtotal * 0.02; // 2% Service Fee
  double get _deliveryFee => _deliveryMethod == "doorstep" ? 1500.0 : 0.0; // Flat 1500 KES for delivery
  double get _total => (_subtotal + _serviceFee + _deliveryFee) - _discountAmount;

  @override
  void initState() {
    super.initState();
    _loadLocationData();
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
      debugPrint("Error loading locations JSON: $e");
    }
  }

  void _applyVoucher() {
    FocusScope.of(context).unfocus();
    if (_voucherController.text.toUpperCase() == "MKULIMA10") {
      setState(() => _discountAmount = _subtotal * 0.10); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("10% Discount Applied!"), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Voucher Code"), backgroundColor: Colors.red));
    }
  }

  void _confirmCheckout() async {
    if (_deliveryMethod == "doorstep" && !_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please complete the delivery address form."), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    // 🔥 THE FIX: Sync the newly typed Address to the Profile so the Farmer sees it!
    if (_deliveryMethod == "doorstep") {
      await _apiClient.updateProfile({
        "county": _selectedCounty,
        "sub_county": _selectedSubCounty,
        "ward": _selectedWard,
        "village": _addressController.text.trim(),
      });
    }

    String methodString = _deliveryMethod == "doorstep" ? "Delivery" : "Pickup";

    bool success = true;
    for (var item in widget.cartItems) {
      if (item['type'] == 'individual') {
        // 🔥 THE FIX: Pass the Pickup vs Delivery string to Python!
        final error = await _apiClient.createMarketOrder(item['id'], item['format'], item['qty'], methodString);
        if (error != null) success = false;
      } else {
        await Future.delayed(const Duration(milliseconds: 500)); 
      }
    }

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        CartManager.items.clear(); 
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Icon(LucideIcons.checkCircle, color: Colors.teal, size: 60),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Order Successful!", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 10),
                Text(
                  "Your total of KES ${_total.toStringAsFixed(0)} has been processed. The farmers have been notified and are preparing your produce.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); 
                    Navigator.pop(context); 
                    Navigator.pop(context); 
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text("Back to Dashboard", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          )
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("An error occurred during checkout."), backgroundColor: Colors.red));
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
          title: Text("Secure Checkout", style: GoogleFonts.poppins(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text("Modify Cart", style: GoogleFonts.poppins(color: Colors.teal.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
            )
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔥 1. ORDER SUMMARY
                    _buildSectionHeader("Order Summary", LucideIcons.receipt),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(
                        children: widget.cartItems.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("${item['weightKg']}kg ${item['crop']}", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                                Text("KES ${(item['weightKg'] * item['pricePerKg']).toStringAsFixed(0)}", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // 🔥 2. VOUCHER & DISCOUNTS
                    _buildSectionHeader("Apply Voucher", LucideIcons.tag),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _voucherController,
                            style: GoogleFonts.poppins(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: "Enter Promo Code",
                              filled: true, fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _applyVoucher,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: Text("Apply", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                        )
                      ],
                    ),
                    const SizedBox(height: 30),

                    // 🔥 3. DELIVERY METHOD
                    _buildSectionHeader("Delivery Method", LucideIcons.truck),
                    Row(
                      children: [
                        _buildMethodOption("doorstep", "Doorstep Delivery", "KES 1,500", Icons.local_shipping, _deliveryMethod, (val) => setState(() => _deliveryMethod = val)),
                        const SizedBox(width: 15),
                        _buildMethodOption("pickup", "Pickup from Hub", "Free", LucideIcons.store, _deliveryMethod, (val) => setState(() => _deliveryMethod = val)),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // 🔥 4. SMART ADDRESS FORM (Only shows if Doorstep)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      child: _deliveryMethod == "doorstep" ? Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader("Delivery Address", LucideIcons.mapPin),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                              child: Column(
                                children: [
                                  _buildAddressField(_nameController, "Full Name"),
                                  _buildAddressField(_phoneController, "Phone Number", isPhone: true),
                                  
                                  _buildDropdownField("County / Region", _selectedCounty, _counties, (val) {
                                    setState(() {
                                      _selectedCounty = val;
                                      _selectedSubCounty = null;
                                      _selectedWard = null;
                                      _wards = [];
                                      
                                      var countyObj = _locationsData.firstWhere((c) => c['county_name'] == val);
                                      var constituencies = countyObj['constituencies'] as List<dynamic>;
                                      _subCounties = constituencies.map((c) => c['constituency_name'].toString()).toList();
                                    });
                                  }),
                                  
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDropdownField("City / Sub-County", _selectedSubCounty, _subCounties, (val) {
                                          setState(() {
                                            _selectedSubCounty = val;
                                            _selectedWard = null;
                                            
                                            var countyObj = _locationsData.firstWhere((c) => c['county_name'] == _selectedCounty);
                                            var constituencies = countyObj['constituencies'] as List<dynamic>;
                                            var constituencyObj = constituencies.firstWhere((c) => c['constituency_name'] == val);
                                            _wards = List<String>.from(constituencyObj['wards']);
                                          });
                                        })
                                      ),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: _buildDropdownField("Ward", _selectedWard, _wards, (val) {
                                          setState(() => _selectedWard = val);
                                        })
                                      ),
                                    ],
                                  ),

                                  _buildAddressField(_addressController, "Exact Address (Estate, House No, Apt No)"),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ) : const SizedBox.shrink(),
                    ),

                    // 🔥 5. PAYMENT METHODS
                    _buildSectionHeader("Payment Method", LucideIcons.creditCard),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(
                        children: [
                          RadioListTile(
                            title: Text("Pay Now (Secure Escrow)", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                            value: "pay_now", groupValue: _paymentMode,
                            activeColor: Colors.teal.shade700,
                            onChanged: (val) => setState(() => _paymentMode = val.toString()),
                          ),
                          if (_paymentMode == "pay_now")
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: DropdownButtonFormField<String>(
                                value: _payNowMethod,
                                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50, contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
                                items: [
                                  DropdownMenuItem(value: "mpesa", child: Text("M-Pesa Express", style: GoogleFonts.poppins(fontSize: 13))),
                                  DropdownMenuItem(value: "card", child: Text("Bank Card (Visa/Mastercard)", style: GoogleFonts.poppins(fontSize: 13))),
                                ],
                                onChanged: (val) => setState(() => _payNowMethod = val!),
                              ),
                            ),
                            
                          const Divider(height: 0),
                          RadioListTile(
                            title: Text("Pay on Delivery", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                            value: "pay_on_delivery", groupValue: _paymentMode,
                            activeColor: Colors.teal.shade700,
                            onChanged: (val) => setState(() => _paymentMode = val.toString()),
                          ),
                          if (_paymentMode == "pay_on_delivery")
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: DropdownButtonFormField<String>(
                                value: _podMethod,
                                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50, contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
                                items: [
                                  DropdownMenuItem(value: "mobile_money", child: Text("Mobile Money on Arrival", style: GoogleFonts.poppins(fontSize: 13))),
                                  DropdownMenuItem(value: "bank_transfer", child: Text("Bank Transfer on Arrival", style: GoogleFonts.poppins(fontSize: 13))),
                                  DropdownMenuItem(value: "cash", child: Text("Cash on Delivery", style: GoogleFonts.poppins(fontSize: 13))),
                                ],
                                onChanged: (val) => setState(() => _podMethod = val!),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),

            // 🔥 6. STICKY FOOTER (CALCULATIONS & CONFIRM)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildReceiptRow("Subtotal", _subtotal),
                    const SizedBox(height: 8),
                    _buildReceiptRow("Service Fee (2%)", _serviceFee),
                    const SizedBox(height: 8),
                    _buildReceiptRow("Delivery Fee", _deliveryFee),
                    if (_discountAmount > 0) ...[
                      const SizedBox(height: 8),
                      _buildReceiptRow("Voucher Discount", -_discountAmount, isDiscount: true),
                    ],
                    const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider(height: 1)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Total to Pay", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        Text(
                          "KES ${_total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}", 
                          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal.shade900)
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _confirmCheckout,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                        child: _isLoading 
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text("Confirm & Checkout", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.teal.shade700),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildMethodOption(String id, String title, String cost, IconData icon, String groupValue, Function(String) onChanged) {
    bool isSelected = groupValue == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.teal.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? Colors.teal.shade500 : Colors.grey.shade300, width: isSelected ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.teal.shade700 : Colors.grey.shade400, size: 28),
              const SizedBox(height: 8),
              Text(title, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center, maxLines: 1),
              Text(cost, style: GoogleFonts.poppins(fontSize: 11, color: isSelected ? Colors.teal.shade700 : Colors.grey.shade500, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressField(TextEditingController controller, String label, {bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 13),
          filled: true, fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        ),
        validator: (value) => value!.isEmpty ? "Required" : null,
      ),
    );
  }

  Widget _buildDropdownField(String label, String? val, List<String> items, Function(String?) changed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: val,
        isExpanded: true,
        style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 13),
          filled: true, fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        ),
        icon: Icon(LucideIcons.chevronDown, color: Colors.teal.shade700, size: 20),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: items.isEmpty ? null : changed,
        validator: (value) => value == null || value.isEmpty ? "Required" : null,
      ),
    );
  }

  Widget _buildReceiptRow(String label, double amount, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
        Text(
          "${isDiscount ? '' : 'KES '}${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}", 
          style: GoogleFonts.poppins(color: isDiscount ? Colors.green.shade700 : Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)
        ),
      ],
    );
  }
}