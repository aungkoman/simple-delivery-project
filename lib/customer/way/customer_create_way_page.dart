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
  final _descriptionController = TextEditingController();
  final _remarkController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    _descriptionController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _submitDeliveryRequest() async {
    // Dismiss keyboard before submitting
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw const AuthException('User session not found.');

      await supabase.from('ways').insert({
        'customer_id': user.id,
        'rider_id': null,
        'pickup_location': _pickupController.text.trim(),
        'drop_location': _dropController.text.trim(),
        'description': _descriptionController.text.trim(),
        'remark': _remarkController.text.trim(),
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Delivery request submitted successfully!'),
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
            content: Text('Failed to submit request: $error'),
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

  InputDecoration _buildInputDecoration(String label, String hint, IconData icon, Color iconColor) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(icon, color: iconColor, size: 22),
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
        borderSide: BorderSide(color: Colors.green.shade600, width: 2),
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
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Dismisses the keyboard when tapping anywhere outside a text field
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('New Delivery', style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- Description Section ---
                      _buildSectionHeader('Package Details'),
                      TextFormField(
                        controller: _descriptionController,
                        textInputAction: TextInputAction.next,
                        decoration: _buildInputDecoration(
                          'What are we delivering?',
                          'e.g., 2 medium boxes of clothes (Fragile)',
                          Icons.inventory_2_outlined,
                          Colors.brown.shade400,
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? 'Please describe what is being delivered.'
                            : null,
                      ),
                      const SizedBox(height: 28),

                      // --- Routing Section ---
                      _buildSectionHeader('Routing Information'),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _pickupController,
                              textInputAction: TextInputAction.next,
                              decoration: _buildInputDecoration(
                                'Pickup Address',
                                'e.g., Shop A, Main Road',
                                Icons.radio_button_checked,
                                Colors.blue.shade500,
                              ).copyWith(fillColor: Colors.grey.shade50),
                              validator: (value) => (value == null || value.trim().isEmpty)
                                  ? 'Please provide a pickup location.'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _dropController,
                              textInputAction: TextInputAction.next,
                              decoration: _buildInputDecoration(
                                'Drop-off Address',
                                'e.g., No. 123, 5th Street',
                                Icons.location_on,
                                Colors.red.shade500,
                              ).copyWith(fillColor: Colors.grey.shade50),
                              validator: (value) => (value == null || value.trim().isEmpty)
                                  ? 'Please provide a destination address.'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // --- Instructions Section ---
                      _buildSectionHeader('Additional Instructions'),
                      TextFormField(
                        controller: _remarkController,
                        maxLines: 3,
                        textInputAction: TextInputAction.done,
                        decoration: _buildInputDecoration(
                          'Delivery Notes (Optional)',
                          'e.g., Please call when you arrive, drop at the back door...',
                          Icons.note_alt_outlined,
                          Colors.orange.shade400,
                        ).copyWith(alignLabelWithHint: true),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),

            // --- Fixed Bottom Action Bar ---
            // --- Fixed Bottom Action Bar ---
            Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16, // Safe area
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitDeliveryRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.green.shade700.withOpacity(0.7),
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
                    Text(
                      'Confirm Delivery',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}