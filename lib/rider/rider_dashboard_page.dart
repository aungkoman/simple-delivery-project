import 'package:flutter/material.dart';
import 'package:simpledelivery/rider/way/way_detail_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Import your AuthPage if you want to route back to login on logout
// import 'auth_page.dart';

class RiderDashboardPage extends StatefulWidget {
  const RiderDashboardPage({super.key});

  @override
  State<RiderDashboardPage> createState() => _RiderDashboardPageState();
}

class _RiderDashboardPageState extends State<RiderDashboardPage> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<dynamic> _myWays = [];

  @override
  void initState() {
    super.initState();
    _fetchMyWays();
  }

  Future<void> _fetchMyWays() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Fetch only ways assigned to THIS rider, and join the customer name
      final response = await supabase
          .from('ways')
          .select('*, customer:profiles!ways_customer_id_fkey(full_name, phone)')
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Deliveries'),
        backgroundColor: Colors.orange, // Give Rider app a distinct color
        actions: [
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
      body: RefreshIndicator(
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
                      builder: (context) => WayDetailPage(wayData: way),
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
}