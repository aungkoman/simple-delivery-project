import 'package:flutter/material.dart';
import 'package:simpledelivery/customer/customer_dashboard_page.dart';
import 'package:simpledelivery/rider/rider_dashboard_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin/admin_panel_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();

  bool _isLoading = false;
  bool _isLogin = true;
  bool _obscurePassword = true;

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  // Convert phone to pseudo-email for Supabase
  String _formatPhoneToEmail(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return '$cleanPhone@software100.com.mm';
  }

  Future<void> _authenticate() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    // Validate form fields locally first
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final phone = _phoneController.text.trim();
      final password = _passwordController.text.trim();
      final pseudoEmail = _formatPhoneToEmail(phone);

      if (_isLogin) {
        // --- LOGIN LOGIC ---
        final AuthResponse res = await supabase.auth.signInWithPassword(
          email: pseudoEmail,
          password: password,
        );

        final user = res.user;
        if (user != null) {
          final data = await supabase
              .from('profiles')
              .select('role, is_deleted')
              .eq('id', user.id)
              .single();

          if (data['is_deleted'] == true) {
            await supabase.auth.signOut();
            throw const AuthException('This account has been deactivated.');
          }

          final String role = data['role'] ?? 'customer';

          if (mounted) {
            Widget nextScreen;
            if (role == 'admin') {
              nextScreen = const AdminPanelPage();
            } else if (role == 'rider') {
              nextScreen = const RiderDashboardPage();
            } else {
              nextScreen = const CustomerDashboardPage();
            }
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => nextScreen));
          }
        }
      } else {
        // --- REGISTER LOGIC ---
        final fullName = _fullNameController.text.trim();

        await supabase.auth.signUp(
          email: pseudoEmail,
          password: password,
          data: {
            'full_name': fullName,
            'display_name': fullName, // Using full name as display name
            'phone': phone,
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Registration successful! You can now log in.'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Clear password and switch to login mode
          _passwordController.clear();
          setState(() => _isLogin = true);
        }
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('An unexpected error occurred. Please try again.'),
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

  InputDecoration _buildInputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.green.shade600, size: 22),
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Branding / Header ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.local_shipping_rounded, size: 64, color: Colors.green.shade700),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isLogin ? 'Welcome Back!' : 'Create an Account',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin
                          ? 'Enter your phone number to continue'
                          : 'Sign up to start requesting deliveries',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 40),

                    // --- Registration Fields ---
                    if (!_isLogin) ...[
                      TextFormField(
                        controller: _fullNameController,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        decoration: _buildInputDecoration('Full Name', 'e.g., Aung Aung', Icons.person_outline),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Please enter your name' : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // --- Phone Number Field ---
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: _buildInputDecoration('Phone Number', '09123456789', Icons.phone_android_outlined),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Please enter your phone number';
                        if (value.length < 6) return 'Please enter a valid phone number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // --- Password Field ---
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _authenticate(),
                      decoration: _buildInputDecoration('Password', '••••••••', Icons.lock_outline).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Please enter your password';
                        if (!_isLogin && value.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // --- Submit Button ---
                    ElevatedButton(
                      onPressed: _isLoading ? null : _authenticate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.green.shade700.withOpacity(0.7),
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
                          : Text(
                        _isLogin ? 'Login' : 'Create Account',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- Toggle Mode Button ---
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _formKey.currentState?.reset();
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green.shade700,
                      ),
                      child: RichText(
                        text: TextSpan(
                          text: _isLogin ? "Don't have an account? " : "Already have an account? ",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          children: [
                            TextSpan(
                              text: _isLogin ? "Sign up" : "Log in",
                              style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}