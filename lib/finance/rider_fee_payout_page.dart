import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RiderFeePayoutPage extends StatefulWidget {
  final String riderId;
  final String riderName;

  const RiderFeePayoutPage({
    super.key,
    required this.riderId,
    required this.riderName,
  });

  @override
  State<RiderFeePayoutPage> createState() => _RiderFeePayoutPageState();
}

class _RiderFeePayoutPageState extends State<RiderFeePayoutPage> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<dynamic> _pendingFeeWays = [];
  double _totalFeeAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchPendingRiderFees();
  }

  Future<void> _fetchPendingRiderFees() async {
    try {
      // Fetch completed deliveries (dropped) where the rider hasn't been paid yet
      final response = await supabase
          .from('ways')
          .select('*, customer:profiles!ways_customer_id_fkey(full_name)')
          .eq('rider_id', widget.riderId)
          .eq('status', 'dropped') // Only pay for completed jobs
          .eq('rider_fee_status', 'pending')
          .order('updated_at', ascending: false);

      double total = 0.0;
      for (var way in response) {
        total += double.tryParse(way['rider_fee']?.toString() ?? '0') ?? 0;
      }

      if (mounted) {
        setState(() {
          _pendingFeeWays = response;
          _totalFeeAmount = total;
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

  // --- Pay Single Order Fee ---
  Future<void> _paySingleFee(int wayId, double amount) async {
    try {
      await supabase
          .from('ways')
          .update({'rider_fee_status': 'settled'})
          .eq('id', wayId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paid ${_formatCurrency(amount)}'), backgroundColor: Colors.green),
        );
      }
      _fetchPendingRiderFees(); // Refresh the list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // --- Pay ALL Fees (Bulk Update) ---
  Future<void> _payAllFees() async {
    setState(() => _isSubmitting = true);
    try {
      // Bulk update query
      await supabase
          .from('ways')
          .update({'rider_fee_status': 'settled'})
          .eq('rider_id', widget.riderId)
          .eq('status', 'dropped')
          .eq('rider_fee_status', 'pending');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All rider fees settled successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back to dashboard
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
        title: const Text('Rider Fee Payout', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.indigo.shade900))
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
                  backgroundColor: Colors.indigo.shade50,
                  child: Icon(Icons.motorcycle, size: 30, color: Colors.indigo.shade700),
                ),
                const SizedBox(height: 12),
                Text(widget.riderName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Unpaid fees across ${_pendingFeeWays.length} completed orders', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo.shade100),
                  ),
                  child: Column(
                    children: [
                      Text('TOTAL OUTSTANDING FEES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo.shade800)),
                      const SizedBox(height: 4),
                      Text(_formatCurrency(_totalFeeAmount), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.indigo.shade900)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- LIST OF ORDERS ---
          Expanded(
            child: _pendingFeeWays.isEmpty
                ? const Center(child: Text('No pending fees to pay for this rider.'))
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _pendingFeeWays.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final way = _pendingFeeWays[index];
                final customerName = way['customer']?['full_name'] ?? 'Unknown Customer';
                final double feeAmount = double.tryParse(way['rider_fee']?.toString() ?? '0') ?? 0;

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
                        Text('To: $customerName'),
                        const SizedBox(height: 4),
                        Text(
                          'Fee: ${_formatCurrency(feeAmount)}',
                          style: TextStyle(color: Colors.indigo.shade700, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _paySingleFee(way['id'], feeAmount),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade50,
                        foregroundColor: Colors.indigo.shade700,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Settle'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // --- BOTTOM ACTION BAR ---
      bottomNavigationBar: _pendingFeeWays.isEmpty
          ? null
          : Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _payAllFees,
            icon: const Icon(Icons.check_circle),
            label: _isSubmitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Pay All Fees (${_formatCurrency(_totalFeeAmount)})'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade700,
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