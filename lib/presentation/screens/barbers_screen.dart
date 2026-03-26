import 'package:flutter/material.dart';

import 'package:boy_barbershop/data/barbers_repository.dart';
import 'package:boy_barbershop/models/barber.dart';

class BarbersScreen extends StatefulWidget {
  const BarbersScreen({super.key});

  @override
  State<BarbersScreen> createState() => _BarbersScreenState();
}

class _BarbersScreenState extends State<BarbersScreen> {
  final _repo = BarbersRepository();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Barbers',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              FilledButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add barber'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tip: Deactivated barbers won’t appear in Add Sale, but stay on old sales.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<Barber>>(
            stream: _repo.watchAllBarbers(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorCard(
                  title: 'Could not load barbers',
                  error: snapshot.error,
                );
              }
              final barbers = snapshot.data ?? const <Barber>[];
              if (snapshot.connectionState == ConnectionState.waiting &&
                  barbers.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (barbers.isEmpty) {
                return _EmptyState(onAdd: _showCreateDialog);
              }

              return Column(
                children: [
                  for (final b in barbers) ...[
                    _BarberTile(
                      barber: b,
                      onEdit: () => _showEditDialog(b),
                      onDeactivate: b.isActive ? () => _confirmDeactivate(b) : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final result = await showDialog<_BarberDialogResult>(
      context: context,
      builder: (context) => const _BarberDialog(title: 'Add barber'),
    );
    if (!mounted || result == null) return;

    try {
      await _repo.createBarber(
        name: result.name,
        percentageShare: result.percentageShare,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barber added.')),
      );
    } on BarberWriteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _showEditDialog(Barber barber) async {
    final result = await showDialog<_BarberDialogResult>(
      context: context,
      builder: (context) => _BarberDialog(
        title: 'Edit barber',
        initialName: barber.name,
        initialPercentageShare: barber.percentageShare,
      ),
    );
    if (!mounted || result == null) return;

    try {
      await _repo.updateBarber(
        barberId: barber.id,
        name: result.name,
        percentageShare: result.percentageShare,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved.')),
      );
    } on BarberWriteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _confirmDeactivate(Barber barber) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate barber?'),
        content: Text(
          '"${barber.name}" will be hidden from Add Sale, but old sales stay intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;

    try {
      await _repo.deactivateBarber(barber.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barber deactivated.')),
      );
    } on BarberWriteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No barbers yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first barber to start recording sales.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: onAdd,
                child: const Text('Add barber'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarberTile extends StatelessWidget {
  const _BarberTile({
    required this.barber,
    required this.onEdit,
    required this.onDeactivate,
  });

  final Barber barber;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = barber.isActive ? 'Active' : 'Inactive';
    final statusColor = barber.isActive
        ? theme.colorScheme.secondary
        : theme.colorScheme.onSurfaceVariant;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    barber.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  statusText,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Share: ${barber.percentageShare.toStringAsFixed(2)}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                if (onDeactivate != null)
                  FilledButton.tonalIcon(
                    onPressed: onDeactivate,
                    icon: const Icon(Icons.block_rounded),
                    label: const Text('Deactivate'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BarberDialogResult {
  const _BarberDialogResult({
    required this.name,
    required this.percentageShare,
  });

  final String name;
  final double percentageShare;
}

class _BarberDialog extends StatefulWidget {
  const _BarberDialog({
    required this.title,
    this.initialName,
    this.initialPercentageShare,
  });

  final String title;
  final String? initialName;
  final double? initialPercentageShare;

  @override
  State<_BarberDialog> createState() => _BarberDialogState();
}

class _BarberDialogState extends State<_BarberDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _percentageController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _percentageController = TextEditingController(
      text: widget.initialPercentageShare != null
          ? widget.initialPercentageShare!.toStringAsFixed(2)
          : '60.00',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _percentageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _percentageController,
              decoration: const InputDecoration(labelText: 'Percentage share (%)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              validator: (v) {
                final value = _parsePercent(v);
                if (value == null) return 'Enter a valid percentage.';
                if (value < 0 || value > 100) return 'Use 0 to 100.';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final ok = _formKey.currentState?.validate() ?? false;
            if (!ok) return;
            final percent = _parsePercent(_percentageController.text);
            if (percent == null) return;
            Navigator.of(context).pop(
              _BarberDialogResult(
                name: _nameController.text,
                percentageShare: percent,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

double? _parsePercent(String? raw) {
  final cleaned = (raw ?? '').trim().replaceAll(',', '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.title, required this.error});

  final String title;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Error: ${error ?? 'Unknown'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

