import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/login_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/chat_detail_screen.dart';
import 'screens/keygen_step1_screen.dart';
import 'screens/pin_lock_screen.dart';
import 'services/api_service.dart';
import 'services/pgp_service.dart';
import 'services/pin_service.dart';
import 'services/push_notification_service.dart';

/// Global navigator key — used to pop all routes on logout from anywhere.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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

class PgpChatApp extends StatefulWidget {
  const PgpChatApp({super.key});

  @override
  State<PgpChatApp> createState() => _PgpChatAppState();
}

class _PgpChatAppState extends State<PgpChatApp> {
  StreamSubscription<String>? _openConversationSub;

  @override
  void initState() {
    super.initState();

    final push = PushNotificationService();
    _openConversationSub = push.openConversationStream.listen(
      _openConversationFromNotification,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pendingId = push.consumePendingOpenConversationUserId();
      if (pendingId != null) {
        _openConversationFromNotification(pendingId);
      }
    });
  }

  @override
  void dispose() {
    _openConversationSub?.cancel();
    super.dispose();
  }

  Future<void> _openConversationFromNotification(String otherUserId) async {
    final nav = navigatorKey.currentState;
    final navContext = navigatorKey.currentContext;
    if (nav == null || navContext == null) return;

    final auth = Provider.of<AuthProvider>(navContext, listen: false);
    if (!auth.isAuthenticated) return;
    if (!await PgpService().hasKeyPair) return;

    String otherUsername = 'Conversation';
    String? otherPublicKey;

    try {
      final result = await ApiService().getConversations();
      final conversations = List<Map<String, dynamic>>.from(
        result['conversations'] as List? ?? [],
      );

      for (final conv in conversations) {
        if (conv['other_user_id']?.toString() == otherUserId) {
          otherUsername = conv['other_username']?.toString() ?? otherUsername;
          otherPublicKey = conv['other_public_key'] as String?;
          break;
        }
      }
    } catch (_) {
      // Fallback title if conversation lookup fails.
    }

    nav.push(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          otherUserId: otherUserId,
          otherUsername: otherUsername,
          otherPublicKey: otherPublicKey,
        ),
      ),
    );
  }

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
              return const PinLockScreen(child: _PgpKeyGate());
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}

class _PgpKeyGate extends StatefulWidget {
  const _PgpKeyGate();

  @override
  State<_PgpKeyGate> createState() => _PgpKeyGateState();
}

class _PgpKeyGateState extends State<_PgpKeyGate> {
  final PgpService _pgpService = PgpService();
  late Future<bool> _hasKeyPairFuture;

  @override
  void initState() {
    super.initState();
    _hasKeyPairFuture = _pgpService.hasKeyPair;
    _pgpService.addListener(_refreshKeyState);
  }

  @override
  void dispose() {
    _pgpService.removeListener(_refreshKeyState);
    super.dispose();
  }

  void _refreshKeyState() {
    if (!mounted) return;
    setState(() {
      _hasKeyPairFuture = _pgpService.hasKeyPair;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasKeyPairFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.backgroundDark,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final hasKeyPair = snapshot.data ?? false;
        if (!hasKeyPair) {
          return const KeygenStep1Screen();
        }

        return const ChatListScreen();
      },
    );
  }
}
