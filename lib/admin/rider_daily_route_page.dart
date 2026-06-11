import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

class RiderDailyRoutePage extends StatefulWidget {
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
  State<RiderDailyRoutePage> createState() => _RiderDailyRoutePageState();
}

class _RiderDailyRoutePageState extends State<RiderDailyRoutePage> {
  final MapController _mapController = MapController();
  final Distance _distanceCalc = const Distance();

  // Track the currently selected point to show a marker
  LatLng? _selectedPoint;

  void _handleMapTap(TapPosition tapPosition, LatLng tapLatLng) {
    if (widget.routePoints.isEmpty) return;

    double minDistance = double.infinity;
    Map<String, dynamic>? closestRecord;
    LatLng? closestLatLng;

    // Find the closest recorded point to where the user tapped
    for (var point in widget.routePoints) {
      final pointLatLng = LatLng(point['latitude'], point['longitude']);
      final distance = _distanceCalc.as(LengthUnit.Meter, tapLatLng, pointLatLng);

      if (distance < minDistance) {
        minDistance = distance;
        closestRecord = point;
        closestLatLng = pointLatLng;
      }
    }

    // If the tap is within 100 meters of a recorded ping, show the details
    if (minDistance <= 100 && closestRecord != null && closestLatLng != null) {
      setState(() {
        _selectedPoint = closestLatLng;
      });
      _showPointDetails(closestRecord, closestLatLng);
    } else {
      // Clear selection if they tapped far away from the route
      setState(() {
        _selectedPoint = null;
      });
    }
  }

  void _showPointDetails(Map<String, dynamic> record, LatLng pointLatLng) {
    final dateTime = DateTime.parse(record['created_at']).toLocal();
    final timeFormatted = DateFormat('hh:mm a').format(dateTime);
    final dateFormatted = DateFormat('MMM dd, yyyy').format(dateTime);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.access_time_filled, color: Colors.indigo.shade700),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recorded Time',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      Text(
                        timeFormatted,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: Colors.grey.shade200),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Date:', style: TextStyle(color: Colors.grey.shade600)),
                  Text(dateFormatted, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Coordinates:', style: TextStyle(color: Colors.grey.shade600)),
                  Text(
                    '${pointLatLng.latitude.toStringAsFixed(5)}, ${pointLatLng.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      // Clear the selected marker when the bottom sheet closes
      if (mounted) {
        setState(() {
          _selectedPoint = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.routePoints.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Route Not Found')),
        body: const Center(child: Text('No points available for this date.')),
      );
    }

    final List<LatLng> latLngPoints = widget.routePoints.map((p) {
      return LatLng(p['latitude'], p['longitude']);
    }).toList();

    final bounds = LatLngBounds.fromPoints(latLngPoints);
    final startPoint = latLngPoints.first;
    final endPoint = latLngPoints.last;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.riderName}\'s Route', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.displayDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: bounds.center,
          initialZoom: 14.0,
          initialCameraFit: CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(50.0),
          ),
          // Listen for taps on the map to find the nearest route point
          onTap: _handleMapTap,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.simpledelivery.app',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: latLngPoints,
                strokeWidth: 5.0,
                color: Colors.indigo.shade500,
                // isDotted: false,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              // Start Marker
              Marker(
                point: startPoint,
                width: 40,
                height: 40,
                child: const Icon(Icons.play_circle_fill, color: Colors.green, size: 30),
              ),
              // End Marker
              Marker(
                point: endPoint,
                width: 40,
                height: 40,
                child: const Icon(Icons.stop_circle, color: Colors.red, size: 30),
              ),
              // Highlight the selected point if the user tapped one
              if (_selectedPoint != null)
                Marker(
                  point: _selectedPoint!,
                  width: 50,
                  height: 50,
                  child: const Icon(Icons.location_on, color: Colors.orange, size: 40),
                ),
            ],
          ),
        ],
      ),
    );
  }
}