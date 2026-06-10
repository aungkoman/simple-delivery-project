import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLiveMapPage extends StatefulWidget {
  const AdminLiveMapPage({super.key});

  @override
  State<AdminLiveMapPage> createState() => _AdminLiveMapPageState();
}

class _AdminLiveMapPageState extends State<AdminLiveMapPage> {
  final supabase = Supabase.instance.client;
  RealtimeChannel? _dbSubscription;
  final MapController _mapController = MapController();

  bool _isInitializing = true;
  String? _selectedRiderId;

  // Cache to map rider_id -> full_name
  Map<String, String> _riderNamesCache = {};

  // Holds the latest coordinates of every active rider
  Map<String, Map<String, dynamic>> activeRiders = {};

  @override
  void initState() {
    super.initState();
    _initializeMapData();
  }

  Future<void> _initializeMapData() async {
    try {
      // 1. Fetch riders AND their single most recent location in ONE query!
      final response = await supabase
          .from('profiles')
          .select('''
            id, 
            full_name,
            rider_locations (
              latitude, 
              longitude, 
              created_at
            )
          ''')
          .eq('role', 'rider')
      // Sort the joined table by newest first, and limit it to 1 result per rider
          .order('created_at', referencedTable: 'rider_locations', ascending: false)
          .limit(1, referencedTable: 'rider_locations');

      // Get the start of today (Midnight) for filtering
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      for (var profile in response) {
        final riderId = profile['id'];
        final fullName = profile['full_name'] ?? 'Unknown Rider';

        // Cache the name for the list UI
        _riderNamesCache[riderId] = fullName;

        // Check if this rider has a location history
        final locations = profile['rider_locations'] as List<dynamic>?;

        if (locations != null && locations.isNotEmpty) {
          final latestLoc = locations.first;
          final locDate = DateTime.parse(latestLoc['created_at']).toLocal();

          // Only add them to the active map if their last location was recorded TODAY
          if (locDate.isAfter(startOfToday)) {
            activeRiders[riderId] = {
              'lat': latestLoc['latitude'],
              'lng': latestLoc['longitude'],
              'updated_at': latestLoc['created_at'],
            };
          }
        }
      }

      // 2. Start listening to incoming real-time locations to update the map live
      _listenToRiderLocations();

      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing map data: $error')),
        );
        setState(() => _isInitializing = false);
      }
    }
  }

  void _listenToRiderLocations() {
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
            activeRiders[riderId] = {
              'lat': newRecord['latitude'],
              'lng': newRecord['longitude'],
              'updated_at': newRecord['created_at'],
            };

            // Auto-center map on the selected rider if their location updates
            if (_selectedRiderId == riderId) {
              _mapController.move(
                LatLng(newRecord['latitude'], newRecord['longitude']),
                _mapController.camera.zoom, // Keep current zoom level
              );
            }
          });
        }
      },
    )
        .subscribe();
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null) return '';
    try {
      final date = DateTime.parse(isoString).toLocal();
      // Format as "HH:MM AM/PM"
      final hours = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final period = date.hour >= 12 ? 'PM' : 'AM';
      final minutes = date.minute.toString().padLeft(2, '0');
      return "$hours:$minutes $period";
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _dbSubscription?.unsubscribe();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markers = activeRiders.entries.map((entry) {
      final riderId = entry.key;
      final coords = entry.value;
      final isSelected = _selectedRiderId == riderId;

      return Marker(
        point: LatLng(coords['lat'], coords['lng']),
        width: 60,
        height: 60,
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedRiderId = riderId);
            _mapController.move(LatLng(coords['lat'], coords['lng']), 15.0);
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isSelected ? 50 : 36,
                height: isSelected ? 50 : 36,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.indigo.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
              Icon(
                Icons.motorcycle,
                color: isSelected ? Colors.indigo.shade700 : Colors.orange.shade700,
                size: isSelected ? 28 : 22,
              ),
            ],
          ),
        ),
      );
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Live Fleet Tracking', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
          : Column(
        children: [
          // --- TOP PORTION: THE LIVE MAP ---
          Expanded(
            flex: 4,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                // If we have active riders, center on the first one. Otherwise default to Yangon.
                initialCenter: activeRiders.isNotEmpty
                    ? LatLng(activeRiders.values.first['lat'], activeRiders.values.first['lng'])
                    : const LatLng(16.8409, 96.1735),
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.simpledelivery.app',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),

          // --- BOTTOM PORTION: FLEET INTERACTIVE LIST ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Drivers Today',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                Text(
                  '${activeRiders.length} Online',
                  style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: activeRiders.isEmpty
                ? const Center(
              child: Text(
                'No riders have been active today.',
                style: TextStyle(color: Colors.grey),
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: activeRiders.keys.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final riderId = activeRiders.keys.elementAt(index);
                final data = activeRiders[riderId]!;

                final riderName = _riderNamesCache[riderId] ?? 'Rider (${riderId.substring(0, 4)})';
                final isSelected = _selectedRiderId == riderId;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  selected: isSelected,
                  selectedTileColor: Colors.indigo.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: CircleAvatar(
                    backgroundColor: isSelected ? Colors.indigo.shade100 : Colors.orange.shade100,
                    child: Icon(
                      Icons.motorcycle,
                      color: isSelected ? Colors.indigo.shade700 : Colors.orange.shade700,
                    ),
                  ),
                  title: Text(
                    riderName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    'Last update seen: ${_formatTimestamp(data['updated_at'])}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.my_location,
                      color: isSelected ? Colors.indigo.shade700 : Colors.grey.shade400,
                    ),
                    onPressed: () {
                      setState(() => _selectedRiderId = riderId);
                      _mapController.move(LatLng(data['lat'], data['lng']), 15.0);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}