import 'package:flutter/material.dart';
import 'package:simpledelivery/way/way_create_page.dart';
import 'package:simpledelivery/way/way_edit_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WayListingByBillingPage extends StatefulWidget {
  final int initialIndex;

  const WayListingByBillingPage({super.key, this.initialIndex = 0});

  @override
  State<WayListingByBillingPage> createState() => _WayListingByBillingPageState();
}

class _WayListingByBillingPageState extends State<WayListingByBillingPage> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;

  // Categorized lists for Billing Tabs
  List<dynamic> _allWays = [];
  List<dynamic> _pendingPayWays = [];
  List<dynamic> _collectedPayWays = [];
  List<dynamic> _settledPayWays = [];

  @override
  void initState() {
    super.initState();
    _fetchWays();
  }

  Future<void> _fetchWays() async {
    try {
      final response = await supabase
          .from('ways')
          .select('''
            *,
            customer:profiles!ways_customer_id_fkey(full_name, phone),
            rider:profiles!ways_rider_id_fkey(full_name, phone)
          ''')
          .order('created_at', ascending: false);

      final pending = [];
      final collected = [];
      final settled = [];

      for (var way in response) {
        // Use pay_status for categorization instead of operational status
        final payStatus = way['pay_status']?.toString().toLowerCase() ?? 'pending';

        if (payStatus == 'pending') {
          pending.add(way);
        } else if (['collected', 'remitted_to_office'].contains(payStatus)) {
          collected.add(way);
        } else if (['settled', 'prepaid'].contains(payStatus)) {
          settled.add(way);
        } else {
          // Catch all others (like 'lost') in the "All" tab, or you can route them specifically
        }
      }

      if (mounted) {
        setState(() {
          _allWays = response;
          _pendingPayWays = pending;
          _collectedPayWays = collected;
          _settledPayWays = settled;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading billing data: $error'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // --- UI Helpers ---

  Widget _buildEmptyState(String message, IconData icon) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWayList(List<dynamic> ways, String emptyMessage, IconData emptyIcon) {
    return RefreshIndicator(
      onRefresh: _fetchWays,
      color: Colors.teal.shade700,
      child: ways.isEmpty
          ? _buildEmptyState(emptyMessage, emptyIcon)
          : ListView.separated(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
        itemCount: ways.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _BillingWayCard(
            way: ways[index],
            onRefreshRequested: () {
              setState(() => _isLoading = true);
              _fetchWays();
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialIndex,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Billing & Payments', style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.teal.shade800, // Changed color to distinguish from Operational view
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(text: 'All (${_isLoading ? '-' : _allWays.length})'),
              Tab(text: 'Unpaid (${_isLoading ? '-' : _pendingPayWays.length})'),
              Tab(text: 'Collected (${_isLoading ? '-' : _collectedPayWays.length})'),
              Tab(text: 'Settled (${_isLoading ? '-' : _settledPayWays.length})'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
          elevation: 4,
          onPressed: () async {
            final bool? didCreate = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WayCreatePage()),
            );
            if (didCreate == true) {
              setState(() => _isLoading = true);
              _fetchWays();
            }
          },
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('New Invoice', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.teal.shade700))
            : TabBarView(
          children: [
            _buildWayList(_allWays, 'No records found.', Icons.receipt_long),
            _buildWayList(_pendingPayWays, 'No unpaid deliveries.', Icons.hourglass_empty_rounded),
            _buildWayList(_collectedPayWays, 'No cash waiting to be settled.', Icons.account_balance_wallet_outlined),
            _buildWayList(_settledPayWays, 'No settled records.', Icons.check_circle_outline),
          ],
        ),
      ),
    );
  }
}

// --- REDESIGNED COMPONENT FOR BILLING ---

class _BillingWayCard extends StatelessWidget {
  final Map<String, dynamic> way;
  final VoidCallback onRefreshRequested;

  const _BillingWayCard({required this.way, required this.onRefreshRequested});

  Color _getPayStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange.shade600;
      case 'collected': return Colors.blue.shade600;
      case 'remitted_to_office': return Colors.purple.shade600;
      case 'settled':
      case 'prepaid': return Colors.green.shade600;
      case 'lost': return Colors.red.shade600;
      default: return Colors.grey.shade600;
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString == 'Unknown') return 'N/A';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final padMin = date.minute.toString().padLeft(2, '0');
      return "${date.day}/${date.month}/${date.year} ${date.hour}:$padMin";
    } catch (e) {
      return 'Invalid Date';
    }
  }

  // Helper to safely format numbers as currency
  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0 Ks';
    final double parsed = double.tryParse(amount.toString()) ?? 0.0;
    // Format to remove decimals if they are .00
    return "${parsed.toStringAsFixed(parsed.truncateToDouble() == parsed ? 0 : 2)} Ks";
  }

  @override
  Widget build(BuildContext context) {
    // Extract Financial Data
    final payStatus = way['pay_status'] ?? 'pending';
    final payStatusColor = _getPayStatusColor(payStatus);
    final paymentType = way['payment_type']?.toString().toUpperCase() ?? 'N/A';
    final whoPaid = way['who_paid'] ?? 'Unknown';
    final amountToCollect = way['amount_to_collect'];
    final deliveryCharges = way['delivery_charges'];

    // Extract Basic Data
    final customerName = way['customer']?['full_name'] ?? 'Unknown Customer';
    final riderName = way['rider']?['full_name'] ?? 'Unassigned';
    final createdAt = _formatDate(way['created_at']);
    final opStatus = way['status'] ?? 'pending';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final bool? didUpdate = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => WayEditPage(wayData: way)),
            );
            if (didUpdate == true) onRefreshRequested();
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Header Row: ID and Pay Status ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${way['id']}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: payStatusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: payStatusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        payStatus.toUpperCase().replaceAll('_', ' '),
                        style: TextStyle(color: payStatusColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // --- Financial Overview Section ---
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade100),
                  ),
                  child: Row(
                    children: [
                      // Amount to Collect (Highlighted)
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AMOUNT TO COLLECT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
                            const SizedBox(height: 4),
                            Text(
                              _formatCurrency(amountToCollect),
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.teal.shade900),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.teal.shade200, margin: const EdgeInsets.symmetric(horizontal: 12)),
                      // Delivery Fees
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DELIVERY FEE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              _formatCurrency(deliveryCharges),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // --- Billing Types (Prepaid vs COD) ---
                Row(
                  children: [
                    Icon(Icons.payment, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text('Type: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    Text(paymentType, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Icon(Icons.account_balance_wallet_rounded, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text('Paid By: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    Text(whoPaid.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 12),

                // --- Personnel Block ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person_outline, size: 14, color: Colors.teal.shade600),
                              const SizedBox(width: 4),
                              const Text('CUSTOMER', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(createdAt, style: TextStyle(fontSize: 11, color: Colors.grey.shade500))
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('RIDER (Op: $opStatus)', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              Icon(Icons.motorcycle_outlined, size: 14, color: Colors.orange.shade600),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(riderName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: riderName == 'Unassigned' ? Colors.grey : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}