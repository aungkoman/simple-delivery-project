import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart'; // Add this to your pubspec.yaml if not already there
import 'rider_daily_route_page.dart'; // We will create this next

class RiderDetailPage extends StatefulWidget {
  final String riderId;
  final String riderName;

  const RiderDetailPage({
    super.key,
    required this.riderId,
    required this.riderName,
  });

  @override
  State<RiderDetailPage> createState() => _RiderDetailPageState();
}

class _RiderDetailPageState extends State<RiderDetailPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Maps a date string (e.g., "2026-06-04") to a list of location records
  Map<String, List<dynamic>> _groupedRecords = {};
  // Maps a date string to the total distance covered that day (in kilometers)
  Map<String, double> _dailyDistances = {};

  @override
  void initState() {
    super.initState();
    _fetchAndGroupRecords();
  }

  Future<void> _fetchAndGroupRecords() async {
    try {
      // Fetch locations, ordered oldest to newest so path drawing/distance calculation is sequential
      final response = await supabase
          .from('rider_locations')
          .select()
          .eq('rider_id', widget.riderId)
          .order('created_at', ascending: true);

      final Map<String, List<dynamic>> tempGroups = {};
      final Distance distanceCalc = const Distance();

      for (var record in response) {
        final dateObj = DateTime.parse(record['created_at']).toLocal();
        // Format as YYYY-MM-DD
        final dateKey = DateFormat('yyyy-MM-dd').format(dateObj);

        if (!tempGroups.containsKey(dateKey)) {
          tempGroups[dateKey] = [];
        }
        tempGroups[dateKey]!.add(record);
      }

      final Map<String, double> tempDistances = {};

      // Calculate total distance per day
      tempGroups.forEach((date, points) {
        double totalMeters = 0.0;
        for (int i = 0; i < points.length - 1; i++) {
          final p1 = LatLng(points[i]['latitude'], points[i]['longitude']);
          final p2 = LatLng(points[i+1]['latitude'], points[i+1]['longitude']);
          totalMeters += distanceCalc.as(LengthUnit.Meter, p1, p2);
        }
        tempDistances[date] = totalMeters / 1000.0; // Convert to km
      });

      // Sort dates from newest to oldest for the UI list
      final sortedGroups = Map.fromEntries(
          tempGroups.entries.toList()..sort((e1, e2) => e2.key.compareTo(e1.key))
      );

      if (mounted) {
        setState(() {
          _groupedRecords = sortedGroups;
          _dailyDistances = tempDistances;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching records: $error')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('${widget.riderName}\'s Activity', style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
          : _groupedRecords.isEmpty
          ? Center(
        child: Text(
          'No tracking history found for ${widget.riderName}.',
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _groupedRecords.keys.length,
        itemBuilder: (context, index) {
          final dateKey = _groupedRecords.keys.elementAt(index);
          final distance = _dailyDistances[dateKey] ?? 0.0;
          final pointsCount = _groupedRecords[dateKey]!.length;

          // Parse the date nicely for the UI
          final parsedDate = DateTime.parse(dateKey);
          final displayDate = DateFormat('MMM dd, yyyy (EEEE)').format(parsedDate);

          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.calendar_today, color: Colors.indigo.shade400),
              ),
              title: Text(
                displayDate,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.route, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${distance.toStringAsFixed(2)} km covered',
                      style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.gps_fixed, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      '$pointsCount pings',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
              onTap: () {
                // Pass the specific day's records to the map view
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RiderDailyRoutePage(
                      riderName: widget.riderName,
                      dateKey: dateKey,
                      displayDate: displayDate,
                      routePoints: _groupedRecords[dateKey]!,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}