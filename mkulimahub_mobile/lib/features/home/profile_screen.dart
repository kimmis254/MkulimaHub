import 'package:flutter/material.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiClient _apiClient = ApiClient();
  final _bioController = TextEditingController();
  final _cropsController = TextEditingController();
  final _sizeController = TextEditingController();
  
  String _farmingMethod = "Conventional"; // Default
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() async {
    final data = await _apiClient.getProfile();
    if (data != null) {
      setState(() {
        _bioController.text = data['bio'] ?? "";
        _cropsController.text = data['main_crops'] ?? "";
        _sizeController.text = (data['farm_size_acres'] ?? "").toString();
        _farmingMethod = data['farming_method'] ?? "Conventional";
      });
    }
  }

  void _saveProfile() async {
    setState(() => _isLoading = true);

    final data = {
      "bio": _bioController.text,
      "main_crops": _cropsController.text,
      "farm_size_acres": double.tryParse(_sizeController.text) ?? 0.0,
      "farming_method": _farmingMethod
    };

    final error = await _apiClient.updateProfile(data);
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error == null ? "Profile Saved!" : "Error saving"),
          backgroundColor: error == null ? Colors.green : Colors.red,
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Farmer Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Placeholder for Profile Pic (We can add real upload later)
            const Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.green,
                child: Icon(Icons.person, size: 50, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),

            // Bio
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: "About Me & My Farm",
                border: OutlineInputBorder(),
                hintText: "e.g., I grow organic maize in Makueni..."
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 15),

            // Main Crops
            TextField(
              controller: _cropsController,
              decoration: const InputDecoration(
                labelText: "Main Crops Grown",
                border: OutlineInputBorder(),
                hintText: "e.g., Maize, Beans, Mangoes"
              ),
            ),
            const SizedBox(height: 15),

            // Farm Size
            TextField(
              controller: _sizeController,
              decoration: const InputDecoration(
                labelText: "Farm Size (Acres)",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 15),

            // Farming Method Dropdown
            DropdownButtonFormField<String>(
              value: _farmingMethod,
              decoration: const InputDecoration(labelText: "Farming Method", border: OutlineInputBorder()),
              items: ["Organic", "Conventional", "Mixed"].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (val) => setState(() => _farmingMethod = val!),
            ),
            const SizedBox(height: 30),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text("Save Profile", style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}