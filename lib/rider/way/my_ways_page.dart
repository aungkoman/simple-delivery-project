import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyWaysPage extends StatefulWidget {
  const MyWaysPage({super.key});

  @override
  State<MyWaysPage> createState() => _MyWaysPageState();
}

class _MyWaysPageState extends State<MyWaysPage> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<dynamic> _allMyWays = [];

  @override
  void initState() {
    super.initState();
    _fetchAllMyWays();
  }

  Future<void> _fetchAllMyWays() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Fetch ALL ways assigned to this rider, including dropped and cancelled.
      // Order by ID descending so newest deliveries are at the top.
      final response = await supabase
          .from('ways')
          .select('*, customer:profiles!ways_customer_id_fkey(full_name)')
          .eq('rider_id', user.id)
          .order('id', ascending: false);

      if (mounted) {
        setState(() {
          _allMyWays = response;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $error'), backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Delivery History'),
        backgroundColor: Colors.orange,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAllMyWays,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _allMyWays.isEmpty
            ? ListView(
          children: const [
            SizedBox(height: 300),
            Center(child: Text('No delivery history found.')),
          ],
        )
            : ListView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: _allMyWays.length,
          itemBuilder: (context, index) {
            final way = _allMyWays[index];
            final customerName = way['customer']?['full_name'] ?? 'Unknown Customer';
            final status = way['status'] ?? 'unknown';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text('Order #${way['id']} - $customerName', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('Pickup: ${way['pickup_location']}'),
                    Text('Drop: ${way['drop_location']}'),
                  ],
                ),
                isThreeLine: true,
                trailing: Chip(
                  label: Text(
                    status.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: _getStatusColor(status),
                  padding: EdgeInsets.zero,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}