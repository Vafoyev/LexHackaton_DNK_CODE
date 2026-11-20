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
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: session.themeMode,
            routerConfig: _router,
            builder: (context, child) {
              return PrivacyCurtainScope(
                enabled: session.privacyCurtainEnabled,
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
