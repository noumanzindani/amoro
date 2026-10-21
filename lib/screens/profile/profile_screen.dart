import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../theme.dart';
import '../../widgets/profile_card.dart';
import '../../widgets/ui.dart';

/// Your own profile, as other people see it.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final me = session.profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/profile/edit'),
          ),
          PopupMenuButton<String>(
            color: AppColors.surface,
            onSelected: (v) {
              if (v == 'blocked') context.push('/profile/blocked');
              if (v == 'signout') session.signOut();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'blocked', child: Text('Blocked people')),
              PopupMenuItem(value: 'signout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: me == null
          ? const Center(child: AppLoader())
          : ProfileDetails(user: me),
    );
  }
}
