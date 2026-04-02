import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/bloc/promos/promos_cubit.dart';
import 'package:boy_barbershop/bloc/promos/promos_state.dart';
import 'package:boy_barbershop/data/promos_repository.dart';
import 'package:boy_barbershop/models/promo.dart';

class PromosScreen extends StatelessWidget {
  const PromosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _showCreateDialog(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add promo'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Only active promos valid today appear in Add Sale.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          BlocBuilder<PromosCubit, PromosState>(
            builder: (context, state) {
              return switch (state) {
                PromosLoading() =>
                  const Center(child: CircularProgressIndicator()),
                PromosError(:final message) =>
                  _ErrorCard(title: 'Could not load promos', error: message),
                PromosLoaded(:final promos) => promos.isEmpty
                    ? _EmptyState(onAdd: () => _showCreateDialog(context))
                    : Column(
                        children: [
                          for (final p in promos) ...[
                            _PromoTile(
                              promo: p,
                              onEdit: () => _showEditDialog(context, p),
                              onDeactivate:
                                  p.isActive ? () => _confirmDeactivate(context, p) : null,
                              onActivate:
                                  !p.isActive ? () => _activate(context, p) : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
              };
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final result = await showDialog<_PromoDialogResult>(
      context: context,
      builder: (ctx) => _PromoDialog(title: 'Add promo'),
    );
    if (!context.mounted || result == null) return;
    try {
      await context.read<PromosRepository>().create(
            name: result.name,
            type: result.type,
            value: result.value,
            validFrom: result.validFrom,
            validTo: result.validTo,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promo added.')),
      );
    } on PromoWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _showEditDialog(BuildContext context, Promo promo) async {
    final result = await showDialog<_PromoDialogResult>(
      context: context,
      builder: (ctx) => _PromoDialog(
        title: 'Edit promo',
        initialName: promo.name,
        initialType: promo.type,
        initialValue: promo.type == PromoType.free ? 0 : promo.value,
        initialValidFrom: promo.validFrom,
        initialValidTo: promo.validTo,
      ),
    );
    if (!context.mounted || result == null) return;
    try {
      await context.read<PromosRepository>().update(
            id: promo.id,
            name: result.name,
            type: result.type,
            value: result.value,
            validFrom: result.validFrom,
            validTo: result.validTo,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved.')),
      );
    } on PromoWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _confirmDeactivate(BuildContext context, Promo promo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate promo?'),
        content: Text('"${promo.name}" will be hidden from Add Sale.'),
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
    if (!context.mounted || ok != true) return;

    try {
      await context.read<PromosRepository>().deactivate(promo.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promo deactivated.')),
      );
    } on PromoWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _activate(BuildContext context, Promo promo) async {
    try {
      await context.read<PromosRepository>().activate(promo.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promo activated.')),
      );
    } on PromoWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}

class _PromoTile extends StatelessWidget {
  const _PromoTile({
    required this.promo,
    required this.onEdit,
    required this.onDeactivate,
    required this.onActivate,
  });

  final Promo promo;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = promo.isActive ? 'Active' : 'Inactive';
    final statusColor = promo.isActive
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
                    promo.name,
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
              '${_typeLabel(promo)} \u2022 ${promo.validFrom} \u2192 ${promo.validTo}',
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
                if (onActivate != null)
                  FilledButton.tonalIcon(
                    onPressed: onActivate,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Activate'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoDialogResult {
  const _PromoDialogResult({
    required this.name,
    required this.type,
    required this.value,
    required this.validFrom,
    required this.validTo,
  });

  final String name;
  final PromoType type;
  final double value;
  final String validFrom;
  final String validTo;
}

class _PromoDialog extends StatefulWidget {
  const _PromoDialog({
    required this.title,
    this.initialName,
    this.initialType,
    this.initialValue,
    this.initialValidFrom,
    this.initialValidTo,
  });

  final String title;
  final String? initialName;
  final PromoType? initialType;
  final double? initialValue;
  final String? initialValidFrom;
  final String? initialValidTo;

  @override
  State<_PromoDialog> createState() => _PromoDialogState();
}

class _PromoDialogState extends State<_PromoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _valueController;
  late final TextEditingController _fromController;
  late final TextEditingController _toController;

  late PromoType _type;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? PromoType.percentOff;
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _valueController = TextEditingController(
      text: (widget.initialValue ?? 0).toString(),
    );
    _fromController = TextEditingController(text: widget.initialValidFrom ?? '');
    _toController = TextEditingController(text: widget.initialValidTo ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showValue = _type != PromoType.free;

    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Promo name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required.' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PromoType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                      value: PromoType.percentOff,
                      child: Text('Percent off'),
                    ),
                    DropdownMenuItem(
                      value: PromoType.amountOff,
                      child: Text('Amount off (\u20B1)'),
                    ),
                    DropdownMenuItem(
                      value: PromoType.free,
                      child: Text('Free'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _type = v);
                  },
                ),
                if (showValue) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _valueController,
                    decoration: InputDecoration(
                      labelText: _type == PromoType.percentOff
                          ? 'Value (0\u2013100)'
                          : 'Value (\u20B1)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (!showValue) return null;
                      final parsed = _parseNum(v);
                      if (parsed == null) return 'Enter a valid value.';
                      if (parsed < 0) return 'Must be 0 or greater.';
                      if (_type == PromoType.percentOff && parsed > 100) {
                        return 'Must be 0 to 100.';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fromController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Valid from',
                    hintText: 'YYYY-MM-DD',
                    suffixIcon: IconButton(
                      tooltip: 'Pick date',
                      onPressed: () => _pickDay(controller: _fromController),
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                  validator: (v) => _isValidDay(v) ? null : 'Use YYYY-MM-DD.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _toController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Valid to',
                    hintText: 'YYYY-MM-DD',
                    suffixIcon: IconButton(
                      tooltip: 'Pick date',
                      onPressed: () => _pickDay(controller: _toController),
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                  validator: (v) => _isValidDay(v) ? null : 'Use YYYY-MM-DD.',
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _submit() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    final from = _fromController.text.trim();
    final to = _toController.text.trim();
    if (from.compareTo(to) > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('"Valid from" must be on/before "Valid to".')),
      );
      return;
    }
    final value =
        _type == PromoType.free ? 0.0 : (_parseNum(_valueController.text) ?? 0.0);
    Navigator.of(context).pop(
      _PromoDialogResult(
        name: _nameController.text,
        type: _type,
        value: value,
        validFrom: from,
        validTo: to,
      ),
    );
  }

  Future<void> _pickDay({required TextEditingController controller}) async {
    final initial = _tryParseDay(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    controller.text = _formatDay(picked);
    _formKey.currentState?.validate();
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
            Text('No promos yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Create a promo like "30% off" or "\u20B150 off".',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(onPressed: onAdd, child: const Text('Add promo')),
            ),
          ],
        ),
      ),
    );
  }
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

String _typeLabel(Promo promo) {
  switch (promo.type) {
    case PromoType.percentOff:
      return '${promo.value.toStringAsFixed(0)}% off';
    case PromoType.amountOff:
      return '\u20B1${promo.value.toStringAsFixed(0)} off';
    case PromoType.free:
      return 'Free';
  }
}

double? _parseNum(String? raw) {
  final cleaned = (raw ?? '').trim().replaceAll(',', '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

bool _isValidDay(String? value) {
  final v = (value ?? '').trim();
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v);
}

DateTime? _tryParseDay(String raw) {
  final v = raw.trim();
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) return null;
  final parts = v.split('-');
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String _formatDay(DateTime date) {
  final yyyy = date.year.toString().padLeft(4, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}
