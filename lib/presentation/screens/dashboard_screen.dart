import 'package:flutter/material.dart';

import 'package:boy_barbershop/data/barbers_repository.dart';
import 'package:boy_barbershop/data/catalog_repository.dart';
import 'package:boy_barbershop/data/expenses_repository.dart';
import 'package:boy_barbershop/data/inventory_repository.dart';
import 'package:boy_barbershop/data/sales_repository.dart';
import 'package:boy_barbershop/data/settings_repository.dart';
import 'package:boy_barbershop/models/barber.dart';
import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/expense.dart';
import 'package:boy_barbershop/models/inventory_item.dart';
import 'package:boy_barbershop/models/payment_method_item.dart';
import 'package:boy_barbershop/models/sale.dart';
import 'package:boy_barbershop/presentation/screens/add_sale_screen.dart';
import 'package:boy_barbershop/presentation/screens/dashboard/dashboard_logic.dart';
import 'package:boy_barbershop/presentation/screens/dashboard/dashboard_models.dart';
import 'package:boy_barbershop/presentation/screens/expenses_screen.dart';
import 'package:boy_barbershop/presentation/screens/inventory_screen.dart';
import 'package:boy_barbershop/presentation/screens/peak_and_daily_target_screen.dart';
import 'package:boy_barbershop/presentation/screens/reports_screen.dart';
import 'package:boy_barbershop/utils/day_range.dart';
import 'package:boy_barbershop/utils/shop_time.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _dailyTargetSalesKey = 'daily_target_sales_amount';

  final _salesRepo = SalesRepository();
  final _expensesRepo = ExpensesRepository();
  final _barbersRepo = BarbersRepository();
  final _inventoryRepo = InventoryRepository();
  final _settingsRepo = SettingsRepository();
  final _catalogRepo = CatalogRepository();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = todayManilaDay();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Dashboard', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Today: $day',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          StreamBuilder<List<Barber>>(
            stream: _barbersRepo.watchAllBarbers(),
            builder: (context, barbersSnap) {
              if (barbersSnap.hasError) {
                return _ErrorCard(title: 'Could not load barbers', error: barbersSnap.error);
              }
              final barbers = barbersSnap.data ?? const <Barber>[];
              final barberById = mapBarbersById(barbers);

              return StreamBuilder<List<Sale>>(
                stream: _salesRepo.watchSalesForDay(day, limit: 200),
                builder: (context, salesSnap) {
                  if (salesSnap.hasError) {
                    return _ErrorCard(title: 'Could not load sales', error: salesSnap.error);
                  }
                  final sales = salesSnap.data ?? const <Sale>[];

                  return StreamBuilder<List<Expense>>(
                    stream: _expensesRepo.watchExpensesForDay(day, limit: 500),
                    builder: (context, expSnap) {
                      if (expSnap.hasError) {
                        return _ErrorCard(title: 'Could not load expenses', error: expSnap.error);
                      }
                      final expenses = expSnap.data ?? const <Expense>[];
                      final expensesTotal = sumExpenses(expenses);

                      final kpis =
                          computeKpis(sales: sales, expensesTotal: expensesTotal, barberById: barberById);
                      final earningsRows = computeEarningsRows(sales: sales, barbers: barbers);

                      return StreamBuilder<List<InventoryItem>>(
                        stream: _inventoryRepo.watchActiveInventoryItems(),
                        builder: (context, invSnap) {
                          if (invSnap.hasError) {
                            return _ErrorCard(
                              title: 'Could not load inventory',
                              error: invSnap.error,
                            );
                          }
                          final lowStock = lowStockItems(invSnap.data ?? const <InventoryItem>[]);

                          return StreamBuilder<double?>(
                            stream: _settingsRepo.watchOptionalDouble(_dailyTargetSalesKey),
                            builder: (context, targetSnap) {
                              final targetSales = targetSnap.data;
                              final alerts = buildAlerts(
                                todayManilaDay: day,
                                dailyTargetSalesAmount: targetSales,
                                todaySalesTotal: kpis.sales,
                                lowStock: lowStock,
                              );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (alerts.isNotEmpty) ...[
                                    _AlertsCard(
                                      alerts: alerts.take(3).toList(growable: false),
                                      onOpenTarget: () => _openPeakAndTarget(context),
                                      onOpenInventory: () => _openInventory(context),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  _TodayCard(
                                    user: widget.user,
                                    day: day,
                                    sales: sales,
                                    kpis: kpis,
                                    dailyTargetSales: targetSales,
                                    onOpenAddSale: () => _openAddSale(context),
                                    onOpenExpenses: () => _openExpenses(context),
                                    onOpenReports: () => _openReports(context),
                                    onOpenPeakAndTarget: () => _openPeakAndTarget(context),
                                  ),
                                  const SizedBox(height: 12),
                                  _TodaySalesCard(
                                    day: day,
                                    sales: sales,
                                    barberById: barberById,
                                    paymentMethods: _catalogRepo.watchActivePaymentMethods(),
                                    onEditSaved: () {},
                                    onDeleteSaved: () {},
                                    salesRepo: _salesRepo,
                                  ),
                                  const SizedBox(height: 12),
                                  _BarberEarningsCard(rows: earningsRows),
                                  const SizedBox(height: 12),
                                  _ThisMonthCard(
                                    anyDayInMonth: day,
                                    salesRepo: _salesRepo,
                                    expensesRepo: _expensesRepo,
                                    barberById: barberById,
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _openAddSale(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddSaleScreen(user: widget.user)));
  }

  void _openExpenses(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExpensesScreen(user: widget.user)));
  }

  void _openReports(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportsScreen(user: widget.user)));
  }

  void _openPeakAndTarget(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => PeakAndDailyTargetScreen(user: widget.user)));
  }

  void _openInventory(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InventoryScreen()));
  }
}

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({
    required this.alerts,
    required this.onOpenTarget,
    required this.onOpenInventory,
  });

  final List<DashboardAlert> alerts;
  final VoidCallback onOpenTarget;
  final VoidCallback onOpenInventory;

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
            Row(
              children: [
                Expanded(child: Text('Alerts', style: theme.textTheme.titleMedium)),
                Icon(Icons.notifications_outlined, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 12),
            for (final a in alerts) ...[
              _AlertRow(
                alert: a,
                onView: switch (a.type) {
                  DashboardAlertType.belowDailyTarget => onOpenTarget,
                  DashboardAlertType.lowInventory => onOpenInventory,
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, required this.onView});
  final DashboardAlert alert;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert.title,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                alert.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.tonal(
          onPressed: onView,
          child: const Text('View'),
        ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.user,
    required this.day,
    required this.sales,
    required this.kpis,
    required this.dailyTargetSales,
    required this.onOpenAddSale,
    required this.onOpenExpenses,
    required this.onOpenReports,
    required this.onOpenPeakAndTarget,
  });

  final AppUser user;
  final String day;
  final List<Sale> sales;
  final DashboardKpis kpis;
  final double? dailyTargetSales;
  final VoidCallback onOpenAddSale;
  final VoidCallback onOpenExpenses;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenPeakAndTarget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastSale = sales.isEmpty ? null : sales.firstWhere((s) => true, orElse: () => sales.first);
    final lastTime = lastSale?.saleDateTime == null
        ? '—'
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(lastSale!.saleDateTime!.toLocal()),
            alwaysUse24HourFormat: false,
          );

    final target = (dailyTargetSales != null && dailyTargetSales! > 0) ? dailyTargetSales : null;
    final progress = (target == null) ? null : (kpis.sales / target).clamp(0.0, 10.0);
    final remaining = (target == null) ? null : (target - kpis.sales).clamp(0.0, 999999999.0);

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
                Expanded(child: Text('Today', style: theme.textTheme.titleMedium)),
                Text(
                  user.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Last sale: $lastTime',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (target != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Daily target: ₱${formatMoney(target)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    'Remaining: ₱${formatMoney(remaining ?? 0)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(value: progress?.clamp(0.0, 1.0)),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _KpiPill(label: 'Customers', value: '${kpis.customers}'),
                _KpiPill(label: 'Sales', value: '₱${formatMoney(kpis.sales)}'),
                _KpiPill(label: 'Share', value: '₱${formatMoney(kpis.barberShare)}'),
                _KpiPill(label: 'Expenses', value: '₱${formatMoney(kpis.expenses)}'),
                _KpiPill(label: 'Net profit', value: '₱${formatMoney(kpis.netProfitEstimate)}'),
              ],
            ),
            const SizedBox(height: 14),
            Text('Quick actions', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onOpenAddSale,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Add sale'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onOpenExpenses,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Expenses'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onOpenReports,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Reports'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onOpenPeakAndTarget,
                  icon: const Icon(Icons.trending_up_rounded),
                  label: const Text('Peak & Target'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiPill extends StatelessWidget {
  const _KpiPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _TodaySalesCard extends StatelessWidget {
  const _TodaySalesCard({
    required this.day,
    required this.sales,
    required this.barberById,
    required this.paymentMethods,
    required this.salesRepo,
    required this.onEditSaved,
    required this.onDeleteSaved,
  });

  final String day;
  final List<Sale> sales;
  final Map<String, Barber> barberById;
  final Stream<List<PaymentMethodItem>> paymentMethods;
  final SalesRepository salesRepo;
  final VoidCallback onEditSaved;
  final VoidCallback onDeleteSaved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limited = sales.take(30).toList(growable: false);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today’s sales', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Latest first. Edit/delete works immediately.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (limited.isEmpty)
              Text(
                'No sales recorded for today.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Column(
                children: [
                  for (final sale in limited) ...[
                    _SaleTile(
                      sale: sale,
                      barberName: barberById[sale.barberId]?.name ?? 'Unknown',
                      barberShare: barberById[sale.barberId]?.percentageShare ?? 0,
                      onEdit: () => _showEdit(context, sale),
                      onDelete: () => _confirmDelete(context, sale),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Sale sale) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete sale?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (!context.mounted || ok != true) return;
    try {
      await salesRepo.deleteSale(sale.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale deleted.')));
      onDeleteSaved();
    } on SaleCreateException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _showEdit(BuildContext context, Sale sale) async {
    final result = await showDialog<_EditSaleResult>(
      context: context,
      builder: (context) => _EditSaleDialog(sale: sale, paymentMethods: paymentMethods),
    );
    if (!context.mounted || result == null) return;
    try {
      await salesRepo.updateSaleFields(
        saleId: sale.id,
        price: result.price,
        paymentMethodName: result.paymentMethodName,
        notes: result.notes,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes saved.')));
      onEditSaved();
    } on SaleCreateException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({
    required this.sale,
    required this.barberName,
    required this.barberShare,
    required this.onEdit,
    required this.onDelete,
  });

  final Sale sale;
  final String barberName;
  final double barberShare;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dt = sale.saleDateTime;
    final time = dt == null
        ? '—'
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(dt.toLocal()),
            alwaysUse24HourFormat: false,
          );
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    barberName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '₱${formatMoney(sale.price)}',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  'Time: $time',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Earnings (${barberShare.toStringAsFixed(0)}%): ₱${formatMoney(sale.price * (barberShare / 100))}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if ((sale.paymentMethod ?? '').trim().isNotEmpty)
                  Text(
                    'Payment: ${sale.paymentMethod}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if ((sale.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                sale.notes!.trim(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
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
                FilledButton.tonalIcon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditSaleResult {
  const _EditSaleResult({
    required this.price,
    required this.paymentMethodName,
    required this.notes,
  });

  final double price;
  final String? paymentMethodName;
  final String? notes;
}

class _EditSaleDialog extends StatefulWidget {
  const _EditSaleDialog({
    required this.sale,
    required this.paymentMethods,
  });

  final Sale sale;
  final Stream<List<PaymentMethodItem>> paymentMethods;

  @override
  State<_EditSaleDialog> createState() => _EditSaleDialogState();
}

class _EditSaleDialogState extends State<_EditSaleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceController;
  late final TextEditingController _notesController;
  String? _paymentMethodName;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: formatMoney(widget.sale.price));
    _notesController = TextEditingController(text: widget.sale.notes ?? '');
    _paymentMethodName = widget.sale.paymentMethod;
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit sale'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                  decoration: const InputDecoration(labelText: 'Price'),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final parsed = _parsePrice(value);
                    if (parsed == null) return 'Enter a valid price.';
                    if (parsed < 0) return 'Price must be 0 or greater.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<PaymentMethodItem>>(
                  stream: widget.paymentMethods,
                  builder: (context, snap) {
                    final items = snap.data ?? const <PaymentMethodItem>[];
                    final selected =
                        items.any((m) => m.name == _paymentMethodName) ? _paymentMethodName : null;
                    return DropdownButtonFormField<String>(
                      key: ValueKey('editPm:$selected:${items.length}'),
                      initialValue: selected,
                      decoration: const InputDecoration(labelText: 'Payment method (optional)'),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('—')),
                        ...items.map(
                          (m) => DropdownMenuItem<String>(value: m.name, child: Text(m.name)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _paymentMethodName = v),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
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
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }

  void _submit() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    final price = _parsePrice(_priceController.text);
    if (price == null) return;
    Navigator.of(context).pop(
      _EditSaleResult(
        price: price,
        paymentMethodName: _paymentMethodName,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      ),
    );
  }
}

double? _parsePrice(String? raw) {
  final cleaned = (raw ?? '').trim().replaceAll(',', '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

class _BarberEarningsCard extends StatelessWidget {
  const _BarberEarningsCard({required this.rows});
  final List<BarberEarningsRow> rows;

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
            Text('Barber earnings (today)', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Text(
                'No active barbers.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Column(
                children: [
                  for (final r in rows) ...[
                    _EarningsRow(row: r),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _EarningsRow extends StatelessWidget {
  const _EarningsRow({required this.row});
  final BarberEarningsRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.barber.name, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Sales: ₱${formatMoney(row.totalSales)} • ${row.servicesCount} services • ${row.barber.percentageShare.toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '₱${formatMoney(row.earnings)}',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ThisMonthCard extends StatelessWidget {
  const _ThisMonthCard({
    required this.anyDayInMonth,
    required this.salesRepo,
    required this.expensesRepo,
    required this.barberById,
  });

  final String anyDayInMonth;
  final SalesRepository salesRepo;
  final ExpensesRepository expensesRepo;
  final Map<String, Barber> barberById;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = manilaMonthRangeFromDay(anyDayInMonth);
    final days = daysBetweenInclusive(range.startDay, range.endDay);

    return FutureBuilder<List<Object>>(
      future: Future.wait([
        salesRepo.fetchSalesForDaysSafe(days),
        expensesRepo.fetchExpensesForDays(days),
      ]),
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorCard(title: 'Could not load month totals', error: snap.error);
        }
        if (!snap.hasData) {
          return Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final sales = snap.data![0] as List<Sale>;
        final expenses = snap.data![1] as List<Expense>;
        final expensesTotal = sumExpenses(expenses);
        final kpis = computeKpis(sales: sales, expensesTotal: expensesTotal, barberById: barberById);

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
                    Expanded(child: Text('This month', style: theme.textTheme.titleMedium)),
                    Text(
                      range.startDay.substring(0, 7),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _KpiPill(label: 'Customers', value: '${kpis.customers}'),
                    _KpiPill(label: 'Sales', value: '₱${formatMoney(kpis.sales)}'),
                    _KpiPill(label: 'Expenses', value: '₱${formatMoney(kpis.expenses)}'),
                    _KpiPill(label: 'Net profit', value: '₱${formatMoney(kpis.netProfitEstimate)}'),
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

