import 'dart:async';
import 'dart:math';
import 'package:animate_do/animate_do.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api/api_client.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});
  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final ApiClient _apiClient = ApiClient();
  
  String? _selectedCrop;
  String? _selectedRegion;
  String _selectedPriceType = 'Wholesale'; 
  
  List<String> _availableCrops = [];
  List<String> _availableRegions = [];
  Map<String, dynamic> _forecastData = {};

  List<String> _allCropsBaseline = []; 
  Map<String, List<String>> _countyCropMap = {};
  
  bool _isMetadataLoading = true;
  bool _isLoading = false;
  String? _errorMessage;

  int _loadingStep = 0;
  Timer? _loadingTimer;
  final List<String> _loadingTexts = [
    "Analyzing market history...",
    "Correlating weather patterns...",
    "Generating AI forecast..."
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
        
        if (metadata['county_crop_map'] != null) {
          Map<String, dynamic> rawMap = metadata['county_crop_map'];
          _countyCropMap = rawMap.map((key, value) => MapEntry(key, List<String>.from(value)));
        }

        if (_availableRegions.isNotEmpty) {
          _selectedRegion = _availableRegions.first;
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

  void _updateAvailableCropsForRegion(String region) {
    String safeRegionKey = region.toLowerCase().replaceAll(' ', '_');
    
    if (_countyCropMap.containsKey(safeRegionKey)) {
      _availableCrops = _countyCropMap[safeRegionKey]!;
    } else {
      _availableCrops = _countyCropMap['nairobi'] ?? _allCropsBaseline;
    }

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
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          // 🔥 1. THE PREMIUM BACKGROUND HEADER
          Container(
            height: 260,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green.shade900, Colors.green.shade700]
              ),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                          child: const Icon(LucideIcons.trendingUp, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Market Intelligence", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                            Text("AI-Powered Price Forecasts", style: GoogleFonts.poppins(color: Colors.green.shade200, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🔥 2. THE SCROLLING CONTENT
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 100, left: 24, right: 24, bottom: 120), // Added bottom padding for the nav bar!
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  
                  // --- FLOATING CONTROL PANEL ---
                  if (_isMetadataLoading)
                    Container(
                      height: 150,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]),
                      child: Center(child: CircularProgressIndicator(color: Colors.green.shade600)),
                    )
                  else
                    FadeInUp(
                      duration: const Duration(milliseconds: 400),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))],
                          border: Border.all(color: Colors.grey.shade100)
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPremiumDropdown(
                                    value: _selectedRegion, 
                                    items: _availableRegions, 
                                    icon: LucideIcons.mapPin, 
                                    label: "County",
                                    onChanged: (val) {
                                      if (val != null) { 
                                        setState(() {
                                          _selectedRegion = val;
                                          _updateAvailableCropsForRegion(val);
                                        }); 
                                        _fetchPrediction(); 
                                      }
                                    }
                                  )
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: _buildPremiumDropdown(
                                    value: _selectedCrop, 
                                    items: _availableCrops,
                                    icon: LucideIcons.leaf, 
                                    label: "Crop",
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
                            const SizedBox(height: 20),
                            
                            // RETAIL VS WHOLESALE TOGGLE
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                              child: Row(
                                children: [
                                  _buildPremiumToggleButton('Wholesale', LucideIcons.truck),
                                  _buildPremiumToggleButton('Retail', LucideIcons.shoppingBag),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 30),

                  // --- GRAPH AREA ---
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: Container(
                      height: 400, // Slightly taller for a premium feel
                      padding: const EdgeInsets.all(24), 
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
                        border: Border.all(color: Colors.grey.shade100)
                      ),
                      child: _isLoading ? _buildLoadingState() : _errorMessage != null ? _buildErrorState() : _buildGraph(),
                    ),
                  ),
                  
                  // --- AI INSIGHT CARD ---
                  if (_forecastData.isNotEmpty && !_isLoading && _errorMessage == null)
                    FadeInUp(
                      delay: const Duration(milliseconds: 400),
                      child: Container(
                        margin: const EdgeInsets.only(top: 25),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: _getInsightColors(_forecastData['trend'])
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: _getInsightShadowColor(_forecastData['trend']).withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                                  child: Icon(LucideIcons.sparkles, color: _getInsightShadowColor(_forecastData['trend']), size: 20),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("AI Market Insight", style: GoogleFonts.poppins(color: _getTextColor(_forecastData['trend']).withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold)),
                                      Text(
                                        "${_selectedCrop![0].toUpperCase()}${_selectedCrop!.substring(1)} Analysis", 
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: _getTextColor(_forecastData['trend']))
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(16)),
                              child: Text(
                                _getFarmerAdvice(),
                                style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14, height: 1.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STYLING HELPERS FOR THE AI INSIGHT CARD ---
  List<Color> _getInsightColors(String? trend) {
    if (trend == 'rising') return [Colors.green.shade100, Colors.green.shade50];
    if (trend == 'falling') return [Colors.orange.shade100, Colors.orange.shade50];
    return [Colors.blue.shade100, Colors.blue.shade50];
  }
  Color _getInsightShadowColor(String? trend) {
    if (trend == 'rising') return Colors.green.shade700;
    if (trend == 'falling') return Colors.orange.shade700;
    return Colors.blue.shade700;
  }
  Color _getTextColor(String? trend) {
    if (trend == 'rising') return Colors.green.shade900;
    if (trend == 'falling') return Colors.orange.shade900;
    return Colors.blue.shade900;
  }

  String _getUnitMeasurement(String? crop, String priceType) {
    if (crop == null) return "1 KG";
    String c = crop.toLowerCase();
    if (priceType.toLowerCase() == 'retail') {
      if (c.contains('banana') || c.contains('mango') || c.contains('avocado') || c.contains('pineapple')) return "Piece";
      if (c.contains('cabbage')) return "Head";
      if (c.contains('egg')) return "Tray";
      if (c.contains('sukuma') || c.contains('spinach')) return "Bunch";
    }
    return "1 KG";
  }

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
      advice += "⚠️ $_selectedPriceType data was unavailable locally. Showing ${foundType[0].toUpperCase()}${foundType.substring(1)} prices instead.\n\n";
    } else if (fallback.contains("national_alt")) {
      String foundType = fallback.split('_').last;
      advice += "⚠️ Local data was unavailable. Showing Nationwide ${foundType[0].toUpperCase()}${foundType.substring(1)} prices instead.\n\n";
    }

    String unit = _getUnitMeasurement(_selectedCrop, _selectedPriceType);

    if (trend == 'rising') {
      advice += "Prices are looking highly favorable. The current price is $currentStr, and is projected to rise to $expectedStr per $unit.\n\nStrategy: If you have secure, dry storage, consider holding your $crop to lock in higher margins.";
    } else if (trend == 'falling') {
      advice += "The market is cooling down. The current price is $currentStr, but models indicate a drop to $expectedStr per $unit.\n\nStrategy: If your $crop is harvested, it is advisable to liquidate inventory now before prices drop further.";
    } else {
      advice += "The market is exhibiting stability. The current price is $currentStr, and is expected to hover around $expectedStr per $unit.\n\nStrategy: You can sell your $crop at your convenience, as prices are not expected to fluctuate heavily.";
    }
    return advice;
  }

  Widget _buildPremiumToggleButton(String type, IconData icon) {
    bool isSelected = _selectedPriceType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            setState(() => _selectedPriceType = type);
            _fetchPrediction();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))] : []
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.green.shade700 : Colors.grey.shade500),
              const SizedBox(width: 8),
              Text(type, style: GoogleFonts.poppins(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 13, color: isSelected ? Colors.green.shade800 : Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumDropdown({required String? value, required List<String> items, required IconData icon, required String label, required Function(String?) onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              icon: Icon(LucideIcons.chevronDown, color: Colors.green.shade700, size: 18),
              isExpanded: true,
              items: items.map((item) => DropdownMenuItem(value: item, child: Row(
                children: [
                  Icon(icon, size: 16, color: Colors.green.shade600),
                  const SizedBox(width: 10),
                  Flexible(child: Text(item[0].toUpperCase() + item.substring(1), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87), overflow: TextOverflow.ellipsis)),
                ],
              ))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text, bool isDashed, {bool isDot = false}) {
    return Row(
      children: [
        if (isDot)
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle))
        else if (isDashed)
          Row(
            children: List.generate(3, (index) => Container(width: 6, height: 3, color: color, margin: const EdgeInsets.only(right: 3))),
          )
        else
          Container(
  width: 18, 
  height: 3, 
  decoration: BoxDecoration(
    color: color, 
    borderRadius: BorderRadius.circular(2)
  )
),
        const SizedBox(width: 8),
        Text(text, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700, fontWeight: isDot ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Pulse(
            infinite: true,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
              child: Icon(LucideIcons.brainCircuit, size: 40, color: Colors.green.shade600)
            )
          ),
          const SizedBox(height: 25),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Text(
              _loadingTexts[_loadingStep],
              key: ValueKey<int>(_loadingStep),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 14),
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
          Icon(LucideIcons.alertCircle, size: 50, color: Colors.orange.shade400),
          const SizedBox(height: 15),
          Text(_errorMessage!, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildGraph() {
    if (_forecastData == null || _forecastData.isEmpty) return const SizedBox.shrink();

    final rawPast = _forecastData['historical_prices'] ?? _forecastData['past_prices'];
    final rawFuture = _forecastData['future_prices'];

    if (rawPast == null || rawFuture == null || (rawPast as List).isEmpty || (rawFuture as List).isEmpty) return const SizedBox.shrink();

    List<double> past = rawPast.map((e) => (e as num).toDouble()).toList();
    List<double> future = rawFuture.map((e) => (e as num).toDouble()).toList();

    bool isRising = false;
    if (_forecastData['trend'] != null) {
      isRising = _forecastData['trend'] == 'rising';
    } else {
      isRising = future.last >= past.last;
    }
    
    Color futureColor = isRising ? Colors.green.shade600 : Colors.orange.shade600;

    List<FlSpot> pastSpots = [];
    for (int i = 0; i < past.length; i++) pastSpots.add(FlSpot(i.toDouble(), past[i]));    

    List<FlSpot> futureSpots = [];
    futureSpots.add(FlSpot((past.length - 1).toDouble(), past.last));
    for (int i = 0; i < future.length; i++) futureSpots.add(FlSpot((past.length + i).toDouble(), future[i]));    

    double allMin = [...past, ...future].reduce(min);
    double allMax = [...past, ...future].reduce(max);
    double buffer = (allMax - allMin) * 0.4; 
    
    if (buffer == 0) buffer = allMax * 0.2; 
    if (buffer == 0) buffer = 10; 
    
    double bottomY = max(0.0, allMin - buffer); 
    double topY = allMax + buffer;
    
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
            _buildLegendItem(Colors.grey.shade400, "Historical", false),
            const SizedBox(width: 15),
            _buildLegendItem(Colors.blue.shade600, "Today", false, isDot: true),
            const SizedBox(width: 15),
            _buildLegendItem(futureColor, "AI Forecast", true),
          ],
        ),
        const SizedBox(height: 25),
        
        Text(
          "Projected Value (KES per ${_getUnitMeasurement(_selectedCrop, _selectedPriceType)})",
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
        ),
        const SizedBox(height: 15),

        Expanded(
          child: LineChart(
            LineChartData(
              minY: bottomY, maxY: topY, minX: 0, maxX: finalIndex.toDouble(),
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true, drawVerticalLine: false, horizontalInterval: yInterval,
                getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade100, strokeWidth: 1.5, dashArray: [5, 5]),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, reservedSize: 30, interval: 1,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() == 0) {
                        if (todayIndex < 4) return const SizedBox.shrink(); 
                        return Padding(padding: const EdgeInsets.only(top: 10.0, left: 20), child: Text("Start", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)));
                      } else if (value.toInt() == todayIndex) {
                        return Padding(padding: const EdgeInsets.only(top: 10.0), child: Text("Today", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700)));
                      } else if (value.toInt() == finalIndex) {
                        return Padding(padding: const EdgeInsets.only(top: 10.0, right: 30), child: Text("Next Month", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)));
                      }
                      return const SizedBox.shrink();
                    },
                  )
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, reservedSize: 40, interval: yInterval,
                    getTitlesWidget: (value, meta) {
                      if (value == bottomY || value == topY) return const SizedBox.shrink();
                      return Text(value.toInt().toString(), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade400));
                    },
                  )
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: pastSpots, isCurved: false, color: Colors.grey.shade400, barWidth: 3, dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: futureSpots, isCurved: false, color: futureColor, barWidth: 4, dashArray: [8, 5], 
                  
                  // 🔥 THE FINTECH GRADIENT EFFECT
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [futureColor.withOpacity(0.2), futureColor.withOpacity(0.0)],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter
                    ),
                  ),
                  
                  dotData: FlDotData(
                    show: true, checkToShowDot: (spot, barData) => spot.x == todayIndex.toDouble(), 
                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 6, color: Colors.blue.shade600, strokeWidth: 3, strokeColor: Colors.white)
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