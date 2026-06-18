import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RiderCashCollectionPage extends StatefulWidget {
  final String riderId;
  final String riderName;

  const RiderCashCollectionPage({
    super.key,
    required this.riderId,
    required this.riderName,
  });

  @override
  State<RiderCashCollectionPage> createState() => _RiderCashCollectionPageState();
}

class _RiderCashCollectionPageState extends State<RiderCashCollectionPage> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<dynamic> _collectedWays = [];
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchRiderCashWays();
  }

  Future<void> _fetchRiderCashWays() async {
    try {
      final response = await supabase
          .from('ways')
          .select('*, customer:profiles!ways_customer_id_fkey(full_name)')
          .eq('rider_id', widget.riderId)
          .eq('pay_status', 'collected')
          .order('updated_at', ascending: false);

      double total = 0.0;
      for (var way in response) {
        total += double.tryParse(way['amount_to_collect']?.toString() ?? '0') ?? 0;
      }

      if (mounted) {
        setState(() {
          _collectedWays = response;
          _totalAmount = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Collect Single Order ---
  Future<void> _collectSingleOrder(int wayId, double amount) async {
    try {
      await supabase
          .from('ways')
          .update({'pay_status': 'remitted_to_office'})
          .eq('id', wayId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Collected ${_formatCurrency(amount)}'), backgroundColor: Colors.green),
        );
      }
      _fetchRiderCashWays(); // Refresh the list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // --- Collect ALL Orders (Bulk Update) ---
  Future<void> _collectAllCash() async {
    setState(() => _isSubmitting = true);
    try {
      // Powerful single-query bulk update!
      await supabase
          .from('ways')
          .update({'pay_status': 'remitted_to_office'})
          .eq('rider_id', widget.riderId)
          .eq('pay_status', 'collected');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All cash collected successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back to the dashboard since list is now empty
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  String _formatCurrency(double amount) {
    return "${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)} Ks";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Cash Collection', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.blueGrey.shade900))
          : Column(
        children: [
          // --- SUMMARY HEADER ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.orange.shade100,
                  child: Icon(Icons.person, size: 30, color: Colors.orange.shade800),
                ),
                const SizedBox(height: 12),
                Text(widget.riderName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Holding ${_collectedWays.length} collected orders', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Text('TOTAL CASH TO COLLECT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                      Text(_formatCurrency(_totalAmount), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.orange.shade900)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- LIST OF ORDERS ---
          Expanded(
            child: _collectedWays.isEmpty
                ? const Center(child: Text('No cash pending collection for this rider.'))
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _collectedWays.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final way = _collectedWays[index];
                final customerName = way['customer']?['full_name'] ?? 'Unknown Customer';
                final double amount = double.tryParse(way['amount_to_collect']?.toString() ?? '0') ?? 0;

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text('Order #${way['id']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(customerName),
                        Text(
                          _formatCurrency(amount),
                          style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _collectSingleOrder(way['id'], amount),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade50,
                        foregroundColor: Colors.green.shade700,
                        elevation: 0,
                      ),
                      child: const Text('Collect'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // --- BOTTOM ACTION BAR ---
      bottomNavigationBar: _collectedWays.isEmpty
          ? null
          : Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _collectAllCash,
            icon: const Icon(Icons.check_circle),
            label: _isSubmitting
                ? const CircularProgressIndicator(color: Colors.white)
                : Text('Collect All Cash (${_formatCurrency(_totalAmount)})'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}