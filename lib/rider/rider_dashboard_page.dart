import 'package:flutter/material.dart';
import 'package:simpledelivery/rider/rider_live_tracking_page.dart';
import 'package:simpledelivery/rider/way/my_ways_page.dart';
import 'package:simpledelivery/rider/way/way_detail_page.dart';
import 'package:simpledelivery/way/way_detail_read_only_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth_page.dart';
import '../services/rider_tracker_service.dart';
// Import your AuthPage if you want to route back to login on logout
// import 'auth_page.dart';

class RiderDashboardPage extends StatefulWidget {
  const RiderDashboardPage({super.key});

  @override
  State<RiderDashboardPage> createState() => _RiderDashboardPageState();
}

class _RiderDashboardPageState extends State<RiderDashboardPage> {
  final supabase = Supabase.instance.client;

  // 1. Create an instance of our tracking service
  final RiderTrackerService _trackerService = RiderTrackerService();

  // 2. State variable to control the UI and the tracker
  bool _isOnline = false;


  bool _isLoading = true;
  List<dynamic> _myWays = [];
  String _riderName = 'Rider'; // To display in the drawer


  @override
  void initState() {
    super.initState();
    _fetchMyWays();
    _fetchRiderProfile();
  }

  // --- THE MAGIC TOGGLE FUNCTION ---
  Future<void> _toggleOnlineStatus(bool value) async {
    setState(() => _isOnline = value);

    if (_isOnline) {
      // Rider went ONLINE -> Start sending GPS to Supabase
      try {
        await _trackerService.startBackgroundTracking();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('You are Online. Location tracking started.'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } catch (e) {
        setState(() => _isOnline = false); // Revert if permissions failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start tracking: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      // Rider went OFFLINE -> Stop GPS
      _trackerService.stopTracking();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('You are Offline. Tracking stopped.'),
            backgroundColor: Colors.grey.shade800,
          ),
        );
      }
    }
  }

  Future<void> _fetchMyWays() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Fetch only ways assigned to THIS rider, and join the customer name
      final response = await supabase
          .from('ways')
          .select('''
            *, 
            customer:profiles!ways_customer_id_fkey(full_name, phone),
            rider:profiles!ways_rider_id_fkey(full_name, phone)
          ''')
          // .select('*, customer:profiles!ways_customer_id_fkey(full_name, phone)')
          .eq('rider_id', user.id)
      // Hide deliveries that are fully completed or cancelled to keep the UI clean
          .neq('status', 'dropped')
          .neq('status', 'cancelled')
          .order('id', ascending: true);

      if (mounted) {
        setState(() {
          _myWays = response;
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

  // Quick action to update the status
  Future<void> _updateWayStatus(int wayId, String newStatus) async {
    try {
      await supabase
          .from('ways')
          .update({'status': newStatus})
          .eq('id', wayId);

      // Refresh the list to remove it or update the UI
      _fetchMyWays();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $newStatus')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Determine what the "Next Action" button should say based on current status
  Widget _buildActionButton(int wayId, String currentStatus) {
    if (currentStatus == 'assigned' || currentStatus == 'pending') {
      return ElevatedButton.icon(
        onPressed: () => _updateWayStatus(wayId, 'picked_up'),
        icon: const Icon(Icons.inventory_2),
        label: const Text('Mark Picked Up'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
      );
    } else if (currentStatus == 'picked_up') {
      return ElevatedButton.icon(
        onPressed: () => _updateWayStatus(wayId, 'delivering'),
        icon: const Icon(Icons.motorcycle),
        label: const Text('Start Delivering'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
      );
    } else if (currentStatus == 'delivering') {
      return ElevatedButton.icon(
        onPressed: () => _updateWayStatus(wayId, 'dropped'),
        icon: const Icon(Icons.check_circle),
        label: const Text('Confirm Dropped'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
      );
    }

    return const SizedBox.shrink(); // Hide button if no action available
  }

  // Optional: Fetch the rider's name to personalize the Drawer header
  Future<void> _fetchRiderProfile() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final data = await supabase.from('profiles').select('full_name').eq('id', user.id).single();
      if (mounted) setState(() => _riderName = data['full_name'] ?? 'Rider');
    }
  }


  // 2. --- ADD THE DRAWER WIDGET ---
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.orange,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.motorcycle, size: 48, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  _riderName,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Rider Portal',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.local_shipping, color: Colors.orange),
            title: const Text('Active Deliveries'),
            onTap: () {
              Navigator.pop(context); // Just close the drawer
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Delivery History'),
            onTap: () {
              Navigator.pop(context); // Close the drawer first
              // Navigate to the history page
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyWaysPage()),
              );
            },
          ),
          // ---> ADD THIS NEW TILE HERE <---
          ListTile(
            leading: const Icon(Icons.radar, color: Colors.blue),
            title: const Text('Live Tracking Console'),
            subtitle: const Text('View GPS & API Sync'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RiderLiveTrackingPage()),
              );
            },
          ),
          // ---------------------------------

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
      appBar: AppBar(
        title: const Text('My Deliveries'),
        // backgroundColor: Colors.orange, // Give Rider app a distinct color
        backgroundColor: _isOnline ? Colors.green.shade700 : Colors.grey.shade800,
        foregroundColor: Colors.white,
        actions: [
          Row(
            children: [
              Text(
                _isOnline ? 'ONLINE' : 'OFFLINE',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              Switch(
                value: _isOnline,
                activeColor: Colors.white,
                activeTrackColor: Colors.green.shade400,
                inactiveThumbColor: Colors.grey.shade400,
                inactiveTrackColor: Colors.grey.shade600,
                onChanged: _toggleOnlineStatus, // Calls our function above
              ),
              const SizedBox(width: 8),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
              // Navigate back to login
              // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthPage()));
            },
          )
        ],
      ),
      drawer: _buildDrawer(context), // 3. Attach the drawer to the Scaffold
      body: _isOnline == false  ? _offlineIndicator() :  RefreshIndicator(
        onRefresh: _fetchMyWays,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _myWays.isEmpty
            ? ListView(
          children: const [
            SizedBox(height: 300),
            Center(child: Text('No active deliveries assigned to you! 🎉')),
          ],
        )
            : ListView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: _myWays.length,
          itemBuilder: (context, index) {
            final way = _myWays[index];
            final customerName = way['customer']?['full_name'] ?? 'Unknown Customer';
            final customerPhone = way['customer']?['phone'] ?? 'No Phone';
            final status = way['status'] ?? 'unknown';

            return Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  // Navigate to Detail Page instead!
                  final bool? needsRefresh = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WayDetailReadOnlyPage(wayData: way),
                    ),
                  );

                  // If something was updated in the details, refresh the list
                  if (needsRefresh == true) {
                    _fetchMyWays();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order #${way['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Text(status.toUpperCase(), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 24),
                
                      // Customer Info
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Text('$customerName ($customerPhone)', style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 12),
                
                      // Locations
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.storefront, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Pickup: ${way['pickup_location']}')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Drop: ${way['drop_location']}')),
                        ],
                      ),
                
                      const SizedBox(height: 24),
                
                      // Dynamic Action Button
                      _buildActionButton(way['id'], status),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _offlineIndicator(){
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isOnline ? Icons.motorcycle_rounded : Icons.bedtime_outlined,
            size: 80,
            color: _isOnline ? Colors.green.shade700 : Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            _isOnline
                ? 'Looking for deliveries...\nYour location is being shared with Dispatch.'
                : 'You are offline.\nGo online to receive deliveries.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}