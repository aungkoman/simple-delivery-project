import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RiderDailyRoutePage extends StatelessWidget {
  final String riderName;
  final String dateKey;
  final String displayDate;
  final List<dynamic> routePoints;

  const RiderDailyRoutePage({
    super.key,
    required this.riderName,
    required this.dateKey,
    required this.displayDate,
    required this.routePoints,
  });

  @override
  Widget build(BuildContext context) {
    if (routePoints.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Route Not Found')),
        body: const Center(child: Text('No points available for this date.')),
      );
    }

    // Convert raw JSON data to LatLng points for the Polyline
    final List<LatLng> latLngPoints = routePoints.map((p) {
      return LatLng(p['latitude'], p['longitude']);
    }).toList();

    // Determine the map bounds to fit the whole route nicely
    final bounds = LatLngBounds.fromPoints(latLngPoints);

    final startPoint = latLngPoints.first;
    final endPoint = latLngPoints.last;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$riderName\'s Route', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(displayDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        options: MapOptions(
          // Calculate center based on bounds, or default to start point
          initialCenter: bounds.center,
          initialZoom: 14.0,
          initialCameraFit: CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(50.0), // Give some breathing room around the route
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.simpledelivery.app', // Replace with your package name
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: latLngPoints,
                strokeWidth: 4.0,
                color: Colors.indigo.shade600,
                // isDotted: false,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              // Start Marker (Green)
              Marker(
                point: startPoint,
                width: 40,
                height: 40,
                child: const Icon(Icons.play_circle_fill, color: Colors.green, size: 30),
              ),
              // End Marker (Red)
              Marker(
                point: endPoint,
                width: 40,
                height: 40,
                child: const Icon(Icons.stop_circle, color: Colors.red, size: 30),
              ),
            ],
          ),
        ],
      ),
    );
  }
}