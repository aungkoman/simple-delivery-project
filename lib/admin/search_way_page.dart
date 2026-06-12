import 'package:flutter/material.dart';
import 'package:simpledelivery/way/way_detail_read_only_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SearchWayPage extends StatefulWidget {
  const SearchWayPage({super.key});

  @override
  State<SearchWayPage> createState() => _SearchWayPageState();
}

class _SearchWayPageState extends State<SearchWayPage> {
  final supabase = Supabase.instance.client;

  // --- Search Controllers & State ---
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  DateTime? _selectedDate;
  String _selectedStatus = 'all';

  bool _isLoading = false;
  bool _hasSearched = false;
  List<dynamic> _searchResults = [];

  // Manage the filter panel expansion
  bool _isFilterExpanded = true;

  final List<Map<String, String>> _statusOptions = [
    {'value': 'all', 'label': 'All Statuses'},
    {'value': 'pending', 'label': 'Pending'},
    {'value': 'preparing', 'label': 'Preparing'},
    {'value': 'assigned', 'label': 'Assigned'},
    {'value': 'picked_up', 'label': 'Picked Up'},
    {'value': 'delivering', 'label': 'Delivering'},
    {'value': 'dropped', 'label': 'Delivered'},
    {'value': 'cancelled', 'label': 'Cancelled'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  // --- DATE PICKER ---
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.indigo.shade700),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // --- CORE SEARCH LOGIC ---
  Future<void> _performSearch() async {
    FocusScope.of(context).unfocus(); // Close keyboard
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _isFilterExpanded = false; // Auto-collapse filters to show results
    });

    try {
      final nameQ = _nameController.text.trim();
      final phoneQ = _phoneController.text.trim();
      final fromQ = _fromController.text.trim();
      final toQ = _toController.text.trim();

      List<String> validCustomerIds = [];

      // STEP 1: If filtering by Customer Name/Phone, find matching IDs first
      if (nameQ.isNotEmpty || phoneQ.isNotEmpty) {
        var profileQuery = supabase.from('profiles').select('id').eq('role', 'customer');

        if (nameQ.isNotEmpty) profileQuery = profileQuery.ilike('full_name', '%$nameQ%');
        if (phoneQ.isNotEmpty) profileQuery = profileQuery.ilike('phone', '%$phoneQ%');

        final profileRes = await profileQuery;

        // If no customers match, return 0 results immediately
        if (profileRes.isEmpty) {
          if (mounted) {
            setState(() {
              _searchResults = [];
              _isLoading = false;
            });
          }
          return;
        }

        validCustomerIds = profileRes.map((e) => e['id'].toString()).toList();
      }

      // STEP 2: Build the Main Deliveries (Ways) Query
      var waysQuery = supabase
          .from('ways')
          .select('*, customer:profiles!ways_customer_id_fkey(full_name, phone)');

      // Apply Customer ID filters if they exist
      if (validCustomerIds.isNotEmpty) {
        waysQuery = waysQuery.filter('customer_id', 'in', validCustomerIds);
      }

      // Apply Location Filters
      if (fromQ.isNotEmpty) waysQuery = waysQuery.ilike('pickup_location', '%$fromQ%');
      if (toQ.isNotEmpty) waysQuery = waysQuery.ilike('drop_location', '%$toQ%');

      // Apply Status Filter
      if (_selectedStatus != 'all') {
        waysQuery = waysQuery.eq('status', _selectedStatus);
      }

      // Apply Date Filter (Start of day to end of day)
      if (_selectedDate != null) {
        final startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day).toUtc().toIso8601String();
        final endOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59).toUtc().toIso8601String();
        waysQuery = waysQuery.gte('created_at', startOfDay).lte('created_at', endOfDay);
      }

      // Execute Query (Limit to 50 for performance)
      final response = await waysQuery.order('created_at', ascending: false).limit(50);

      if (mounted) {
        setState(() {
          _searchResults = response;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search Error: $error'), backgroundColor: Colors.red));
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _nameController.clear();
      _phoneController.clear();
      _fromController.clear();
      _toController.clear();
      _selectedDate = null;
      _selectedStatus = 'all';
      _searchResults = [];
      _hasSearched = false;
      _isFilterExpanded = true;
    });
  }

  // --- UI HELPERS ---

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange.shade600;
      case 'picked_up': return Colors.blue.shade600;
      case 'delivering': return Colors.purple.shade600;
      case 'dropped': case 'delivered': return Colors.green.shade600;
      case 'rejected': case 'cancelled': return Colors.red.shade600;
      default: return Colors.grey.shade600;
    }
  }

  InputDecoration _buildInputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.indigo.shade400, size: 20),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.indigo.shade600)),
    );
  }

  String _formatDate(String isoString) {
    final date = DateTime.parse(isoString).toLocal();
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Search Deliveries', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Clear Filters',
            onPressed: _clearFilters,
          )
        ],
      ),
      body: Column(
        children: [
          // --- THE FILTER PANEL ---
          Card(
            margin: EdgeInsets.zero,
            elevation: _isFilterExpanded ? 4 : 1,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            child: ExpansionTile(
              initiallyExpanded: _isFilterExpanded,
              onExpansionChanged: (expanded) => setState(() => _isFilterExpanded = expanded),
              title: const Text('Search Parameters', style: TextStyle(fontWeight: FontWeight.bold)),
              leading: Icon(Icons.search, color: Colors.indigo.shade600),
              backgroundColor: Colors.white,
              collapsedBackgroundColor: Colors.white,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [

                SizedBox(height: 08.0,),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _nameController, decoration: _buildInputDeco('Customer Name', Icons.person_outline), textInputAction: TextInputAction.next)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: _buildInputDeco('Phone No.', Icons.phone_android), textInputAction: TextInputAction.next)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _fromController, decoration: _buildInputDeco('Pickup Location', Icons.radio_button_checked), textInputAction: TextInputAction.next)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _toController, decoration: _buildInputDeco('Drop-off Location', Icons.location_on), textInputAction: TextInputAction.done)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Date Picker
                    Expanded(
                      flex: 1,
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 20, color: Colors.indigo.shade400),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedDate == null ? 'Any Date' : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
                                  style: TextStyle(color: _selectedDate == null ? Colors.grey.shade600 : Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_selectedDate != null)
                                GestureDetector(
                                  onTap: () => setState(() => _selectedDate = null),
                                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                                )
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status Dropdown
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        icon: const Icon(Icons.arrow_drop_down_rounded),
                        decoration: _buildInputDeco('Status', Icons.timeline_outlined),
                        items: _statusOptions.map((opt) => DropdownMenuItem(value: opt['value'], child: Text(opt['label']!))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedStatus = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _performSearch,
                    icon: const Icon(Icons.search),
                    label: const Text('Search Deliveries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- RESULTS AREA ---
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.indigo.shade700))
                : (!_hasSearched)
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_rounded, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Enter criteria above to search deliveries.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                ],
              ),
            )
                : (_searchResults.isEmpty)
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No deliveries match your filters.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                  TextButton(onPressed: _clearFilters, child: const Text('Clear Filters'))
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final way = _searchResults[index];
                final customer = way['customer'] ?? {};
                final customerName = customer['full_name'] ?? 'Unknown Customer';
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Order #${way['id']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Text(_formatDate(way['created_at']), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                              const SizedBox(width: 16),
                              Icon(Icons.person, size: 16, color: Colors.blue.shade400),
                              const SizedBox(width: 4),
                              Expanded(child: Text(customerName, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
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
        ],
      ),
    );
  }
}