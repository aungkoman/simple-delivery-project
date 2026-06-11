import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:simpledelivery/admin/rider_detail_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // Ensure you have this imported

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

  // Holds ONLY riders who have sent a location ping TODAY
  Map<String, Map<String, dynamic>> activeRiders = {};

  // Holds EVERY rider, regardless of when they last pinged
  Map<String, Map<String, dynamic>> allRidersData = {};

  @override
  void initState() {
    super.initState();
    _initializeMapData();
  }

  Future<void> _initializeMapData() async {
    try {
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
          .order('created_at', referencedTable: 'rider_locations', ascending: false)
          .limit(1, referencedTable: 'rider_locations');

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      for (var profile in response) {
        final riderId = profile['id'];
        final fullName = profile['full_name'] ?? 'Unknown Rider';

        _riderNamesCache[riderId] = fullName;

        final locations = profile['rider_locations'] as List<dynamic>?;

        if (locations != null && locations.isNotEmpty) {
          final latestLoc = locations.first;
          final locDate = DateTime.parse(latestLoc['created_at']).toLocal();

          final riderData = {
            'lat': latestLoc['latitude'],
            'lng': latestLoc['longitude'],
            'updated_at': latestLoc['created_at'],
          };

          // Add to the "All Riders" pool
          allRidersData[riderId] = riderData;

          // If the location is from today, also add to "Active" pool
          if (locDate.isAfter(startOfToday)) {
            activeRiders[riderId] = riderData;
          }
        } else {
          // Rider exists but has NEVER recorded a location
          allRidersData[riderId] = {
            'lat': null,
            'lng': null,
            'updated_at': null,
          };
        }
      }

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
            final newData = {
              'lat': newRecord['latitude'],
              'lng': newRecord['longitude'],
              'updated_at': newRecord['created_at'],
            };

            // A new insert means they are active right now!
            activeRiders[riderId] = newData;
            allRidersData[riderId] = newData;

            if (_selectedRiderId == riderId) {
              _mapController.move(
                LatLng(newRecord['latitude'], newRecord['longitude']),
                _mapController.camera.zoom,
              );
            }
          });
        }
      },
    ).subscribe();
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null) return 'No location data';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

      final timeFormatted = DateFormat('hh:mm a').format(date);

      if (isToday) {
        return "Today, $timeFormatted";
      } else {
        // If it's an older record, show the date
        return "${DateFormat('MMM dd, yyyy').format(date)}, $timeFormatted";
      }
    } catch (_) {
      return 'Unknown time';
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
    // Only draw map markers for ACTIVE riders so the map isn't cluttered
    // with riders who are at home/offline.
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

          // --- BOTTOM PORTION: TABS FOR ACTIVE / ALL RIDERS ---
          Expanded(
            flex: 4,
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      labelColor: Colors.indigo.shade700,
                      unselectedLabelColor: Colors.grey.shade600,
                      indicatorColor: Colors.indigo.shade700,
                      indicatorWeight: 3,
                      tabs: [
                        Tab(text: 'Active Today (${activeRiders.length})'),
                        Tab(text: 'All Riders (${allRidersData.length})'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildRiderList(activeRiders, emptyMessage: 'No riders are active today.'),
                        _buildRiderList(allRidersData, emptyMessage: 'No riders registered in the system.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Extracted List Builder to reuse for both Tabs
  Widget _buildRiderList(Map<String, Map<String, dynamic>> dataSource, {required String emptyMessage}) {
    if (dataSource.isEmpty) {
      return Center(
        child: Text(emptyMessage, style: const TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: dataSource.keys.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final riderId = dataSource.keys.elementAt(index);
        final data = dataSource[riderId]!;

        final riderName = _riderNamesCache[riderId] ?? 'Rider (${riderId.substring(0, 4)})';
        final isSelected = _selectedRiderId == riderId;
        final hasLocation = data['lat'] != null && data['lng'] != null;

        // Check if this rider is active today to color code them
        final isActiveToday = activeRiders.containsKey(riderId);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          selected: isSelected,
          selectedTileColor: Colors.indigo.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: CircleAvatar(
            backgroundColor: isActiveToday
                ? (isSelected ? Colors.indigo.shade100 : Colors.orange.shade100)
                : Colors.grey.shade200,
            child: Icon(
              Icons.motorcycle,
              color: isActiveToday
                  ? (isSelected ? Colors.indigo.shade700 : Colors.orange.shade700)
                  : Colors.grey.shade500,
            ),
          ),
          title: Text(
            riderName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isActiveToday ? Colors.black87 : Colors.black54,
            ),
          ),
          subtitle: Text(
            'Updated: ${_formatTimestamp(data['updated_at'])}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Locate Button (only enabled if they have a known location)
              IconButton(
                icon: Icon(
                  Icons.my_location,
                  color: hasLocation
                      ? (isSelected ? Colors.indigo.shade700 : Colors.grey.shade400)
                      : Colors.grey.shade300,
                ),
                onPressed: hasLocation
                    ? () {
                  setState(() => _selectedRiderId = riderId);
                  _mapController.move(LatLng(data['lat'], data['lng']), 15.0);
                }
                    : null,
              ),
              // History / Detail Button
              IconButton(
                icon: const Icon(Icons.history, color: Colors.indigo),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RiderDetailPage(
                        riderId: riderId,
                        riderName: riderName,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}