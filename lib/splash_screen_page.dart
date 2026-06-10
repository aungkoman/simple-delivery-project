import 'package:flutter/material.dart';
import 'package:simpledelivery/customer/customer_dashboard_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Adjust these imports to match your project paths
import 'auth_page.dart';
import 'admin/admin_panel_page.dart';
import 'rider/rider_dashboard_page.dart';
// import 'customer/customer_home_page.dart'; // Add your customer page import

class SplashScreenPage extends StatefulWidget {
  const SplashScreenPage({super.key});

  @override
  State<SplashScreenPage> createState() => _SplashScreenPageState();
}

class _SplashScreenPageState extends State<SplashScreenPage> {
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    // Optional: Add a small delay so the splash screen doesn't flash too fast
    await Future.delayed(const Duration(milliseconds: 1500));

    final session = supabase.auth.currentSession;

    if (session != null && session.user != null) {
      try {
        // User is logged in, fetch their role and status
        final data = await supabase
            .from('profiles')
            .select('role, is_deleted')
            .eq('id', session.user!.id)
            .single();

        if (data['is_deleted'] == true) {
          // If deleted, sign them out and redirect to Auth
          await supabase.auth.signOut();
          _navigateToAuth(errorMessage: 'This account has been deactivated.');
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
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const CustomerDashboardPage()),
            );
          }
        }
      } catch (e) {
        // If there's an error fetching the profile, fall back to Auth Page
        _navigateToAuth(errorMessage: 'Session expired or error fetching profile.');
      }
    } else {
      // No active session, redirect to Auth Page
      _navigateToAuth();
    }
  }

  void _navigateToAuth({String? errorMessage}) {
    if (!mounted) return;

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AuthPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // You can replace this with your app's logo
            // Icon(Icons.local_shipping, size: 80, color: Colors.blue),
            SizedBox(
                width: 100,
                child: Image.asset("assets/images/app_icon.png")),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}