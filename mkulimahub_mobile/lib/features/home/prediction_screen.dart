import 'package:animate_do/animate_do.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'dart:math'; 

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final ApiClient _apiClient = ApiClient();
  
  String _selectedCrop = 'Mangoes';
  List<dynamic> _forecastData = [];
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _crops = ['Mangoes', 'Maize', 'Beans'];

  @override
  void initState() {
    super.initState();
    _fetchPrediction();
  }

  void _fetchPrediction() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _apiClient.getPrediction(_selectedCrop);
      setState(() {
        _forecastData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Market Forecast",
          style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            FadeInDown(
              duration: const Duration(milliseconds: 600),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[800]!, Colors.green[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
                  ]
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(LucideIcons.bot, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("AI Price Advisor", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("Predicting trends for the next 7 days.", style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 12)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // Crop Selector
            FadeInDown(
              delay: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCrop,
                    icon: const Icon(LucideIcons.chevronDown, color: Colors.green),
                    isExpanded: true,
                    items: _crops.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCrop = val);
                        _fetchPrediction();
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),

            // THE CHART CONTAINER
            FadeInUp(
              delay: const Duration(milliseconds: 300),
              child: Container(
                height: 400, 
                padding: const EdgeInsets.only(right: 25, left: 10, top: 30, bottom: 10), // Added more right/top padding for numbers
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
                  ],
                ),
                child: _isLoading
                    ? _buildAILoadingState() // <--- NEW AI LOADING UI
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(LucideIcons.wifiOff, size: 40, color: Colors.red),
                                const SizedBox(height: 10),
                                Text(_errorMessage!, style: GoogleFonts.poppins(color: Colors.red)),
                              ],
                            ),
                          )
                        : _buildChart(),
              ),
            ),
            
            // Insight Card
            if (_forecastData.isNotEmpty && !_isLoading)
              FadeInUp(
                delay: const Duration(milliseconds: 500),
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _forecastData.last['trend'] == 'rising' ? LucideIcons.trendingUp : LucideIcons.trendingDown, 
                        color: Colors.blue[800]
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.poppins(color: Colors.blue[900], fontSize: 14),
                            children: [
                              const TextSpan(text: "AI Forecast: "), // Changed text
                              TextSpan(
                                text: "Prices expected to ${_forecastData.last['trend']} ",
                                style: const TextStyle(fontWeight: FontWeight.bold)
                              ),
                              const TextSpan(text: "based on Prophet Time-Series analysis."), // Highlighted AI model
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 120), 
          ],
        ),
      ),
    );
  }

  // --- NEW: Custom AI Loading State ---
  Widget _buildAILoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.green),
          const SizedBox(height: 25),
          Pulse( // Using animate_do to make the text throb like it's "thinking"
            infinite: true,
            child: Text(
              "Prophet AI is analyzing\nhistorical market patterns...",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.green[700], 
                fontWeight: FontWeight.w500,
                fontSize: 13
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (_forecastData.isEmpty) return Center(child: Text("No Data", style: GoogleFonts.poppins()));

    List<FlSpot> spots = [];
    for (int i = 0; i < _forecastData.length; i++) {
      double price = (_forecastData[i]['predicted_price'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), price));    
    }

    // --- NEW: Advanced Mathematical Scaling ---
    double minPrice = spots.map((e) => e.y).reduce(min);
    double maxPrice = spots.map((e) => e.y).reduce(max);
    
    // Prevent completely flat lines from breaking the graph
    if (minPrice == maxPrice) {
      minPrice -= 5;
      maxPrice += 5;
    }

    // Give 40% breathing room to center the line perfectly
    double buffer = (maxPrice - minPrice) * 0.4; 
    double bottomY = (minPrice - buffer).floorToDouble();
    double topY = (maxPrice + buffer).ceilToDouble();
    
    // Ensure the grid lines are perfectly spaced numbers (e.g., 5, 10, 15)
    double yInterval = ((topY - bottomY) / 5).ceilToDouble();
    if (yInterval == 0) yInterval = 1;

    return LineChart(
      LineChartData(
        minY: bottomY,
        maxY: topY,
        
        // --- NEW: Interactive AI Tooltips ---
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (LineBarSpot touchedSpot) => Colors.green[800]!.withOpacity(0.9),
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  'AI Prediction\n',
                  GoogleFonts.poppins(color: Colors.white70, fontSize: 10),
                  children: [
                    TextSpan(
                      text: 'KES ${spot.y.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval, // Fixed Interval
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200], strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, 
              interval: 1, 
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text("Day ${value.toInt() + 1}", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                );
              },
              reservedSize: 30
            )
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, 
              reservedSize: 40,
              interval: yInterval, // Fixed Interval
              getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            )
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true, 
            color: Colors.green[600],
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true, // Show dots so users know where to tap
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: Colors.green[600]!);
              }
            ),
            belowBarData: BarAreaData(
              show: true, 
              gradient: LinearGradient(
                colors: [Colors.green.withOpacity(0.3), Colors.green.withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            ),
          ),
        ],
      ),
    );
  }
}