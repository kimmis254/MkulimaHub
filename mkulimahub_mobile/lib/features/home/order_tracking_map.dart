import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

class OrderTrackingMap extends StatefulWidget {
  final String entityName; // e.g., "Contract #BR-0004" or "Direct Order"
  final String status;

  const OrderTrackingMap({
    super.key,
    required this.entityName,
    required this.status,
  });

  @override
  State<OrderTrackingMap> createState() => _OrderTrackingMapState();
}

class _OrderTrackingMapState extends State<OrderTrackingMap> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();

  // Default coordinate focused on Nairobi
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(-1.286389, 36.817223),
    zoom: 12.0,
  );

  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _setInitialMarkers();
  }

  void _setInitialMarkers() {
    setState(() {
      _markers.add(
        const Marker(
          markerId: MarkerId('delivery_truck'),
          position: LatLng(-1.286389, 36.817223),
          infoWindow: InfoWindow(
            title: 'Current Location',
            snippet: 'Produce in transit',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal.shade800,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Live Tracking", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(widget.entityName, style: GoogleFonts.poppins(color: Colors.teal.shade200, fontSize: 12)),
          ],
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
          ),

          // Status Overlay Card
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
                  ]
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
                    child: Icon(LucideIcons.truck, color: Colors.teal.shade700),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Transit Status", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                        Text(widget.status.toUpperCase(), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        child: Icon(LucideIcons.navigation, color: Colors.teal.shade800),
        onPressed: () async {
          final GoogleMapController controller = await _controller.future;
          controller.animateCamera(CameraUpdate.newCameraPosition(_initialPosition));
        },
      ),
    );
  }
}