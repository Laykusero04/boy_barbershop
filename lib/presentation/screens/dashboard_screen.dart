import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
import 'package:boy_barbershop/utils/day_range.dart';
import 'package:boy_barbershop/utils/shop_time.dart';

String _dashboardSaleEarningsLine({required Sale sale, required Barber? barber}) {
  if (barber != null &&
      barber.compensationType == BarberCompensationType.dailyRate) {
    return 'Daily rate: ₱${formatMoney(barber.dailyRate)} / day';
  }
  final share = barber?.percentageShare ?? 0.0;
  final earn = sale.price * (share / 100);
  return 'Earnings (${share.toStringAsFixed(0)}%): ₱${formatMoney(earn)}';
}

String _dashboardEarningsRowSubtitle(BarberEarningsRow row) {
  final b = row.barber;
  final pay = b.compensationType == BarberCompensationType.dailyRate
      ? 'daily ₱${formatMoney(b.dailyRate)}'
      : '${b.percentageShare.toStringAsFixed(0)}%';
  return 'Sales: ₱${formatMoney(row.totalSales)} • ${row.servicesCount} services • $pay';
}

const double _kPagePadding = 24;
const double _kSectionGap = 20;
const double _kInnerGap = 10;
const int _kSalesPreviewCount = 6;

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.day});

  final String day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          formatManilaDayForDisplay(day),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.cells});

  final List<({String label, String value})> cells;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 12.0;
        final w = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cells
              .map(
                (c) => SizedBox(
                  width: w,
                  child: _StatCell(label: c.label, value: c.value),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.user, required this.goToDestination});

  final AppUser user;
  final void Function(String destinationId) goToDestination;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _dailyTargetSalesKey = 'daily_target_sales_amount';

  @override
  Widget build(BuildContext context) {
    final day = todayManilaDay();

    final salesRepo = context.read<SalesRepository>();
    final expensesRepo = context.read<ExpensesRepository>();
    final barbersRepo = context.read<BarbersRepository>();
    final inventoryRepo = context.read<InventoryRepository>();
    final settingsRepo = context.read<SettingsRepository>();
    final catalogRepo = context.read<CatalogRepository>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(_kPagePadding, _kPagePadding, _kPagePadding, 32),
        children: [
          _DashboardHeader(day: day),
          const SizedBox(height: 12),

          StreamBuilder<List<Barber>>(
            stream: barbersRepo.watchAllBarbers(),
            builder: (context, barbersSnap) {
              if (barbersSnap.hasError) {
                return _ErrorCard(title: 'Could not load barbers', error: barbersSnap.error);
              }
              final barbers = barbersSnap.data ?? const <Barber>[];
              final barberById = mapBarbersById(barbers);

              return StreamBuilder<List<Sale>>(
                stream: salesRepo.watchSalesForDay(day, limit: 200),
                builder: (context, salesSnap) {
                  if (salesSnap.hasError) {
                    return _ErrorCard(title: 'Could not load sales', error: salesSnap.error);
                  }
                  final sales = salesSnap.data ?? const <Sale>[];

                  return StreamBuilder<List<Expense>>(
                    stream: expensesRepo.watchExpensesForDay(day, limit: 500),
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
                        stream: inventoryRepo.watchActiveInventoryItems(),
                        builder: (context, invSnap) {
                          if (invSnap.hasError) {
                            return _ErrorCard(
                              title: 'Could not load inventory',
                              error: invSnap.error,
                            );
                          }
                          final lowStock = lowStockItems(invSnap.data ?? const <InventoryItem>[]);

                          return StreamBuilder<double?>(
                            stream: settingsRepo.watchOptionalDouble(_dailyTargetSalesKey),
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
                                      onOpenTarget: () => widget.goToDestination('peak_and_daily_target'),
                                      onOpenInventory: () => widget.goToDestination('inventory'),
                                    ),
                                    const SizedBox(height: _kSectionGap),
                                  ],
                                  _TodayCard(
                                    user: widget.user,
                                    day: day,
                                    sales: sales,
                                    kpis: kpis,
                                    dailyTargetSales: targetSales,
                                    onOpenAddSale: () =>
                                        showAddSaleDialog(context, user: widget.user),
                                  ),
                                  const SizedBox(height: _kSectionGap),
                                  _TodaySalesCard(
                                    sales: sales,
                                    barberById: barberById,
                                    paymentMethods: catalogRepo.watchActivePaymentMethods(),
                                    onEditSaved: () {},
                                    onDeleteSaved: () {},
                                    salesRepo: salesRepo,
                                  ),
                                  const SizedBox(height: _kSectionGap),
                                  _BarberEarningsCard(rows: earningsRows),
                                  const SizedBox(height: _kSectionGap),
                                  _ThisMonthCard(
                                    anyDayInMonth: day,
                                    salesRepo: salesRepo,
                                    expensesRepo: expensesRepo,
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Alerts',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.notifications_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < alerts.length; i++) ...[
              _AlertRow(
                alert: alerts[i],
                onTap: switch (alerts[i].type) {
                  DashboardAlertType.belowDailyTarget => onOpenTarget,
                  DashboardAlertType.lowInventory => onOpenInventory,
                },
              ),
              if (i < alerts.length - 1) const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, required this.onTap});

  final DashboardAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(10);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.65),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
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
  });

  final AppUser user;
  final String day;
  final List<Sale> sales;
  final DashboardKpis kpis;
  final double? dailyTargetSales;
  final VoidCallback onOpenAddSale;

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
            const SizedBox(height: _kInnerGap),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total sales',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${formatMoney(kpis.sales)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last sale $lastTime',
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
                      'Daily target ₱${formatMoney(target)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    'Remaining ₱${formatMoney(remaining ?? 0)}',
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
            _StatGrid(
              cells: [
                (label: 'Customers', value: '${kpis.customers}'),
                (label: 'Barber share', value: '₱${formatMoney(kpis.barberShare)}'),
                (label: 'Expenses', value: '₱${formatMoney(kpis.expenses)}'),
                (label: 'Net profit', value: '₱${formatMoney(kpis.netProfitEstimate)}'),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Quick actions',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: _kInnerGap),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpenAddSale,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Add sale'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodaySalesCard extends StatefulWidget {
  const _TodaySalesCard({
    required this.sales,
    required this.barberById,
    required this.paymentMethods,
    required this.salesRepo,
    required this.onEditSaved,
    required this.onDeleteSaved,
  });

  final List<Sale> sales;
  final Map<String, Barber> barberById;
  final Stream<List<PaymentMethodItem>> paymentMethods;
  final SalesRepository salesRepo;
  final VoidCallback onEditSaved;
  final VoidCallback onDeleteSaved;

  @override
  State<_TodaySalesCard> createState() => _TodaySalesCardState();
}

class _TodaySalesCardState extends State<_TodaySalesCard> {
  bool _showAllSales = false;

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
      await widget.salesRepo.deleteSale(sale.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale deleted.')));
      widget.onDeleteSaved();
    } on SaleCreateException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _showEdit(BuildContext context, Sale sale) async {
    final result = await showDialog<_EditSaleResult>(
      context: context,
      builder: (context) => _EditSaleDialog(sale: sale, paymentMethods: widget.paymentMethods),
    );
    if (!context.mounted || result == null) return;
    try {
      await widget.salesRepo.updateSaleFields(
        saleId: sale.id,
        price: result.price,
        paymentMethodName: result.paymentMethodName,
        notes: result.notes,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes saved.')));
      widget.onEditSaved();
    } on SaleCreateException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allSales = widget.sales.take(30).toList(growable: false);
    final hasMore = allSales.length > _kSalesPreviewCount;
    final visible = _showAllSales || !hasMore
        ? allSales
        : allSales.take(_kSalesPreviewCount).toList(growable: false);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text('Today\u2019s sales', style: theme.textTheme.titleMedium)),
                Tooltip(
                  message: 'Latest first. Changes apply immediately.',
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (allSales.isEmpty)
              Text(
                'No sales recorded for today.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.35)),
                    _SaleRow(
                      sale: visible[i],
                      barberName: widget.barberById[visible[i].barberId]?.name ?? 'Unknown',
                      barber: widget.barberById[visible[i].barberId],
                      onEdit: () => _showEdit(context, visible[i]),
                      onDelete: () => _confirmDelete(context, visible[i]),
                    ),
                  ],
                  if (hasMore) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() => _showAllSales = !_showAllSales),
                        child: Text(_showAllSales ? 'Show fewer' : 'Show all (${allSales.length})'),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({
    required this.sale,
    required this.barberName,
    required this.barber,
    required this.onEdit,
    required this.onDelete,
  });

  final Sale sale;
  final String barberName;
  final Barber? barber;
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
    final pay = (sale.paymentMethod ?? '').trim().isNotEmpty ? ' • ${sale.paymentMethod}' : '';
    final meta = '$time • ${_dashboardSaleEarningsLine(sale: sale, barber: barber)}$pay';
    final notes = (sale.notes ?? '').trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(barberName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${formatMoney(sale.price)}',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_vert_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ],
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
                  _dashboardEarningsRowSubtitle(row),
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('This month', style: theme.textTheme.titleMedium)),
                      Text(
                        formatManilaMonthYearForDisplay(range.startDay),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Loading month totals\u2026',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
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
                      formatManilaMonthYearForDisplay(range.startDay),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total sales',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₱${formatMoney(kpis.sales)}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _StatGrid(
                  cells: [
                    (label: 'Customers', value: '${kpis.customers}'),
                    (label: 'Expenses', value: '₱${formatMoney(kpis.expenses)}'),
                    (label: 'Net profit', value: '₱${formatMoney(kpis.netProfitEstimate)}'),
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
