import 'package:go_router/go_router.dart';

import '../../app/app_shell.dart';
import '../../features/analysis/presentation/analysis_detail_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/onboarding_page.dart';
import '../../features/auth/presentation/role_select_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/documents/presentation/documents_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/legal_corpus/presentation/legal_corpus_page.dart';
import '../../features/profile/presentation/profile_page.dart';

GoRouter createAppRouter({
  Duration splashDelay = const Duration(milliseconds: 1600),
}) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => SplashPage(autoNavigateDelay: splashDelay),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/role-select',
        builder: (_, _) => const RoleSelectPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, _) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/documents',
                builder: (_, _) => const DocumentsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/laws',
                builder: (_, _) => const LegalCorpusPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/analysis/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return AnalysisDetailPage(analysisId: id);
        },
      ),
    ],
  );
}
