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

  List<String> _allCropsBaseline = []; 
  Map<String, List<String>> _countyCropMap = {};
  
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
        _allCropsBaseline = List<String>.from(metadata['crops']);
        
        // 🔥 1. Save the mapping dictionary from the backend
        if (metadata['county_crop_map'] != null) {
          Map<String, dynamic> rawMap = metadata['county_crop_map'];
          _countyCropMap = rawMap.map((key, value) => MapEntry(key, List<String>.from(value)));
        }

        if (_availableRegions.isNotEmpty) {
          _selectedRegion = _availableRegions.first;
          // 🔥 2. Filter the crop list for the first region immediately!
          _updateAvailableCropsForRegion(_selectedRegion!);
        }
        
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

  // 🔥 ADD THIS HELPER FUNCTION right below _fetchMarketMetadata:
  void _updateAvailableCropsForRegion(String region) {
    String safeRegionKey = region.toLowerCase().replaceAll(' ', '_');
    
    if (_countyCropMap.containsKey(safeRegionKey)) {
      _availableCrops = _countyCropMap[safeRegionKey]!;
    } else {
      // Fallback to Nairobi or the national baseline if county is missing
      _availableCrops = _countyCropMap['nairobi'] ?? _allCropsBaseline;
    }

    // Safety check: If the previously selected crop isn't grown in this new county, reset it!
    if (_availableCrops.isNotEmpty && !_availableCrops.contains(_selectedCrop)) {
      _selectedCrop = _availableCrops.first;
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
      Expanded(
        child: _buildDropdown(
          value: _selectedRegion, 
          items: _availableRegions, 
          icon: LucideIcons.mapPin, 
          onChanged: (val) {
            if (val != null) { 
              setState(() {
                _selectedRegion = val;
                // 🔥 3. Trigger the Smart Filter when the user changes counties!
                _updateAvailableCropsForRegion(val);
              }); 
              _fetchPrediction(); 
            }
          }
        )
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _buildDropdown(
          value: _selectedCrop, 
          items: _availableCrops, // This list is now dynamically shrinking!
          icon: LucideIcons.leaf, 
          onChanged: (val) {
            if (val != null) { 
              setState(() => _selectedCrop = val); 
              _fetchPrediction(); 
            }
          }
        )
      ),
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
                      // 🔥 THIS IS THE ROW THAT IS CRASHING!
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start, // Align to top in case text wraps
                        children: [
                          Icon(LucideIcons.lightbulb, color: _forecastData['trend'] == 'rising' ? Colors.green[800] : Colors.orange[800]),
                          const SizedBox(width: 10),
                          
                          // 🔥 THE FIX: Wrap the Title Text in an Expanded widget
                          Expanded(
                            child: Text(
                              "Market Advice for ${_selectedCrop![0].toUpperCase()}${_selectedCrop!.substring(1)}", 
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _getFarmerAdvice(), // <-- This is where your string gets called!
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

  String _getUnitMeasurement(String? crop, String priceType) {
    if (crop == null) return "1 KG";
    String c = crop.toLowerCase();
    
    // Retail is often sold individually
    if (priceType.toLowerCase() == 'retail') {
      if (c.contains('banana') || c.contains('mango') || c.contains('avocado') || c.contains('pineapple')) {
        return "Piece";
      }
      if (c.contains('cabbage')) return "Head";
      if (c.contains('egg')) return "Tray";
      if (c.contains('sukuma') || c.contains('spinach')) return "Bunch";
    }
    
    // Default fallback
    return "1 KG";
  }

  // Jargon-Free Advice Generator
  String _getFarmerAdvice() {
    String trend = _forecastData['trend'] ?? 'stable';
    String fallback = _forecastData['fallback_type'] ?? "none";
    
    String crop = _selectedCrop != null ? _selectedCrop![0].toUpperCase() + _selectedCrop!.substring(1) : 'harvest';
    
    double currentPrice = (_forecastData['current_price'] as num).toDouble();
    List<double> futurePrices = (_forecastData['future_prices'] as List).map((e) => (e as num).toDouble()).toList();
    double expectedPrice = futurePrices.last;
    
    String currentStr = "KES ${currentPrice.toInt()}";
    String expectedStr = "KES ${expectedPrice.toInt()}";

    String advice = "";
    
    if (fallback == "flatline") {
      return "⚠️ Market data for $crop is currently too sparse to predict a curve. Prices are currently around $currentStr and are projected to remain stable based on the last known records.";
    } else if (fallback == "national") {
      advice += "⚠️ Local data was unavailable. Showing the Nationwide average.\n\n";
    } else if (fallback.contains("alt_type")) {
      String foundType = fallback.split('_').last; 
      // 🔥 Tell the user they are looking at Retail instead of Wholesale!
      advice += "⚠️ $_selectedPriceType data was unavailable locally. Showing ${foundType[0].toUpperCase()}${foundType.substring(1)} prices instead.\n\n";
    } else if (fallback.contains("national_alt")) {
      String foundType = fallback.split('_').last;
      advice += "⚠️ Local data was unavailable. Showing Nationwide ${foundType[0].toUpperCase()}${foundType.substring(1)} prices instead.\n\n";
    }

    String unit = _getUnitMeasurement(_selectedCrop, _selectedPriceType);

    if (trend == 'rising') {
      advice += "Prices are looking good! The current price is $currentStr, and we expect it to rise to about $expectedStr per $unit by next month.\n\nWhat you should do: If you have safe, dry storage, consider holding onto your $crop for a few more weeks to lock in that higher profit.";
    } else if (trend == 'falling') {
      advice += "The market is slowing down. The current price is $currentStr, but we expect it to drop to about $expectedStr per $unit by next month.\n\nWhat you should do: If your $crop is harvested and ready, it might be best to sell it now before the price drops further.";
    } else {
      advice += "The market is relatively stable. The current price is $currentStr, and we expect it to hover around $expectedStr per $unit next month.\n\nWhat you should do: You can sell your $crop at your convenience, as prices are not expected to fluctuate significantly in the near future.";
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
    // 🔥 1. Safely handle completely empty or null states without crashing
    if (_forecastData == null || _forecastData.isEmpty) {
      return const SizedBox.shrink();
    }

    // 🔥 2. The Bulletproof Extractor: 
    // Checks both your old key ('past_prices') and our new API key ('historical_prices')
    final rawPast = _forecastData['historical_prices'] ?? _forecastData['past_prices'];
    final rawFuture = _forecastData['future_prices'];

    // If the API failed to send the lists, exit gracefully instead of red-screening
    if (rawPast == null || rawFuture == null || (rawPast as List).isEmpty || (rawFuture as List).isEmpty) {
      return const SizedBox.shrink();
    }

    // Safely cast to doubles
    List<double> past = rawPast.map((e) => (e as num).toDouble()).toList();
    List<double> future = rawFuture.map((e) => (e as num).toDouble()).toList();

    // 🔥 3. Smart Trend Calculator
    // If the backend sends a trend, use it. If not, calculate it on the fly!
    bool isRising = false;
    if (_forecastData['trend'] != null) {
      isRising = _forecastData['trend'] == 'rising';
    } else {
      isRising = future.last >= past.last;
    }
    
    Color futureColor = isRising ? Colors.green[600]! : Colors.red[500]!;

    List<FlSpot> pastSpots = [];
    for (int i = 0; i < past.length; i++) {
      pastSpots.add(FlSpot(i.toDouble(), past[i]));    
    }

    List<FlSpot> futureSpots = [];
    // Start future line exactly where past line ended for a seamless connection
    futureSpots.add(FlSpot((past.length - 1).toDouble(), past.last));
    for (int i = 0; i < future.length; i++) {
      futureSpots.add(FlSpot((past.length + i).toDouble(), future[i]));    
    }

    double allMin = [...past, ...future].reduce(min);
    double allMax = [...past, ...future].reduce(max);
    double buffer = (allMax - allMin) * 0.4; 
    
    // 🔥 THE MATH FIX: If the price is a flatline, artificially create a buffer!
    if (buffer == 0) {
      buffer = allMax * 0.2; 
    }
    if (buffer == 0) {
      buffer = 10; // Failsafe if the price is literally 0
    }
    
    double bottomY = max(0.0, allMin - buffer); 
    double topY = allMax + buffer;
    
    // Create clean, evenly spaced grid lines
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
        
        Padding(
          padding: const EdgeInsets.only(left: 10.0),
          child: Text(
            "Price (KES per ${_getUnitMeasurement(_selectedCrop, _selectedPriceType)})",
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
              clipData: const FlClipData.all(),
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
                        // 🔥 THE FIX: Hide "Start" if the history is too short!
                        if (todayIndex < 4) return const SizedBox.shrink(); 
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 20),
                          child: Text("Start", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
                        );
                      } else if (value.toInt() == todayIndex) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text("Today", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[700])),
                        );
                      } else if (value.toInt() == finalIndex) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0, right: 30),
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
                    reservedSize: 35, 
                    interval: yInterval,
                    getTitlesWidget: (value, meta) {
                      if (value == bottomY || value == topY) return const SizedBox.shrink();
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
                  isCurved: false, // 🔥 FIX: Set this to false!
                  color: Colors.grey[400],
                  barWidth: 3,
                  dotData: FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: futureSpots,
                  isCurved: false, // 🔥 FIX: Set this to false!
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