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

  // User Stats
  int _userCount = 0;
  int _adminCount = 0;
  int _riderCount = 0;
  int _customerCount = 0;

  // Delivery Stats
  int _wayCount = 0;
  int _pendingCount = 0;
  int _activeCount = 0;
  int _completedCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardStats();
  }

  Future<void> _fetchDashboardStats() async {
    try {
      // 1. Fetch User Counts
      final users = await supabase.from('profiles').count(CountOption.exact);
      final admins = await supabase.from('profiles').count(CountOption.exact).eq('role', 'admin');
      final riders = await supabase.from('profiles').count(CountOption.exact).eq('role', 'rider');
      final customers = await supabase.from('profiles').count(CountOption.exact).eq('role', 'customer');

      // 2. Fetch Delivery Counts (Using .or() for multiple status matches)
      final totalWays = await supabase.from('ways').count(CountOption.exact);
      final pendingWays = await supabase.from('ways').count(CountOption.exact).eq('status', 'pending');
      final activeWays = await supabase.from('ways').count(CountOption.exact).or('status.eq.picked_up,status.eq.delivering');
      final completedWays = await supabase.from('ways').count(CountOption.exact).or('status.eq.dropped,status.eq.delivered,status.eq.cancelled,status.eq.rejected');

      if (mounted) {
        setState(() {
          _userCount = users;
          _adminCount = admins;
          _riderCount = riders;
          _customerCount = customers;

          _wayCount = totalWays;
          _pendingCount = pendingWays;
          _activeCount = activeWays;
          _completedCount = completedWays;

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

  // Standard Card for secondary metrics (Users, History)
  Widget _buildStatCard(String title, int count, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 28, color: color),
                ),
                const SizedBox(height: 12),
                Text(
                  count.toString(),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Highlight Card for Primary Metrics (Pending & Active Deliveries)
  Widget _buildHighlightCard(String title, int count, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, size: 32, color: Colors.white),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Action Required', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  count.toString(),
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 24, left: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildCustomDrawerHeader(BuildContext context) {
    return Container(
      width: double.infinity,
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
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // --- TIER 1: ACTIVE OPERATIONS (Highest Priority) ---
              _buildSectionHeader('Current Operations'),
              Row(
                children: [
                  Expanded(
                    child: _buildHighlightCard('Pending\nOrders', _pendingCount, Icons.hourglass_empty_rounded, Colors.orange.shade600, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const WayListingPage(initialIndex: 1)));
                    }),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildHighlightCard('Active\nIn Transit', _activeCount, Icons.motorcycle_rounded, Colors.purple.shade600, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const WayListingPage(initialIndex: 2)));
                    }),
                  ),
                ],
              ),

              // --- TIER 2: DELIVERY HISTORY (Secondary Priority) ---
              _buildSectionHeader('Delivery Records'),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Completed', _completedCount, Icons.check_circle_outline, Colors.green.shade600, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const WayListingPage(initialIndex: 3)));
                    }),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard('Total Deliveries', _wayCount, Icons.local_shipping_outlined, Colors.blue.shade600, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const WayListingPage(initialIndex: 0)));
                    }),
                  ),
                ],
              ),

              // --- TIER 3: USER MANAGEMENT (Lowest Priority) ---
              _buildSectionHeader('Personnel & Users'),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Customers', _customerCount, Icons.people_outline, Colors.teal.shade600, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const UserListingPage(initialIndex: 3)));
                    }),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard('Riders', _riderCount, Icons.motorcycle_outlined, Colors.orange.shade600, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const UserListingPage(initialIndex: 2)));
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Admins', _adminCount, Icons.admin_panel_settings_outlined, Colors.indigo, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const UserListingPage(initialIndex: 1)));
                    }),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: _buildStatCard('All Users', _userCount, Icons.admin_panel_settings_outlined, Colors.indigo, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const UserListingPage(initialIndex: 0)));
                    }),
                  ),
                ],
              ),

              const SizedBox(height: 40), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }
}