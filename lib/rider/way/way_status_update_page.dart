import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WayStatusUpdatePage extends StatefulWidget {
  final Map<String, dynamic> wayData;

  const WayStatusUpdatePage({super.key, required this.wayData});

  @override
  State<WayStatusUpdatePage> createState() => _WayStatusUpdatePageState();
}

class _WayStatusUpdatePageState extends State<WayStatusUpdatePage> {
  final supabase = Supabase.instance.client;

  late TextEditingController _remarkController;
  late String _selectedStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _remarkController = TextEditingController(text: widget.wayData['remark'] ?? '');

    final validStatuses = ['pending', 'preparing', 'assigned', 'picked_up', 'delivering', 'dropped', 'cancelled'];
    final currentStatus = widget.wayData['status']?.toString().toLowerCase() ?? 'pending';
    _selectedStatus = validStatuses.contains(currentStatus) ? currentStatus : 'pending';
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _updateStatusAndRemark() async {
    setState(() => _isLoading = true);

    try {
      await supabase.from('ways').update({
        'status': _selectedStatus,
        'remark': _remarkController.text.trim(),
      }).eq('id', widget.wayData['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status and Remark updated!')),
        );
        Navigator.pop(context, true); // Pop back and trigger refresh
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Update Way #${widget.wayData['id']}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: InputDecoration(
                labelText: 'Delivery Status',
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

            TextField(
              controller: _remarkController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Add Remark / Note',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
                hintText: 'E.g., Customer requested drop at back door...',
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _updateStatusAndRemark,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Save Update', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}