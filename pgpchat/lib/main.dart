import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/login_screen.dart';
import 'screens/chat_list_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        theme: AppTheme.darkTheme,
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (auth.isAuthenticated) {
              // Load settings when authenticated
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<SettingsProvider>().loadSettings();
              });
              return const ChatListScreen();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
