import 'dart:async';
import 'dart:math';
import 'package:animate_do/animate_do.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});
  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final ApiClient _apiClient = ApiClient();
  
  String? _selectedCrop;
  String? _selectedRegion;
  String _selectedPriceType = 'Wholesale'; // 🔥 New Toggle State
  
  List<String> _availableCrops = [];
  List<String> _availableRegions = [];
  Map<String, dynamic> _forecastData = {};
  
  bool _isMetadataLoading = true;
  bool _isLoading = false;
  String? _errorMessage;

  // 🔥 Stepped Loading Animation Variables
  int _loadingStep = 0;
  Timer? _loadingTimer;
  final List<String> _loadingTexts = [
    "Checking recent market prices...",
    "Looking at weather patterns...",
    "Calculating the best time to sell..."
  ];

  @override
  void initState() {
    super.initState();
    _fetchMarketMetadata();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  void _fetchMarketMetadata() async {
    try {
      final metadata = await _apiClient.getMarketMetadata();
      setState(() {
        _availableRegions = List<String>.from(metadata['regions']);
        _availableCrops = List<String>.from(metadata['crops']);
        if (_availableRegions.isNotEmpty) _selectedRegion = _availableRegions.first;
        if (_availableCrops.isNotEmpty) _selectedCrop = _availableCrops.first;
        _isMetadataLoading = false;
      });
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

  void _startLoadingAnimation() {
    setState(() {
      _isLoading = true;
      _loadingStep = 0;
    });
    _loadingTimer?.cancel();
    _loadingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      setState(() {
        if (_loadingStep < _loadingTexts.length - 1) {
          _loadingStep++;
        }
      });
    });
  }

  void _fetchPrediction() async {
    if (_selectedCrop == null || _selectedRegion == null) return;
    _startLoadingAnimation();
    setState(() => _errorMessage = null);

    try {
      final data = await _apiClient.getPrediction(_selectedCrop!, _selectedRegion!, _selectedPriceType);
      setState(() {
        _forecastData = data;
        _isLoading = false;
        _loadingTimer?.cancel();
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll("Exception: ", "");
        _isLoading = false;
        _loadingTimer?.cancel();
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
        title: Text("Market Advice", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- DROPDOWNS & TOGGLES ---
            if (_isMetadataLoading)
               Center(child: CircularProgressIndicator(color: Colors.green[600]))
            else
              FadeInDown(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildDropdown(value: _selectedRegion, items: _availableRegions, icon: LucideIcons.mapPin, onChanged: (val) {
                          if (val != null) { setState(() => _selectedRegion = val); _fetchPrediction(); }
                        })),
                        const SizedBox(width: 10),
                        Expanded(child: _buildDropdown(value: _selectedCrop, items: _availableCrops, icon: LucideIcons.leaf, onChanged: (val) {
                          if (val != null) { setState(() => _selectedCrop = val); _fetchPrediction(); }
                        })),
                      ],
                    ),
                    const SizedBox(height: 15),
                    
                    // 🔥 RETAIL VS WHOLESALE TOGGLE
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                      child: Row(
                        children: [
                          _buildToggleButton('Wholesale', LucideIcons.truck),
                          _buildToggleButton('Retail', LucideIcons.shoppingBag),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            
            const SizedBox(height: 25),

            // --- GRAPH AREA ---
            FadeInUp(
              child: Container(
                height: 350, 
                padding: const EdgeInsets.all(20), 
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: _isLoading ? _buildLoadingState() : _errorMessage != null ? _buildErrorState() : _buildGraph(),
              ),
            ),
            
            // --- FARMER FRIENDLY ADVICE ---
            if (_forecastData.isNotEmpty && !_isLoading && _errorMessage == null)
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _forecastData['trend'] == 'rising' ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: _forecastData['trend'] == 'rising' ? Colors.green[200]! : Colors.orange[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.lightbulb, color: _forecastData['trend'] == 'rising' ? Colors.green[800] : Colors.orange[800]),
                          const SizedBox(width: 10),
                          Text("Market Advice for ${_selectedCrop![0].toUpperCase()}${_selectedCrop!.substring(1)}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _getFarmerAdvice(),
                        style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 100), 
          ],
        ),
      ),
    );
  }

  // Jargon-Free Advice Generator
  String _getFarmerAdvice() {
    bool isRising = _forecastData['trend'] == 'rising';
    String fallback = _forecastData['fallback_type'] ?? "none";
    
    String crop = _selectedCrop != null ? _selectedCrop![0].toUpperCase() + _selectedCrop!.substring(1) : 'harvest';
    String advice = "";
    
    // 🔥 NEW: Tell the farmer why the graph is a flat line
    if (fallback == "flatline") {
      return "⚠️ Market data for $crop in this region is currently too sparse for our AI to accurately predict future trends.\n\nPrices are projected to remain stable based on the last known records. We recommend checking local market activity directly before selling.";
    }

    if (isRising) {
      advice += "Prices are looking good! We expect the price per KG to slowly go up next month because of seasonal market changes. \n\nWhat you should do: If you have safe, dry storage, consider holding onto your $crop for a few more weeks to get a better profit.";
    } else {
      advice += "The market is slowing down. We expect the price per KG to drop slightly over the next month as the market gets crowded. \n\nWhat you should do: If you have already harvested your $crop, it might be best to sell now to lock in the current price.";
    }
    return advice;
  }

  Widget _buildToggleButton(String type, IconData icon) {
    bool isSelected = _selectedPriceType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            setState(() => _selectedPriceType = type);
            _fetchPrediction();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green[50] : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.green[700] : Colors.grey[500]),
              const SizedBox(width: 8),
              Text(type, style: GoogleFonts.poppins(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.green[800] : Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({required String? value, required List<String> items, required IconData icon, required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(LucideIcons.chevronDown, color: Colors.green[700], size: 18),
          isExpanded: true,
          items: items.map((item) => DropdownMenuItem(value: item, child: Row(
            children: [
              Icon(icon, size: 16, color: Colors.green[600]),
              const SizedBox(width: 8),
              Flexible(child: Text(item[0].toUpperCase() + item.substring(1), style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis)),
            ],
          ))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
  Widget _buildLegendItem(Color color, String text, bool isDashed, {bool isDot = false}) {
    return Row(
      children: [
        if (isDot)
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle))
        else if (isDashed)
          Row(
            children: List.generate(3, (index) => Container(
              width: 5, height: 3, color: color, margin: const EdgeInsets.only(right: 2)
            )),
          )
        else
          Container(width: 15, height: 3, color: color),
        const SizedBox(width: 6),
        Text(text, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700], fontWeight: isDot ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }


  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Pulse(infinite: true, child: Icon(LucideIcons.truck, size: 50, color: Colors.green[600])),
          const SizedBox(height: 25),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Text(
              _loadingTexts[_loadingStep],
              key: ValueKey<int>(_loadingStep),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.green[800], fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.alertCircle, size: 40, color: Colors.orange[400]),
          const SizedBox(height: 10),
          Text(_errorMessage!, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildGraph() {
    if (_forecastData.isEmpty) return const SizedBox.shrink();

    List<double> past = List<double>.from(_forecastData['past_prices']);
    List<double> future = List<double>.from(_forecastData['future_prices']);
    bool isRising = _forecastData['trend'] == 'rising';
    Color futureColor = isRising ? Colors.green[600]! : Colors.red[500]!;

    List<FlSpot> pastSpots = [];
    for (int i = 0; i < past.length; i++) {
      pastSpots.add(FlSpot(i.toDouble(), past[i]));    
    }

    List<FlSpot> futureSpots = [];
    // Start future line exactly where past line ended
    futureSpots.add(FlSpot((past.length - 1).toDouble(), past.last));
    for (int i = 0; i < future.length; i++) {
      futureSpots.add(FlSpot((past.length + i).toDouble(), future[i]));    
    }

    double allMin = [...past, ...future].reduce(min);
    double allMax = [...past, ...future].reduce(max);
    double buffer = (allMax - allMin) * 0.4; // Increased from 0.15 to 0.4
    
    // Ensure it never goes negative, but gives plenty of headroom
    double bottomY = max(0.0, allMin - buffer); 
    double topY = allMax + buffer;
    
    // Create clean, evenly spaced grid lines (e.g., every 50 or 100 KES)
    double yInterval = ((topY - bottomY) / 5).ceilToDouble();
    if (yInterval <= 0) yInterval = 10; 

    int todayIndex = past.length - 1;
    int finalIndex = past.length + future.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(Colors.grey[400]!, "Past", false),
            const SizedBox(width: 15),
            _buildLegendItem(Colors.blue[600]!, "Today", false, isDot: true),
            const SizedBox(width: 15),
            _buildLegendItem(futureColor, "Expected", true),
          ],
        ),
        const SizedBox(height: 15),
        
        // 🔥 NEW: Explicit Price Unit Label
        Padding(
          padding: const EdgeInsets.only(left: 10.0),
          child: Text(
            "Price (KES per 1 KG)",
            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[500]),
          ),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: LineChart(
            LineChartData(
              minY: bottomY,
              maxY: topY,
              minX: 0,
              maxX: finalIndex.toDouble(),
              
              // 🔥 NEW: Subtle Dashed Grid Lines to anchor the numbers
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yInterval,
                getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200], strokeWidth: 1, dashArray: [4, 4]),
              ),
              
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 20), // Nudge to prevent cutoff
                          child: Text("2 Weeks Ago", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
                        );
                      } else if (value.toInt() == todayIndex) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text("Today", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[700])),
                        );
                      } else if (value.toInt() == finalIndex) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0, right: 30), // Nudge to prevent cutoff
                          child: Text("Next Month", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  )
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, 
                    reservedSize: 35, // Tighter spacing since we removed "KES " from the numbers
                    interval: yInterval,
                    getTitlesWidget: (value, meta) {
                      if (value == bottomY || value == topY) return const SizedBox.shrink();
                      // Because the label above says "KES per 1 KG", we only need clean numbers here
                      return Text(value.toInt().toString(), style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]));
                    },
                  )
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: pastSpots,
                  isCurved: true,
                  curveSmoothness: 0.15,
                  preventCurveOverShooting: true, // 🔥 FIX: Stops the line from dipping below the data points
                  color: Colors.grey[400],
                  barWidth: 3,
                  dotData: FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: futureSpots,
                  isCurved: true,
                  curveSmoothness: 0.15,
                  preventCurveOverShooting: true, // 🔥 FIX: Stops the prediction from diving off the screen
                  color: futureColor,
                  barWidth: 4,
                  dashArray: [8, 5], 
                  dotData: FlDotData(
                    show: true, 
                    checkToShowDot: (spot, barData) => spot.x == todayIndex.toDouble(), 
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(radius: 6, color: Colors.blue[600]!, strokeWidth: 2, strokeColor: Colors.white);
                    }
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}