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
  final _phoneController = TextEditingController(); // Email အစား Phone
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isLoading = false;
  bool _isLogin = true;

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  // ဖုန်းနံပါတ်ကို Dummy Email Format သို့ ပြောင်းပေးသော Function
  String _formatPhoneToEmail(String phone) {
    // ကိန်းဂဏန်းများသာ ကျန်အောင် စစ်ထုတ်ခြင်း (ဥပမာ - space များ၊ + များ ပါလာလျှင် ဖယ်ရန်)
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return '$cleanPhone@simpledelivery.dummy.com';
  }

  Future<void> _authenticate() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final phone = _phoneController.text.trim();
      final password = _passwordController.text.trim();

      if (phone.isEmpty || password.isEmpty) {
        throw const AuthException('Please enter both phone number and password.');
      }

      // Supabase သို့ မပို့ခင် ဖုန်းနံပါတ်ကို Email Format ပြောင်းခြင်း
      final pseudoEmail = _formatPhoneToEmail(phone);

      if (_isLogin) {
        // Log in logic
        final AuthResponse res = await supabase.auth.signInWithPassword(
          email: pseudoEmail,
          password: password,
        );

        final user = res.user;
        if (user != null) {
          final data = await supabase
              .from('profiles')
              .select('role, is_deleted') // Fetch the deleted status
              .eq('id', user.id)
              .single();

          if (data['is_deleted'] == true) {
            // If they are soft-deleted, immediately log them out and show an error
            await supabase.auth.signOut();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('This account has been deactivated.')),
              );
            }
            return;
          }

          final String role = data['role'] ?? 'customer';

          if (mounted) {
            if (role == 'admin') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const AdminPanelPage()),
              );
            } else if (role == 'rider') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const RiderDashboardPage()),
              );
            } else if (role == 'customer') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const CustomerDashboardPage()),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Logged in successfully as $role!')),
              );
            }
          }
        }
      } else {
        // Register logic
        final fullName = _fullNameController.text.trim();
        final displayName = fullName;

        if (fullName.isEmpty) {
          throw const AuthException('Please fill in your full name.');
        }

        await supabase.auth.signUp(
          email: pseudoEmail,
          password: password,
          data: {
            'full_name': fullName,
            'display_name': displayName,
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful! You can now log in.')),
          );
          // ချက်ချင်း Login မဝင်စေချင်လျှင် Login Form သို့ ပြန်ပြောင်းပေးနိုင်ပါသည်
          setState(() {
            _isLogin = true;
          });
        }
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Login' : 'Register'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              if (!_isLogin) ...[
                TextField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name (Official)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Phone Number Input
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone, // ပြောင်းလဲထားသော အပိုင်း
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '09123456789',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _authenticate,
                child: Text(_isLoading ? 'Loading...' : (_isLogin ? 'Login' : 'Register')),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                child: Text(
                  _isLogin
                      ? 'Don\'t have an account? Register'
                      : 'Already have an account? Login',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}