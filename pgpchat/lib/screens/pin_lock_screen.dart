import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/pin_service.dart';
import '../services/pgp_service.dart';
import '../services/api_service.dart';
import '../widgets/responsive_center.dart';
import 'login_screen.dart';

class PinLockScreen extends StatefulWidget {
  final Widget child;
  const PinLockScreen({super.key, required this.child});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> with WidgetsBindingObserver {
  final PinService _pinService = PinService();
  final List<String> _entered = [];
  bool _locked = false;
  bool _shaking = false;
  bool _wiping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_pinService.isEnabled && !_wiping) {
        setState(() {
          _locked = true;
          _entered.clear();
        });
      }
    }
  }

  Future<void> _checkLock() async {
    await _pinService.init();
    if (_pinService.isEnabled) {
      setState(() => _locked = true);
    }
  }

  void _onDigit(String digit) {
    if (_entered.length >= 4 || _wiping) return;
    HapticFeedback.lightImpact();
    setState(() => _entered.add(digit));

    if (_entered.length == 4) {
      _verifyPin();
    }
  }

  void _onDelete() {
    if (_entered.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _entered.removeLast());
  }

  Future<void> _verifyPin() async {
    final pin = _entered.join();
    final valid = await _pinService.verifyPin(pin);

    if (valid) {
      setState(() {
        _locked = false;
        _entered.clear();
      });
      return;
    }

    // Wrong PIN — shake animation
    setState(() => _shaking = true);
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _shaking = false;
      _entered.clear();
    });

    // Check if we need to wipe
    if (_pinService.shouldWipe) {
      await _wipeApp();
    }
  }

  Future<void> _wipeApp() async {
    setState(() => _wiping = true);

    // Wipe PGP keys
    await PgpService().wipeKeys();
    // Wipe PIN
    await _pinService.removePin();
    // Clear all prefs (token, settings, etc.)
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Reset API token cache
    await ApiService().setToken(null);

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;

    return Scaffold(
      body: ResponsiveScaffoldBody(
        child: SafeArea(
          child: _wiping ? _buildWiping() : _buildPinEntry(),
        ),
      ),
    );
  }

  Widget _buildWiping() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, size: 64, color: AppColors.error),
          SizedBox(height: 24),
          Text(
            'Too many failed attempts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Resetting app data...',
            style: TextStyle(fontSize: 14, color: AppColors.textSubDark),
          ),
          SizedBox(height: 24),
          CircularProgressIndicator(color: AppColors.error),
        ],
      ),
    );
  }

  Widget _buildPinEntry() {
    final remaining = _pinService.attemptsRemaining;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lock icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.lock_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Enter PIN',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textMainDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your 4-digit PIN to unlock',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSubDark,
              ),
            ),
            const SizedBox(height: 32),

            // PIN dots
            TweenAnimationBuilder<double>(
              key: ValueKey(_shaking),
              tween: _shaking
                  ? Tween(begin: -10.0, end: 0.0)
                  : Tween(begin: 0.0, end: 0.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(value, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _entered.length;
                  return Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color: filled ? AppColors.primary : AppColors.borderDark,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),

            // Attempts warning
            if (remaining < PinService.maxAttempts)
              Text(
                remaining <= 2
                    ? '$remaining attempt${remaining == 1 ? '' : 's'} left before app reset'
                    : '$remaining attempts remaining',
                style: TextStyle(
                  fontSize: 12,
                  color: remaining <= 2 ? AppColors.error : AppColors.textSubDark,
                  fontWeight: remaining <= 2 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            const SizedBox(height: 40),

            // Numpad
            _buildNumpad(),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return SizedBox(
      width: 280,
      child: Column(
        children: [
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', 'del'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row.map((key) {
                  if (key.isEmpty) {
                    return const SizedBox(width: 72, height: 72);
                  }
                  if (key == 'del') {
                    return _NumpadKey(
                      onTap: _onDelete,
                      child: const Icon(Icons.backspace_outlined,
                          color: AppColors.textMainDark, size: 24),
                    );
                  }
                  return _NumpadKey(
                    onTap: () => _onDigit(key),
                    child: Text(
                      key,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMainDark,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _NumpadKey extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _NumpadKey({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderDark),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
