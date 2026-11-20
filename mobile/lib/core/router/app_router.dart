import 'package:go_router/go_router.dart';

import '../../app/app_shell.dart';
import '../../features/analysis/presentation/analysis_detail_page.dart';
import '../../features/documents/presentation/documents_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/legal_corpus/presentation/legal_corpus_page.dart';
import '../../features/profile/presentation/profile_page.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
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
