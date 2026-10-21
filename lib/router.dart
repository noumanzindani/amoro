import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'models/app_user.dart';
import 'providers/session_provider.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/community/community_screen.dart';
import 'screens/discover/discover_screen.dart';
import 'screens/home/home_shell.dart';
import 'screens/matches/matches_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/profile/blocked_users_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'widgets/ui.dart';

GoRouter buildRouter(SessionProvider session) => GoRouter(
  initialLocation: '/discover',
  refreshListenable: session,
  redirect: (context, state) {
    final at = state.matchedLocation;
    switch (session.status) {
      case SessionStatus.loading:
        return at == '/splash' ? null : '/splash';
      case SessionStatus.signedOut:
        return at == '/sign-in' ? null : '/sign-in';
      case SessionStatus.onboarding:
        return at == '/onboarding' ? null : '/onboarding';
      case SessionStatus.ready:
        const gates = {'/splash', '/sign-in', '/onboarding'};
        return gates.contains(at) ? '/discover' : null;
    }
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (_, _) => const Scaffold(body: Center(child: AppLoader())),
    ),
    GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
    GoRoute(
      path: '/chat/:matchId',
      builder: (_, state) => ChatScreen(
        matchId: state.pathParameters['matchId']!,
        other: state.extra is AppUser ? state.extra as AppUser : null,
      ),
    ),
    GoRoute(
      path: '/profile/blocked',
      builder: (_, _) => const BlockedUsersScreen(),
    ),
    GoRoute(
      path: '/profile/edit',
      builder: (_, _) => const EditProfileScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => HomeShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/discover',
              builder: (_, _) => const DiscoverScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/community',
              builder: (_, _) => const CommunityScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/matches', builder: (_, _) => const MatchesScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          ],
        ),
      ],
    ),
  ],
);
