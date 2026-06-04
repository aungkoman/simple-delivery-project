import 'package:flutter/material.dart';
import 'package:simpledelivery/auth_page.dart';
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
  String _phone = '09****';

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
          .select('full_name, email')
          .eq('id', user.id)
          .single();

      if (mounted) {
        _customerName = profileData['full_name'] ?? 'Customer';
        _phone = profileData['email'] ?? 'email';
        _phone = _phone.split("@").first;
      }

      // 2. UPDATED QUERY: Fetch both Rider AND Customer profile details
      final response = await supabase
          .from('ways')
          .select('''
            *, 
            rider:profiles!ways_rider_id_fkey(full_name, phone),
            customer:profiles!ways_customer_id_fkey(full_name, phone)
          ''')
          .eq('customer_id', user.id)
          .order('id', ascending: false);

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

  // UPDATED UI: A reusable widget to build the lists with personnel info
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

        // Extract Rider Info
        final riderName = way['rider']?['full_name'] ?? 'Unassigned';
        final riderPhone = way['rider']?['phone'] ?? '';

        // Extract Customer Info
        final customerName = way['customer']?['full_name'] ?? _customerName;
        final customerPhone = way['customer']?['phone'] ?? '';

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
                  // --- Header ---
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

                  // --- Locations ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.storefront, color: Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text('From: ${way['pickup_location']}', maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text('To: ${way['drop_location']}', maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- Personnel Information Block ---
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Customer Side
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Customer', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              if (customerPhone.isNotEmpty)
                                Text(customerPhone, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            ],
                          ),
                        ),

                        // Vertical Divider
                        Container(width: 1, height: 30, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 8)),

                        // Rider Side
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Rider', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(riderName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.right),
                              if (riderPhone.isNotEmpty)
                                Text(riderPhone, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                // const SizedBox(height: 8),
                Text(_customerName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text(_phone, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.normal)),
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
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthPage()));
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Orders'),
          backgroundColor: Colors.green,
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
            RefreshIndicator(
              onRefresh: _fetchCustomerData,
              child: _buildOrderList(_activeWays, 'You have no active orders right now.'),
            ),
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
    return FloatingActionButton.extended(
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      onPressed: () async {
        final bool? didCreate = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CustomerCreateWayPage()),
        );
        if (didCreate == true) {
          _fetchCustomerData();
        }
      },
      label: const Text("New Order", style: TextStyle(fontWeight: FontWeight.bold)),
      icon: const Icon(Icons.add),
    );
  }
}