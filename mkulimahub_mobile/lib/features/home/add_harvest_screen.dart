import 'package:flutter/material.dart';
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

  // Pre-defined crops to keep data clean
  final List<String> _crops = ['Maize', 'Beans', 'Mangoes', 'Green Grams', 'Avocado'];
  String? _selectedCrop;

  void _submitHarvest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCrop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a crop")),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 1. Prepare Data
    final harvestData = {
      "crop_name": _selectedCrop,
      "weight_kg": double.parse(_weightController.text),
      "price_per_kg": double.parse(_priceController.text),
    };

    // 2. Send to Backend
    final error = await _apiClient.addHarvest(harvestData);

    setState(() => _isLoading = false);

    if (error == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Harvest Posted Successfully!"), backgroundColor: Colors.green),
        );
        // Go back to Home and tell it to refresh
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
      appBar: AppBar(title: const Text("Add New Harvest")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "What are you selling today?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // 1. Crop Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCrop,
                decoration: const InputDecoration(
                  labelText: "Select Crop",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.grass),
                ),
                items: _crops.map((crop) {
                  return DropdownMenuItem(value: crop, child: Text(crop));
                }).toList(),
                onChanged: (val) => setState(() => _selectedCrop = val),
              ),
              const SizedBox(height: 15),

              // 2. Weight Input
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: "Weight (kg)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.scale),
                  suffixText: "kg",
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return "Required";
                  if (double.tryParse(v) == null) return "Must be a number";
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // 3. Price Input
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: "Price per kg",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                  prefixText: "KES ",
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return "Required";
                  if (double.tryParse(v) == null) return "Must be a number";
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // 4. Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _submitHarvest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Post Harvest", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}