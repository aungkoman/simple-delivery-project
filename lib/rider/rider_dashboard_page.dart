import 'package:flutter/material.dart';
import 'package:simpledelivery/rider/rider_live_tracking_page.dart';
import 'package:simpledelivery/rider/way/my_ways_page.dart';
import 'package:simpledelivery/way/way_detail_read_only_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth_page.dart';
import '../services/rider_tracker_service.dart';

class RiderDashboardPage extends StatefulWidget {
  const RiderDashboardPage({super.key});

  @override
  State<RiderDashboardPage> createState() => _RiderDashboardPageState();
}

class _RiderDashboardPageState extends State<RiderDashboardPage> {
  final supabase = Supabase.instance.client;
  final RiderTrackerService _trackerService = RiderTrackerService();

  bool _isOnline = false;
  bool _isLoading = true;

  List<dynamic> _allActiveWays = [];
  String _riderName = 'Rider';

  // --- NEW: UI/UX Filter State ---
  // Can be: 'all', 'pickup', 'transit'
  String _currentFilter = 'all';

  @override
  void initState() {
    super.initState();
    _fetchMyWays();
    _fetchRiderProfile();
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    setState(() => _isOnline = value);

    if (_isOnline) {
      try {
        await _trackerService.startBackgroundTracking();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('You are Online.'), backgroundColor: Colors.green.shade700),
          );
        }
      } catch (e) {
        setState(() => _isOnline = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start tracking: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      _trackerService.stopTracking();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('You are Offline.'), backgroundColor: Colors.grey.shade800),
        );
      }
    }
  }

  Future<void> _fetchMyWays() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('ways')
          .select('''
            *, 
            customer:profiles!ways_customer_id_fkey(full_name, phone),
            rider:profiles!ways_rider_id_fkey(full_name, phone)
          ''')
          .eq('rider_id', user.id)
          .neq('status', 'dropped')
          .neq('status', 'cancelled')
          .order('id', ascending: true);

      if (mounted) {
        setState(() {
          _allActiveWays = response;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading deliveries: $error'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateWayStatus(int wayId, String newStatus) async {
    try {
      await supabase.from('ways').update({'status': newStatus}).eq('id', wayId);
      _fetchMyWays(); // Refresh data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to $newStatus')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating: $error'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _fetchRiderProfile() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final data = await supabase.from('profiles').select('full_name').eq('id', user.id).single();
      if (mounted) setState(() => _riderName = data['full_name'] ?? 'Rider');
    }
  }

  // --- DATA FILTERING HELPERS ---

  List<dynamic> get _pickupWays {
    return _allActiveWays.where((way) => ['pending', 'preparing', 'assigned'].contains(way['status'])).toList();
  }

  List<dynamic> get _transitWays {
    return _allActiveWays.where((way) => ['picked_up', 'delivering'].contains(way['status'])).toList();
  }

  List<dynamic> get _displayedWays {
    if (_currentFilter == 'pickup') return _pickupWays;
    if (_currentFilter == 'transit') return _transitWays;
    return _allActiveWays;
  }

  // --- UI BUILDERS ---

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required String filterKey
  }) {
    final isSelected = _currentFilter == filterKey;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          // Toggle filter off if tapped again, otherwise set to new filter
          setState(() {
            _currentFilter = isSelected ? 'all' : filterKey;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? color : Colors.grey.shade200, width: 2),
            boxShadow: isSelected
                ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: isSelected ? Colors.white : color),
                  if (isSelected) const Icon(Icons.check_circle, color: Colors.white, size: 16),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                  count.toString(),
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white : Colors.black87
                  )
              ),
              const SizedBox(height: 4),
              Text(
                  title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white.withOpacity(0.9) : Colors.grey.shade600
                  )
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, $_riderName 👋',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your Shift Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatCard(
                  title: 'To Pickup',
                  count: _pickupWays.length,
                  icon: Icons.storefront_rounded,
                  color: Colors.orange.shade600,
                  filterKey: 'pickup'
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                  title: 'In Transit',
                  count: _transitWays.length,
                  icon: Icons.motorcycle_rounded,
                  color: Colors.purple.shade600,
                  filterKey: 'transit'
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Helper text indicating the filter status
          if (_currentFilter != 'all')
            Row(
              children: [
                Icon(Icons.filter_list, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Showing only ${_currentFilter == 'pickup' ? 'To Pickup' : 'In Transit'} orders.',
                  style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic, fontSize: 13),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(int wayId, String currentStatus) {
    if (currentStatus == 'assigned' || currentStatus == 'pending') {
      return ElevatedButton.icon(
        onPressed: () => _updateWayStatus(wayId, 'picked_up'),
        icon: const Icon(Icons.inventory_2),
        label: const Text('Mark Picked Up'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
      );
    } else if (currentStatus == 'picked_up') {
      return ElevatedButton.icon(
        onPressed: () => _updateWayStatus(wayId, 'delivering'),
        icon: const Icon(Icons.motorcycle),
        label: const Text('Start Delivering'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
      );
    } else if (currentStatus == 'delivering') {
      return ElevatedButton.icon(
        onPressed: () => _updateWayStatus(wayId, 'dropped'),
        icon: const Icon(Icons.check_circle),
        label: const Text('Confirm Dropped'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.green.shade700, Colors.green.shade500])),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.motorcycle, size: 48, color: Colors.white),
                const SizedBox(height: 8),
                Text(_riderName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const Text('Rider Portal', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.local_shipping, color: Colors.green.shade700),
            title: const Text('Active Deliveries'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Delivery History'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MyWaysPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.radar, color: Colors.blue),
            title: const Text('Live Tracking Console'),
            subtitle: const Text('View GPS & API Sync'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const RiderLiveTrackingPage()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              await supabase.auth.signOut();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthPage()));
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('My Shift', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: _isOnline ? Colors.green.shade700 : Colors.grey.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Row(
            children: [
              Text(_isOnline ? 'ONLINE' : 'OFFLINE', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
              Switch(
                value: _isOnline,
                activeColor: Colors.white,
                activeTrackColor: Colors.green.shade400,
                inactiveThumbColor: Colors.grey.shade400,
                inactiveTrackColor: Colors.grey.shade600,
                onChanged: _toggleOnlineStatus,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: !_isOnline
          ? _offlineIndicator()
          : RefreshIndicator(
        onRefresh: _fetchMyWays,
        color: Colors.green.shade700,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            _buildDashboardHeader(),
            Expanded(
              child: _displayedWays.isEmpty
                  ? ListView(
                children: [
                  const SizedBox(height: 100),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.celebration_rounded, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _currentFilter == 'all'
                              ? 'No active deliveries!\nYou are all caught up.'
                              : 'No orders in this category.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              )
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                itemCount: _displayedWays.length,
                itemBuilder: (context, index) {
                  final way = _displayedWays[index];
                  final customerName = way['customer']?['full_name'] ?? 'Unknown Customer';
                  final customerPhone = way['customer']?['phone'] ?? 'No Phone';
                  final status = way['status'] ?? 'unknown';

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200)
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        final bool? needsRefresh = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => WayDetailReadOnlyPage(wayData: way)),
                        );
                        if (needsRefresh == true) _fetchMyWays();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Order #${way['id']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(20)
                                  ),
                                  child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 10)
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                CircleAvatar(backgroundColor: Colors.blue.shade50, radius: 16, child: Icon(Icons.person, color: Colors.blue.shade400, size: 16)),
                                const SizedBox(width: 12),
                                Text('$customerName ($customerPhone)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.radio_button_checked, color: Colors.orange, size: 20),
                                const SizedBox(width: 12),
                                Expanded(child: Text(way['pickup_location'] ?? 'N/A', style: TextStyle(color: Colors.grey.shade700))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on, color: Colors.red, size: 20),
                                const SizedBox(width: 12),
                                Expanded(child: Text(way['drop_location'] ?? 'N/A', style: TextStyle(color: Colors.grey.shade700))),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildActionButton(way['id'], status),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _offlineIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
            child: Icon(Icons.bedtime_outlined, size: 80, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          Text(
            'You are currently offline.\nGo online to manage your shift.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500, height: 1.5),
          ),
        ],
      ),
    );
  }
}