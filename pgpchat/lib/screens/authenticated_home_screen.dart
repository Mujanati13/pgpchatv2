import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/pgp_service.dart';
import 'chat_list_screen.dart';
import 'keygen_step1_screen.dart';
import 'pin_lock_screen.dart';

class AuthenticatedHomeScreen extends StatelessWidget {
  const AuthenticatedHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PinLockScreen(child: PgpKeyGate());
  }
}

class PgpKeyGate extends StatefulWidget {
  const PgpKeyGate({super.key});

  @override
  State<PgpKeyGate> createState() => _PgpKeyGateState();
}

class _PgpKeyGateState extends State<PgpKeyGate> {
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
