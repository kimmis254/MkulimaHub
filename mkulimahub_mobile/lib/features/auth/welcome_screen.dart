import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/features/auth/login_screen.dart';
import 'package:mkulimahub_mobile/features/auth/register_screen.dart';
import 'package:mkulimahub_mobile/features/buyer/buyer_registration_screen.dart';


class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // 🔥 LOGO & HEADER
              FadeInDown(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                    child: Icon(LucideIcons.sprout, size: 40, color: Colors.green.shade700),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FadeInDown(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  "Welcome to MkulimaHub",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 10),
              FadeInDown(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  "How would you like to use the platform today?",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                ),
              ),
              
              const Spacer(),

              // 🔥 OPTION 1: THE FARMER
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: _buildRoleCard(
                  context: context,
                  title: "I am a Farmer / Co-op",
                  subtitle: "List harvests, join hubs, and pledge to bulk contracts.",
                  icon: LucideIcons.leaf,
                  primaryColor: Colors.green.shade700,
                  backgroundColor: Colors.green.shade50,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                ),
              ),
              
              const SizedBox(height: 20),

              // 🔥 OPTION 2: THE CORPORATE BUYER
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: _buildRoleCard(
                  context: context,
                  title: "I am a Customer / Buyer",
                  subtitle: "Source crops, post bulk requests, and track logistics.",
                  icon: LucideIcons.shoppingBag, // 
                  primaryColor: Colors.blue.shade800,
                  backgroundColor: Colors.blue.shade50,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BuyerRegistrationScreen())),
                ),
              ),

              const Spacer(),

              // 🔥 UNIVERSAL LOGIN
              FadeInUp(
                delay: const Duration(milliseconds: 500),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Already have an account? ", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14)),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: Text(
                        "Sign In", 
                        style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14, decoration: TextDecoration.underline)
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primaryColor,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(color: primaryColor.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
          ]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: primaryColor, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(LucideIcons.chevronRight, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}