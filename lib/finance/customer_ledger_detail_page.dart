import 'package:flutter/material.dart';
import 'package:simpledelivery/way/way_detail_read_only_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerLedgerDetailPage extends StatefulWidget {
  final String customerId;
  final String customerName;
  final List<int> wayIds;
  final double netPayout;

  const CustomerLedgerDetailPage({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.wayIds,
    required this.netPayout,
  });

  @override
  State<CustomerLedgerDetailPage> createState() => _CustomerLedgerDetailPageState();
}

class _CustomerLedgerDetailPageState extends State<CustomerLedgerDetailPage> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<dynamic> _ledgerWays = [];

  @override
  void initState() {
    super.initState();
    _fetchLedgerDetails();
  }

  Future<void> _fetchLedgerDetails() async {
    if (widget.wayIds.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // UPGRADE: Fetch customer and rider relationships so the WayDetailReadOnlyPage has all the info it needs!
      final response = await supabase
          .from('ways')
          .select('*, customer:profiles!ways_customer_id_fkey(full_name, phone), rider:profiles!ways_rider_id_fkey(full_name, phone)')
          .inFilter('id', widget.wayIds)
          .order('updated_at', ascending: false);

      if (mounted) {
        setState(() {
          _ledgerWays = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _settleCustomerBalance() async {
    setState(() => _isSubmitting = true);
    try {
      await supabase
          .from('ways')
          .update({'sender_payout_status': 'settled'})
          .inFilter('id', widget.wayIds)
          .eq('payment_type', 'cod');

      await supabase
          .from('ways')
          .update({'pay_status': 'settled'})
          .inFilter('id', widget.wayIds)
          .eq('who_paid', 'sender');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Settled ${_formatCurrency(widget.netPayout)} successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  String _formatCurrency(double amount) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final formatted = "${absAmount.toStringAsFixed(absAmount.truncateToDouble() == absAmount ? 0 : 2)} Ks";
    return isNegative ? "-$formatted" : formatted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('${widget.customerName} Ledger', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
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
                Text(widget.netPayout >= 0 ? 'TOTAL PAYOUT TO SENDER' : 'AMOUNT SENDER OWES US', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency(widget.netPayout.abs()),
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: widget.netPayout >= 0 ? Colors.green.shade700 : Colors.red.shade700
                  ),
                ),
                const SizedBox(height: 4),
                Text('Calculated from ${_ledgerWays.length} recent orders', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ],
            ),
          ),

          // --- DETAILED ORDER LIST ---
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _ledgerWays.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final way = _ledgerWays[index];
                final double parcelValue = double.tryParse(way['parcel_value']?.toString() ?? '0') ?? 0;
                final double deliveryCharge = double.tryParse(way['delivery_charges']?.toString() ?? '0') ?? 0;

                final paymentType = way['payment_type']?.toString().toLowerCase() ?? 'prepaid';
                final whoPaid = way['who_paid']?.toString().toLowerCase() ?? 'sender';
                final senderPayoutStatus = way['sender_payout_status']?.toString().toLowerCase() ?? 'pending';
                final payStatus = way['pay_status']?.toString().toLowerCase() ?? 'pending';

                double codOwed = (paymentType == 'cod' && senderPayoutStatus == 'pending') ? parcelValue : 0;
                double feeOwed = (whoPaid == 'sender' && payStatus == 'pending') ? deliveryCharge : 0;
                double netForOrder = codOwed - feeOwed;

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    // UPGRADE: Passing the actual 'way' data to the detail page!
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WayDetailReadOnlyPage(
                          wayData: way as Map<String, dynamic>,
                        ),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Order #${way['id']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                              Text(
                                _formatCurrency(netForOrder),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: netForOrder >= 0 ? Colors.green.shade700 : Colors.red.shade700
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Drop Location: ${way['drop_location'] ?? 'Unknown'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('COD Collected', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                              Text(codOwed > 0 ? _formatCurrency(codOwed) : '-', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Delivery Fee', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                              Text(feeOwed > 0 ? '- ${_formatCurrency(feeOwed)}' : '-', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // --- BOTTOM ACTION BAR ---
      bottomNavigationBar: _ledgerWays.isEmpty
          ? null
          : Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _settleCustomerBalance,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.netPayout >= 0 ? Colors.blueGrey.shade900 : Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            child: _isSubmitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(widget.netPayout >= 0 ? 'Mark Ledger as Transferred' : 'Mark Ledger as Collected'),
          ),
        ),
      ),
    );
  }
}