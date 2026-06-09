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

  // --- Input Controllers ---
  final _phoneSearchController = TextEditingController();
  final _newCustomerNameController = TextEditingController();
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _remarkController = TextEditingController();

  // --- State Variables ---
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Search State
  bool _isSearchingPhone = false;
  bool _searchPerformed = false;
  Map<String, dynamic>? _foundCustomer;

  List<dynamic> _riders = [];

  String? _selectedCustomerId;
  String? _selectedRiderId;
  String _selectedStatus = 'pending';

  @override
  void initState() {
    super.initState();
    // We only need to fetch riders up front; customers are searched dynamically
    _fetchRiders();
  }

  @override
  void dispose() {
    _phoneSearchController.dispose();
    _newCustomerNameController.dispose();
    _pickupController.dispose();
    _dropController.dispose();
    _descriptionController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _fetchRiders() async {
    try {
      final riderResponse = await supabase
          .from('profiles')
          .select('id, full_name')
          .eq('role', 'rider')
          .eq('is_deleted', false)
          .order('full_name');

      if (mounted) {
        setState(() {
          _riders = riderResponse;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading riders: $error'), backgroundColor: Colors.red.shade600),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Search Customer Logic ---
  Future<void> _searchCustomerByPhone() async {
    final phone = _phoneSearchController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number to search.')),
      );
      return;
    }

    FocusScope.of(context).unfocus(); // Dismiss keyboard

    setState(() {
      _isSearchingPhone = true;
      _searchPerformed = false;
      _foundCustomer = null;
      _selectedCustomerId = null;
    });

    try {
      // Use maybeSingle() to handle exactly 0 or 1 result safely
      final response = await supabase
          .from('profiles')
          .select('id, full_name, phone')
          .eq('role', 'customer')
          .eq('phone', phone)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (response != null) {
            _foundCustomer = response;
            _selectedCustomerId = response['id'];
          }
          _searchPerformed = true;
          _isSearchingPhone = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $error'), backgroundColor: Colors.red.shade600),
        );
        setState(() => _isSearchingPhone = false);
      }
    }
  }

  // --- Main Submission Logic ---
  Future<void> _createWay() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (!_searchPerformed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please search for a customer phone number first.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. CREATE NEW USER VIA EDGE FUNCTION IF NOT FOUND
      if (_foundCustomer == null) {
        final newName = _newCustomerNameController.text.trim();
        final newPhone = _phoneSearchController.text.trim();

        if (newName.isEmpty) {
          throw const FormatException('New customer name is required.');
        }

        // Generate a unique dummy email required by Supabase Auth
        final dummyEmail = '$newPhone@deliveryapp.local';

        // Invoke the secure Edge Function we built
        final response = await supabase.functions.invoke(
          'create-user',
          body: {
            'email': dummyEmail,
            'password': 'TempPassword123!',
            'full_name': newName,
            'phone': newPhone,
            'role': 'customer',
          },
        );

        if (response.status != 200) {
          throw Exception(response.data['error'] ?? 'Failed to create user account.');
        }

        // Extract the newly created user's ID
        _selectedCustomerId = response.data['user']['id'];
      }

      // 2. CREATE THE DELIVERY WAY
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
        Navigator.pop(context, true); // Pop back and tell the list to refresh
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
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- UI Design Helpers ---

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

                      // --- Dynamic Customer Search Section ---
                      _buildSectionHeader('Customer Lookup'),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _phoneSearchController,
                              keyboardType: TextInputType.phone,
                              decoration: _buildInputDecoration('Phone Number', Icons.phone),
                              onFieldSubmitted: (_) => _searchCustomerByPhone(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _isSearchingPhone ? null : _searchCustomerByPhone,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSearchingPhone
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.search),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- Search Results UI ---
                      if (_searchPerformed) ...[
                        if (_foundCustomer != null) ...[
                          // EXISTING CUSTOMER FOUND
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              border: Border.all(color: Colors.green.shade200),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 32),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Customer Found', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                                      Text(_foundCustomer!['full_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text(_foundCustomer!['phone'], style: TextStyle(color: Colors.grey.shade700)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // NO CUSTOMER FOUND -> SHOW CREATION FORM
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              border: Border.all(color: Colors.orange.shade200),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person_add, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    const Text('New Customer', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text('No existing account found. Provide a name to automatically register them.', style: TextStyle(fontSize: 12)),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _newCustomerNameController,
                                  textInputAction: TextInputAction.next,
                                  decoration: _buildInputDecoration('Full Name', Icons.person_outline).copyWith(
                                    fillColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                      ],

                      // --- Rider Assignment ---
                      _buildSectionHeader('Assigned Personnel'),
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