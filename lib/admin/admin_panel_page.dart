import 'package:flutter/material.dart';
import 'package:simpledelivery/way/way_listing_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../user/user_listing_page.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  int _adminCount = 0;
  int _riderCount = 0;
  int _customerCount = 0;
  int _wayCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardStats();
  }

  Future<void> _fetchDashboardStats() async {
    try {
      final admins = await supabase.from('profiles').count(CountOption.exact).eq('role', 'admin');
      final riders = await supabase.from('profiles').count(CountOption.exact).eq('role', 'rider');
      final customers = await supabase.from('profiles').count(CountOption.exact).eq('role', 'customer');
      final ways = await supabase.from('ways').count(CountOption.exact);

      if (mounted) {
        setState(() {
          _adminCount = admins;
          _riderCount = riders;
          _customerCount = customers;
          _wayCount = ways;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading stats: $error'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              count.toString(),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  // --- NEW DRAWER WIDGET ---
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.admin_panel_settings, size: 48, color: Colors.white),
                SizedBox(height: 8),
                Text(
                  'Admin Control',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('User Management'),
            onTap: () {
              Navigator.pop(context); // Close the drawer first
              // Navigate to the User Listing Page
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserListingPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.route),
            title: const Text('Way Management'),
            onTap: () {
              Navigator.pop(context); // Close the drawer first
              // Navigate to the User Listing Page
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WayListingPage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              await supabase.auth.signOut();
              // Optionally route back to your Login Screen here if you aren't using an Auth listener
              // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthPage()));
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
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Stats',
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchDashboardStats();
            },
          )
        ],
      ),
      drawer: _buildDrawer(context), // Attach the Drawer here
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildStatCard('Admins', _adminCount, Icons.admin_panel_settings, Colors.blue),
            _buildStatCard('Riders', _riderCount, Icons.motorcycle, Colors.orange),
            _buildStatCard('Customers', _customerCount, Icons.people, Colors.green),
            _buildStatCard('Total Ways', _wayCount, Icons.local_shipping, Colors.purple),
          ],
        ),
      ),
    );
  }
}