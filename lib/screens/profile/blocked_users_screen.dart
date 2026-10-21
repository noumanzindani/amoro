import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/block_provider.dart';
import '../../services/user_repository.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final blocks = context.watch<BlockProvider>();
    final ids = blocks.blockedByMe;
    return Scaffold(
      appBar: AppBar(
        leading: const CircleBackButton(),
        title: const Text('Blocked people'),
      ),
      body: ids.isEmpty
          ? const Center(
              child: Text(
                'You haven\'t blocked anyone.',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          : FutureBuilder<List<AppUser>>(
              // Keyed by the set so it reloads after an unblock.
              key: ValueKey(ids.join(',')),
              future: context.read<UserRepository>().getMany(ids),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: AppLoader());
                return ListView(
                  children: [
                    for (final u in snap.data!)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surface,
                          backgroundImage: u.photoUrls.isEmpty
                              ? null
                              : CachedNetworkImageProvider(u.photoUrls.first),
                        ),
                        title: Text(u.name),
                        trailing: TextButton(
                          onPressed: () => blocks.unblock(u.uid),
                          child: const Text('Unblock'),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
