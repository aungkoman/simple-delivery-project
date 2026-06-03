import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WayCreatePage extends StatefulWidget {
  const WayCreatePage({super.key});

  @override
  State<WayCreatePage> createState() => _WayCreatePageState();
}

class _WayCreatePageState extends State<WayCreatePage> {
  final supabase = Supabase.instance.client;

  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;

  // Lists to hold the fetched users for our dropdowns
  List<dynamic> _customers = [];
  List<dynamic> _riders = [];

  // Selected values
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
    super.dispose();
  }

  // Fetch the active customers and riders so the admin can select them by name
  Future<void> _fetchUsersForDropdowns() async {
    try {
      // 1. Fetch active customers
      final customerResponse = await supabase
          .from('profiles')
          .select('id, full_name')
          .eq('role', 'customer')
          .eq('is_deleted', false) // Respecting our soft delete!
          .order('full_name');

      // 2. Fetch active riders
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

          // Auto-select the first customer if the list isn't empty
          if (_customers.isNotEmpty) {
            _selectedCustomerId = _customers.first['id'];
          }

          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $error'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createWay() async {
    final pickup = _pickupController.text.trim();
    final drop = _dropController.text.trim();

    // Basic Validation
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer.')),
      );
      return;
    }
    if (pickup.isEmpty || drop.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pickup and Drop locations are required.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Insert the new delivery into the database
      await supabase.from('ways').insert({
        'customer_id': _selectedCustomerId,
        'rider_id': _selectedRiderId, // This can safely be null if unassigned
        'pickup_location': pickup,
        'drop_location': drop,
        'status': _selectedStatus,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery Way created successfully!')),
        );
        Navigator.pop(context, true); // Return true to trigger a list refresh
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating way: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Way'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Customer Dropdown (Required) ---
            DropdownButtonFormField<String>(
              value: _selectedCustomerId,
              decoration: const InputDecoration(
                labelText: 'Select Customer *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              items: _customers.map<DropdownMenuItem<String>>((customer) {
                return DropdownMenuItem<String>(
                  value: customer['id'],
                  child: Text(customer['full_name']),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedCustomerId = value),
            ),
            const SizedBox(height: 16),

            // --- Rider Dropdown (Optional) ---
            DropdownButtonFormField<String?>(
              value: _selectedRiderId,
              decoration: const InputDecoration(
                labelText: 'Assign Rider (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.motorcycle),
              ),
              // Add a "Unassigned" option at the top
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Leave Unassigned'),
                ),
                ..._riders.map<DropdownMenuItem<String>>((rider) {
                  return DropdownMenuItem<String>(
                    value: rider['id'],
                    child: Text(rider['full_name']),
                  );
                }),
              ],
              onChanged: (value) => setState(() => _selectedRiderId = value),
            ),
            const SizedBox(height: 24),

            // --- Location Inputs ---
            TextField(
              controller: _pickupController,
              decoration: const InputDecoration(
                labelText: 'Pickup Location *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.storefront, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _dropController,
              decoration: const InputDecoration(
                labelText: 'Drop Location *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on, color: Colors.red),
              ),
            ),
            const SizedBox(height: 24),

            // --- Status Dropdown ---
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Initial Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'preparing', child: Text('Preparing')),
                DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selectedStatus = value);
              },
            ),
            const SizedBox(height: 32),

            // --- Submit Button ---
            ElevatedButton(
              onPressed: _isSubmitting ? null : _createWay,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                _isSubmitting ? 'Saving...' : 'Create Delivery Way',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}