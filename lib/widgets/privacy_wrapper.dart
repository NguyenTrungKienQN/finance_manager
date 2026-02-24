import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/biometric_service.dart';

class PrivacyWrapper extends StatefulWidget {
  final Widget child;
  const PrivacyWrapper({super.key, required this.child});

  @override
  State<PrivacyWrapper> createState() => _PrivacyWrapperState();
}

class _PrivacyWrapperState extends State<PrivacyWrapper>
    with WidgetsBindingObserver {
  bool _isAuthenticated = false;
  bool _isBackground = false;
  bool _isAuthenticating = false; // Guard against re-entry loop
  final BiometricService _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authenticate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return; // Prevent loop
    if (mounted) {
      setState(() {
        _isAuthenticating = true;
      });
    }

    try {
      final result = await _biometricService.authenticate();

      if (result == BiometricResult.cancelled) {
        // Force exit the app if the user taps Cancel on the FaceID prompt
        if (Platform.isIOS) {
          exit(0);
        } else {
          SystemNavigator.pop();
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isAuthenticated = (result == BiometricResult.success ||
              result == BiometricResult.notAvailable);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // ONLY on paused (actually leaving app), NOT inactive
      // inactive fires when biometric dialog shows — ignoring it prevents the loop
      setState(() {
        _isBackground = true;
        _isAuthenticated = false;
      });
    } else if (state == AppLifecycleState.inactive) {
      // Show blur for app switcher preview, but do NOT reset auth
      setState(() {
        _isBackground = true;
      });
    } else if (state == AppLifecycleState.resumed) {
      setState(() {
        _isBackground = false;
      });
      // Do NOT automatically call _authenticate() here!
      // When biometric dialog closes (fail/cancel), the app resumes.
      // Auto-calling it here defeats the purpose of the "Try Again" button
      // and can cause infinite Face ID prompt loops.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // Blur / Lock Overlay
        if (!_isAuthenticated || _isBackground)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withValues(alpha: 0.1),
                alignment: Alignment.center,
                child: _isBackground
                    ? const SizedBox() // Just blur in background
                    : Material(
                        color: Colors.transparent,
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.lock_outline,
                                size: 64,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Ứng dụng đang bị khóa',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      if (Platform.isIOS) {
                                        exit(0);
                                      } else {
                                        SystemNavigator.pop();
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 12),
                                      foregroundColor: Colors.white70,
                                    ),
                                    child: const Text('Thoát'),
                                  ),
                                  const SizedBox(width: 16),
                                  ElevatedButton(
                                    onPressed: _authenticate,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.indigo,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32, vertical: 12),
                                    ),
                                    child: const Text('Thử lại'),
                                  ),
                                ],
                              ),
                            ]),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}
