import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;

  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  bool _isLoading = true;
  bool _isSaving = false;
  String _userRole = 'user';

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _fetchProfileData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // The email is securely stored in the Auth session
      _emailController.text = user.email ?? 'No email';

      // Fetch the rest of the details from the public.profiles table
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _fullNameController.text = data['full_name'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _userRole = data['role'] ?? 'user';
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $error'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isSaving = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw const AuthException('No user logged in.');

      final fullName = _fullNameController.text.trim();
      final phone = _phoneController.text.trim();

      if (fullName.isEmpty) {
        throw const FormatException('Name cannot be empty.');
      }

      // Update the user's row in the profiles table
      await supabase.from('profiles').update({
        'full_name': fullName,
        'phone': phone,
      }).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        // Optionally pop back, or stay on the page
        // Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // Determine header color based on role to make it feel customized
  Color _getThemeColor() {
    switch (_userRole.toLowerCase()) {
      case 'admin': return Colors.blue;
      case 'rider': return Colors.orange;
      case 'customer': default: return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _getThemeColor();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: themeColor,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: themeColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            // Avatar Circle
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: themeColor.withOpacity(0.2),
                child: Text(
                  _fullNameController.text.isNotEmpty
                      ? _fullNameController.text.substring(0, 1).toUpperCase()
                      : '?',
                  style: TextStyle(fontSize: 40, color: themeColor, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _userRole.toUpperCase(),
                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ),
            const SizedBox(height: 32),

            // Email (Read Only)

            TextField(
              controller: _emailController,
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Email Address (Cannot be changed here)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  tooltip: 'Change Email',
                  onPressed: _showChangeEmailDialog,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 20),

            // Full Name
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 20),

            // Phone Number
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 40),

            // Save Button
            ElevatedButton(
              onPressed: _isSaving ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                _isSaving ? 'Saving...' : 'Save Changes',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangeEmailDialog() async {
    final TextEditingController newEmailController = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // StatefulBuilder allows updating the dialog's UI (loading state)
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change Email Address'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'We will send a confirmation link to your new email. The change will not take effect until you click it.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'New Email Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                    final newEmail = newEmailController.text.trim();
                    if (newEmail.isEmpty || !newEmail.contains('@')) return;

                    setDialogState(() => isSubmitting = true);

                    try {
                      // Tell Supabase Auth to update the email
                      await supabase.auth.updateUser(
                        UserAttributes(email: newEmail),
                      );

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Confirmation link sent! Please check your new email inbox.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setDialogState(() => isSubmitting = false);
                      }
                    }
                  },
                  child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send Link'),
                ),
              ],
            );
          },
        );
      },
    );
  }

}