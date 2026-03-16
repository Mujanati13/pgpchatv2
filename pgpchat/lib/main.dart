import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/login_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/pin_lock_screen.dart';
import 'services/api_service.dart';
import 'services/pin_service.dart';
import 'services/push_notification_service.dart';

/// Global navigator key — used to pop all routes on logout from anywhere.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Always use the production server URL, overwriting any stale cached value
  await ApiService().setBaseUrl('http://93.127.129.90:3000/api');
  await PinService().init();
  await PushNotificationService().init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const PgpChatApp());
}

class PgpChatApp extends StatelessWidget {
  const PgpChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuth()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp(
        title: 'PGP Chat',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: AppTheme.darkTheme,
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (auth.isAuthenticated) {
              // Load settings when authenticated
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<SettingsProvider>().loadSettings();
              });
              return PinLockScreen(child: const ChatListScreen());
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
