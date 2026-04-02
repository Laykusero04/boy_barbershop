import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/bloc/app/app_bloc.dart';
import 'package:boy_barbershop/bloc/app/app_event.dart';
import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/presentation/navigation/destinations.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.user,
    required this.selectedId,
    required this.onSelect,
  });

  final AppUser user;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final groups = <AppDestinationGroup, List<AppDestination>>{};
    for (final d in appDestinations) {
      (groups[d.group] ??= []).add(d);
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeader(user: user),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ..._buildGroup(
                    context: context,
                    title: 'OPERATIONS',
                    destinations: groups[AppDestinationGroup.operations] ?? const [],
                  ),
                  ..._buildGroup(
                    context: context,
                    title: 'MONEY',
                    destinations: groups[AppDestinationGroup.money] ?? const [],
                  ),
                  ..._buildGroup(
                    context: context,
                    title: 'INSIGHTS',
                    destinations: groups[AppDestinationGroup.insights] ?? const [],
                  ),
                  ..._buildGroup(
                    context: context,
                    title: 'STOCK',
                    destinations: groups[AppDestinationGroup.stock] ?? const [],
                  ),
                  ..._buildGroup(
                    context: context,
                    title: 'ACCOUNT',
                    destinations: groups[AppDestinationGroup.account] ?? const [],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.read<AppBloc>().add(const AppLogoutRequested());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroup({
    required BuildContext context,
    required String title,
    required List<AppDestination> destinations,
  }) {
    if (destinations.isEmpty) return const [];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                letterSpacing: 0.8,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
      ...destinations.map((d) {
        final selected = d.id == selectedId;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: ListTile(
            selected: selected,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            leading: Icon(d.icon),
            title: Text(d.title),
            onTap: () {
              Navigator.of(context).pop();
              onSelect(d.id);
            },
          ),
        );
      }),
    ];
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: scheme.primary.withValues(alpha: 0.12),
            foregroundColor: scheme.primary,
            child: Text(
              user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (user.email.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              user.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            user.role.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

