import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:boy_barbershop/data/admin_repository.dart';
import 'package:boy_barbershop/models/app_user.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  late final AdminRepository _repo;
  StreamSubscription<List<AuditLogEntry>>? _sub;

  List<AuditLogEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = context.read<AdminRepository>();
    _sub = _repo.watchAuditLogs(limit: 200).listen(
      (entries) {
        if (!mounted) return;
        setState(() {
          _entries = entries;
          _loading = false;
          _error = null;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_entries.isEmpty) {
      return Center(
        child: Text(
          'No audit logs yet',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return _AuditLogTile(entry: entry);
      },
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  const _AuditLogTile({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dateStr = entry.timestamp != null
        ? _formatDate(entry.timestamp!)
        : 'Unknown time';

    final actionInfo = _actionMeta(entry.action);

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            CircleAvatar(
              radius: 18,
              backgroundColor: actionInfo.color.withValues(alpha: 0.12),
              foregroundColor: actionInfo.color,
              child: Icon(actionInfo.icon, size: 18),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    actionInfo.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'by ${entry.actorName}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (entry.details != null && entry.details!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.details!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final m = months[dt.month - 1];
    final d = dt.day;
    final y = dt.year;
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$m $d, $y  $hour:$min $amPm';
  }

  static ({String label, IconData icon, Color color}) _actionMeta(
    String action,
  ) {
    return switch (action) {
      'create_user' => (
        label: 'User created',
        icon: Icons.person_add_outlined,
        color: Colors.green,
      ),
      'update_user' => (
        label: 'User updated',
        icon: Icons.edit_outlined,
        color: Colors.blue,
      ),
      'enable_user' => (
        label: 'User enabled',
        icon: Icons.check_circle_outline,
        color: Colors.teal,
      ),
      'disable_user' => (
        label: 'User disabled',
        icon: Icons.block_outlined,
        color: Colors.red,
      ),
      _ => (
        label: action,
        icon: Icons.info_outline,
        color: Colors.grey,
      ),
    };
  }
}
