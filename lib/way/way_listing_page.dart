import 'package:flutter/material.dart';
import 'package:simpledelivery/way/way_create_page.dart';
import 'package:simpledelivery/way/way_edit_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WayListingPage extends StatefulWidget {

  final int initialIndex; // 1. Add this variable

  const WayListingPage({super.key, this.initialIndex = 0});

  @override
  State<WayListingPage> createState() => _WayListingPageState();
}

class _WayListingPageState extends State<WayListingPage> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;

  // Categorized lists for tabs
  List<dynamic> _allWays = [];
  List<dynamic> _pendingWays = [];
  List<dynamic> _activeWays = [];
  List<dynamic> _completedWays = [];

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
          .order('created_at', ascending: false); // Newest deliveries first

      final pending = [];
      final active = [];
      final completed = [];

      for (var way in response) {
        final status = way['status']?.toString().toLowerCase() ?? 'pending';
        if (status == 'pending') {
          pending.add(way);
        } else if (['picked_up', 'delivering'].contains(status)) {
          active.add(way);
        } else {
          // dropped, delivered, cancelled, rejected
          completed.add(way);
        }
      }

      if (mounted) {
        setState(() {
          _allWays = response;
          _pendingWays = pending;
          _activeWays = active;
          _completedWays = completed;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading deliveries: $error'),
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
      physics: const AlwaysScrollableScrollPhysics(), // Ensures pull-to-refresh works
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
      color: Colors.indigo.shade700,
      child: ways.isEmpty
          ? _buildEmptyState(emptyMessage, emptyIcon)
          : ListView.separated(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80), // Padding for FAB
        itemCount: ways.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _WayCard(
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
      length: 4, // All, Pending, Active, Completed
      initialIndex: widget.initialIndex,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Delivery Management', style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.indigo.shade700,
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
              Tab(text: 'Pending (${_isLoading ? '-' : _pendingWays.length})'),
              Tab(text: 'Active (${_isLoading ? '-' : _activeWays.length})'),
              Tab(text: 'Completed (${_isLoading ? '-' : _completedWays.length})'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.indigo.shade700,
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
          label: const Text('New Delivery', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.indigo.shade700))
            : TabBarView(
          children: [
            _buildWayList(_allWays, 'No deliveries found in the system.', Icons.local_shipping_outlined),
            _buildWayList(_pendingWays, 'No pending deliveries waiting for riders.', Icons.hourglass_empty_rounded),
            _buildWayList(_activeWays, 'No deliveries currently in transit.', Icons.motorcycle_outlined),
            _buildWayList(_completedWays, 'No completed or cancelled deliveries.', Icons.check_circle_outline),
          ],
        ),
      ),
    );
  }
}

// --- EXTRACTED COMPONENT ---

class _WayCard extends StatelessWidget {
  final Map<String, dynamic> way;
  final VoidCallback onRefreshRequested;

  const _WayCard({required this.way, required this.onRefreshRequested});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange.shade600;
      case 'picked_up': return Colors.blue.shade600;
      case 'delivering': return Colors.purple.shade600;
      case 'dropped':
      case 'delivered': return Colors.green.shade600;
      case 'rejected':
      case 'cancelled': return Colors.red.shade600;
      default: return Colors.grey.shade600;
    }
  }

  // --- NEW: Helper method to format Supabase timestamps safely ---
  String _formatDate(String? isoString) {
    if (isoString == null || isoString == 'Unknown') return 'N/A';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final padMin = date.minute.toString().padLeft(2, '0');
      // Format: DD/MM/YYYY at HH:MM
      return "${date.day}/${date.month}/${date.year} ${date.hour}:$padMin";
    } catch (e) {
      return 'Invalid Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = way['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);

    final customerName = way['customer']?['full_name'] ?? 'Unknown Customer';
    final riderName = way['rider']?['full_name'] ?? 'Unassigned';

    final pickup = way['pickup_location'] ?? 'Unknown';
    final drop = way['drop_location'] ?? 'Unknown';
    // Format the timestamps before injecting them into the UI
    final createdAt = _formatDate(way['created_at']);
    final updatedAt = _formatDate(way['updated_at']);

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
                // --- Header Row ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${way['id']}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // --- Routing UI ---
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.radio_button_checked, color: Colors.blue, size: 16),
                          Expanded(child: Container(width: 1.5, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(vertical: 4))),
                          const Icon(Icons.location_on, color: Colors.red, size: 18),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pickup, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                            const SizedBox(height: 16),
                            Text(drop, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                      // Forward Arrow Indicator
                      Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 12),

                // --- Personnel Block ---
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Customer Side
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
                            Text(createdAt , style: TextStyle(fontSize: 11, color: Colors.grey.shade500))
                          ],
                        ),
                      ),

                      // Vertical Divider
                      Container(width: 1, height: 30, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 12)),

                      // Rider Side
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Text('RIDER', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 4),
                                Icon(Icons.motorcycle_outlined, size: 14, color: Colors.orange.shade600),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(riderName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: riderName == 'Unassigned' ? Colors.grey : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),

                            Text(updatedAt,   style: TextStyle(fontSize: 11, color: Colors.grey.shade500))
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}