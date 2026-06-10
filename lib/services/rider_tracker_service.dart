import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:supabase_flutter/supabase_flutter.dart';

class RiderTrackerService {
  final supabase = Supabase.instance.client;

  Future<void> startBackgroundTracking() async {
    final session = supabase.auth.currentSession;
    final riderId = session?.user.id;

    if (riderId == null) return;

    // Replace these with your actual Supabase keys
    const supabaseUrl = 'https://nhyeutkgxyiqcxrfojcq.supabase.co';
    const anonKey = 'sb_publishable_Vmh6rfrhGndn3jHJp1XOLw_Z5ZlS6Cz';

    await bg.BackgroundGeolocation.ready(bg.Config(
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
      distanceFilter: 15, // Only record if they move 15 meters
      stopOnTerminate: false, // Keep tracking even if they swipe the app away
      startOnBoot: true,      // Start tracking if they restart their phone
      debug: true,            // TRUE sounds a beep when location is recorded (Turn false for production)

      // --- THE MAGIC SUPABASE REST API INTEGRATION ---
      url: '$supabaseUrl/rest/v1/rider_locations',
      method: "POST",
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer ${session?.accessToken}',
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal', // Tells Supabase we don't need the data returned
      },
      // We format the plugin's payload to match our Supabase columns exactly
      httpRootProperty: '.',
      locationTemplate: '{"rider_id": "$riderId", "latitude": <%= latitude %>, "longitude": <%= longitude %>}',
      autoSync: true, // Auto uploads to Supabase when internet is available
    )).then((bg.State state) {
      if (!state.enabled) {
        // Start tracking!
        bg.BackgroundGeolocation.start();
      }
    });
  }

  void stopTracking() {
    bg.BackgroundGeolocation.stop();
  }
}