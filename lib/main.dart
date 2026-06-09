import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simpledelivery/auth_page.dart';
import 'package:simpledelivery/providers/notification_provider.dart';
import 'package:simpledelivery/services/notification_storage_service.dart';
import 'package:simpledelivery/splash_screen_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification/notification_detail_page.dart';



/// Your exact Firebase credentials extracted from the JSON provided
FirebaseOptions get _currentPlatformOptions {
  if (Platform.isAndroid) {
    return const FirebaseOptions(
      apiKey: 'AIzaSyAPJjXvWp_jvAFWryF5SJ6b66cazKh-PMU',
      appId: '1:437446574582:android:68adb6346d7da6f2b607d7',
      messagingSenderId: '437446574582',
      projectId: 'simple-delivery-npt',
      storageBucket: 'simple-delivery-npt.firebasestorage.app',
    );
  }
  throw UnsupportedError('Platform not configured yet.');
}


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: _currentPlatformOptions);
  print("--- BACKGROUND MESSAGE RECEIVED ---");
  print("Title: ${message.notification?.title}");
  print("Body: ${message.notification?.body}");
  print("Data payload: ${message.data}");
  // 🟢 SAVE TO STORAGE WHEN APP IS CLOSED/BACKGROUNDED
  await NotificationStorageService.saveNotification(message);
}

void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nhyeutkgxyiqcxrfojcq.supabase.co',
    anonKey: 'sb_publishable_Vmh6rfrhGndn3jHJp1XOLw_Z5ZlS6Cz',
  );

  // Initialize Firebase with manual options
  await Firebase.initializeApp(
    options: _currentPlatformOptions,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MyApp(),
    ),
  );
  // runApp(const MyApp());
}


// Converted to StatefulWidget to manage persistent FCM Streams safely
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Global key to display snackbars from anywhere without needing a localized BuildContext
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  // 1. ADD THIS GLOBAL NAVIGATOR KEY
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupGlobalFCM();
  }

  Future<void> _setupGlobalFCM() async {
    final FirebaseMessaging fcm = FirebaseMessaging.instance;

    // Test Log: Trigger an explicit analytics event
    await FirebaseAnalytics.instance.logEvent(
      name: 'app_fcm_setup_triggered',
      parameters: {'status': 'started'},
    );

    // A. Request Permissions (Required for Android 13+)
    NotificationSettings settings = await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission.');

      // B. Get Device Token
      String? token = await fcm.getToken();
      print("FCM Device Token: $token");

      // C. FOREGROUND LISTENER
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async{
        print("--- FOREGROUND MESSAGE RECEIVED ---");
        print("Title: ${message.notification?.title}");

        // 🟢 SAVE TO STORAGE WHEN APP IS OPEN
        if (mounted) {
          Provider.of<NotificationProvider>(context, listen: false)
              .handleNewNotification(message);
        }


        if (message.notification != null) {
          // Displays a clean message banner at the bottom while using the app
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text("${message.notification!.title}: ${message.notification!.body}"),
              backgroundColor: Colors.deepPurple,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });

      // D. INTERACTION LISTENER (App running/suspended in background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print("--- APP OPENED VIA NOTIFICATION ---");

        // RECOMMENDED EVENT: Log when a user interacts and clicks open a background notification
        FirebaseAnalytics.instance.logEvent(
          name: 'notification_interacted',
          parameters: {
            'click_action': 'opened_from_background',
            'screen_target': message.data['screen'] ?? 'none',
          },
        );

        _handleNotificationNavigation(message);
      });

      // E. CHECK FOR TERMINATED LAUNCH (App completely closed)
      RemoteMessage? initialMessage = await fcm.getInitialMessage();
      if (initialMessage != null) {
        print("--- APP WOKE UP FROM TERMINATED STATE VIA NOTIFICATION ---");

        // RECOMMENDED EVENT: Log when an application cold boot is forced by a notification click
        FirebaseAnalytics.instance.logEvent(
          name: 'notification_interacted',
          parameters: {
            'click_action': 'opened_from_terminated',
            'screen_target': initialMessage.data['screen'] ?? 'none',
          },
        );

        _handleNotificationNavigation(initialMessage);
      }
    } else {
      print('User declined notification permission.');

      // RECOMMENDED EVENT: Track user notification opt-out rate
      await FirebaseAnalytics.instance.logEvent(
        name: 'notification_permission_changed',
        parameters: {'granted': false},
      );

    }
  }
  void _handleNotificationNavigation(RemoteMessage message) {
    print("Notification Payload Data");
    final notification = message.notification;
    final data = message.data;

    // Safely pull the attached notification image URL across platforms
    String? imageUrl;
    if (notification != null) {
      if (Platform.isAndroid) {
        imageUrl = notification.android?.imageUrl;
      } else if (Platform.isIOS) {
        imageUrl = notification.apple?.imageUrl;
      }
    }

    // Force a safe navigation drop down using the global routing engine
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => NotificationDetailPage(
          title: notification?.title ?? 'အကြောင်းကြားစာ',
          body: notification?.body ?? '',
          payload: data,
          imageUrl: imageUrl, // Send image path to detail page
        ),
      ),
    );
  }
  void _handleNotificationNavigation2(RemoteMessage message) {
    print("Notification Payload Data");
    // TODO: Add your routing logic here if you pass data parameters like: data['screen']
    final notification = message.notification;
    final data = message.data;

    // Use global navigator key to route to the new detail page safely
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => NotificationDetailPage(
          title: notification?.title ?? 'အကြောင်းကြားစာ',
          body: notification?.body ?? '',
          payload: data,
        ),
      ),
    );

  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey, // Linked for foreground notifications//
      // 🟢 FIX: Bind the navigatorKey here so _navigatorKey.currentState works!
      navigatorKey: _navigatorKey,

      debugShowCheckedModeBanner: false,
      title: 'Myanmar Credit Information System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreenPage(),
      // ADD THIS LINE: Automatically logs screen views when using named routes or standard MaterialPageRoutes
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
    );
  }
}
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Delivery App',
//       theme: ThemeData(
//         // This is the theme of your application.
//         //
//         // TRY THIS: Try running your application with "flutter run". You'll see
//         // the application has a purple toolbar. Then, without quitting the app,
//         // try changing the seedColor in the colorScheme below to Colors.green
//         // and then invoke "hot reload" (save your changes or press the "hot
//         // reload" button in a Flutter-supported IDE, or press "r" if you used
//         // the command line to start the app).
//         //
//         // Notice that the counter didn't reset back to zero; the application
//         // state is not lost during the reload. To reset the state, use hot
//         // restart instead.
//         //
//         // This works for code too, not just values: Most code changes can be
//         // tested with just a hot reload.
//         colorScheme: .fromSeed(seedColor: Colors.deepPurple),
//       ),
//       home: const SplashScreenPage(),
//
//
//     );
//   }
// }

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
