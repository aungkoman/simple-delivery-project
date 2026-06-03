import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WayListingPage extends StatefulWidget {
  const WayListingPage({super.key});

  @override
  State<WayListingPage> createState() => _WayListingPageState();
}

class _WayListingPageState extends State<WayListingPage> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<dynamic> _ways = [];

  @override
  void initState() {
    super.initState();
    _fetchWays();
  }

  Future<void> _fetchWays() async {
    try {
      // Fetch ways and JOIN the profiles table to get the actual names instead of just UUIDs
      // The syntax '!ways_customer_id_fkey' tells Supabase exactly which relationship to follow
      final response = await supabase
          .from('ways')
          .select('''
            *,
            customer:profiles!ways_customer_id_fkey(full_name),
            rider:profiles!ways_rider_id_fkey(full_name)
          ''')
          .order('id', ascending: false); // Newest deliveries first

      if (mounted) {
        setState(() {
          _ways = response;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading ways: $error'), backgroundColor: Colors.red),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper method to color-code the delivery status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'picked_up':
        return Colors.blue;
      case 'delivering':
        return Colors.purple;
      case 'dropped':
      case 'delivered':
        return Colors.green;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Way (Delivery) Management'),
      ),
      // FAB for the admin to manually create a new delivery way
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Create Way feature coming soon!')),
          );
        },
        tooltip: 'Add New Way',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchWays,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _ways.isEmpty
            ? ListView(
          children: const [
            SizedBox(height: 300),
            Center(child: Text('No deliveries found.')),
          ],
        )
            : ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: _ways.length,
          itemBuilder: (context, index) {
            final way = _ways[index];

            // Safely extract nested relational data
            final customerName = way['customer']?['full_name'] ?? 'Unknown Customer';
            final riderName = way['rider']?['full_name'] ?? 'Unassigned';

            final pickup = way['pickup_location'] ?? 'Unknown';
            final drop = way['drop_location'] ?? 'Unknown';
            final status = way['status'] ?? 'pending';

            return Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: ID and Status Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Way #${way['id']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Chip(
                          label: Text(
                            status.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: _getStatusColor(status),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const Divider(),

                    // Middle Section: Routing
                    Row(
                      children: [
                        const Icon(Icons.storefront, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Pickup: $pickup', style: const TextStyle(fontSize: 14))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Drop: $drop', style: const TextStyle(fontSize: 14))),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Bottom Section: Personnel
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Customer', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text(customerName, style: const TextStyle(fontWeight: FontWeight.w500)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Rider', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text(riderName, style: const TextStyle(fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}