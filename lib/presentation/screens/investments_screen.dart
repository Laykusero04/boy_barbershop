import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/data/cashflow_repository.dart';
import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/cashflow_entry.dart';
import 'package:boy_barbershop/utils/shop_time.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Column(
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(Icons.savings_outlined,
                        color: scheme.onPrimaryContainer, size: 26),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Owner capital',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Record money you add to or take from the shop.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'About owner transactions',
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.help_outline_rounded),
                    onPressed: () => _showInvestmentsHelpDialog(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Tabs ──
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Add Transaction'),
              Tab(text: 'My Investments'),
            ],
          ),

          // ── Tab views ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _AddTransactionTab(user: widget.user),
                const _InvestmentsListTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Add Transaction
// ─────────────────────────────────────────────────────────────────────────────

class _AddTransactionTab extends StatefulWidget {
  const _AddTransactionTab({required this.user});
  final AppUser user;

  @override
  State<_AddTransactionTab> createState() => _AddTransactionTabState();
}

class _AddTransactionTabState extends State<_AddTransactionTab>
    with AutomaticKeepAliveClientMixin {
  late String _day;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _day = todayManilaDay();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cashflow = context.read<CashflowRepository>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Card(
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: scheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add transaction',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Choose deposit (cash in) or withdrawal (cash out).',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                _DateField(
                  label: 'Day to record',
                  value: _day,
                  onPick: () async {
                    final picked =
                        await _pickDay(context, initial: _day);
                    if (picked == null) return;
                    setState(() => _day = picked);
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                    ),
                    onPressed: () =>
                        _openDialog(context, type: _OwnerTxnType.deposit),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Owner deposit'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                    ),
                    onPressed: () =>
                        _openDialog(context, type: _OwnerTxnType.withdrawal),
                    icon: const Icon(Icons.remove_rounded),
                    label: const Text('Owner withdrawal'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ── Day activity ──
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            'Activity for $_day',
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<CashflowEntry>>(
          stream: cashflow.watchEntriesForDay(_day, limit: 500),
          builder: (context, snap) {
            if (snap.hasError) {
              return _ErrorCard(
                  title: 'Could not load entries', error: snap.error);
            }
            final items = (snap.data ?? const <CashflowEntry>[])
                .where((e) => _isOwnerCategory(e.category))
                .toList(growable: false);

            if (snap.connectionState == ConnectionState.waiting &&
                items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (items.isEmpty) {
              return _EmptyStateCard(
                icon: Icons.inbox_outlined,
                title: 'No owner transactions for this day',
                subtitle:
                    'Deposits and withdrawals you add appear here.',
              );
            }

            final deposits = items
                .where((e) => e.type == CashflowType.cashIn)
                .fold<double>(0, (s, e) => s + e.amount);
            final withdrawals = items
                .where((e) => e.type == CashflowType.cashOut)
                .fold<double>(0, (s, e) => s + e.amount);

            return Column(
              children: [
                _TotalsCard(
                    deposits: deposits, withdrawals: withdrawals),
                const SizedBox(height: 12),
                for (final e in items) ...[
                  _OwnerTxnTile(
                      entry: e,
                      onDelete: () => _confirmDelete(context, e)),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _openDialog(BuildContext context,
      {required _OwnerTxnType type}) async {
    final result = await showDialog<_OwnerTxnResult>(
      context: context,
      builder: (context) => _OwnerTxnDialog(day: _day, type: type),
    );
    if (!context.mounted || result == null) return;

    final cashflow = context.read<CashflowRepository>();
    try {
      await cashflow.createEntry(
        occurredAtUtc: result.occurredAtUtc,
        occurredDayManila: result.dayManila,
        type: result.cashflowType,
        category: result.category,
        amount: result.amount,
        paymentMethod: result.paymentMethod,
        referenceSaleId: null,
        referenceExpenseId: null,
        notes: result.notes,
        createdByUid: widget.user.uid,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Owner transaction saved.')),
      );
      setState(() => _day = result.dayManila);
    } on CashflowWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, CashflowEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!context.mounted || ok != true) return;

    final cashflow = context.read<CashflowRepository>();
    try {
      await cashflow.deleteEntry(entry.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction deleted.')),
      );
    } on CashflowWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — My Investments (all owner transactions)
// ─────────────────────────────────────────────────────────────────────────────

class _InvestmentsListTab extends StatelessWidget {
  const _InvestmentsListTab();

  @override
  Widget build(BuildContext context) {
    final cashflow = context.read<CashflowRepository>();

    return StreamBuilder<List<CashflowEntry>>(
      stream: cashflow.watchOwnerEntries(limit: 500),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: _ErrorCard(
                title: 'Could not load investments', error: snap.error),
          );
        }

        final items = snap.data ?? const <CashflowEntry>[];

        if (snap.connectionState == ConnectionState.waiting &&
            items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: _EmptyStateCard(
              icon: Icons.savings_outlined,
              title: 'No investments yet',
              subtitle:
                  'Owner deposits and withdrawals will appear here once you add them.',
            ),
          );
        }

        // Compute totals
        final totalDeposits = items
            .where((e) => e.type == CashflowType.cashIn)
            .fold<double>(0, (s, e) => s + e.amount);
        final totalWithdrawals = items
            .where((e) => e.type == CashflowType.cashOut)
            .fold<double>(0, (s, e) => s + e.amount);

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: items.length + 1, // +1 for totals card
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TotalsCard(
                    deposits: totalDeposits,
                    withdrawals: totalWithdrawals),
              );
            }
            final entry = items[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OwnerTxnTile(
                entry: entry,
                showDate: true,
                onDelete: () =>
                    _confirmDelete(context, entry),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, CashflowEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!context.mounted || ok != true) return;

    final cashflow = context.read<CashflowRepository>();
    try {
      await cashflow.deleteEntry(entry.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction deleted.')),
      );
    } on CashflowWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets & helpers
// ─────────────────────────────────────────────────────────────────────────────

enum _OwnerTxnType { deposit, withdrawal }

class _OwnerTxnResult {
  const _OwnerTxnResult({
    required this.occurredAtUtc,
    required this.dayManila,
    required this.cashflowType,
    required this.category,
    required this.amount,
    required this.paymentMethod,
    required this.notes,
  });

  final DateTime occurredAtUtc;
  final String dayManila;
  final CashflowType cashflowType;
  final String category;
  final double amount;
  final String? paymentMethod;
  final String? notes;
}

class _OwnerTxnDialog extends StatefulWidget {
  const _OwnerTxnDialog({required this.day, required this.type});

  final String day;
  final _OwnerTxnType type;

  @override
  State<_OwnerTxnDialog> createState() => _OwnerTxnDialogState();
}

class _OwnerTxnDialogState extends State<_OwnerTxnDialog> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _day;
  late TimeOfDay _time;
  final _amountController = TextEditingController();
  final _paymentController = TextEditingController(text: 'Cash');
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _day = parseYyyyMmDd(widget.day) ??
        parseYyyyMmDd(todayManilaDay()) ??
        DateTime.now();
    final now = nowManila();
    _time = TimeOfDay(hour: now.hour, minute: now.minute);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _paymentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == _OwnerTxnType.deposit
        ? 'Owner deposit'
        : 'Owner withdrawal';
    return AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DateField(
                  label: 'Date',
                  value: yyyyMmDd(_day),
                  onPick: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _day,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked == null) return;
                    setState(() => _day = DateTime(
                        picked.year, picked.month, picked.day));
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showTimePicker(
                        context: context, initialTime: _time);
                    if (picked == null) return;
                    setState(() => _time = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Time',
                      suffixIcon: Icon(Icons.schedule_outlined),
                    ),
                    child: Text(_time.format(context)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                      signed: false, decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Amount', hintText: '0.00'),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final parsed = _parseMoney(v);
                    if (parsed == null) return 'Enter a valid amount.';
                    if (parsed <= 0) {
                      return 'Amount must be greater than 0.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _paymentController,
                  decoration: const InputDecoration(
                    labelText: 'Payment method (optional)',
                    hintText: 'Cash / GCash / Bank',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (recommended)',
                  ),
                  maxLines: 2,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
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
    final amount = _parseMoney(_amountController.text);
    if (amount == null) return;

    final dtUtc = utcFromManilaParts(
      year: _day.year,
      month: _day.month,
      day: _day.day,
      hour: _time.hour,
      minute: _time.minute,
    );
    final dayManila = yyyyMmDd(_day);

    final cashflowType = widget.type == _OwnerTxnType.deposit
        ? CashflowType.cashIn
        : CashflowType.cashOut;
    final category = widget.type == _OwnerTxnType.deposit
        ? 'Owner deposit'
        : 'Owner withdrawal';

    Navigator.of(context).pop(
      _OwnerTxnResult(
        occurredAtUtc: dtUtc,
        dayManila: dayManila,
        cashflowType: cashflowType,
        category: category,
        amount: amount,
        paymentMethod: _paymentController.text.trim().isEmpty
            ? null
            : _paymentController.text,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text,
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.deposits,
    required this.withdrawals,
  });

  final double deposits;
  final double withdrawals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 18,
          runSpacing: 10,
          children: [
            _pill(
                context, 'Deposits', deposits, theme.colorScheme.secondary),
            _pill(context, 'Withdrawals', withdrawals,
                theme.colorScheme.error),
            _pill(
              context,
              'Net',
              deposits - withdrawals,
              (deposits - withdrawals) < 0
                  ? theme.colorScheme.error
                  : theme.colorScheme.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(
      BuildContext context, String label, double value, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: \u20b1${_formatMoney(value)}',
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _OwnerTxnTile extends StatelessWidget {
  const _OwnerTxnTile({
    required this.entry,
    required this.onDelete,
    this.showDate = false,
  });

  final CashflowEntry entry;
  final VoidCallback onDelete;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIn = entry.type == CashflowType.cashIn;
    final color =
        isIn ? theme.colorScheme.secondary : theme.colorScheme.error;
    final dt = entry.occurredAt;
    final time = dt == null
        ? '\u2014'
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(dt.toLocal()),
            alwaysUse24HourFormat: false,
          );

    return Card(
      elevation: 0,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(
                    isIn
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.category,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${isIn ? '+' : '-'}\u20b1${_formatMoney(entry.amount)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (showDate)
                  Text(
                    entry.occurredDay,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                Text(
                  'Time: $time',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if ((entry.paymentMethod ?? '').trim().isNotEmpty)
                  Text(
                    'Method: ${entry.paymentMethod}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if ((entry.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.notes!.trim(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final String value; // YYYY-MM-DD
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(value),
      ),
    );
  }
}

Future<String?> _pickDay(BuildContext context,
    {required String initial}) async {
  final parsed = parseYyyyMmDd(initial);
  final now = DateTime.now();
  final initialDate = parsed ?? DateTime(now.year, now.month, now.day);
  final picked = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
  if (picked == null) return null;
  return yyyyMmDd(picked);
}

bool _isOwnerCategory(String category) {
  final c = category.trim().toLowerCase();
  return c == 'owner deposit' || c == 'owner withdrawal';
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData? icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 44, color: scheme.outline),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
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
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

void _showInvestmentsHelpDialog(BuildContext context) {
  final theme = Theme.of(context);
  final muted = theme.colorScheme.onSurfaceVariant;
  final bodyStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.45);

  showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('About owner transactions'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Use this screen when you move money between yourself and the shop\u2019s cash drawer.',
                style: bodyStyle,
              ),
              const SizedBox(height: 16),
              Text('Owner deposit',
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                'You put cash (or equivalent) into the business. It is saved as a cash-in line on Cash flow for the date you pick.',
                style: bodyStyle?.copyWith(color: muted),
              ),
              const SizedBox(height: 14),
              Text('Owner withdrawal',
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                'You take cash out of the business. It is saved as a cash-out line on Cash flow.',
                style: bodyStyle?.copyWith(color: muted),
              ),
              const SizedBox(height: 14),
              Text('Why Cash flow?',
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                'Cash flow is the drawer ledger for each day. Owner lines stay there so you can reconcile expected cash with what you actually counted.',
                style: bodyStyle?.copyWith(color: muted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      );
    },
  );
}

double? _parseMoney(String? raw) {
  final cleaned = (raw ?? '').trim().replaceAll(',', '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

String _formatMoney(double value) {
  final fixed = value.toStringAsFixed(2);
  if (fixed.endsWith('.00')) return fixed.substring(0, fixed.length - 3);
  return fixed;
}
