import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

// 🔥 THE FIX: Removed all State, Timers, and Navigation!
// This is now purely a visual screen controlled by main.dart.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade900, const Color(0xFF0A192F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Pulse(
              infinite: true,
              duration: const Duration(seconds: 2),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.green.shade400.withOpacity(0.3), blurRadius: 40, spreadRadius: 10),
                  ],
                ),
                child: const Icon(LucideIcons.sprout, size: 80, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            FadeInUp(
              child: Text(
                "MkulimaHub",
                style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Text(
                "Empowering the Agricultural Supply Chain",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.green.shade100,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}