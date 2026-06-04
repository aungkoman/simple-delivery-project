import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerCreateWayPage extends StatefulWidget {
  const CustomerCreateWayPage({super.key});

  @override
  State<CustomerCreateWayPage> createState() => _CustomerCreateWayPageState();
}

class _CustomerCreateWayPageState extends State<CustomerCreateWayPage> {
  final supabase = Supabase.instance.client;

  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    super.dispose();
  }

  Future<void> _submitDeliveryRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw const AuthException('User session not found.');

      // Insert the delivery request into the database
      await supabase.from('ways').insert({
        'customer_id': user.id,          // Implicitly sets the logged-in customer
        'rider_id': null,                // Left empty for Admin to assign later
        'pickup_location': _pickupController.text.trim(),
        'drop_location': _dropController.text.trim(),
        'status': 'pending',             // Automatically starts as pending
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery request submitted successfully!')),
        );
        Navigator.pop(context, true); // Pop back with 'true' to signal a dashboard refresh
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit request: $error'), backgroundColor: Colors.red),
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
        title: const Text('Request Delivery'),
        backgroundColor: Colors.green,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Enter your pickup and drop-off information below to request a local rider.',
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // --- Pickup Location Input ---
              TextFormField(
                controller: _pickupController,
                decoration: const InputDecoration(
                  labelText: 'Pickup Address / Business Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.storefront, color: Colors.blue),
                  hintText: 'e.g., Shop A, Main Road',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a pickup location.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // --- Drop Location Input ---
              TextFormField(
                controller: _dropController,
                decoration: const InputDecoration(
                  labelText: 'Drop-off Address / Destination',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on, color: Colors.red),
                  hintText: 'e.g., No. 123, 5th Street',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a destination address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),

              // --- Submit Button ---
              ElevatedButton(
                onPressed: _submitDeliveryRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Submit Request',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}