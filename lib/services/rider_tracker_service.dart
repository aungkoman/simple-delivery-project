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

    // 1. REGISTER THE HTTP LISTENER FIRST
    bg.BackgroundGeolocation.onHttp((bg.HttpEvent event) {
      print('================================================');
      if (event.success) {
        print('[HTTP Sync] 🟢 SUCCESS - Status: ${event.status}');
        print('[HTTP Sync] 🟢 Response: ${event.responseText}');
      } else {
        print('[HTTP Sync] 🔴 FAILED - Status: ${event.status}');
        print('[HTTP Sync] 🔴 Error: ${event.responseText}');
      }
      print('================================================');
    });

    // Optional: Log when locations are recorded locally before they sync
    bg.BackgroundGeolocation.onLocation((bg.Location location) {
      print('[Location Recorded] 📍 ${location.coords.latitude}, ${location.coords.longitude}');
    });


    await bg.BackgroundGeolocation.ready(bg.Config(
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
      distanceFilter: 0, // Only record if they move 15 meters
      stopOnTerminate: false, // Keep tracking even if they swipe the app away
      startOnBoot: true,      // Start tracking if they restart their phone
      debug: true,            // TRUE sounds a beep when location is recorded (Turn false for production)
      locationUpdateInterval: 15000,
      fastestLocationUpdateInterval: 15000,
      preventSuspend: true, // Keep CPU awake while stationary


      logLevel: bg.Config.LOG_LEVEL_VERBOSE,

      // PERMISSION CONFIGURATION
      locationAuthorizationRequest: 'Always',
      backgroundPermissionRationale: bg.PermissionRationale(
          title: "Background Location Required",
          message: "To track your route while the phone is locked, please select 'Allow all the time' in the next screen.",
          positiveAction: "Take me to settings",
          negativeAction: "Cancel"
      ),


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
        // bg.BackgroundGeolocation.start();
        bg.BackgroundGeolocation.start().then((bg.State state) {
          bg.BackgroundGeolocation.changePace(true); // <--- THE OVERRIDE
          print('🚀 Tracking started and locked into MOVING state.');
          print('🚀 Tracking already enabled. Locked into MOVING state.');
        });
      }
    });
  }

  void stopTracking() {
    bg.BackgroundGeolocation.stop();
  }
}