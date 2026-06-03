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

  late TextEditingController _pickupController;
  late TextEditingController _dropController;

  bool _isLoading = true;
  bool _isSubmitting = false;

  List<dynamic> _customers = [];
  List<dynamic> _riders = [];

  String? _selectedCustomerId;
  String? _selectedRiderId;
  late String _selectedStatus;

  @override
  void initState() {
    super.initState();

    // Pre-fill existing data
    _pickupController = TextEditingController(text: widget.wayData['pickup_location']);
    _dropController = TextEditingController(text: widget.wayData['drop_location']);

    _selectedCustomerId = widget.wayData['customer_id'];
    _selectedRiderId = widget.wayData['rider_id'];

    // Ensure the status is valid, otherwise default to pending
    final validStatuses = ['pending', 'preparing', 'assigned', 'picked_up', 'delivering', 'dropped', 'cancelled'];
    final currentStatus = widget.wayData['status']?.toString().toLowerCase() ?? 'pending';
    _selectedStatus = validStatuses.contains(currentStatus) ? currentStatus : 'pending';

    _fetchUsersForDropdowns();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsersForDropdowns() async {
    try {
      // SMART FETCH: Get active users OR the user currently assigned to this way (in case they were soft-deleted)

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
          .select('id, full_name')
          .eq('role', 'customer')
          .or(customerFilter)
          .order('full_name');

      final riderResponse = await supabase
          .from('profiles')
          .select('id, full_name')
          .eq('role', 'rider')
          .or(riderFilter)
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
          SnackBar(content: Text('Error loading users: $error'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateWay() async {
    final pickup = _pickupController.text.trim();
    final drop = _dropController.text.trim();

    if (_selectedCustomerId == null || pickup.isEmpty || drop.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer, Pickup, and Drop locations are required.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await supabase.from('ways').update({
        'customer_id': _selectedCustomerId,
        'rider_id': _selectedRiderId,
        'pickup_location': pickup,
        'drop_location': drop,
        'status': _selectedStatus,
      }).eq('id', widget.wayData['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery updated successfully!')),
        );
        Navigator.pop(context, true); // Return true to trigger refresh
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating way: $error'), backgroundColor: Colors.red),
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
        title: Text('Edit Way #${widget.wayData['id']}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Status Dropdown ---
            // Put status at the top so it's easy for the Admin to update quickly
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: InputDecoration(
                labelText: 'Current Status',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.blue.shade50,
              ),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'preparing', child: Text('Preparing')),
                DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
                DropdownMenuItem(value: 'picked_up', child: Text('Picked Up')),
                DropdownMenuItem(value: 'delivering', child: Text('Delivering')),
                DropdownMenuItem(value: 'dropped', child: Text('Dropped / Delivered')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selectedStatus = value);
              },
            ),
            const SizedBox(height: 24),

            // --- Customer Dropdown ---
            DropdownButtonFormField<String>(
              value: _selectedCustomerId,
              decoration: const InputDecoration(
                labelText: 'Customer *',
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

            // --- Rider Dropdown ---
            DropdownButtonFormField<String?>(
              value: _selectedRiderId,
              decoration: const InputDecoration(
                labelText: 'Assigned Rider',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.motorcycle),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Unassigned'),
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
            const SizedBox(height: 32),

            // --- Submit Button ---
            ElevatedButton(
              onPressed: _isSubmitting ? null : _updateWay,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                _isSubmitting ? 'Saving...' : 'Save Changes',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}