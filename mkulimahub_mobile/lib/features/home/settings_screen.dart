import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🔥 Required for Firebase deletion
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/auth/auth_service.dart';
import 'package:mkulimahub_mobile/features/auth/welcome_screen.dart'; 

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();
  
  bool _isLoggingOut = false;
  bool _isDeleting = false;

  // ==========================================
  // LOGOUT LOGIC
  // ==========================================
  void _handleLogout() async {
    setState(() => _isLoggingOut = true);
    
    // Clear the secure tokens and Google sessions
    await _apiClient.logout(); 
    await _authService.signOut();

    if (mounted) {
      // Route all the way back to the front door
      Navigator.pushAndRemoveUntil(
        context, 
        MaterialPageRoute(builder: (_) => const WelcomeScreen()), 
        (route) => false
      );
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
              child: Icon(LucideIcons.logOut, color: Colors.orange.shade600),
            ),
            const SizedBox(width: 12),
            Text("Log Out", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text("Are you sure you want to securely log out of MkulimaHub?", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text("Log Out", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  // ==========================================
  // DELETION LOGIC
  // ==========================================
  Future<void> _handleDeleteAccount() async {
    // 1. Confirm Deletion
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(LucideIcons.alertTriangle, color: Colors.red.shade600),
            ),
            const SizedBox(width: 12),
            Text("Delete Account", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text("Are you sure you want to permanently delete your MkulimaHub account? This action cannot be undone.", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontWeight: FontWeight.w600))
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text("Delete", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    // 2. Delete from FastAPI Database first
    final dbError = await _apiClient.deleteAccount();

    if (dbError == null) {
      // 3. Delete from Firebase 
      try {
        await FirebaseAuth.instance.currentUser?.delete();
      } catch (e) {
        print("Firebase deletion error (user might need to re-login to delete): $e");
      }
      
      // 4. Send them to the Welcome Screen
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()), (route) => false);
      }
    } else {
      setState(() => _isDeleting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dbError, style: GoogleFonts.poppins()), 
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Settings", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoggingOut || _isDeleting
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  _isDeleting ? "Deleting account..." : "Logging out securely...", 
                  style: GoogleFonts.poppins(color: Colors.grey.shade600)
                ),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(24.0),
            physics: const BouncingScrollPhysics(),
            children: [
              FadeInUp(delay: const Duration(milliseconds: 100), child: _buildSectionHeader("Account Preferences")),
              FadeInUp(delay: const Duration(milliseconds: 150), child: _buildSettingsTile(LucideIcons.user, "Personal Information", "Edit your profile details", Colors.blue)),
              FadeInUp(delay: const Duration(milliseconds: 200), child: _buildSettingsTile(LucideIcons.shieldCheck, "Security & Privacy", "Password, 2FA, and sessions", Colors.indigo)),
              FadeInUp(delay: const Duration(milliseconds: 250), child: _buildSettingsTile(LucideIcons.bellRing, "Notifications", "Manage SMS and Push alerts", Colors.orange)),
              
              const SizedBox(height: 30),
              
              FadeInUp(delay: const Duration(milliseconds: 300), child: _buildSectionHeader("Support & About")),
              FadeInUp(delay: const Duration(milliseconds: 350), child: _buildSettingsTile(LucideIcons.helpCircle, "Help Center", "FAQs and contact support", Colors.teal)),
              FadeInUp(delay: const Duration(milliseconds: 400), child: _buildSettingsTile(LucideIcons.fileText, "Terms & Policies", "Legal and privacy agreements", Colors.grey.shade700)),
              
              const SizedBox(height: 40),
              
              // 🔥 DANGER ZONE 
              FadeInUp(delay: const Duration(milliseconds: 500), child: _buildSectionHeader("Danger Zone")),
              
              // Logout Button
              FadeInUp(
                delay: const Duration(milliseconds: 550),
                child: GestureDetector(
                  onTap: _confirmLogout,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.shade100),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.logOut, color: Colors.orange.shade600, size: 20),
                        const SizedBox(width: 10),
                        Text("Log Out", style: GoogleFonts.poppins(color: Colors.orange.shade700, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ),

              // Delete Account Button
              FadeInUp(
                delay: const Duration(milliseconds: 600),
                child: GestureDetector(
                  onTap: _handleDeleteAccount,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.trash2, color: Colors.red.shade600, size: 20),
                        const SizedBox(width: 10),
                        Text("Delete Account", style: GoogleFonts.poppins(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // App Version text
              Center(
                child: Text("MkulimaHub v1.0.0", style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 12)),
              ),
            ],
          ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
        subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
        trailing: Icon(LucideIcons.chevronRight, color: Colors.grey.shade400, size: 20),
        onTap: () {
          // Placeholder for sub-settings pages
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$title coming soon!", style: GoogleFonts.poppins())));
        },
      ),
    );
  }
}