import 'dart:ui';

import 'package:flutter/material.dart';

/// Displays a frosted privacy shield when the app enters `inactive` state
/// (e.g. Android App Switcher / Incoming call / OS system overlay).
class PrivacyCurtainScope extends StatefulWidget {
  const PrivacyCurtainScope({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<PrivacyCurtainScope> createState() => _PrivacyCurtainScopeState();
}

class _PrivacyCurtainScopeState extends State<PrivacyCurtainScope>
    with WidgetsBindingObserver {
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) {
      if (_obscured) setState(() => _obscured = false);
      return;
    }
    final shouldObscure = state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden;
    if (shouldObscure != _obscured) {
      setState(() => _obscured = shouldObscure);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.enabled && _obscured)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                color: const Color(0xE60B3B8C),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        size: 56,
                        color: Colors.white,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'LexGuard AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Shartnomalar maxfiyligi himoyalangan',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
