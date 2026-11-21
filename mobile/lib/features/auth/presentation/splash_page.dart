import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../session/presentation/cubit/session_cubit.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    this.autoNavigateDelay = const Duration(milliseconds: 1600),
  });

  final Duration autoNavigateDelay;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _scale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();

    _navTimer = Timer(widget.autoNavigateDelay, () {
      if (!mounted) return;
      context.go('/onboarding');
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: const Key('splash_screen'),
      backgroundColor: c.canvasBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final logoSize = (w * 0.22).clamp(76.0, 100.0);
          final titleSize = (w * 0.095).clamp(34.0, 44.0);
          final subSize = (w * 0.044).clamp(16.0, 20.0);

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        Color.lerp(c.canvasBg, c.rolePrimaryDark, 0.22)!,
                        c.canvasBg,
                      ]
                    : [
                        Color.lerp(Colors.white, c.rolePrimary, 0.06)!,
                        c.canvasBg,
                      ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: (w * 0.08).clamp(24.0, 40.0),
                  vertical: (h * 0.04).clamp(20.0, 36.0),
                ),
                child: Column(
                  children: [
                    const Spacer(),
                    FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: ScaleTransition(
                          scale: _scale,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: logoSize,
                                height: logoSize,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(logoSize * 0.28),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      c.roleGradientStart,
                                      c.roleGradientEnd,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          c.rolePrimary.withValues(alpha: 0.28),
                                      blurRadius: 32,
                                      offset: const Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  CupertinoIcons.shield_lefthalf_fill,
                                  color: Colors.white,
                                  size: logoSize * 0.50,
                                ),
                              ),
                              SizedBox(height: (h * 0.032).clamp(20.0, 30.0)),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'LexGuard AI',
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.2,
                                    height: 1.05,
                                    color: c.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                AppStrings.t(
                                  lang,
                                  'splash_tagline',
                                  script: script,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: subSize,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 64,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 3.5,
                          backgroundColor:
                              c.rolePrimary.withValues(alpha: 0.14),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(c.rolePrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
