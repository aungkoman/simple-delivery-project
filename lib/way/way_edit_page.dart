import 'package:flutter/material.dart';
import 'package:simpledelivery/way/way_detail_read_only_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WayEditPage extends StatefulWidget {
  final Map<String, dynamic> wayData;

  const WayEditPage({super.key, required this.wayData});

  @override
  State<WayEditPage> createState() => _WayEditPageState();
}

class _WayEditPageState extends State<WayEditPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // --- NEW: Scroll and Key management ---
  final ScrollController _statusScrollController = ScrollController();
  late List<GlobalKey> _statusKeys;

  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _remarkController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _riders = [];

  String? _selectedCustomerId;
  String? _selectedRiderId;
  late String _selectedStatus;

  final List<Map<String, String>> _statusOptions = [
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

    // Initialize keys for every status option
    _statusKeys = List.generate(_statusOptions.length, (index) => GlobalKey());

    _pickupController.text = widget.wayData['pickup_location'] ?? '';
    _dropController.text = widget.wayData['drop_location'] ?? '';
    _descriptionController.text = widget.wayData['description'] ?? '';
    _remarkController.text = widget.wayData['remark'] ?? '';

    _selectedCustomerId = widget.wayData['customer_id'];
    _selectedRiderId = widget.wayData['rider_id'];

    final currentStatus = widget.wayData['status']?.toString().toLowerCase() ?? 'pending';
    final validValues = _statusOptions.map((opt) => opt['value']).toList();
    _selectedStatus = validValues.contains(currentStatus) ? currentStatus : 'pending';

    _fetchUsersForDropdowns();

    // --- NEW: Center the selected status after the first frame ---
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedStatus());
  }

  // --- NEW: Centering Logic ---
  void _scrollToSelectedStatus() {
    final index = _statusOptions.indexWhere((opt) => opt['value'] == _selectedStatus);
    if (index != -1) {
      final context = _statusKeys[index].currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5, // 0.5 centers the element in the viewport
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _statusScrollController.dispose(); // Clean up controller
    _pickupController.dispose();
    _dropController.dispose();
    _descriptionController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  // ... _fetchUsersForDropdowns and _updateWay remain the same as previous step ...
  Future<void> _fetchUsersForDropdowns() async {
    try {
      String customerFilter = 'is_deleted.eq.false';
      if (_selectedCustomerId != null) {
        customerFilter = 'is_deleted.eq.false,id.eq.$_selectedCustomerId';
      }

      String riderFilter = 'is_deleted.eq.false';
      if (_selectedRiderId != null) {
        riderFilter = 'is_deleted.eq.false,id.eq.$_selectedRiderId';
      }

      final customerResponse = await supabase
          .from('profiles')
          .select('id, full_name, phone')
          .eq('role', 'customer')
          .or(customerFilter)
          .order('full_name');

      final riderResponse = await supabase
          .from('profiles')
          .select('id, full_name, phone')
          .eq('role', 'rider')
          .or(riderFilter)
          .order('full_name');

      if (mounted) {
        setState(() {
          _customers = List<Map<String, dynamic>>.from(customerResponse);
          _riders = List<Map<String, dynamic>>.from(riderResponse);
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateWay() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) return;

    setState(() => _isSubmitting = true);
    try {
      await supabase.from('ways').update({
        'customer_id': _selectedCustomerId,
        'rider_id': _selectedRiderId,
        'pickup_location': _pickupController.text.trim(),
        'drop_location': _dropController.text.trim(),
        'description': _descriptionController.text.trim(),
        'remark': _remarkController.text.trim(),
        'status': _selectedStatus,
      }).eq('id', widget.wayData['id']);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Color _getStatusThemeColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange.shade600;
      case 'preparing': return Colors.amber.shade700;
      case 'assigned': return Colors.teal.shade600;
      case 'picked_up': return Colors.blue.shade600;
      case 'delivering': return Colors.purple.shade600;
      case 'dropped': return Colors.green.shade600;
      case 'cancelled': return Colors.red.shade600;
      default: return Colors.indigo.shade600;
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.indigo.shade400, size: 22),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.indigo.shade600, width: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    String initialRiderText = '';
    if (!_isLoading && _selectedRiderId != null) {
      try {
        final currentRider = _riders.firstWhere((r) => r['id'] == _selectedRiderId);
        initialRiderText = '${currentRider['full_name']} (${currentRider['phone'] ?? 'No Phone'})';
      } catch (e) {}
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Text('Edit Order #${widget.wayData['id']}', style: const TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(onPressed: (){
              Navigator.push(context, MaterialPageRoute(builder: (context) => WayDetailReadOnlyPage(wayData: widget.wayData)));
            }, icon: Icon(Icons.eighteen_mp))
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.indigo.shade700))
            : Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 4),
                        child: const Text('Operational Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),

                      // --- SCROLLABLE STATUS CHIPS WITH CENTERING ---
                      SizedBox(
                        height: 50,
                        child: ListView.separated(
                          controller: _statusScrollController, // Attach controller
                          scrollDirection: Axis.horizontal,
                          itemCount: _statusOptions.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final item = _statusOptions[index];
                            final value = item['value']!;
                            final label = item['label']!;
                            final isSelected = _selectedStatus == value;
                            final themeColor = _getStatusThemeColor(value);

                            return Padding(
                              key: _statusKeys[index], // Assign key for ensureVisible
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: ChoiceChip(
                                label: Text(label),
                                selected: isSelected,
                                labelStyle: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                                selectedColor: themeColor,
                                backgroundColor: Colors.white,
                                side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                onSelected: (bool selected) {
                                  if (selected) {
                                    setState(() => _selectedStatus = value);
                                    // Center the chip when manually tapped as well
                                    _scrollToSelectedStatus();
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ... Rest of UI (Personnel, Details, Buttons) remains the same ...
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 4),
                        child: const Text('Assigned Personnel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                      DropdownButtonFormField<String>(
                        value: _customers.any((c) => c['id'] == _selectedCustomerId) ? _selectedCustomerId : null,
                        icon: const Icon(Icons.arrow_drop_down_rounded),
                        decoration: _buildInputDecoration('Customer (Required)', Icons.person_outline),
                        items: _customers.map<DropdownMenuItem<String>>((customer) {
                          return DropdownMenuItem<String>(
                            value: customer['id'],
                            child: Text('${customer['full_name']} (${customer['phone'] ?? '...'})', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedCustomerId = value),
                      ),
                      const SizedBox(height: 16),
                      Autocomplete<Map<String, dynamic>>(
                        initialValue: TextEditingValue(text: initialRiderText),
                        displayStringForOption: (option) => '${option['full_name']} (${option['phone'] ?? 'N/A'})',
                        optionsBuilder: (val) => val.text.isEmpty ? _riders : _riders.where((r) => r['full_name'].toLowerCase().contains(val.text.toLowerCase())),
                        onSelected: (selection) => setState(() => _selectedRiderId = selection['id']),
                        fieldViewBuilder: (ctx, ctrl, focus, onComplete) {
                          return TextFormField(
                            controller: ctrl,
                            focusNode: focus,
                            decoration: _buildInputDecoration('Search Assigned Rider', Icons.motorcycle_outlined).copyWith(
                              suffixIcon: _selectedRiderId != null ? IconButton(icon: Icon(Icons.clear, color: Colors.red), onPressed: () { ctrl.clear(); setState(() => _selectedRiderId = null); }) : Icon(Icons.search),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 4),
                        child: const Text('Delivery Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                      TextFormField(controller: _descriptionController, decoration: _buildInputDecoration('Package Description', Icons.inventory_2_outlined)),
                      const SizedBox(height: 16),
                      TextFormField(controller: _pickupController, decoration: _buildInputDecoration('Pickup', Icons.radio_button_checked)),
                      const SizedBox(height: 16),
                      TextFormField(controller: _dropController, decoration: _buildInputDecoration('Drop-off', Icons.location_on)),
                      const SizedBox(height: 16),
                      TextFormField(controller: _remarkController, maxLines: 2, decoration: _buildInputDecoration('Remarks', Icons.note_alt_outlined)),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(20),
              color: Colors.white,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _updateWay,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade700, foregroundColor: Colors.white, minimumSize: Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isSubmitting ? CircularProgressIndicator(color: Colors.white) : Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}