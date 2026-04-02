import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/bloc/barbers/barbers_cubit.dart';
import 'package:boy_barbershop/bloc/barbers/barbers_state.dart';
import 'package:boy_barbershop/data/barbers_repository.dart';
import 'package:boy_barbershop/models/barber.dart';

class BarbersScreen extends StatelessWidget {
  const BarbersScreen({super.key});

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
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add barber'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tip: Deactivated barbers won\u2019t appear in Add Sale, but stay on old sales.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          BlocBuilder<BarbersCubit, BarbersState>(
            builder: (context, state) {
              return switch (state) {
                BarbersLoading() =>
                  const Center(child: CircularProgressIndicator()),
                BarbersError(:final message) =>
                  _ErrorCard(title: 'Could not load barbers', error: message),
                BarbersLoaded(:final barbers) => barbers.isEmpty
                    ? _EmptyState(onAdd: () => _showCreateDialog(context))
                    : Column(
                        children: [
                          for (final b in barbers) ...[
                            _BarberTile(
                              barber: b,
                              onEdit: () => _showEditDialog(context, b),
                              onDeactivate:
                                  b.isActive ? () => _confirmDeactivate(context, b) : null,
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

  Future<BarberCompensationType?> _showCompensationTypeDialog(
      BuildContext context) async {
    return showDialog<BarberCompensationType>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add barber'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'How is this barber paid?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(BarberCompensationType.percentage),
              child: const Text('Percentage of sales'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(BarberCompensationType.dailyRate),
              child: const Text('Daily rate'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final compensationType = await _showCompensationTypeDialog(context);
    if (!context.mounted || compensationType == null) return;

    final result = await showDialog<_BarberDialogResult>(
      context: context,
      builder: (ctx) => _BarberDialog(
        title: 'Add barber',
        lockedCompensationType: compensationType,
      ),
    );
    if (!context.mounted || result == null) return;

    try {
      await context.read<BarbersRepository>().createBarber(
            name: result.name,
            compensationType: result.compensationType,
            percentageShare: result.percentageShare,
            dailyRate: result.dailyRate,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barber added.')),
      );
    } on BarberWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _showEditDialog(BuildContext context, Barber barber) async {
    final result = await showDialog<_BarberDialogResult>(
      context: context,
      builder: (ctx) => _BarberDialog(
        title: 'Edit barber',
        initialName: barber.name,
        initialCompensationType: barber.compensationType,
        initialPercentageShare: barber.percentageShare,
        initialDailyRate: barber.dailyRate,
      ),
    );
    if (!context.mounted || result == null) return;

    try {
      await context.read<BarbersRepository>().updateBarber(
            barberId: barber.id,
            name: result.name,
            compensationType: result.compensationType,
            percentageShare: result.percentageShare,
            dailyRate: result.dailyRate,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved.')),
      );
    } on BarberWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _confirmDeactivate(BuildContext context, Barber barber) async {
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
    if (!context.mounted || ok != true) return;

    try {
      await context.read<BarbersRepository>().deactivateBarber(barber.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barber deactivated.')),
      );
    } on BarberWriteException catch (e) {
      if (!context.mounted) return;
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

    final payLine = barber.compensationType == BarberCompensationType.dailyRate
        ? 'Daily rate: \u20B1${barber.dailyRate.toStringAsFixed(2)}'
        : 'Share: ${barber.percentageShare.toStringAsFixed(2)}%';

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
              payLine,
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
    required this.compensationType,
    required this.percentageShare,
    required this.dailyRate,
  });

  final String name;
  final BarberCompensationType compensationType;
  final double percentageShare;
  final double dailyRate;
}

class _BarberDialog extends StatefulWidget {
  const _BarberDialog({
    required this.title,
    this.initialName,
    this.initialCompensationType,
    this.initialPercentageShare,
    this.initialDailyRate,
    this.lockedCompensationType,
  });

  final String title;
  final String? initialName;
  final BarberCompensationType? initialCompensationType;
  final double? initialPercentageShare;
  final double? initialDailyRate;
  final BarberCompensationType? lockedCompensationType;

  @override
  State<_BarberDialog> createState() => _BarberDialogState();
}

class _BarberDialogState extends State<_BarberDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _percentageController;
  late final TextEditingController _dailyRateController;
  late BarberCompensationType _compensationType;

  @override
  void initState() {
    super.initState();
    _compensationType = widget.lockedCompensationType ??
        widget.initialCompensationType ??
        BarberCompensationType.percentage;
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _percentageController = TextEditingController(
      text: widget.initialPercentageShare != null
          ? widget.initialPercentageShare!.toStringAsFixed(2)
          : '60.00',
    );
    _dailyRateController = TextEditingController(
      text: widget.initialDailyRate != null
          ? widget.initialDailyRate!.toStringAsFixed(2)
          : '0.00',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _percentageController.dispose();
    _dailyRateController.dispose();
    super.dispose();
  }

  void _setCompensationType(BarberCompensationType v) {
    setState(() => _compensationType = v);
  }

  @override
  Widget build(BuildContext context) {
    final showTypePicker = widget.lockedCompensationType == null;

    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showTypePicker) ...[
                Text(
                  'Compensation',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SegmentedButton<BarberCompensationType>(
                  segments: const [
                    ButtonSegment(
                      value: BarberCompensationType.percentage,
                      label: Text('Percent'),
                      icon: Icon(Icons.percent_rounded),
                    ),
                    ButtonSegment(
                      value: BarberCompensationType.dailyRate,
                      label: Text('Daily'),
                      icon: Icon(Icons.calendar_today_outlined),
                    ),
                  ],
                  selected: {_compensationType},
                  onSelectionChanged: (s) {
                    if (s.isEmpty) return;
                    _setCompensationType(s.first);
                  },
                ),
                const SizedBox(height: 16),
              ] else ...[
                Text(
                  _compensationType == BarberCompensationType.dailyRate
                      ? 'Daily rate'
                      : 'Percentage of sales',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required.' : null,
              ),
              const SizedBox(height: 12),
              if (_compensationType == BarberCompensationType.percentage)
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
                )
              else
                TextFormField(
                  controller: _dailyRateController,
                  decoration: const InputDecoration(
                    labelText: 'Daily rate (\u20B1)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: false,
                  ),
                  validator: (v) {
                    final value = _parseMoney(v);
                    if (value == null) return 'Enter a valid amount.';
                    if (value < 0) return 'Amount cannot be negative.';
                    return null;
                  },
                ),
            ],
          ),
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
            final type = widget.lockedCompensationType ?? _compensationType;
            double percentageShare = 0;
            double dailyRate = 0;
            if (type == BarberCompensationType.percentage) {
              final percent = _parsePercent(_percentageController.text);
              if (percent == null) return;
              percentageShare = percent;
            } else {
              final dr = _parseMoney(_dailyRateController.text);
              if (dr == null) return;
              dailyRate = dr;
            }
            Navigator.of(context).pop(
              _BarberDialogResult(
                name: _nameController.text,
                compensationType: type,
                percentageShare: percentageShare,
                dailyRate: dailyRate,
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

double? _parseMoney(String? raw) {
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
