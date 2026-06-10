import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLiveMapPage extends StatefulWidget {
  const AdminLiveMapPage({super.key});

  @override
  State<AdminLiveMapPage> createState() => _AdminLiveMapPageState();
}

class _AdminLiveMapPageState extends State<AdminLiveMapPage> {
  final supabase = Supabase.instance.client;
  RealtimeChannel? _dbSubscription;

  // A map holding the latest coordinates of every active rider
  // Key: Rider ID, Value: Map of Lat/Lng data
  Map<String, Map<String, dynamic>> activeRiders = {};

  @override
  void initState() {
    super.initState();
    _listenToRiderLocations();
  }

  void _listenToRiderLocations() {
    // Listen directly to INSERTs on the rider_locations table
    _dbSubscription = supabase
        .channel('public:rider_locations')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'rider_locations',
      callback: (payload) {
        final newRecord = payload.newRecord;
        final riderId = newRecord['rider_id'];

        if (mounted && riderId != null) {
          setState(() {
            // Update or add the rider's latest position
            activeRiders[riderId] = {
              'lat': newRecord['latitude'],
              'lng': newRecord['longitude'],
              'updated_at': newRecord['created_at'],
            };
          });
        }
      },
    )
        .subscribe();
  }

  @override
  void dispose() {
    _dbSubscription?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Fleet Tracking'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: activeRiders.isEmpty
          ? const Center(child: Text('Waiting for rider location updates...'))
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: activeRiders.keys.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          String rId = activeRiders.keys.elementAt(index);
          var data = activeRiders[rId]!;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: const Icon(Icons.motorcycle, color: Colors.orange),
            ),
            title: Text('Rider: ${rId.substring(0, 8)}...'),
            subtitle: Text('Lat: ${data['lat']}\nLng: ${data['lng']}'),
            trailing: const Icon(Icons.location_on, color: Colors.green),
            isThreeLine: true,
          );
        },
      ),
    );
  }
}