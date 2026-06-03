import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserListingPage extends StatefulWidget {
  const UserListingPage({super.key});

  @override
  State<UserListingPage> createState() => _UserListingPageState();
}

class _UserListingPageState extends State<UserListingPage> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<dynamic> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      // Fetch all profiles, ordered by role so admins/riders group together
      final response = await supabase
          .from('profiles')
          .select()
          .order('role', ascending: true);

      if (mounted) {
        setState(() {
          _users = response;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $error'), backgroundColor: Colors.red),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper method to assign icons based on the user's role
  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'rider':
        return Icons.motorcycle;
      case 'customer':
      default:
        return Icons.person;
    }
  }

  // Helper method to assign colors based on the user's role
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.blue;
      case 'rider':
        return Colors.orange;
      case 'customer':
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
      ),
      // RefreshIndicator allows the admin to pull-to-refresh the list
      body: RefreshIndicator(
        onRefresh: _fetchUsers,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _users.isEmpty
            ? ListView( // Use ListView so pull-to-refresh still works when empty
          children: const [
            SizedBox(height: 300),
            Center(child: Text('No users found.')),
          ],
        )
            : ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: _users.length,
          itemBuilder: (context, index) {
            final user = _users[index];
            final role = user['role'] ?? 'Unknown';
            final fullName = user['full_name'] ?? 'No Name Provided';
            final phone = user['phone'] ?? 'No Phone';

            // 1. Extract the newly added email field
            final email = user['email'] ?? 'No email recorded';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getRoleColor(role).withOpacity(0.2),
                  child: Icon(_getRoleIcon(role), color: _getRoleColor(role)),
                ),
                title: Text(
                  fullName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('Role: ${role.toUpperCase()}'),

                    // 2. Display the email
                    Text('Email: $email', style: const TextStyle(color: Colors.blueGrey)),

                    Text('Phone: $phone'),
                  ],
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.grey),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Edit feature coming soon!')),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}