import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_env.dart';
import '../core/network/api_client.dart';
import '../core/router/app_router.dart';
import '../core/security/privacy_curtain.dart';
import '../core/security/screen_security.dart';
import '../core/theme/app_theme.dart';
import '../features/contracts/data/local_demo_lexguard_repository.dart';
import '../features/contracts/data/remote_lexguard_repository.dart';
import '../features/contracts/domain/entities/lex_models.dart';
import '../features/contracts/domain/repositories/lexguard_repository.dart';
import '../features/contracts/presentation/cubit/contracts_cubit.dart';
import '../features/session/presentation/cubit/session_cubit.dart';

class LexGuardApp extends StatefulWidget {
  const LexGuardApp({super.key, this.repository});

  final LexGuardRepository? repository;

  @override
  State<LexGuardApp> createState() => _LexGuardAppState();
}

class _LexGuardAppState extends State<LexGuardApp> {
  late final GoRouter _router;
  late final LexGuardRepository _repo;
  late final ScreenSecurityService _screenSecurity;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter();
    _screenSecurity = ScreenSecurityService();
    if (widget.repository != null) {
      _repo = widget.repository!;
    } else if (AppEnv.useMockData) {
      _repo = LocalDemoLexGuardRepository();
    } else {
      final tokenStore = SecureTokenStore();
      _repo = RemoteLexGuardRepository(ApiClient(tokenStore: tokenStore));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SessionCubit(_screenSecurity)),
        BlocProvider(create: (_) => ContractsCubit(_repo)..bootstrap()),
      ],
      child: BlocBuilder<SessionCubit, SessionState>(
        builder: (context, session) {
          return MaterialApp.router(
            title: 'LexGuard AI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(
              segment: session.segment,
              brightness: Brightness.light,
            ),
            darkTheme: AppTheme.build(
              segment: session.segment,
              brightness: Brightness.dark,
            ),
            themeMode: session.themeMode,
            routerConfig: _router,
            builder: (context, child) {
              final secured = PrivacyCurtainScope(
                enabled: session.privacyCurtainEnabled,
                child: child ?? const SizedBox.shrink(),
              );
              final width = MediaQuery.sizeOf(context).width;
              if (width >= 840 && session.phoneFrameOnDesktop) {
                return _IphoneDesktopPreviewWrapper(
                  segment: session.segment,
                  onToggleFrame: () =>
                      context.read<SessionCubit>().toggleDesktopFrame(),
                  child: secured,
                );
              }
              return secured;
            },
          );
        },
      ),
    );
  }
}

class _IphoneDesktopPreviewWrapper extends StatelessWidget {
  const _IphoneDesktopPreviewWrapper({
    required this.segment,
    required this.onToggleFrame,
    required this.child,
  });

  final AccountSegment segment;
  final VoidCallback onToggleFrame;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final roleLabel = segment == AccountSegment.business
        ? 'Yuridik (Emerald)'
        : 'Jismoniy (Sapphire)';

    return Scaffold(
      backgroundColor: const Color(0xFF080D18),
      body: Column(
        children: [
          Container(
            height: 44,
            color: const Color(0xFF0D1322),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.device_phone_portrait,
                  color: Color(0xFF38BDF8),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'LexGuard AI · iOS Glassmorphism Preview · Faol rol: $roleLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onToggleFrame,
                  icon: const Icon(
                    CupertinoIcons.desktopcomputer,
                    color: Color(0xFF38BDF8),
                    size: 15,
                  ),
                  label: const Text(
                    'Keng ekran',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Container(
                width: 414,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(44),
                  border: Border.all(color: const Color(0xFF2B3447), width: 7),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 40,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: 14, bottom: 8),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
