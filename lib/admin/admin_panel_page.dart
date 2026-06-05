import 'package:flutter/material.dart';
import 'package:simpledelivery/way/way_listing_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth_page.dart';
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
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // --- UI COMPONENTS ---

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            count.toString(),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }



  Widget _buildCustomDrawerHeader(BuildContext context) {
    return Container(
      width: double.infinity, // <--- ADD THIS LINE
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 24,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade800, Colors.indigo.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white,
              child: Icon(Icons.shield_outlined, size: 32, color: Colors.indigo.shade700),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Admin Control',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          Text(
            'System Management Dashboard',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          _buildCustomDrawerHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ListTile(
                  leading: Icon(Icons.dashboard_outlined, color: Colors.indigo.shade700),
                  title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
                  selected: true,
                  selectedTileColor: Colors.indigo.shade50,
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.people_outline, color: Colors.black54),
                  title: const Text('User Management'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const UserListingPage()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.route_outlined, color: Colors.black54),
                  title: const Text('Delivery Management'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const WayListingPage()));
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red.shade600),
            title: Text('Secure Logout', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w600)),
            onTap: () async {
              Navigator.pop(context);
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('System Overview', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Stats',
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchDashboardStats();
            },
          )
        ],
      ),
      drawer: _buildDrawer(context),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.indigo.shade700))
          : RefreshIndicator(
        onRefresh: _fetchDashboardStats,
        color: Colors.indigo.shade700,
        child: GridView.count(
          padding: const EdgeInsets.all(20.0),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          // Makes the cards slightly taller than they are wide
          childAspectRatio: 0.9,
          children: [
            _buildStatCard('Admins', _adminCount, Icons.admin_panel_settings_outlined, Colors.indigo),
            _buildStatCard('Riders', _riderCount, Icons.motorcycle_outlined, Colors.orange.shade600),
            _buildStatCard('Customers', _customerCount, Icons.people_outline, Colors.teal.shade600),
            _buildStatCard('Total Deliveries', _wayCount, Icons.local_shipping_outlined, Colors.blue.shade600),
          ],
        ),
      ),
    );
  }
}