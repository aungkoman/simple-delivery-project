import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

class RiderLiveTrackingPage extends StatefulWidget {
  const RiderLiveTrackingPage({super.key});

  @override
  State<RiderLiveTrackingPage> createState() => _RiderLiveTrackingPageState();
}

class _RiderLiveTrackingPageState extends State<RiderLiveTrackingPage> {
  // We will store our live logs here. Newest at the top (index 0).
  final List<String> _logs = [];

  int _syncSuccessCount = 0;
  int _syncFailCount = 0;
  bg.Location? _lastLocation;

  @override
  void initState() {
    super.initState();
    _setupLiveListeners();
    _addLog('🚀 Live Tracking Console Initialized');
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      // Insert at the top of the list so we don't have to scroll down
      _logs.insert(0, '${DateTime.now().toLocal().toString().split('.')[0]} - $message');
    });
  }

  void _setupLiveListeners() {
    // 1. Listen for Live Location updates
    bg.BackgroundGeolocation.onLocation((bg.Location location) {
      if (!mounted) return;
      setState(() {
        _lastLocation = location;
      });
      _addLog('📍 Captured: ${location.coords.latitude.toStringAsFixed(5)}, ${location.coords.longitude.toStringAsFixed(5)}');
    });

    // 2. Listen for Live Supabase API Sync updates
    bg.BackgroundGeolocation.onHttp((bg.HttpEvent event) {
      if (!mounted) return;

      if (event.success) {
        setState(() => _syncSuccessCount++);
        _addLog('🟢 SYNC SUCCESS (Status: ${event.status})');
      } else {
        setState(() => _syncFailCount++);
        _addLog('🔴 SYNC FAILED (Status: ${event.status}) | ${event.responseText}');
      }
    });

    // 3. Listen for Plugin State changes (Moving vs Stationary)
    bg.BackgroundGeolocation.onMotionChange((bg.Location location) {
      _addLog('🏃‍♂️ Motion Changed: isMoving -> ${location.isMoving}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Live Sync Console'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear Logs',
            onPressed: () {
              setState(() => _logs.clear());
            },
          )
        ],
      ),
      body: Column(
        children: [
          _buildSummaryHeader(),
          const Divider(height: 1, thickness: 2),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                // Color code the logs for easy reading
                Color textColor = Colors.black87;
                if (log.contains('🟢')) textColor = Colors.green.shade700;
                if (log.contains('🔴')) textColor = Colors.red.shade700;
                if (log.contains('📍')) textColor = Colors.blue.shade700;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      log,
                      style: TextStyle(
                        fontFamily: 'monospace', // Makes it look like a terminal
                        fontSize: 12,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // A sleek header to show the current status
  Widget _buildSummaryHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatMetric('API Success', _syncSuccessCount.toString(), Colors.green),
              _buildStatMetric('API Failed', _syncFailCount.toString(), Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.gps_fixed, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _lastLocation == null
                        ? 'Waiting for first GPS lock...'
                        : 'Lat: ${_lastLocation!.coords.latitude}\nLng: ${_lastLocation!.coords.longitude}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }
}