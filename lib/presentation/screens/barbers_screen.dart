import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/bloc/barbers/barbers_cubit.dart';
import 'package:boy_barbershop/bloc/barbers/barbers_state.dart';
import 'package:boy_barbershop/bloc/shifts/shifts_cubit.dart';
import 'package:boy_barbershop/bloc/shifts/shifts_state.dart';
import 'package:boy_barbershop/data/barbers_repository.dart';
import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/barber.dart';
import 'package:boy_barbershop/models/barber_shift.dart';
import 'package:boy_barbershop/presentation/widgets/close_shift_dialog.dart';

class BarbersScreen extends StatelessWidget {
  const BarbersScreen({super.key, required this.user});

  final AppUser user;

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
                              onRemove:
                                  !b.isActive ? () => _confirmRemove(context, b) : null,
                              onOpenShift: b.isActive
                                  ? () => _markOnDuty(context, b)
                                  : null,
                              onCloseShift: b.isActive
                                  ? (shift) => _endDuty(context, b, shift)
                                  : null,
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
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(BarberCompensationType.guaranteedBase),
              child: const Text('Guaranteed base + commission'),
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

  Future<void> _markOnDuty(BuildContext context, Barber barber) async {
    final cubit = context.read<ShiftsCubit>();
    final id = await cubit.openShift(
      barberId: barber.id,
      openedByUid: user.uid,
    );
    if (!context.mounted) return;
    if (id == null) {
      final msg = cubit.state.errorMessage ?? 'Could not mark on duty.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      cubit.clearError();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${barber.name} is now on duty.')),
    );
  }

  Future<void> _endDuty(
    BuildContext context,
    Barber barber,
    BarberShift shift,
  ) async {
    final result = await showDialog<EndDutyResult>(
      context: context,
      builder: (ctx) => EndDutyDialog(barberName: barber.name),
    );
    if (!context.mounted || result == null) return;
    final cubit = context.read<ShiftsCubit>();
    switch (result) {
      case EndDutyClose(:final classification):
        final ok = await cubit.closeShift(
          shiftId: shift.id,
          classification: classification,
          closedByUid: user.uid,
        );
        if (!context.mounted) return;
        if (!ok) {
          final msg = cubit.state.errorMessage ?? 'Could not end duty.';
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
          cubit.clearError();
          return;
        }
        final label =
            classification == DayClassification.full ? 'Full day' : 'Half day';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${barber.name} off duty — $label.')),
        );
      case EndDutyDiscard():
        final ok = await cubit.cancelShift(shift.id);
        if (!context.mounted) return;
        if (!ok) {
          final msg = cubit.state.errorMessage ?? 'Could not discard duty.';
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
          cubit.clearError();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${barber.name}’s duty discarded — no salary charged.'),
          ),
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

  static const _removalReasons = [
    'Resigned / left voluntarily',
    'End of contract',
    'Poor performance',
    'Attendance issues / no-show',
    'Policy violation',
    'Business downsizing',
    'Relocated / moved away',
    'Other',
  ];

  Future<void> _confirmRemove(BuildContext context, Barber barber) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        String? selected;
        final otherController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setState) {
            final isOther = selected == 'Other';
            return AlertDialog(
              title: const Text('Remove barber'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Why are you removing "${barber.name}"?',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    RadioGroup<String>(
                      groupValue: selected ?? '',
                      onChanged: (v) => setState(() => selected = v),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final r in _removalReasons)
                            RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(r),
                              value: r,
                            ),
                        ],
                      ),
                    ),
                    if (isOther) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: otherController,
                        decoration: const InputDecoration(
                          labelText: 'Specify reason',
                        ),
                        maxLines: 2,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'This barber will be permanently removed from the list. Old sales will keep their records.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
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
                  onPressed: selected == null
                      ? null
                      : () {
                          final value = isOther
                              ? otherController.text.trim().isEmpty
                                  ? 'Other'
                                  : otherController.text.trim()
                              : selected!;
                          Navigator.of(context).pop(value);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        );
      },
    );
    if (!context.mounted || reason == null) return;

    try {
      await context.read<BarbersRepository>().removeBarber(
            barberId: barber.id,
            reason: reason,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barber removed.')),
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
    required this.onRemove,
    required this.onOpenShift,
    required this.onCloseShift,
  });

  final Barber barber;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;
  final VoidCallback? onRemove;
  final VoidCallback? onOpenShift;
  final void Function(BarberShift shift)? onCloseShift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = barber.isActive ? 'Active' : 'Inactive';
    final statusColor = barber.isActive
        ? theme.colorScheme.secondary
        : theme.colorScheme.onSurfaceVariant;

    final payLine = switch (barber.compensationType) {
      BarberCompensationType.dailyRate =>
        'Daily rate: \u20B1${barber.dailyRate.toStringAsFixed(2)}',
      BarberCompensationType.guaranteedBase =>
        'Guaranteed \u20B1${barber.dailyRate.toStringAsFixed(2)}/day + ${barber.percentageShare.toStringAsFixed(0)}%',
      BarberCompensationType.percentage =>
        'Share: ${barber.percentageShare.toStringAsFixed(2)}%',
    };

    return BlocBuilder<ShiftsCubit, ShiftsState>(
      buildWhen: (a, b) =>
          a.openShiftByBarberId[barber.id] !=
          b.openShiftByBarberId[barber.id],
      builder: (context, shiftsState) {
        final openShift = shiftsState.openShiftFor(barber.id);
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
                if (barber.isActive) ...[
                  const SizedBox(height: 8),
                  _DutyChip(shift: openShift),
                ],
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
                    if (barber.isActive &&
                        openShift == null &&
                        onOpenShift != null)
                      FilledButton.icon(
                        onPressed: onOpenShift,
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('On duty'),
                      ),
                    if (barber.isActive &&
                        openShift != null &&
                        onCloseShift != null)
                      FilledButton.icon(
                        onPressed: () => onCloseShift!(openShift),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Off duty'),
                      ),
                    if (onDeactivate != null)
                      FilledButton.tonalIcon(
                        onPressed: onDeactivate,
                        icon: const Icon(Icons.block_rounded),
                        label: const Text('Deactivate'),
                      ),
                    if (onRemove != null)
                      FilledButton.tonalIcon(
                        onPressed: onRemove,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: theme.colorScheme.error,
                        ),
                        label: Text(
                          'Remove',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DutyChip extends StatelessWidget {
  const _DutyChip({required this.shift});

  final BarberShift? shift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (shift == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle_outlined,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            'Off duty',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
    final openedAt = shift!.openedAt;
    final timeText = openedAt == null
        ? '—'
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(openedAt.toLocal()),
            alwaysUse24HourFormat: false,
          );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.circle, size: 12, color: Colors.green),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'On duty • opened $timeText',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.green.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
                    ButtonSegment(
                      value: BarberCompensationType.guaranteedBase,
                      label: Text('Guaranteed'),
                      icon: Icon(Icons.shield_outlined),
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
                  switch (_compensationType) {
                    BarberCompensationType.dailyRate => 'Daily rate',
                    BarberCompensationType.guaranteedBase => 'Guaranteed base + commission',
                    BarberCompensationType.percentage => 'Percentage of sales',
                  },
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
              if (_compensationType == BarberCompensationType.percentage ||
                  _compensationType == BarberCompensationType.guaranteedBase)
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
              if (_compensationType == BarberCompensationType.guaranteedBase)
                const SizedBox(height: 12),
              if (_compensationType == BarberCompensationType.dailyRate ||
                  _compensationType == BarberCompensationType.guaranteedBase)
                TextFormField(
                  controller: _dailyRateController,
                  decoration: InputDecoration(
                    labelText: _compensationType == BarberCompensationType.guaranteedBase
                        ? 'Guaranteed daily minimum (\u20B1)'
                        : 'Daily rate (\u20B1)',
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
              if (_compensationType == BarberCompensationType.guaranteedBase) ...[
                const SizedBox(height: 8),
                Text(
                  'Barber earns the commission OR the guaranteed daily minimum — whichever is higher.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
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
            } else if (type == BarberCompensationType.dailyRate) {
              final dr = _parseMoney(_dailyRateController.text);
              if (dr == null) return;
              dailyRate = dr;
            } else {
              // guaranteedBase: needs both
              final percent = _parsePercent(_percentageController.text);
              final dr = _parseMoney(_dailyRateController.text);
              if (percent == null || dr == null) return;
              percentageShare = percent;
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
