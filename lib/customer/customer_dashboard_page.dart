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
  String _customerPhone = 'N/A';
  String _customerEmail = '';

  @override
  void initState() {
    super.initState();
    _fetchCustomerData();
  }

  Future<void> _fetchCustomerData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Fetch Customer Profile
      final profileData = await supabase
          .from('profiles')
          .select('full_name, phone, email')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted && profileData != null) {
        _customerName = profileData['full_name'] ?? 'Customer';
        _customerPhone = profileData['phone'] ?? 'No phone provided';
        _customerEmail = profileData['email'] ?? user.email ?? '';
      }

      // 2. Fetch Orders with Rider & Customer Joins
      final response = await supabase
          .from('ways')
          .select('''
            *, 
            rider:profiles!ways_rider_id_fkey(full_name, phone),
            customer:profiles!ways_customer_id_fkey(full_name, phone)
          ''')
          .eq('customer_id', user.id)
          .order('id', ascending: false);

      // 3. Sort into Active vs Past
      final active = [];
      final past = [];

      for (var way in response) {
        final status = way['status']?.toString().toLowerCase();
        if (['dropped', 'delivered', 'cancelled', 'rejected'].contains(status)) {
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
          SnackBar(
            content: Text('Error loading orders: $error'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<dynamic> ways, String emptyMessage, IconData emptyIcon) {
    if (ways.isEmpty) {
      return _buildEmptyState(emptyMessage, emptyIcon);
    }

    return RefreshIndicator(
      onRefresh: _fetchCustomerData,
      color: Colors.green.shade600,
      child: ListView.separated(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80), // Padding for FAB
        itemCount: ways.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _OrderCard(
            way: ways[index],
            fallbackCustomerName: _customerName,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => WayDetailReadOnlyPage(wayData: ways[index])),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Colors.green.shade700,
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _customerName.isNotEmpty ? _customerName[0].toUpperCase() : 'C',
                style: TextStyle(fontSize: 24, color: Colors.green.shade700, fontWeight: FontWeight.bold),
              ),
            ),
            accountName: Text(_customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            accountEmail: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_customerPhone),
                if (_customerEmail.isNotEmpty) Text(_customerEmail, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent_outlined),
            title: const Text('Support'),
            onTap: () {
              // TODO: Add support action
            },
          ),
          const Spacer(),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red.shade600),
            title: Text('Logout', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w600)),
            onTap: () async {
              Navigator.pop(context); // Close drawer
              await supabase.auth.signOut();
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthPage()));
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('My Orders', style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: [
              Tab(text: 'Active Orders'),
              Tab(text: 'Past History'),
            ],
          ),
        ),
        drawer: _buildDrawer(context),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          elevation: 4,
          onPressed: () async {
            final bool? didCreate = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CustomerCreateWayPage()),
            );
            if (didCreate == true) {
              setState(() => _isLoading = true);
              _fetchCustomerData();
            }
          },
          label: const Text("New Order", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          icon: const Icon(Icons.add_box_outlined),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.green.shade700))
            : TabBarView(
          children: [
            _buildOrderList(_activeWays, 'No active orders right now.', Icons.local_shipping_outlined),
            _buildOrderList(_pastWays, 'No past order history.', Icons.history),
          ],
        ),
      ),
    );
  }
}

// --- EXTRACTED COMPONENT FOR CLEANER CODE ---

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> way;
  final String fallbackCustomerName;
  final VoidCallback onTap;

  const _OrderCard({
    required this.way,
    required this.fallbackCustomerName,
    required this.onTap,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange.shade600;
      case 'picked_up': return Colors.blue.shade600;
      case 'delivering': return Colors.purple.shade600;
      case 'dropped':
      case 'delivered': return Colors.green.shade600;
      case 'rejected':
      case 'cancelled': return Colors.red.shade600;
      default: return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = way['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);

    final riderName = way['rider']?['full_name'] ?? 'Unassigned';
    final riderPhone = way['rider']?['phone'] ?? 'Waiting for rider...';

    final customerName = way['customer']?['full_name'] ?? fallbackCustomerName;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      'Order #${way['id']}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87)
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Routing UI ---
              IntrinsicHeight(
                child: Row(
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.radio_button_checked, color: Colors.blue, size: 16),
                        Expanded(child: Container(width: 1.5, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(vertical: 4))),
                        const Icon(Icons.location_on, color: Colors.red, size: 18),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(way['pickup_location'] ?? 'Unknown', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 16),
                          Text(way['drop_location'] ?? 'Unknown', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 12),

              // --- Personnel Block ---
              Row(
                children: [
                  // Rider Info (Highlighted as it's most relevant to the customer)
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.orange.shade50,
                          child: Icon(Icons.motorcycle, size: 18, color: Colors.orange.shade700),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(riderName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(riderPhone, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(width: 1, height: 30, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 12)),

                  // Customer Name (Simplified to just show who ordered it, good for multi-user accounts)
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Ordered by', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(customerName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}