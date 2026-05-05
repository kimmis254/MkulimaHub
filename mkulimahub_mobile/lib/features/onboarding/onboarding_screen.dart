import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/features/auth/welcome_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      "title": "Smart Farming, Simplified",
      "description": "Access AI-driven insights, predict market prices, and track your harvests with precision.",
      "image": "https://images.unsplash.com/photo-1595841696677-6489ff3f8cd1?w=800", // Farmer in field
    },
    {
      "title": "Direct Market Access",
      "description": "Cut out the middlemen. Sell your premium produce directly to verified corporate buyers and supermarkets.",
      "image": "https://images.unsplash.com/photo-1615486171439-06bd6b0c2266?w=800", // Produce boxes
    },
    {
      "title": "The Power of Hub Pools",
      "description": "Join delivery squads with other farmers to fulfill massive bulk contracts and unlock higher revenues.",
      "image": "https://images.unsplash.com/photo-1586771107445-d3af2209d846?w=800", // Corporate/Logistics
    }
  ];

  void _nextPage() {
    if (_currentPage < _onboardingData.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    } else {
      // 🔥 Move to Welcome Screen when done!
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()));
    }
  }

  void _skipOnboarding() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 🔥 1. THE IMAGE SLIDER
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _onboardingData.length,
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _onboardingData[index]["image"]!,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                  // Dark gradient overlay so the image blends into the white card below
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.6),
                          Colors.white,
                        ],
                        stops: const [0.0, 0.5, 0.9],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // 🔥 2. THE TOP SKIP BUTTON
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: TextButton(
                  onPressed: _skipOnboarding,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text("Skip", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),

          // 🔥 3. THE BOTTOM INTERACTIVE CARD
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.45,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      FadeInUp(
                        key: ValueKey(_currentPage), // Forces animation to replay on swipe
                        duration: const Duration(milliseconds: 500),
                        child: Text(
                          _onboardingData[_currentPage]["title"]!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 15),
                      FadeInUp(
                        key: ValueKey("desc_$_currentPage"),
                        delay: const Duration(milliseconds: 100),
                        duration: const Duration(milliseconds: 500),
                        child: Text(
                          _onboardingData[_currentPage]["description"]!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600, height: 1.6),
                        ),
                      ),
                    ],
                  ),
                  
                  // DOT INDICATORS & NEXT BUTTON
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: List.generate(
                          _onboardingData.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 8),
                            height: 8,
                            width: _currentPage == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index ? Colors.green.shade700 : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _nextPage,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 60,
                          width: _currentPage == _onboardingData.length - 1 ? 160 : 60,
                          decoration: BoxDecoration(
                            color: Colors.green.shade700,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
                            ]
                          ),
                          child: Center(
                            child: _currentPage == _onboardingData.length - 1
                                ? Text("Get Started", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
                                : const Icon(LucideIcons.arrowRight, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}