import 'package:flutter/material.dart';
import 'package:simpledelivery/way/way_detail_read_only_page.dart';
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
  String _currentFilter = 'all'; // Filters: 'all', 'dropped', 'cancelled'

  @override
  void initState() {
    super.initState();
    _fetchAllMyWays();
  }

  Future<void> _fetchAllMyWays() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // PERFORMANCE FIX: Added created_at and .limit(100) to prevent memory crashes
      final response = await supabase
          .from('ways')
          .select('id, pickup_location, drop_location, status, created_at, customer:profiles!ways_customer_id_fkey(full_name)')
          .eq('rider_id', user.id)
          .order('id', ascending: false)
          .limit(100);

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

  // --- DATA FILTERING ---
  List<dynamic> get _displayedWays {
    if (_currentFilter == 'all') return _allMyWays;
    return _allMyWays.where((way) => way['status'] == _currentFilter).toList();
  }

  // --- UI HELPERS ---
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

  String _formatDate(String? isoString) {
    if (isoString == null) return 'Unknown Date';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final padMin = date.minute.toString().padLeft(2, '0');
      return "${date.day} ${months[date.month - 1]}, ${date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour)}:$padMin ${date.hour >= 12 ? 'PM' : 'AM'}";
    } catch (_) {
      return 'Invalid Date';
    }
  }

  Widget _buildFilterChip(String label, String filterValue) {
    final isSelected = _currentFilter == filterValue;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: Colors.indigo.shade50,
        labelStyle: TextStyle(
          color: isSelected ? Colors.indigo.shade700 : Colors.grey.shade700,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.white,
        side: BorderSide(color: isSelected ? Colors.indigo.shade300 : Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (selected) {
          if (selected) setState(() => _currentFilter = filterValue);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Delivery History', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.grey.shade900, // Premium dark header
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Row
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All History', 'all'),
                  _buildFilterChip('Completed', 'dropped'),
                  _buildFilterChip('Cancelled', 'cancelled'),
                ],
              ),
            ),
          ),

          // Main List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchAllMyWays,
              color: Colors.green.shade700,
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: Colors.grey.shade800))
                  : _displayedWays.isEmpty
                  ? ListView(
                children: [
                  const SizedBox(height: 150),
                  Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No deliveries found in this category.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                    ),
                  ),
                ],
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _displayedWays.length,
                itemBuilder: (context, index) {
                  final way = _displayedWays[index];
                  final customerName = way['customer']?['full_name'] ?? 'Unknown Customer';
                  final status = way['status'] ?? 'unknown';
                  final statusColor = _getStatusColor(status);

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => WayDetailReadOnlyPage(wayData: way)),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: ID and Status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Order #${way['id']}',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
                                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Date and Customer
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 6),
                                Text(_formatDate(way['created_at']), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.person, size: 16, color: Colors.blue.shade400),
                                const SizedBox(width: 6),
                                Text(customerName, style: const TextStyle(fontWeight: FontWeight.w500)),
                              ],
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1),
                            ),

                            // Locations
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.radio_button_checked, color: Colors.orange, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(way['pickup_location'] ?? 'N/A', style: TextStyle(color: Colors.grey.shade700, fontSize: 13))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on, color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(way['drop_location'] ?? 'N/A', style: TextStyle(color: Colors.grey.shade700, fontSize: 13))),
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
          ),
        ],
      ),
    );
  }
}