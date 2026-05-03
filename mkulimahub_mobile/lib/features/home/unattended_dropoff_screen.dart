import 'dart:convert';
import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';

class UnattendedDropoffScreen extends StatefulWidget {
  final int squadId;
  final String cropName;

  const UnattendedDropoffScreen({
    super.key,
    required this.squadId,
    required this.cropName,
  });

  @override
  State<UnattendedDropoffScreen> createState() => _UnattendedDropoffScreenState();
}

class _UnattendedDropoffScreenState extends State<UnattendedDropoffScreen> {
  final ApiClient _apiClient = ApiClient();
  final ImagePicker _picker = ImagePicker();

  File? _scalePhoto;
  File? _cropPhoto;
  bool _isSubmitting = false;

 Future<void> _pickImage(bool isScale, ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 50, // 🔥 Compress the quality
      maxWidth: 800,    // 🔥 Force a small resolution to prevent payload crashes!
      maxHeight: 800,   // 🔥 Force a small resolution to prevent payload crashes!
    );

    if (pickedFile != null && mounted) {
      setState(() {
        if (isScale) {
          _scalePhoto = File(pickedFile.path);
        } else {
          _cropPhoto = File(pickedFile.path);
        }
      });
    }
  }

  Future<void> _submitEvidence() async {
    if (_scalePhoto == null || _cropPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide both required photos."), backgroundColor: Colors.red)
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Convert images to Base64 for the backend
    final scaleBytes = await _scalePhoto!.readAsBytes();
    final cropBytes = await _cropPhoto!.readAsBytes();
    
    final scaleBase64 = "data:image/jpeg;base64,${base64Encode(scaleBytes)}";
    final cropBase64 = "data:image/jpeg;base64,${base64Encode(cropBytes)}";

    final error = await _apiClient.submitUnattendedDropoff(widget.squadId, scaleBase64, cropBase64);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (error == null) {
        // Success! Pop back to the previous screen.
        Navigator.pop(context, true); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Evidence submitted safely! Awaiting Hub Audit."), backgroundColor: Colors.green)
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red)
        );
      }
    }
  }

  Widget _buildPhotoCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required File? currentPhoto,
    required bool isScale,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: currentPhoto != null ? Colors.green.shade200 : Colors.grey.shade200, width: currentPhoto != null ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: currentPhoto != null ? Colors.green.shade50 : Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(currentPhoto != null ? LucideIcons.checkCircle : icon, color: currentPhoto != null ? Colors.green.shade700 : Colors.blue.shade700),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Image Preview or Empty State
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: currentPhoto == null ? Border.all(color: Colors.grey.shade300, style: BorderStyle.solid) : null,
              image: currentPhoto != null 
                  ? DecorationImage(image: FileImage(currentPhoto), fit: BoxFit.cover)
                  : null,
            ),
            child: currentPhoto == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.camera, size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text("No photo added yet", style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  )
                : null, // Image handles itself via DecorationImage
          ),
          const SizedBox(height: 15),

          // Camera Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(isScale, ImageSource.camera),
                  icon: const Icon(LucideIcons.camera, size: 16),
                  label: Text(currentPhoto != null ? "Retake" : "Take Photo", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(LucideIcons.image),
                  color: Colors.grey.shade600,
                  tooltip: "Upload from Gallery",
                  onPressed: () => _pickImage(isScale, ImageSource.gallery),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canSubmit = _scalePhoto != null && _cropPhoto != null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.green.shade800,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("Digital Drop-off", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 10),
            decoration: BoxDecoration(
              color: Colors.green.shade800,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.orange.shade500, borderRadius: BorderRadius.circular(8)),
                  child: Text("SQUAD BR-${widget.squadId.toString().padLeft(4, '0')}", style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                Text("Hub Admin Unavailable?", style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text("Securely log your ${widget.cropName} delivery by uploading photographic evidence.", style: GoogleFonts.poppins(color: Colors.green.shade100, fontSize: 12)),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  FadeInLeft(
                    child: _buildPhotoCard(
                      title: "1. The Weighing Scale",
                      subtitle: "Show the final weight reading clearly.",
                      icon: LucideIcons.scale,
                      currentPhoto: _scalePhoto,
                      isScale: true,
                    ),
                  ),
                  FadeInRight(
                    delay: const Duration(milliseconds: 100),
                    child: _buildPhotoCard(
                      title: "2. The Secure Storage",
                      subtitle: "Show the bags safely stacked inside the Hub.",
                      icon: LucideIcons.warehouse,
                      currentPhoto: _cropPhoto,
                      isScale: false,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: ElevatedButton.icon(
          onPressed: canSubmit && !_isSubmitting ? _submitEvidence : null,
          icon: const Icon(LucideIcons.shieldCheck, color: Colors.white),
          label: Text("Submit Evidence & Drop-off", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            disabledBackgroundColor: Colors.grey.shade300,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}