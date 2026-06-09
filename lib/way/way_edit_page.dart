import 'package:flutter/material.dart';
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

  // Define valid statuses and clear human-readable labels
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
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    _descriptionController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

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
            content: Text('Error loading users: $error'),
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

    if (_selectedCustomerId == null || !_customers.any((c) => c['id'] == _selectedCustomerId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a valid customer for this delivery.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Delivery updated successfully!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating delivery: $error'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // --- UI Helpers ---

  // Match colors with your card tracking palette
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.indigo.shade600, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String initialRiderText = '';
    if (!_isLoading && _selectedRiderId != null) {
      try {
        final currentRider = _riders.firstWhere((r) => r['id'] == _selectedRiderId);
        initialRiderText = '${currentRider['full_name']} (${currentRider['phone'] ?? 'No Phone'})';
      } catch (e) {
        // Ignored
      }
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

                      // --- SMOOTH OPERATIONAL CHIPS ---
                      _buildSectionHeader('Operational Status'),
                      SizedBox(
                        height: 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _statusOptions.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final item = _statusOptions[index];
                            final value = item['value']!;
                            final label = item['label']!;

                            final isSelected = _selectedStatus == value;
                            final themeColor = _getStatusThemeColor(value);

                            return ChoiceChip(
                              label: Text(label),
                              selected: isSelected,
                              labelStyle: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : Colors.grey.shade700,
                                fontSize: 13,
                              ),
                              selectedColor: themeColor,
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: isSelected ? Colors.transparent : Colors.grey.shade300,
                              ),
                              elevation: isSelected ? 2 : 0,
                              pressElevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              onSelected: (bool selected) {
                                if (selected) {
                                  setState(() => _selectedStatus = value);
                                }
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 28),

                      // --- Personnel ---
                      _buildSectionHeader('Assigned Personnel'),

                      DropdownButtonFormField<String>(
                        value: _customers.any((c) => c['id'] == _selectedCustomerId) ? _selectedCustomerId : null,
                        icon: const Icon(Icons.arrow_drop_down_rounded),
                        decoration: _buildInputDecoration('Customer (Required)', Icons.person_outline),
                        items: _customers.map<DropdownMenuItem<String>>((customer) {
                          final phone = customer['phone'] ?? 'No Phone';
                          return DropdownMenuItem<String>(
                            value: customer['id'],
                            child: Text('${customer['full_name']} ($phone)', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        validator: (value) => value == null ? 'Please select a customer' : null,
                        onChanged: (value) => setState(() => _selectedCustomerId = value),
                      ),
                      const SizedBox(height: 16),

                      Autocomplete<Map<String, dynamic>>(
                        initialValue: TextEditingValue(text: initialRiderText),
                        displayStringForOption: (option) => '${option['full_name']} (${option['phone'] ?? 'No Phone'})',
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return _riders;
                          }
                          final query = textEditingValue.text.toLowerCase();
                          return _riders.where((rider) {
                            final name = rider['full_name']?.toString().toLowerCase() ?? '';
                            final phone = rider['phone']?.toString().toLowerCase() ?? '';
                            return name.contains(query) || phone.contains(query);
                          });
                        },
                        onSelected: (Map<String, dynamic> selection) {
                          setState(() => _selectedRiderId = selection['id']);
                          FocusScope.of(context).unfocus();
                        },
                        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            onEditingComplete: onEditingComplete,
                            decoration: _buildInputDecoration('Search Assigned Rider', Icons.motorcycle_outlined).copyWith(
                              hintText: 'Type to change assignment',
                              suffixIcon: _selectedRiderId != null
                                  ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.redAccent),
                                onPressed: () {
                                  controller.clear();
                                  setState(() => _selectedRiderId = null);
                                  focusNode.unfocus();
                                },
                              )
                                  : const Icon(Icons.search, color: Colors.grey),
                            ),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              borderRadius: BorderRadius.circular(12),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: 250,
                                  maxWidth: MediaQuery.of(context).size.width - 40,
                                ),
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (BuildContext context, int index) {
                                    final option = options.elementAt(index);
                                    return InkWell(
                                      onTap: () => onSelected(option),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.motorcycle, color: Colors.indigo, size: 20),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(option['full_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                                if (option['phone'] != null)
                                                  Text(option['phone'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),

                      // --- Delivery Details ---
                      _buildSectionHeader('Delivery Details & Routing'),
                      TextFormField(
                        controller: _descriptionController,
                        textInputAction: TextInputAction.next,
                        decoration: _buildInputDecoration('Package Description', Icons.inventory_2_outlined),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Please describe the package' : null,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _pickupController,
                              textInputAction: TextInputAction.next,
                              decoration: _buildInputDecoration('Pickup Location', Icons.radio_button_checked).copyWith(
                                prefixIcon: Icon(Icons.radio_button_checked, color: Colors.blue.shade500, size: 22),
                                fillColor: Colors.grey.shade50,
                              ),
                              validator: (value) => (value == null || value.trim().isEmpty) ? 'Pickup location is required' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _dropController,
                              textInputAction: TextInputAction.next,
                              decoration: _buildInputDecoration('Drop-off Location', Icons.location_on).copyWith(
                                prefixIcon: Icon(Icons.location_on, color: Colors.red.shade500, size: 22),
                                fillColor: Colors.grey.shade50,
                              ),
                              validator: (value) => (value == null || value.trim().isEmpty) ? 'Drop-off location is required' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _remarkController,
                        maxLines: 3,
                        textInputAction: TextInputAction.done,
                        decoration: _buildInputDecoration('Delivery Instructions / Remarks', Icons.note_alt_outlined).copyWith(
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),

            // --- Fixed Bottom Action Bar ---
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _updateWay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.indigo.shade700.withOpacity(0.7),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  )
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_outlined, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}