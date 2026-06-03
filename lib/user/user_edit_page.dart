import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserEditPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const UserEditPage({super.key, required this.userData});

  @override
  State<UserEditPage> createState() => _UserEditPageState();
}

class _UserEditPageState extends State<UserEditPage> {
  final supabase = Supabase.instance.client;

  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  late String _selectedRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill the text fields with the data passed from the listing page
    _fullNameController = TextEditingController(text: widget.userData['full_name'] ?? '');
    _phoneController = TextEditingController(text: widget.userData['phone'] ?? '');
    _emailController = TextEditingController(text: widget.userData['email'] ?? 'No email');

    // Ensure the role is one of our valid dropdown options
    final validRoles = ['customer', 'rider', 'admin'];
    final currentRole = widget.userData['role']?.toString().toLowerCase() ?? 'customer';
    _selectedRole = validRoles.contains(currentRole) ? currentRole : 'customer';
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _updateUser() async {
    setState(() => _isLoading = true);

    try {
      final fullName = _fullNameController.text.trim();
      final phone = _phoneController.text.trim();

      if (fullName.isEmpty) {
        throw const FormatException('Full Name cannot be empty.');
      }

      // Update the public.profiles table
      await supabase.from('profiles').update({
        'full_name': fullName,
        'phone': phone,
        'role': _selectedRole,
      }).eq('id', widget.userData['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User updated successfully!')),
        );
        Navigator.pop(context, true); // Return 'true' to indicate success and trigger a refresh
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating user: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit User'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Read-Only Email Field
            TextField(
              controller: _emailController,
              enabled: false, // Prevents editing
              decoration: const InputDecoration(
                labelText: 'Email (Read-Only)',
                border: OutlineInputBorder(),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Role Selection Dropdown
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Assign Role',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'customer', child: Text('Customer')),
                DropdownMenuItem(value: 'rider', child: Text('Rider')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedRole = value;
                  });
                }
              },
            ),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _updateUser,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Save Changes', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}