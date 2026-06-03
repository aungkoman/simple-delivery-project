import 'package:flutter/material.dart';
import 'package:simpledelivery/user/user_edit_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserDetailPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const UserDetailPage({super.key, required this.userData});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  final supabase = Supabase.instance.client;
  bool _isDeleting = false;

  // Helper to get role colors (keeping it consistent)
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return Colors.blue;
      case 'rider': return Colors.orange;
      case 'customer': default: return Colors.green;
    }
  }

  Future<void> _deleteUser() async {
    // 1. Show Confirmation Dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${widget.userData['full_name']}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    // If user pressed cancel, stop here
    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      final userId = widget.userData['id'];

      // 2. Delete the user from the public.profiles table
      // await supabase.from('profiles').delete().eq('id', userId);
      // 👈 CHANGED: We UPDATE the row instead of DELETING it
      await supabase
          .from('profiles')
          .update({'is_deleted': true})
          .eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted successfully.')),
        );
        Navigator.pop(context, true); // Pop back to listing page and signal a refresh
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting user: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.userData['role'] ?? 'Unknown';
    final roleColor = _getRoleColor(role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details'),
        actions: [
          // Edit Button in the AppBar
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final bool? didUpdate = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserEditPage(userData: widget.userData),
                ),
              );
              if (didUpdate == true) {
                // If the profile was updated, pop back so the list can refresh.
                // Alternatively, you could fetch the fresh data here to stay on the detail page.
                if (mounted) Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Avatar Header
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: roleColor.withOpacity(0.2),
                child: Text(
                  (widget.userData['full_name'] ?? '?').substring(0, 1).toUpperCase(),
                  style: TextStyle(fontSize: 40, color: roleColor, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Data Cards
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow(Icons.person, 'Full Name', widget.userData['full_name'] ?? 'N/A'),
                    const Divider(),
                    _buildDetailRow(Icons.email, 'Email', widget.userData['email'] ?? 'N/A'),
                    const Divider(),
                    _buildDetailRow(Icons.phone, 'Phone', widget.userData['phone'] ?? 'N/A'),
                    const Divider(),
                    _buildDetailRow(Icons.badge, 'Role', role.toUpperCase(), color: roleColor),
                    const Divider(),
                    _buildDetailRow(Icons.fingerprint, 'User ID', widget.userData['id'] ?? 'N/A'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Delete Button
            ElevatedButton.icon(
              onPressed: _deleteUser,
              icon: const Icon(Icons.delete),
              label: const Text('Delete User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to draw clean rows of data
  Widget _buildDetailRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color ?? Colors.grey[600], size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}