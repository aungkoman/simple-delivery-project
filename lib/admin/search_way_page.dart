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

  // --- Search & Filter State ---
  final _universalSearchController = TextEditingController();

  DateTime? _selectedDate;
  String _selectedStatus = 'all';
  String _selectedRiderId = 'all';

  bool _isLoading = false;
  bool _hasSearched = false;
  List<dynamic> _searchResults = [];
  List<Map<String, dynamic>> _riders = [];

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
  void initState() {
    super.initState();
    _fetchRidersForDropdown();
  }

  @override
  void dispose() {
    _universalSearchController.dispose();
    super.dispose();
  }

  // --- FETCH FILTERS ---
  Future<void> _fetchRidersForDropdown() async {
    try {
      final response = await supabase
          .from('profiles')
          .select('id, full_name')
          .eq('role', 'rider')
          .eq('is_deleted', false)
          .order('full_name');

      if (mounted) {
        setState(() {
          _riders = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      // Silently fail or log, dropdown will just show "All Riders"
      debugPrint('Error loading riders: $e');
    }
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

  // --- CORE OMNI-SEARCH LOGIC ---
  Future<void> _performSearch() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _isFilterExpanded = false;
    });

    try {
      // Remove commas to prevent breaking the PostgREST syntax
      final rawQuery = _universalSearchController.text.trim().replaceAll(',', ' ');
      List<String> matchingCustomerIds = [];

      // STEP 1: If there's text, search the Profiles table for matching Customers
      if (rawQuery.isNotEmpty) {
        final profileRes = await supabase
            .from('profiles')
            .select('id')
            .eq('role', 'customer')
            .or('full_name.ilike.%$rawQuery%,phone.ilike.%$rawQuery%');

        matchingCustomerIds = profileRes.map((e) => e['id'].toString()).toList();
      }

      // STEP 2: Build the Main Deliveries (Ways) Query
      var waysQuery = supabase
          .from('ways')
          .select('*, customer:profiles!ways_customer_id_fkey(full_name, phone)');

      // Apply Explicit Dropdown Filters
      if (_selectedRiderId != 'all') {
        waysQuery = waysQuery.eq('rider_id', _selectedRiderId);
      }

      if (_selectedStatus != 'all') {
        waysQuery = waysQuery.eq('status', _selectedStatus);
      }

      if (_selectedDate != null) {
        final startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day).toUtc().toIso8601String();
        final endOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59).toUtc().toIso8601String();
        waysQuery = waysQuery.gte('created_at', startOfDay).lte('created_at', endOfDay);
      }

      // Apply the Universal Text Search (The Omni-filter)
      if (rawQuery.isNotEmpty) {
        // Search locations and remarks
        String orFilterString = 'pickup_location.ilike.%$rawQuery%,drop_location.ilike.%$rawQuery%,remark.ilike.%$rawQuery%';

        // If the query matched any customers, inject them into the OR filter
        if (matchingCustomerIds.isNotEmpty) {
          String idsJoined = matchingCustomerIds.join(',');
          orFilterString += ',customer_id.in.($idsJoined)';
        }

        waysQuery = waysQuery.or(orFilterString);
      }

      // Execute Query (Cap at 50 results to keep UI snappy)
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
      _universalSearchController.clear();
      _selectedDate = null;
      _selectedStatus = 'all';
      _selectedRiderId = 'all';
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
          // --- THE GOOGLE-STYLE OMNIBOX & FILTER PANEL ---
          Card(
            margin: EdgeInsets.zero,
            elevation: _isFilterExpanded ? 4 : 1,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            child: ExpansionTile(
              initiallyExpanded: _isFilterExpanded,
              onExpansionChanged: (expanded) => setState(() => _isFilterExpanded = expanded),
              title: const Text('Search & Filters', style: TextStyle(fontWeight: FontWeight.bold)),
              leading: Icon(Icons.tune, color: Colors.indigo.shade600),
              backgroundColor: Colors.white,
              collapsedBackgroundColor: Colors.white,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                // 1. UNIVERSAL SEARCH BAR
                TextFormField(
                  controller: _universalSearchController,
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) => _performSearch(),
                  decoration: InputDecoration(
                    hintText: 'Search by Customer, Phone, Location, or Remarks...',
                    prefixIcon: Icon(Icons.search, color: Colors.indigo.shade600, size: 24),
                    filled: true,
                    fillColor: Colors.indigo.shade50,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. SPECIFIC DROPDOWN FILTERS
                Row(
                  children: [
                    // Rider Dropdown
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _selectedRiderId,
                        icon: const Icon(Icons.arrow_drop_down_rounded),
                        isExpanded: true,
                        decoration: _buildInputDeco('Assigned Rider', Icons.motorcycle),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All Riders')),
                          ..._riders.map((r) => DropdownMenuItem(value: r['id'].toString(), child: Text(r['full_name'], overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRiderId = val);
                        },
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
                const SizedBox(height: 12),

                // 3. DATE FILTER & SEARCH BUTTON
                Row(
                  children: [
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
                    Expanded(
                      flex: 1,
                      child: ElevatedButton.icon(
                        onPressed: _performSearch,
                        icon: const Icon(Icons.search),
                        label: const Text('Search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  Icon(Icons.manage_search_rounded, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Enter search criteria or select filters above.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
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