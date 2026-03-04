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
  
  // Phase 2: Dynamic State Variables
  String? _selectedCrop;
  String? _selectedRegion;
  
  List<String> _availableCrops = [];
  List<String> _availableRegions = [];
  
  List<dynamic> _forecastData = [];
  
  bool _isMetadataLoading = true; // New loading state for the dropdowns
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // In Phase 2, we first fetch what the backend supports before predicting
    _fetchMarketMetadata();
  }

  // 🔥 NEW: Fetch available crops and regions from the Python backend
  void _fetchMarketMetadata() async {
    setState(() {
      _isMetadataLoading = true;
      _errorMessage = null;
    });

    try {
      final metadata = await _apiClient.getMarketMetadata();
      setState(() {
        // Convert the dynamic lists from JSON to String lists
        _availableRegions = List<String>.from(metadata['regions']);
        _availableCrops = List<String>.from(metadata['crops']);
        
        // Set defaults to the first available items so the UI doesn't crash
        if (_availableRegions.isNotEmpty) _selectedRegion = _availableRegions.first;
        if (_availableCrops.isNotEmpty) _selectedCrop = _availableCrops.first;
        
        _isMetadataLoading = false;
      });

      // Once we know the region and crop, trigger the first prediction!
      if (_selectedRegion != null && _selectedCrop != null) {
        _fetchPrediction();
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to connect to MkulimaHub servers.";
        _isMetadataLoading = false;
      });
    }
  }

  // 🔥 UPGRADED: Now sends both Crop AND Region to the backend
  void _fetchPrediction() async {
    if (_selectedCrop == null || _selectedRegion == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _apiClient.getPrediction(_selectedCrop!, _selectedRegion!);
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
        automaticallyImplyLeading: false,
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
            // --- HEADER BANNER ---
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
                          Text("Predicting trends for the next 30 days.", style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 12)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // --- DYNAMIC DROPDOWNS ---
            if (_isMetadataLoading)
               Center(child: Padding(
                 padding: const EdgeInsets.all(20.0),
                 child: CircularProgressIndicator(color: Colors.green[600]),
               ))
            else if (_errorMessage != null && _availableCrops.isEmpty)
               Center(child: Text(_errorMessage!, style: TextStyle(color: Colors.red)))
            else
              FadeInDown(
                delay: const Duration(milliseconds: 200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // REGION DROPDOWN
                    Text(" Market Region", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: _selectedRegion,
                      items: _availableRegions,
                      icon: LucideIcons.mapPin,
                      onChanged: (val) {
                        if (val != null && val != _selectedRegion) {
                          setState(() => _selectedRegion = val);
                          _fetchPrediction();
                        }
                      }
                    ),
                    const SizedBox(height: 16),
                    
                    // CROP DROPDOWN
                    Text(" Commodity", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: _selectedCrop,
                      items: _availableCrops,
                      icon: LucideIcons.leaf,
                      onChanged: (val) {
                        if (val != null && val != _selectedCrop) {
                          setState(() => _selectedCrop = val);
                          _fetchPrediction();
                        }
                      }
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 25),

            // --- AI CHART AREA ---
            FadeInUp(
              delay: const Duration(milliseconds: 300),
              child: Container(
                height: 400, 
                padding: const EdgeInsets.only(right: 25, left: 10, top: 30, bottom: 10), 
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
                  ],
                ),
                child: _isLoading
                    ? _buildAILoadingState() 
                    : _errorMessage != null && _availableCrops.isNotEmpty
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
            
            // --- TREND INDICATOR ---
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
                              const TextSpan(text: "AI Forecast: "), 
                              TextSpan(
                                text: "Prices expected to ${_forecastData.last['trend']} ",
                                style: const TextStyle(fontWeight: FontWeight.bold)
                              ),
                              const TextSpan(text: "based on Prophet Time-Series analysis."), 
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

  // Helper widget to keep the dropdown UI clean
  Widget _buildDropdown({required String? value, required List<String> items, required IconData icon, required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(LucideIcons.chevronDown, color: Colors.green[700], size: 20),
          isExpanded: true,
          items: items.map((item) {
            // Capitalize the first letter for the UI
            String displayTitle = item[0].toUpperCase() + item.substring(1);
            return DropdownMenuItem(
              value: item, 
              child: Row(
                children: [
                  Icon(icon, size: 18, color: Colors.green[600]),
                  const SizedBox(width: 10),
                  Text(displayTitle, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                ],
              )
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildAILoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.green),
          const SizedBox(height: 25),
          Pulse( 
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
    if (_forecastData.isEmpty) return Center(child: Text("No Data available for this combination.", style: GoogleFonts.poppins()));

    List<FlSpot> spots = [];
    for (int i = 0; i < _forecastData.length; i++) {
      double price = (_forecastData[i]['predicted_price'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), price));    
    }

    double minPrice = spots.map((e) => e.y).reduce(min);
    double maxPrice = spots.map((e) => e.y).reduce(max);
    
    if (minPrice == maxPrice) {
      minPrice -= 5;
      maxPrice += 5;
    }

    double buffer = (maxPrice - minPrice) * 0.4; 
    double bottomY = (minPrice - buffer).floorToDouble();
    double topY = (maxPrice + buffer).ceilToDouble();
    
    double yInterval = ((topY - bottomY) / 5).ceilToDouble();
    if (yInterval == 0) yInterval = 1;

    return LineChart(
      LineChartData(
        minY: bottomY,
        maxY: topY,
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
          horizontalInterval: yInterval, 
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200], strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, 
              interval: 5, // Spaced out for 30 days
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
              interval: yInterval, 
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
              show: true, 
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