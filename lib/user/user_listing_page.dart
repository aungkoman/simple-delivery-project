import 'package:flutter/material.dart';
import 'package:simpledelivery/user/user_create_page.dart';
import 'package:simpledelivery/user/user_detail_page.dart';
import 'package:simpledelivery/user/user_edit_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserListingPage extends StatefulWidget {
  final int initialIndex; // 1. Add this variable

  const UserListingPage({super.key, this.initialIndex = 0});

  @override
  State<UserListingPage> createState() => _UserListingPageState();
}

class _UserListingPageState extends State<UserListingPage> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;

  // Separate lists for each tab
  List<dynamic> _allUsers = [];
  List<dynamic> _adminUsers = [];
  List<dynamic> _riderUsers = [];
  List<dynamic> _customerUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('is_deleted', false)
          .order('created_at', ascending: false); // Order by newest first

      final admins = [];
      final riders = [];
      final customers = [];

      // Sort users into their respective lists
      for (var user in response) {
        final role = user['role']?.toString().toLowerCase() ?? 'customer';
        if (role == 'admin') {
          admins.add(user);
        } else if (role == 'rider') {
          riders.add(user);
        } else {
          customers.add(user);
        }
      }

      if (mounted) {
        setState(() {
          _allUsers = response;
          _adminUsers = admins;
          _riderUsers = riders;
          _customerUsers = customers;
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

  // --- UI Helpers ---

  Widget _buildEmptyState(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(), // Ensures pull-to-refresh works
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserList(List<dynamic> users, String emptyMessage) {
    return RefreshIndicator(
      onRefresh: _fetchUsers,
      color: Colors.indigo.shade700,
      child: users.isEmpty
          ? _buildEmptyState(emptyMessage)
          : ListView.separated(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80), // Padding for FAB
        itemCount: users.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _UserCard(
            user: users[index],
            onRefreshRequested: () {
              setState(() => _isLoading = true);
              _fetchUsers();
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // All, Admins, Riders, Customers
      initialIndex: widget.initialIndex, // 3. Apply it here!
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('User Management', style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            isScrollable: true, // Allows tabs to scroll horizontally if screen is narrow
            tabAlignment: TabAlignment.start,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(text: 'All (${_isLoading ? '-' : _allUsers.length})'),
              Tab(text: 'Admins (${_isLoading ? '-' : _adminUsers.length})'),
              Tab(text: 'Riders (${_isLoading ? '-' : _riderUsers.length})'),
              Tab(text: 'Customers (${_isLoading ? '-' : _customerUsers.length})'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
          elevation: 4,
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const UserCreatePage()),
            );
            setState(() => _isLoading = true);
            _fetchUsers();
          },
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Add User', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.indigo.shade700))
            : TabBarView(
          children: [
            _buildUserList(_allUsers, 'No active users found.'),
            _buildUserList(_adminUsers, 'No admin accounts found.'),
            _buildUserList(_riderUsers, 'No rider accounts found.'),
            _buildUserList(_customerUsers, 'No customer accounts found.'),
          ],
        ),
      ),
    );
  }
}

// --- EXTRACTED COMPONENT ---

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onRefreshRequested;

  const _UserCard({required this.user, required this.onRefreshRequested});

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return Colors.indigo.shade600;
      case 'rider': return Colors.orange.shade600;
      case 'customer':
      default: return Colors.teal.shade600;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return Icons.admin_panel_settings_outlined;
      case 'rider': return Icons.motorcycle_outlined;
      case 'customer':
      default: return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = user['role'] ?? 'customer';
    final fullName = user['full_name'] ?? 'No Name Provided';
    final phone = user['phone'] ?? 'No Phone';
    final email = user['email'] ?? 'No email recorded';

    final roleColor = _getRoleColor(role);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final bool? needsRefresh = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => UserDetailPage(userData: user)),
            );
            if (needsRefresh == true) onRefreshRequested();
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: roleColor.withOpacity(0.1),
                  child: Icon(_getRoleIcon(role), color: roleColor, size: 24),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              fullName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: roleColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(phone, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              email,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: Colors.indigo.shade400),
                      tooltip: 'Edit User',
                      onPressed: () async {
                        final bool? didUpdate = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => UserEditPage(userData: user)),
                        );
                        if (didUpdate == true) onRefreshRequested();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}