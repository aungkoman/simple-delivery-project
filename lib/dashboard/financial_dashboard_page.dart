import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../finance/rider_cash_collection_page.dart';
import '../finance/rider_fee_payout_page.dart';

class FinancialDashboardPage extends StatefulWidget {
  const FinancialDashboardPage({super.key});

  @override
  State<FinancialDashboardPage> createState() => _FinancialDashboardPageState();
}

class _FinancialDashboardPageState extends State<FinancialDashboardPage> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;

  // --- Aggregate Financial Metrics ---
  double _totalRiderHoldingCash = 0.0;
  double _totalOwedToSenders = 0.0;
  double _totalOwedToRiders = 0.0;
  double _expectedHubRevenue = 0.0; // Gross delivery charges of completed orders

  // --- Actionable Data ---
  List<Map<String, dynamic>> _ridersHoldingCashList = [];
  List<Map<String, dynamic>> _ridersOwedFeesList = []; // NEW: List for rider payouts

  @override
  void initState() {
    super.initState();
    _fetchFinancialData();
  }

  Future<void> _fetchFinancialData() async {
    try {
      // Fetch ways that are relevant for accounting (Not cancelled)
      // Joined with rider to get names for the cash-holding list
      final response = await supabase
          .from('ways')
          .select('*, rider:profiles!ways_rider_id_fkey(id, full_name)')
          .neq('status', 'cancelled');

      double riderCash = 0;
      double owedSenders = 0;
      double owedRiders = 0;
      double hubRev = 0;

      // Temporary map to calculate which specific riders are holding cash
      Map<String, Map<String, dynamic>> riderCashMap = {};
      Map<String, Map<String, dynamic>> riderOwedMap = {}; // NEW: Map for owed fees

      for (var way in response) {
        final double amountToCollect = double.tryParse(way['amount_to_collect']?.toString() ?? '0') ?? 0;
        final double riderFee = double.tryParse(way['rider_fee']?.toString() ?? '0') ?? 0;
        final double parcelValue = double.tryParse(way['parcel_value']?.toString() ?? '0') ?? 0;
        final double deliveryCharges = double.tryParse(way['delivery_charges']?.toString() ?? '0') ?? 0;

        final String payStatus = way['pay_status']?.toString().toLowerCase() ?? 'pending';
        final String riderFeeStatus = way['rider_fee_status']?.toString().toLowerCase() ?? 'pending';
        final String senderPayoutStatus = way['sender_payout_status']?.toString().toLowerCase() ?? 'pending';
        final String opStatus = way['status']?.toString().toLowerCase() ?? 'pending';
        final String paymentType = way['payment_type']?.toString().toLowerCase() ?? 'prepaid';

        // 1. RIDER HOLDING CASH
        // If the status is 'collected', it means the rider took the money but hasn't given it to the hub ('remitted_to_office')
        if (payStatus == 'collected') {
          riderCash += amountToCollect;

          // Add to individual rider's tally
          final riderData = way['rider'];
          if (riderData != null) {
            final riderId = riderData['id'];
            final riderName = riderData['full_name'] ?? 'Unknown';
            if (!riderCashMap.containsKey(riderId)) {
              riderCashMap[riderId] = {'id': riderId, 'name': riderName, 'amount': 0.0, 'order_count': 0};
            }
            riderCashMap[riderId]!['amount'] += amountToCollect;
            riderCashMap[riderId]!['order_count'] += 1;
          }
        }

        // 2. OWED TO SENDERS (COD Payouts)
        // If the item was delivered (dropped), it was COD, and we haven't paid the sender yet.
        if (opStatus == 'dropped' && paymentType == 'cod' && senderPayoutStatus == 'pending') {
          owedSenders += parcelValue;
        }

        // 3. OWED TO RIDERS
        // Unsettled rider fees for completed deliveries
        if (opStatus == 'dropped' && riderFeeStatus == 'pending') {
          owedRiders += riderFee;

          // NEW: Add to individual rider's owed tally
          final riderData = way['rider'];
          if (riderData != null) {
            final riderId = riderData['id'];
            final riderName = riderData['full_name'] ?? 'Unknown';
            if (!riderOwedMap.containsKey(riderId)) {
              riderOwedMap[riderId] = {'id': riderId, 'name': riderName, 'amount': 0.0, 'order_count': 0};
            }
            riderOwedMap[riderId]!['amount'] += riderFee;
            riderOwedMap[riderId]!['order_count'] += 1;
          }
        }

        // 4. HUB GROSS REVENUE
        // Value of delivery charges for all successfully dropped items
        if (opStatus == 'dropped') {
          hubRev += deliveryCharges;
        }
      }

      // Convert the rider map to a sorted list (Highest cash holders first)
      List<Map<String, dynamic>> sortedRiders = riderCashMap.values.toList();
      sortedRiders.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

      List<Map<String, dynamic>> sortedOwedRiders = riderOwedMap.values.toList();
      sortedOwedRiders.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

      if (mounted) {
        setState(() {
          _totalRiderHoldingCash = riderCash;
          _totalOwedToSenders = owedSenders;
          _totalOwedToRiders = owedRiders;
          _expectedHubRevenue = hubRev;
          _ridersHoldingCashList = sortedRiders;
          _ridersOwedFeesList = sortedOwedRiders; // Save the new list
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

  // --- UI Helpers ---
  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return "${(amount / 1000000).toStringAsFixed(2)}M Ks";
    } else if (amount >= 1000) {
      return "${(amount / 1000).toStringAsFixed(1)}K Ks";
    }
    return "${amount.toStringAsFixed(0)} Ks";
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _formatCurrency(amount),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Financial Overview', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {
            setState(() => _isLoading = true);
            _fetchFinancialData();
          })
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.blueGrey.shade900))
          : RefreshIndicator(
        onRefresh: _fetchFinancialData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Company Balance Sheet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // --- 2x2 GRID FOR METRICS ---
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  _buildMetricCard(
                    title: 'Riders Cash',
                    amount: _totalRiderHoldingCash,
                    icon: Icons.account_balance_wallet,
                    color: Colors.orange.shade600,
                    subtitle: 'Collected, pending remit',
                  ),
                  _buildMetricCard(
                    title: 'Owed to Senders',
                    amount: _totalOwedToSenders,
                    icon: Icons.storefront,
                    color: Colors.red.shade500,
                    subtitle: 'COD payouts pending',
                  ),
                  _buildMetricCard(
                    title: 'Owed to Riders',
                    amount: _totalOwedToRiders,
                    icon: Icons.motorcycle,
                    color: Colors.indigo.shade500,
                    subtitle: 'Unpaid delivery fees',
                  ),
                  _buildMetricCard(
                    title: 'Gross Revenue',
                    amount: _expectedHubRevenue,
                    icon: Icons.trending_up,
                    color: Colors.green.shade600,
                    subtitle: 'Completed deliveries',
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // --- ACTIONABLE LIST: RIDERS HOLDING CASH ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Cash Collection Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
                    child: Text('${_ridersHoldingCashList.length} Riders', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                  )
                ],
              ),
              const SizedBox(height: 12),

              _ridersHoldingCashList.isEmpty
                  ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade300),
                    const SizedBox(height: 12),
                    Text('All cash is settled.', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              )
                  : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _ridersHoldingCashList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final rider = _ridersHoldingCashList[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      // 1. Navigate to the new collection page
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RiderCashCollectionPage(
                            riderId: rider['id'],
                            riderName: rider['name'],
                          ),
                        ),
                      );
                      // 2. Refresh the dashboard when the admin comes back!
                      setState(() => _isLoading = true);
                      _fetchFinancialData();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade100),
                        // Highlight the worst offender with a shadow
                        boxShadow: index == 0 ? [BoxShadow(color: Colors.red.shade100, blurRadius: 8, offset: const Offset(0, 2))] : [],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: index == 0 ? Colors.red.shade100 : Colors.grey.shade100,
                            foregroundColor: index == 0 ? Colors.red.shade700 : Colors.black54,
                            child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(rider['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 4),
                                Text('Across ${rider['order_count']} orders', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(
                            _formatCurrency(rider['amount']),
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.orange.shade700),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),


              // --- ACTIONABLE LIST 2: RIDER PAYOUTS (FEES) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rider Fee Payouts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(20)),
                    child: Text('${_ridersOwedFeesList.length} Riders', style: TextStyle(color: Colors.indigo.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                  )
                ],
              ),
              const SizedBox(height: 12),

              _ridersOwedFeesList.isEmpty
                  ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade300),
                    const SizedBox(height: 12),
                    Text('All rider fees are paid.', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              )
                  : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _ridersOwedFeesList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final rider = _ridersOwedFeesList[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async{
                      // Setup navigation for Rider Fee Payout Page here
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RiderFeePayoutPage(
                            riderId: rider['id'],
                            riderName: rider['name'],
                          ),
                        ),
                      );
                      setState(() => _isLoading = true);
                      _fetchFinancialData();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.indigo.shade100),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.indigo.shade50,
                            foregroundColor: Colors.indigo.shade700,
                            child: const Icon(Icons.motorcycle, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(rider['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 4),
                                Text('Fees for ${rider['order_count']} delivered orders', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(
                            _formatCurrency(rider['amount']),
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.indigo.shade700),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}