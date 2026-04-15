import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/data/admin_repository.dart';
import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/user_role.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final AdminRepository _repo;
  StreamSubscription<List<AppUser>>? _sub;

  List<AppUser> _allUsers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Tabs: Cashiers, Barbers, All
    _tabController = TabController(length: 3, vsync: this);
    _repo = context.read<AdminRepository>();
    _sub = _repo.watchAllUsers().listen(
      (users) {
        if (!mounted) return;
        setState(() {
          _allUsers = users;
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
    _tabController.dispose();
    super.dispose();
  }

  List<AppUser> _filterByRole(UserRole role) =>
      _allUsers.where((u) => u.role == role).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        // ── Tab bar ──────────────────────────────────────────────────
        Material(
          color: scheme.surfaceContainerHighest,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Cashiers'),
              Tab(text: 'Barbers'),
              Tab(text: 'All'),
            ],
          ),
        ),

        // ── Body ─────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _UserList(
                          users: _filterByRole(UserRole.cashier),
                          emptyLabel: 'No cashier accounts yet',
                          admin: widget.user,
                          repo: _repo,
                        ),
                        _UserList(
                          users: _filterByRole(UserRole.barber),
                          emptyLabel: 'No barber accounts yet',
                          admin: widget.user,
                          repo: _repo,
                        ),
                        _UserList(
                          users: _allUsers,
                          emptyLabel: 'No users found',
                          admin: widget.user,
                          repo: _repo,
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// User list
// ═════════════════════════════════════════════════════════════════════════════

class _UserList extends StatelessWidget {
  const _UserList({
    required this.users,
    required this.emptyLabel,
    required this.admin,
    required this.repo,
  });

  final List<AppUser> users;
  final String emptyLabel;
  final AppUser admin;
  final AdminRepository repo;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: users.length + 1, // +1 for the Add button at the top
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return FilledButton.tonalIcon(
            onPressed: () => _showCreateDialog(context),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Add account'),
          );
        }
        final user = users[index - 1];
        return _UserCard(user: user, admin: admin, repo: repo);
      },
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _CreateUserDialog(admin: admin, repo: repo),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Single user card
// ═════════════════════════════════════════════════════════════════════════════

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.admin,
    required this.repo,
  });

  final AppUser user;
  final AppUser admin;
  final AdminRepository repo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSelf = user.uid == admin.uid;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _roleColor(user.role).withValues(alpha: 0.15),
          foregroundColor: _roleColor(user.role),
          child: Text(
            user.displayName.isNotEmpty
                ? user.displayName[0].toUpperCase()
                : '?',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _RoleChip(role: user.role),
          ],
        ),
        subtitle: Text(
          user.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isSelf
            ? Chip(
                label: Text(
                  'You',
                  style: theme.textTheme.labelSmall,
                ),
                visualDensity: VisualDensity.compact,
              )
            : IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _showEditDialog(context),
              ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _EditUserDialog(
        target: user,
        admin: admin,
        repo: repo,
      ),
    );
  }

  static Color _roleColor(UserRole role) => switch (role) {
        UserRole.admin => Colors.deepPurple,
        UserRole.cashier => Colors.teal,
        UserRole.barber => Colors.orange,
      };
}

// ═════════════════════════════════════════════════════════════════════════════
// Role chip
// ═════════════════════════════════════════════════════════════════════════════

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      UserRole.admin => Colors.deepPurple,
      UserRole.cashier => Colors.teal,
      UserRole.barber => Colors.orange,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        role.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Create user dialog
// ═════════════════════════════════════════════════════════════════════════════

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog({required this.admin, required this.repo});

  final AppUser admin;
  final AdminRepository repo;

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  UserRole _role = UserRole.cashier;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.repo.createUser(
        email: _emailCtrl.text,
        password: 'Password123',
        firstName: _firstNameCtrl.text,
        lastName: _lastNameCtrl.text,
        role: _role,
        actingAdmin: widget.admin,
      );
      if (mounted) Navigator.of(context).pop();
    } on AdminException catch (e) {
      setState(() => _error = e.message);
    } on Object {
      setState(() => _error = 'Something went wrong.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create account'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) ...[
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _firstNameCtrl,
                  decoration: const InputDecoration(labelText: 'First name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameCtrl,
                  decoration: const InputDecoration(labelText: 'Last name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 8),
                Text(
                  'Default password: Password123',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(
                      value: UserRole.cashier,
                      child: Text('Cashier'),
                    ),
                    DropdownMenuItem(
                      value: UserRole.barber,
                      child: Text('Barber'),
                    ),
                    DropdownMenuItem(
                      value: UserRole.admin,
                      child: Text('Admin'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _role = v);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Edit user dialog
// ═════════════════════════════════════════════════════════════════════════════

class _EditUserDialog extends StatefulWidget {
  const _EditUserDialog({
    required this.target,
    required this.admin,
    required this.repo,
  });

  final AppUser target;
  final AppUser admin;
  final AdminRepository repo;

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late UserRole _role;
  late bool _isActive;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.target.firstName);
    _lastNameCtrl = TextEditingController(text: widget.target.lastName);
    _role = widget.target.role;
    _isActive = true; // default active; Firestore may have `is_active` field
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.repo.updateUser(
        uid: widget.target.uid,
        firstName: _firstNameCtrl.text,
        lastName: _lastNameCtrl.text,
        role: _role,
        isActive: _isActive,
        actingAdmin: widget.admin,
      );
      if (mounted) Navigator.of(context).pop();
    } on AdminException catch (e) {
      setState(() => _error = e.message);
    } on Object {
      setState(() => _error = 'Something went wrong.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.target.displayName}'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) ...[
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _firstNameCtrl,
                  decoration: const InputDecoration(labelText: 'First name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameCtrl,
                  decoration: const InputDecoration(labelText: 'Last name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(
                      value: UserRole.cashier,
                      child: Text('Cashier'),
                    ),
                    DropdownMenuItem(
                      value: UserRole.barber,
                      child: Text('Barber'),
                    ),
                    DropdownMenuItem(
                      value: UserRole.admin,
                      child: Text('Admin'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _role = v);
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Account active'),
                  subtitle: Text(
                    _isActive ? 'User can log in' : 'User is disabled',
                  ),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
