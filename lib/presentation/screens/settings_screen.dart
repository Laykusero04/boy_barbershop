import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/data/settings_repository.dart';

const String kHalfDayPercentageKey = 'half_day_percentage';
const double kDefaultHalfDayPercentage = 0.5;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = context.read<SettingsRepository>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Payroll', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<double>(
                stream: repo.watchDouble(
                  kHalfDayPercentageKey,
                  defaultValue: kDefaultHalfDayPercentage,
                ),
                builder: (context, snap) {
                  final value = snap.data ?? kDefaultHalfDayPercentage;
                  return _HalfDayPercentageEditor(
                    initialFraction: value,
                    onSave: (fraction) async {
                      try {
                        await repo.setDouble(kHalfDayPercentageKey, fraction);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Saved.')),
                        );
                      } on SettingsWriteException catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.message)),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HalfDayPercentageEditor extends StatefulWidget {
  const _HalfDayPercentageEditor({
    required this.initialFraction,
    required this.onSave,
  });

  final double initialFraction;
  final Future<void> Function(double fraction) onSave;

  @override
  State<_HalfDayPercentageEditor> createState() =>
      _HalfDayPercentageEditorState();
}

class _HalfDayPercentageEditorState extends State<_HalfDayPercentageEditor> {
  late final TextEditingController _controller;
  bool _saving = false;
  double? _lastSyncedFraction;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _percentText(widget.initialFraction),
    );
    _lastSyncedFraction = widget.initialFraction;
  }

  @override
  void didUpdateWidget(covariant _HalfDayPercentageEditor old) {
    super.didUpdateWidget(old);
    if (_lastSyncedFraction != widget.initialFraction) {
      _lastSyncedFraction = widget.initialFraction;
      _controller.text = _percentText(widget.initialFraction);
    }
  }

  String _percentText(double fraction) {
    final pct = (fraction * 100).clamp(0.0, 100.0);
    final asInt = pct.roundToDouble();
    if ((pct - asInt).abs() < 0.001) {
      return asInt.toStringAsFixed(0);
    }
    return pct.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final raw = _controller.text.trim().replaceAll(',', '');
    final pct = double.tryParse(raw);
    if (pct == null || pct.isNaN || pct.isInfinite || pct < 0 || pct > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a number between 0 and 100.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(pct / 100.0);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Half-day pay (% of daily rate)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'When a shift is closed as Half day, the barber earns this percentage of their daily rate. '
          'Default 50%. Applies to Daily rate and Guaranteed base + commission compensation types.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                decoration: const InputDecoration(
                  labelText: 'Half-day percentage',
                  suffixText: '%',
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _saving ? null : _handleSave,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }
}
