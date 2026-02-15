import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final ApiClient _apiClient = ApiClient();
  
  // State variables
  String _selectedCrop = 'Mangoes';
  List<dynamic> _forecastData = [];
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _crops = ['Mangoes', 'Maize', 'Beans']; // Match your AI model capabilities

  @override
  void initState() {
    super.initState();
    _fetchPrediction(); // Load default prediction on start
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
      appBar: AppBar(title: const Text("AI Price Forecast")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Selector
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Text("Predict Price for:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: _selectedCrop,
                      items: _crops.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCrop = val);
                          _fetchPrediction();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. The Chart
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                      : _buildChart(),
            ),
            
            // 3. Insight Text
            if (_forecastData.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Trend Analysis: Prices are expected to go ${_forecastData.last['trend']} next week.",
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (_forecastData.isEmpty) return const Center(child: Text("No Data"));

    // Convert API data to Chart points
    List<FlSpot> spots = [];
    for (int i = 0; i < _forecastData.length; i++) {
      double price = (_forecastData[i]['predicted_price'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), price));    
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, reservedSize: 22)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: const Color(0xff37434d))),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.green,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.2)),
          ),
        ],
      ),
    );
  }
}