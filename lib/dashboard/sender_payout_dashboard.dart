import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../finance/customer_ledger_detail_page.dart';

class SenderPayoutDashboard extends StatefulWidget {
  const SenderPayoutDashboard({super.key});

  @override
  State<SenderPayoutDashboard> createState() => _SenderPayoutDashboardState();
}

class _SenderPayoutDashboardState extends State<SenderPayoutDashboard> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSubmitting = false;

  // A list holding the calculated financial ledger for each customer
  List<Map<String, dynamic>> _customerLedgers = [];
  double _totalNetPayout = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchCustomerLedgers();
  }

  Future<void> _fetchCustomerLedgers() async {
    try {
      // Fetch all completed deliveries where there is either a pending COD payout OR a pending delivery fee
      final response = await supabase
          .from('ways')
          .select('*, customer:profiles!ways_customer_id_fkey(id, full_name, phone)')
          .eq('status', 'dropped') // Only calculate completed deliveries
          .or('sender_payout_status.eq.pending,pay_status.eq.pending');

      Map<String, Map<String, dynamic>> ledgerMap = {};
      double totalNet = 0.0;

      for (var way in response) {
        final customer = way['customer'];
        if (customer == null) continue;

        final String customerId = customer['id'];
        final String customerName = customer['full_name'] ?? 'Unknown Sender';
        final String customerPhone = customer['phone'] ?? 'No Phone';

        final double parcelValue = double.tryParse(way['parcel_value']?.toString() ?? '0') ?? 0;
        final double deliveryCharge = double.tryParse(way['delivery_charges']?.toString() ?? '0') ?? 0;

        final paymentType = way['payment_type']?.toString().toLowerCase() ?? 'prepaid';
        final whoPaid = way['who_paid']?.toString().toLowerCase() ?? 'sender';
        final senderPayoutStatus = way['sender_payout_status']?.toString().toLowerCase() ?? 'pending';
        final payStatus = way['pay_status']?.toString().toLowerCase() ?? 'pending';

        // Initialize ledger for this customer if it doesn't exist
        if (!ledgerMap.containsKey(customerId)) {
          ledgerMap[customerId] = {
            'customer_id': customerId,
            'customer_name': customerName,
            'customer_phone': customerPhone,
            'cod_owed_to_customer': 0.0,
            'fees_owed_by_customer': 0.0,
            'order_count': 0,
            'way_ids': <int>[], // Keep track of the specific ways to update them later
          };
        }

        bool involvedInLedger = false;

        // 1. Money we OWE the customer (COD Collected)
        if (paymentType == 'cod' && senderPayoutStatus == 'pending') {
          ledgerMap[customerId]!['cod_owed_to_customer'] += parcelValue;
          involvedInLedger = true;
        }

        // 2. Money the customer OWES us (Unpaid Delivery Charges)
        if (whoPaid == 'sender' && payStatus == 'pending') {
          ledgerMap[customerId]!['fees_owed_by_customer'] += deliveryCharge;
          involvedInLedger = true;
        }

        if (involvedInLedger) {
          ledgerMap[customerId]!['order_count'] += 1;
          ledgerMap[customerId]!['way_ids'].add(way['id']);
        }
      }

      // Filter out empty ledgers and calculate the Net Payout
      List<Map<String, dynamic>> finalLedgers = [];
      for (var entry in ledgerMap.values) {
        final double cod = entry['cod_owed_to_customer'];
        final double fees = entry['fees_owed_by_customer'];

        // If there's actually money moving in either direction
        if (cod > 0 || fees > 0) {
          final double netPayout = cod - fees;
          entry['net_payout'] = netPayout;
          totalNet += netPayout;
          finalLedgers.add(entry);
        }
      }

      // Sort by highest payout owed
      finalLedgers.sort((a, b) => (b['net_payout'] as double).compareTo(a['net_payout'] as double));

      if (mounted) {
        setState(() {
          _customerLedgers = finalLedgers;
          _totalNetPayout = totalNet;
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

  // --- Settle a specific customer's balance ---
  Future<void> _settleCustomerBalance(String customerId, List<int> wayIds, double netAmount) async {
    setState(() => _isSubmitting = true);
    try {
      // 1. Update COD payouts to 'settled'
      await supabase
          .from('ways')
          .update({'sender_payout_status': 'settled'})
          .inFilter('id', wayIds)
          .eq('payment_type', 'cod');

      // 2. Update Delivery Fees to 'settled'
      await supabase
          .from('ways')
          // .update({'pay_status': 'settled'})
          .update({'sender_payout_status': 'settled'})
          .inFilter('id', wayIds)
          .eq('who_paid', 'sender');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Settled ${_formatCurrency(netAmount)} balance successfully!'), backgroundColor: Colors.green),
        );
        _fetchCustomerLedgers(); // Refresh UI
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    finally{
      setState(() => _isSubmitting = false);
    }
  }

  String _formatCurrency(double amount) {
    // Handle negative numbers gracefully
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
        title: const Text('Customer Payouts', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {
            setState(() => _isLoading = true);
            _fetchCustomerLedgers();
          })
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.blueGrey.shade900))
          : Column(
        children: [
          // --- TOTALS HEADER ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                Text('TOTAL PENDING PAYOUTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1)),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency(_totalNetPayout),
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: _totalNetPayout >= 0 ? Colors.green.shade700 : Colors.red.shade700
                  ),
                ),
                const SizedBox(height: 4),
                Text('Across ${_customerLedgers.length} active sellers', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ],
            ),
          ),

          // --- LEDGER LIST ---
          Expanded(
            child: _customerLedgers.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
                  const SizedBox(height: 16),
                  Text('All customer accounts are settled.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                ],
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _customerLedgers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final ledger = _customerLedgers[index];
                final double codOwed = ledger['cod_owed_to_customer'];
                final double feesOwed = ledger['fees_owed_by_customer'];
                final double netPayout = ledger['net_payout'];

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    // Navigate to the detail page and wait for a result
                    final bool? didSettle = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CustomerLedgerDetailPage(
                          customerId: ledger['customer_id'],
                          customerName: ledger['customer_name'],
                          wayIds: ledger['way_ids'],
                          netPayout: netPayout,
                        ),
                      ),
                    );

                    // If the admin clicked "Settle" on the detail page, refresh this dashboard!
                    if (didSettle == true) {
                      setState(() => _isLoading = true);
                      _fetchCustomerLedgers();
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      children: [
                        // Customer Info Header
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blueGrey.shade50,
                                child: Icon(Icons.storefront, color: Colors.blueGrey.shade700),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ledger['customer_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text(ledger['customer_phone'], style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                                child: Text('${ledger['order_count']} Orders', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                              )
                            ],
                          ),
                        ),
                        Divider(height: 1, color: Colors.grey.shade200),
                  
                        // Ledger Math
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('COD to Remit (Owed to Sender)', style: TextStyle(color: Colors.grey)),
                                  Text(_formatCurrency(codOwed), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Delivery Fees (Owed to Us)', style: TextStyle(color: Colors.grey)),
                                  Text('- ${_formatCurrency(feesOwed)}', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(netPayout >= 0 ? 'NET PAYOUT' : 'SENDER OWES US', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(
                                    _formatCurrency(netPayout.abs()),
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: netPayout >= 0 ? Colors.black87 : Colors.red.shade700
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                  
                              // Action Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting
                                      ? null
                                      : () => _settleCustomerBalance(ledger['customer_id'], ledger['way_ids'], netPayout),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: netPayout >= 0 ? Colors.blueGrey.shade900 : Colors.orange.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                      netPayout >= 0 ? 'Mark as Transferred' : 'Mark as Collected',
                                      style: const TextStyle(fontWeight: FontWeight.bold)
                                  ),
                                ),
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
        ],
      ),
    );
  }
}