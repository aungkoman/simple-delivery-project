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

  LatLng? _selectedPoint;
  List<List<dynamic>> _trips = [];

  // A palette of colors to distinguish different trips visually
  final List<Color> _tripColors = [
    Colors.indigo.shade600,
    Colors.teal.shade600,
    Colors.purple.shade600,
    Colors.orange.shade600,
    Colors.blue.shade600,
  ];

  @override
  void initState() {
    super.initState();
    _segmentRoutes();
  }

  void _segmentRoutes() {
    if (widget.routePoints.isEmpty) return;

    List<dynamic> currentTrip = [];

    for (int i = 0; i < widget.routePoints.length; i++) {
      if (i == 0) {
        currentTrip.add(widget.routePoints[i]);
        continue;
      }

      final prevTime = DateTime.parse(widget.routePoints[i - 1]['created_at']).toLocal();
      final currTime = DateTime.parse(widget.routePoints[i]['created_at']).toLocal();

      // The threshold: If there is a gap of more than 15 minutes, consider it a new trip
      final difference = currTime.difference(prevTime).inMinutes;

      if (difference > 15) {
        _trips.add(currentTrip);
        currentTrip = [widget.routePoints[i]];
      } else {
        currentTrip.add(widget.routePoints[i]);
      }
    }

    // Add the final active trip
    if (currentTrip.isNotEmpty) {
      _trips.add(currentTrip);
    }
  }

  void _handleMapTap(TapPosition tapPosition, LatLng tapLatLng) {
    if (widget.routePoints.isEmpty) return;

    double minDistance = double.infinity;
    Map<String, dynamic>? closestRecord;
    LatLng? closestLatLng;

    // Search across all trips to find the closest point
    for (var trip in _trips) {
      for (var point in trip) {
        final pointLatLng = LatLng(point['latitude'], point['longitude']);
        final distance = _distanceCalc.as(LengthUnit.Meter, tapLatLng, pointLatLng);

        if (distance < minDistance) {
          minDistance = distance;
          closestRecord = point;
          closestLatLng = pointLatLng;
        }
      }
    }

    if (minDistance <= 100 && closestRecord != null && closestLatLng != null) {
      setState(() => _selectedPoint = closestLatLng);
      _showPointDetails(closestRecord, closestLatLng);
    } else {
      setState(() => _selectedPoint = null);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.my_location, color: Colors.indigo.shade700, size: 28),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recorded Time', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      Text(timeFormatted, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    ],
                  ),
                ],
              ),
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
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.indigo.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close Details'),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() => _selectedPoint = null);
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

    // Get all points to calculate the camera bounds
    final List<LatLng> allLatLngPoints = widget.routePoints
        .map((p) => LatLng(p['latitude'], p['longitude']))
        .toList();
    final bounds = LatLngBounds.fromPoints(allLatLngPoints);

    // Build the polylines and markers dynamically from the segmented trips
    List<Polyline> renderPolylines = [];
    List<Marker> renderMarkers = [];

    for (int i = 0; i < _trips.length; i++) {
      final trip = _trips[i];
      if (trip.isEmpty) continue;

      final tripPoints = trip.map<LatLng>((p) => LatLng(p['latitude'], p['longitude'])).toList();
      final color = _tripColors[i % _tripColors.length]; // Cycle through colors

      // 1. Draw the segmented polyline
      renderPolylines.add(
        Polyline(
          points: tripPoints,
          strokeWidth: 5.0,
          color: color,
        ),
      );

      // 2. Add Start & End markers for each individual trip
      renderMarkers.add(
        Marker(
          point: tripPoints.first,
          width: 30,
          height: 30,
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(Icons.play_circle_fill, color: color, size: 26),
          ),
        ),
      );

      renderMarkers.add(
        Marker(
          point: tripPoints.last,
          width: 30,
          height: 30,
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.stop_circle, color: Colors.red, size: 26),
          ),
        ),
      );
    }

    // Add the interactive tap marker if active
    if (_selectedPoint != null) {
      renderMarkers.add(
        Marker(
          point: _selectedPoint!,
          width: 50,
          height: 50,
          child: const Icon(Icons.location_on, color: Colors.orange, size: 40),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.riderName}\'s Routes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('${widget.displayDate} • ${_trips.length} Trips', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: bounds.center,
          initialZoom: 13.0,
          initialCameraFit: CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(50.0),
          ),
          onTap: _handleMapTap,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.simpledelivery.app',
          ),
          PolylineLayer(polylines: renderPolylines),
          MarkerLayer(markers: renderMarkers),
        ],
      ),
    );
  }
}