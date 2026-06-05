import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WayCreatePage extends StatefulWidget {
  const WayCreatePage({super.key});

  @override
  State<WayCreatePage> createState() => _WayCreatePageState();
}

class _WayCreatePageState extends State<WayCreatePage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _remarkController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;

  List<dynamic> _customers = [];
  List<dynamic> _riders = [];

  String? _selectedCustomerId;
  String? _selectedRiderId;
  String _selectedStatus = 'pending';

  @override
  void initState() {
    super.initState();
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
      final customerResponse = await supabase
          .from('profiles')
          .select('id, full_name')
          .eq('role', 'customer')
          .eq('is_deleted', false)
          .order('full_name');

      final riderResponse = await supabase
          .from('profiles')
          .select('id, full_name')
          .eq('role', 'rider')
          .eq('is_deleted', false)
          .order('full_name');

      if (mounted) {
        setState(() {
          _customers = customerResponse;
          _riders = riderResponse;
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

  Future<void> _createWay() async {
    FocusScope.of(context).unfocus(); // Dismiss keyboard

    if (!_formKey.currentState!.validate()) return;

    // Explicit validation since it's a dropdown
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a customer for this delivery.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await supabase.from('ways').insert({
        'customer_id': _selectedCustomerId,
        'rider_id': _selectedRiderId,
        'pickup_location': _pickupController.text.trim(),
        'drop_location': _dropController.text.trim(),
        'description': _descriptionController.text.trim(),
        'remark': _remarkController.text.trim(),
        'status': _selectedStatus,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Delivery created successfully!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // Return true to trigger list refresh
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating delivery: $error'),
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Create New Delivery', style: TextStyle(fontWeight: FontWeight.w600)),
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
                      // --- Personnel ---
                      _buildSectionHeader('Assigned Personnel'),
                      DropdownButtonFormField<String>(
                        value: _selectedCustomerId,
                        icon: const Icon(Icons.arrow_drop_down_rounded),
                        decoration: _buildInputDecoration('Customer (Required)', Icons.person_outline),
                        items: _customers.map<DropdownMenuItem<String>>((customer) {
                          return DropdownMenuItem<String>(
                            value: customer['id'],
                            child: Text(customer['full_name'], overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        validator: (value) => value == null ? 'Please select a customer' : null,
                        onChanged: (value) => setState(() => _selectedCustomerId = value),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String?>(
                        value: _selectedRiderId,
                        icon: const Icon(Icons.arrow_drop_down_rounded),
                        decoration: _buildInputDecoration('Assigned Rider', Icons.motorcycle_outlined),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Leave Unassigned', style: TextStyle(color: Colors.grey)),
                          ),
                          ..._riders.map<DropdownMenuItem<String>>((rider) {
                            return DropdownMenuItem<String>(
                              value: rider['id'],
                              child: Text(rider['full_name'], overflow: TextOverflow.ellipsis),
                            );
                          }),
                        ],
                        onChanged: (value) => setState(() => _selectedRiderId = value),
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
                      const SizedBox(height: 28),

                      // --- Operational Status ---
                      _buildSectionHeader('Initial Status'),
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        icon: const Icon(Icons.arrow_drop_down_rounded),
                        decoration: _buildInputDecoration('Status', Icons.timeline_outlined).copyWith(
                          fillColor: Colors.indigo.shade50,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'pending', child: Text('Pending (Default)')),
                          DropdownMenuItem(value: 'preparing', child: Text('Preparing')),
                          DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _selectedStatus = value);
                        },
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
                  onPressed: _isSubmitting ? null : _createWay,
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
                      Icon(Icons.add_box_outlined, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Create Delivery',
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