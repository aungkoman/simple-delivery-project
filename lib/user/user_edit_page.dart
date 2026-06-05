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
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  late String _selectedRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.userData['full_name'] ?? '');
    _phoneController = TextEditingController(text: widget.userData['phone'] ?? '');
    _emailController = TextEditingController(text: widget.userData['email'] ?? 'No email recorded');

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
    FocusScope.of(context).unfocus(); // Dismiss keyboard

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final fullName = _fullNameController.text.trim();
      final phone = _phoneController.text.trim();

      await supabase.from('profiles').update({
        'full_name': fullName,
        'phone': phone,
        'role': _selectedRole,
      }).eq('id', widget.userData['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('User profile updated successfully!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // Return 'true' to trigger list refresh
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user: $error'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- UI Helpers ---

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.indigo.shade400, size: 22),
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
        borderSide: BorderSide(color: Colors.indigo.shade600, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
    );
  }

  // Helper method to build custom selectable chips
  Widget _buildRoleChip(String roleValue, String label, IconData icon) {
    final isSelected = _selectedRole == roleValue;

    return ChoiceChip(
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.indigo.shade400
            ),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          setState(() => _selectedRole = roleValue);
        }
      },
      selectedColor: Colors.indigo.shade600,
      backgroundColor: Colors.white,
      showCheckmark: false, // Hide default checkmark to rely on our custom colors/icons
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? Colors.indigo.shade600 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Edit User Profile', style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.indigo.shade700,
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
                      // --- Read-Only Identity Info ---
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8, left: 4),
                        child: Text('Account Identity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ),
                      TextFormField(
                        controller: _emailController,
                        enabled: false,
                        style: TextStyle(color: Colors.grey.shade600),
                        decoration: _buildInputDecoration('Email Address', Icons.lock_outline).copyWith(
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Text(
                          'Email addresses are linked to authentication and cannot be changed here.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // --- Editable Profile Info ---
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8, left: 4),
                        child: Text('Profile Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ),
                      TextFormField(
                        controller: _fullNameController,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        decoration: _buildInputDecoration('Full Name', Icons.person_outline),
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? 'Full Name cannot be empty.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        decoration: _buildInputDecoration('Phone Number', Icons.phone_outlined),
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? 'Phone Number cannot be empty.'
                            : null,
                      ),
                      const SizedBox(height: 32),

                      // --- System Role (Now using Chips) ---
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8, left: 4),
                        child: Text('System Access Role', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ),
                      Wrap(
                        spacing: 12, // Horizontal space between chips
                        runSpacing: 12, // Vertical space between lines of chips
                        children: [
                          _buildRoleChip('customer', 'Customer', Icons.person_outline),
                          _buildRoleChip('rider', 'Rider', Icons.motorcycle_outlined),
                          _buildRoleChip('admin', 'Admin', Icons.admin_panel_settings_outlined),
                        ],
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
              width: double.infinity, // Ensure the container spans full width
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
                ],
              ),
              // Wrap the button in a SizedBox to prevent shrinking
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.indigo.shade700.withOpacity(0.7),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  )
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_outlined, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}