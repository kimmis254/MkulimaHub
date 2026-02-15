class Harvest {
  final int id;
  final String cropName;
  final double weightKg;
  final double pricePerKg;
  final int farmerId;

  Harvest({
    required this.id,
    required this.cropName,
    required this.weightKg,
    required this.pricePerKg,
    required this.farmerId,
  });

  // Factory: Converts JSON (from API) into a Harvest Object
  factory Harvest.fromJson(Map<String, dynamic> json) {
    return Harvest(
      id: json['id'],
      cropName: json['crop_name'], // Must match Python schema exactly!
      weightKg: (json['weight_kg'] as num).toDouble(),
      pricePerKg: (json['price_per_kg'] as num).toDouble(),
      farmerId: json['farmer_id'],
    );
  }
}