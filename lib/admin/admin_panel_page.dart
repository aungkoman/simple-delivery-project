import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      // 1. Fetch exact counts directly from Supabase for efficiency
      final admins = await supabase.from('profiles').count(CountOption.exact).eq('role', 'admin');
      final riders = await supabase.from('profiles').count(CountOption.exact).eq('role', 'rider');
      final customers = await supabase.from('profiles').count(CountOption.exact).eq('role', 'customer');
      final ways = await supabase.from('ways').count(CountOption.exact);

      // 2. Update the UI state
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

  // A reusable widget for the dashboard cards
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        // Use a GridView to display the stats nicely
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