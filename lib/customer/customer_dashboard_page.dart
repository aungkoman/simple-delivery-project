import 'package:flutter/material.dart';
import 'package:simpledelivery/customer/way/customer_create_way_page.dart';
import 'package:simpledelivery/way/way_detail_read_only_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerDashboardPage extends StatefulWidget {
  const CustomerDashboardPage({super.key});

  @override
  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends State<CustomerDashboardPage> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<dynamic> _activeWays = [];
  List<dynamic> _pastWays = [];
  String _customerName = 'Customer';

  @override
  void initState() {
    super.initState();
    _fetchCustomerData();
  }

  Future<void> _fetchCustomerData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Fetch Customer Name for the Drawer
      final profileData = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .single();

      if (mounted) {
        _customerName = profileData['full_name'] ?? 'Customer';
      }

      // 2. Fetch ALL ways for this customer, joining the Rider's info this time
      final response = await supabase
          .from('ways')
          .select('*, rider:profiles!ways_rider_id_fkey(full_name, phone)')
          .eq('customer_id', user.id)
          .order('id', ascending: false); // Newest first

      // 3. Sort the data into Active vs Past orders
      final active = [];
      final past = [];

      for (var way in response) {
        final status = way['status']?.toString().toLowerCase();
        if (status == 'dropped' || status == 'delivered' || status == 'cancelled' || status == 'rejected') {
          past.add(way);
        } else {
          active.add(way);
        }
      }

      if (mounted) {
        setState(() {
          _activeWays = active;
          _pastWays = past;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading orders: $error'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'picked_up': return Colors.blue;
      case 'delivering': return Colors.purple;
      case 'dropped': case 'delivered': return Colors.green;
      case 'rejected': case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  // A reusable widget to build the lists for both tabs
  Widget _buildOrderList(List<dynamic> ways, String emptyMessage) {
    if (ways.isEmpty) {
      return Center(
        child: Text(emptyMessage, style: const TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: ways.length,
      itemBuilder: (context, index) {
        final way = ways[index];
        final status = way['status'] ?? 'pending';
        final riderName = way['rider']?['full_name'] ?? 'Waiting for Assignment';
        final riderPhone = way['rider']?['phone'] ?? '';

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => WayDetailReadOnlyPage(wayData: way)),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order #${way['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Chip(
                        label: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        backgroundColor: _getStatusColor(status),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      const Icon(Icons.motorcycle, color: Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      Text('Rider: $riderName ${riderPhone.isNotEmpty ? '($riderPhone)' : ''}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('To: ${way['drop_location']}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.green),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.person, size: 48, color: Colors.white),
                const SizedBox(height: 8),
                Text(_customerName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const Text('Customer Account', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              await supabase.auth.signOut();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // We have 2 tabs
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Orders'),
          backgroundColor: Colors.green, // Distinct color for Customer App
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.local_shipping), text: 'Active'),
              Tab(icon: Icon(Icons.history), text: 'History'),
            ],
          ),
        ),
        drawer: _buildDrawer(context),
        floatingActionButton: _fab(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          children: [
            // Tab 1: Active
            RefreshIndicator(
              onRefresh: _fetchCustomerData,
              child: _buildOrderList(_activeWays, 'You have no active orders right now.'),
            ),
            // Tab 2: Past
            RefreshIndicator(
              onRefresh: _fetchCustomerData,
              child: _buildOrderList(_pastWays, 'You have no past order history.'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fab(){
    return FloatingActionButton.extended(onPressed: () async {
      // Navigate to the customer creation page and wait for a success result
      final bool? didCreate = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CustomerCreateWayPage()),
      );
      // If a new delivery request was submitted, refresh the tabs automatically
      if (didCreate == true) {
        _fetchCustomerData();
      }
    }, label: Text("New Order") , icon: Icon(Icons.add),);
  }
}