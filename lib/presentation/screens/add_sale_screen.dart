import 'package:flutter/material.dart';

import 'package:boy_barbershop/data/catalog_repository.dart';
import 'package:boy_barbershop/data/cashflow_repository.dart';
import 'package:boy_barbershop/data/promos_repository.dart';
import 'package:boy_barbershop/data/sales_repository.dart';
import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/barber.dart';
import 'package:boy_barbershop/models/payment_method_item.dart';
import 'package:boy_barbershop/models/promo.dart';
import 'package:boy_barbershop/models/sale.dart';
import 'package:boy_barbershop/models/sale_create.dart';
import 'package:boy_barbershop/models/service_item.dart';

class AddSaleScreen extends StatefulWidget {
  const AddSaleScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _catalogRepo = CatalogRepository();
  final _salesRepo = SalesRepository(cashflow: CashflowRepository());
  final _promosRepo = PromosRepository();

  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedBarberId;
  String? _selectedServiceId;
  String? _selectedPaymentMethodName;
  String? _selectedPromoId;
  double? _promoOriginalPrice;
  double? _promoDiscountAmount;

  bool _isSaving = false;

  late String _salesDay;
  int _salesRows = 20;

  @override
  void initState() {
    super.initState();
    _salesDay = _todayManilaDay();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sales', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  TabBar(
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'Add sale'),
                      Tab(text: 'Sales'),
                      Tab(text: 'Daily breakdown'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _buildAddSaleTab(context),
                  _SalesForDateTab(
                    catalogRepo: _catalogRepo,
                    salesRepo: _salesRepo,
                    initialSaleDay: _salesDay,
                    initialRows: _salesRows,
                    onSaleDayChanged: (v) => setState(() => _salesDay = v),
                    onRowsChanged: (v) => setState(() => _salesRows = v),
                  ),
                  _DailyBreakdownTab(
                    catalogRepo: _catalogRepo,
                    salesRepo: _salesRepo,
                    initialSaleDay: _salesDay,
                    onSaleDayChanged: (v) => setState(() => _salesDay = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddSaleTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _BarberField(
                    stream: _catalogRepo.watchActiveBarbers(),
                    value: _selectedBarberId,
                    onChanged: (id) => setState(() => _selectedBarberId = id),
                  ),
                  const SizedBox(height: 12),
                  _ServiceField(
                    stream: _catalogRepo.watchActiveServices(),
                    value: _selectedServiceId,
                    onChanged: (service) {
                      setState(() => _selectedServiceId = service?.id);
                      if (service != null) {
                        _priceController.text = _formatMoney(service.defaultPrice);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: false,
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Price (amount to charge)',
                      hintText: '0.00',
                    ),
                    readOnly: _selectedPromoId != null,
                    validator: (value) {
                      final parsed = _parsePrice(value);
                      if (parsed == null) return 'Enter a valid price.';
                      if (parsed < 0) return 'Price must be 0 or greater.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _PromoField(
                    stream: _promosRepo.watchActiveValidForDay(_todayManilaDay()),
                    value: _selectedPromoId,
                    onChanged: (promo) {
                      if (promo == null) {
                        setState(() {
                          _selectedPromoId = null;
                          _promoOriginalPrice = null;
                          _promoDiscountAmount = null;
                        });
                        return;
                      }

                      final current = _parsePrice(_priceController.text);
                      if (current == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enter a price before applying a promo.'),
                          ),
                        );
                        return;
                      }

                      final result = _applyPromo(
                        original: current,
                        type: promo.type,
                        value: promo.value,
                      );

                      setState(() {
                        _selectedPromoId = promo.id;
                        _promoOriginalPrice = current;
                        _promoDiscountAmount = result.discountAmount;
                        _priceController.text = _formatMoney(result.finalPrice);
                      });
                    },
                    onClear: _selectedPromoId == null
                        ? null
                        : () {
                            final restore = _promoOriginalPrice;
                            setState(() {
                              _selectedPromoId = null;
                              _promoOriginalPrice = null;
                              _promoDiscountAmount = null;
                              if (restore != null) {
                                _priceController.text = _formatMoney(restore);
                              }
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  _PaymentMethodField(
                    stream: _catalogRepo.watchActivePaymentMethods(),
                    value: _selectedPaymentMethodName,
                    onChanged: (value) =>
                        setState(() => _selectedPaymentMethodName = value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                    maxLines: 2,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(_isSaving ? 'Saving...' : 'Save sale'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tip: Services auto-fill the default price. You can still edit it.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final price = _parsePrice(_priceController.text);
    if (price == null) return;

    setState(() => _isSaving = true);
    try {
      final saleId = await _salesRepo.createSale(
        SaleCreate(
          barberId: _selectedBarberId ?? '',
          serviceId: _selectedServiceId ?? '',
          price: price,
          saleDayManila: _todayManilaDay(),
          paymentMethodName: _selectedPaymentMethodName,
          notes: _notesController.text,
          createdByUid: widget.user.uid,
          promoId: _selectedPromoId,
          originalPrice: _promoOriginalPrice,
          discountAmount: _promoDiscountAmount,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sale saved (#$saleId).')),
      );

      setState(() {
        _selectedServiceId = null;
        _selectedPromoId = null;
        _promoOriginalPrice = null;
        _promoDiscountAmount = null;
        _priceController.clear();
        _notesController.clear();
      });
    } on SaleCreateException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _SalesForDateTab extends StatefulWidget {
  const _SalesForDateTab({
    required this.catalogRepo,
    required this.salesRepo,
    required this.initialSaleDay,
    required this.initialRows,
    required this.onSaleDayChanged,
    required this.onRowsChanged,
  });

  final CatalogRepository catalogRepo;
  final SalesRepository salesRepo;
  final String initialSaleDay;
  final int initialRows;
  final ValueChanged<String> onSaleDayChanged;
  final ValueChanged<int> onRowsChanged;

  @override
  State<_SalesForDateTab> createState() => _SalesForDateTabState();
}

class _SalesForDateTabState extends State<_SalesForDateTab> {
  late String _day;
  late int _rows;
  late String _viewDay;
  late int _viewRows;

  @override
  void initState() {
    super.initState();
    _day = widget.initialSaleDay;
    _rows = widget.initialRows;
    _viewDay = _day;
    _viewRows = _rows;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sales for a selected date', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Date',
                        value: _day,
                        onPick: () async {
                          final picked = await _pickDay(context, initial: _day);
                          if (picked == null) return;
                          setState(() => _day = picked);
                          widget.onSaleDayChanged(picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('rows:$_rows'),
                        initialValue: _rows,
                        decoration: const InputDecoration(labelText: 'Rows'),
                        items: const [
                          DropdownMenuItem(value: 20, child: Text('20')),
                          DropdownMenuItem(value: 50, child: Text('50')),
                        ],
                        onChanged: (v) {
                          final next = v ?? 20;
                          setState(() => _rows = next);
                          widget.onRowsChanged(next);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => setState(() {
                      _viewDay = _day;
                      _viewRows = _rows;
                    }),
                    child: const Text('View'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Barber>>(
          stream: widget.catalogRepo.watchActiveBarbers(),
          builder: (context, barbersSnap) {
            if (barbersSnap.hasError) {
              return _ErrorCard(
                title: 'Could not load barbers',
                error: barbersSnap.error,
              );
            }
            final barbers = barbersSnap.data ?? const <Barber>[];
            final barberById = {for (final b in barbers) b.id: b};

            return StreamBuilder<List<ServiceItem>>(
              stream: widget.catalogRepo.watchActiveServices(),
              builder: (context, servicesSnap) {
                if (servicesSnap.hasError) {
                  return _ErrorCard(
                    title: 'Could not load services',
                    error: servicesSnap.error,
                  );
                }
                final services = servicesSnap.data ?? const <ServiceItem>[];
                final serviceById = {for (final s in services) s.id: s};

                return StreamBuilder<List<Sale>>(
                  stream: widget.salesRepo.watchSalesForDay(
                    _viewDay,
                    limit: _viewRows,
                  ),
                  builder: (context, salesSnap) {
                    if (salesSnap.hasError) {
                      return _ErrorCard(
                        title: 'Could not load sales',
                        error: salesSnap.error,
                      );
                    }
                    final sales = salesSnap.data ?? const <Sale>[];
                    if (salesSnap.connectionState == ConnectionState.waiting &&
                        sales.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (sales.isEmpty) {
                      return _EmptyStateCard(
                        title: 'No sales for this day.',
                        subtitle: 'Try another date.',
                      );
                    }

                    return Column(
                      children: [
                        for (final sale in sales) ...[
                          _SaleTile(
                            sale: sale,
                            barberName: barberById[sale.barberId]?.name ?? 'Unknown',
                            barberShare: barberById[sale.barberId]?.percentageShare ??
                                0.0,
                            serviceName:
                                serviceById[sale.serviceId]?.name ?? 'Unknown',
                            onEdit: () => _showEditSaleDialog(context, sale),
                            onDelete: () => _confirmDelete(context, sale),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, Sale sale) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete sale?'),
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

    try {
      await widget.salesRepo.deleteSale(sale.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale deleted.')),
      );
    } on SaleCreateException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _showEditSaleDialog(BuildContext context, Sale sale) async {
    final result = await showDialog<_EditSaleResult>(
      context: context,
      builder: (context) => _EditSaleDialog(
        sale: sale,
        paymentMethods: widget.catalogRepo.watchActivePaymentMethods(),
      ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved.')),
      );
    } on SaleCreateException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}

class _DailyBreakdownTab extends StatefulWidget {
  const _DailyBreakdownTab({
    required this.catalogRepo,
    required this.salesRepo,
    required this.initialSaleDay,
    required this.onSaleDayChanged,
  });

  final CatalogRepository catalogRepo;
  final SalesRepository salesRepo;
  final String initialSaleDay;
  final ValueChanged<String> onSaleDayChanged;

  @override
  State<_DailyBreakdownTab> createState() => _DailyBreakdownTabState();
}

class _DailyBreakdownTabState extends State<_DailyBreakdownTab> {
  late String _day;
  late String _viewDay;

  @override
  void initState() {
    super.initState();
    _day = widget.initialSaleDay;
    _viewDay = _day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily breakdown', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Summarizes sales per barber for the selected date.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _DateField(
                  label: 'Date',
                  value: _day,
                  onPick: () async {
                    final picked = await _pickDay(context, initial: _day);
                    if (picked == null) return;
                    setState(() => _day = picked);
                    widget.onSaleDayChanged(picked);
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => setState(() => _viewDay = _day),
                    child: const Text('View'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () => _openBreakdownSheet(context),
                    child: const Text('Open Daily breakdown'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _BreakdownPreview(
          catalogRepo: widget.catalogRepo,
          salesRepo: widget.salesRepo,
          saleDay: _viewDay,
        ),
      ],
    );
  }

  Future<void> _openBreakdownSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _DailyBreakdownSheet(
            catalogRepo: widget.catalogRepo,
            salesRepo: widget.salesRepo,
            initialSaleDay: _viewDay,
            onSaleDayChanged: (v) {
              setState(() {
                _day = v;
                _viewDay = v;
              });
              widget.onSaleDayChanged(v);
            },
          ),
        ),
      ),
    );
  }
}

class _BreakdownPreview extends StatelessWidget {
  const _BreakdownPreview({
    required this.catalogRepo,
    required this.salesRepo,
    required this.saleDay,
  });

  final CatalogRepository catalogRepo;
  final SalesRepository salesRepo;
  final String saleDay;

  @override
  Widget build(BuildContext context) {
    return _DailyBreakdownContent(
      catalogRepo: catalogRepo,
      salesRepo: salesRepo,
      saleDay: saleDay,
      compact: true,
    );
  }
}

class _DailyBreakdownSheet extends StatefulWidget {
  const _DailyBreakdownSheet({
    required this.catalogRepo,
    required this.salesRepo,
    required this.initialSaleDay,
    required this.onSaleDayChanged,
  });

  final CatalogRepository catalogRepo;
  final SalesRepository salesRepo;
  final String initialSaleDay;
  final ValueChanged<String> onSaleDayChanged;

  @override
  State<_DailyBreakdownSheet> createState() => _DailyBreakdownSheetState();
}

class _DailyBreakdownSheetState extends State<_DailyBreakdownSheet> {
  late String _day;
  late String _viewDay;

  @override
  void initState() {
    super.initState();
    _day = widget.initialSaleDay;
    _viewDay = _day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Daily breakdown',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Date',
                  value: _day,
                  onPick: () async {
                    final picked = await _pickDay(context, initial: _day);
                    if (picked == null) return;
                    setState(() => _day = picked);
                    widget.onSaleDayChanged(picked);
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => setState(() => _viewDay = _day),
                child: const Text('View'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: _DailyBreakdownContent(
                catalogRepo: widget.catalogRepo,
                salesRepo: widget.salesRepo,
                saleDay: _viewDay,
                compact: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyBreakdownContent extends StatelessWidget {
  const _DailyBreakdownContent({
    required this.catalogRepo,
    required this.salesRepo,
    required this.saleDay,
    required this.compact,
  });

  final CatalogRepository catalogRepo;
  final SalesRepository salesRepo;
  final String saleDay;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Barber>>(
      stream: catalogRepo.watchActiveBarbers(),
      builder: (context, barbersSnap) {
        if (barbersSnap.hasError) {
          return _ErrorCard(title: 'Could not load barbers', error: barbersSnap.error);
        }
        final barbers = barbersSnap.data ?? const <Barber>[];
        final barberById = {for (final b in barbers) b.id: b};

        return StreamBuilder<List<ServiceItem>>(
          stream: catalogRepo.watchActiveServices(),
          builder: (context, servicesSnap) {
            if (servicesSnap.hasError) {
              return _ErrorCard(
                title: 'Could not load services',
                error: servicesSnap.error,
              );
            }
            final services = servicesSnap.data ?? const <ServiceItem>[];
            final serviceById = {for (final s in services) s.id: s};

            return StreamBuilder<List<Sale>>(
              stream: salesRepo.watchSalesForDay(saleDay, limit: 500),
              builder: (context, salesSnap) {
                if (salesSnap.hasError) {
                  return _ErrorCard(title: 'Could not load sales', error: salesSnap.error);
                }
                final sales = salesSnap.data ?? const <Sale>[];
                if (salesSnap.connectionState == ConnectionState.waiting &&
                    sales.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (sales.isEmpty) {
                  return _EmptyStateCard(
                    title: 'No sales recorded for this day.',
                    subtitle: 'Try another date.',
                  );
                }

                final breakdown = _computeBreakdown(
                  sales: sales,
                  barberById: barberById,
                  serviceById: serviceById,
                );

                return Column(
                  children: [
                    for (final barber in breakdown) ...[
                      Card(
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
                                      barber.barberName,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ),
                                  Text(
                                    '${barber.servicesCount} services',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  Text(
                                    'Sales: ₱${_formatMoney(barber.salesTotal)}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'Earnings (${barber.percentageShare.toStringAsFixed(0)}%): ₱${_formatMoney(barber.earnings)}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              for (final svc in barber.services) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        svc.serviceName,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                    Text(
                                      '${svc.count} • ₱${_formatMoney(svc.sales)}',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ],
                              if (!compact) const SizedBox(height: 4),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _BreakdownBarber {
  const _BreakdownBarber({
    required this.barberId,
    required this.barberName,
    required this.percentageShare,
    required this.servicesCount,
    required this.salesTotal,
    required this.earnings,
    required this.services,
  });

  final String barberId;
  final String barberName;
  final double percentageShare;
  final int servicesCount;
  final double salesTotal;
  final double earnings;
  final List<_BreakdownService> services;
}

class _BreakdownService {
  const _BreakdownService({
    required this.serviceId,
    required this.serviceName,
    required this.count,
    required this.sales,
  });

  final String serviceId;
  final String serviceName;
  final int count;
  final double sales;
}

List<_BreakdownBarber> _computeBreakdown({
  required List<Sale> sales,
  required Map<String, Barber> barberById,
  required Map<String, ServiceItem> serviceById,
}) {
  final byBarber = <String, List<Sale>>{};
  for (final s in sales) {
    byBarber.putIfAbsent(s.barberId, () => []).add(s);
  }

  final out = <_BreakdownBarber>[];
  byBarber.forEach((barberId, barberSales) {
    final barber = barberById[barberId];
    final barberName = barber?.name ?? 'Unknown';
    final share = barber?.percentageShare ?? 0.0;

    final totalSales = barberSales.fold<double>(0.0, (sum, s) => sum + s.price);
    final servicesCount = barberSales.length;
    final earnings = totalSales * (share / 100);

    final byService = <String, List<Sale>>{};
    for (final s in barberSales) {
      byService.putIfAbsent(s.serviceId, () => []).add(s);
    }

    final services = <_BreakdownService>[];
    byService.forEach((serviceId, svcSales) {
      final serviceName = serviceById[serviceId]?.name ?? 'Unknown';
      final svcTotal = svcSales.fold<double>(0.0, (sum, s) => sum + s.price);
      services.add(
        _BreakdownService(
          serviceId: serviceId,
          serviceName: serviceName,
          count: svcSales.length,
          sales: svcTotal,
        ),
      );
    });
    services.sort((a, b) => b.sales.compareTo(a.sales));

    out.add(
      _BreakdownBarber(
        barberId: barberId,
        barberName: barberName,
        percentageShare: share,
        servicesCount: servicesCount,
        salesTotal: totalSales,
        earnings: earnings,
        services: services,
      ),
    );
  });

  out.sort((a, b) => b.salesTotal.compareTo(a.salesTotal));
  return out;
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({
    required this.sale,
    required this.barberName,
    required this.barberShare,
    required this.serviceName,
    required this.onEdit,
    required this.onDelete,
  });

  final Sale sale;
  final String barberName;
  final double barberShare;
  final String serviceName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dt = sale.saleDateTime;
    final time = dt == null
        ? '—'
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(dt),
            alwaysUse24HourFormat: false,
          );
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
                    '$barberName • $serviceName',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '₱${_formatMoney(sale.price)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
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
                  'Earnings (${barberShare.toStringAsFixed(0)}%): ₱${_formatMoney(sale.price * (barberShare / 100))}',
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
    _priceController = TextEditingController(text: _formatMoney(widget.sale.price));
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
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: false,
                    decimal: true,
                  ),
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
                    final selected = items.any((m) => m.name == _paymentMethodName)
                        ? _paymentMethodName
                        : null;
                    return DropdownButtonFormField<String>(
                      key: ValueKey('editPm:$selected:${items.length}'),
                      initialValue: selected,
                      decoration:
                          const InputDecoration(labelText: 'Payment method (optional)'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('—'),
                        ),
                        ...items.map(
                          (m) => DropdownMenuItem<String>(
                            value: m.name,
                            child: Text(m.name),
                          ),
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
    final price = _parsePrice(_priceController.text);
    if (price == null) return;
    Navigator.of(context).pop(
      _EditSaleResult(
        price: price,
        paymentMethodName: _paymentMethodName,
        notes: _notesController.text,
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

Future<String?> _pickDay(BuildContext context, {required String initial}) async {
  final parsed = _parseYyyyMmDd(initial);
  final now = DateTime.now();
  final initialDate = parsed ?? DateTime(now.year, now.month, now.day);
  final picked = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
  if (picked == null) return null;
  return _yyyyMmDd(picked);
}

DateTime? _parseYyyyMmDd(String raw) {
  final trimmed = raw.trim();
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
  if (m == null) return null;
  final yyyy = int.tryParse(m.group(1)!);
  final mm = int.tryParse(m.group(2)!);
  final dd = int.tryParse(m.group(3)!);
  if (yyyy == null || mm == null || dd == null) return null;
  return DateTime(yyyy, mm, dd);
}

String _yyyyMmDd(DateTime d) {
  final yyyy = d.year.toString().padLeft(4, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

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
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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

class _BarberField extends StatelessWidget {
  const _BarberField({
    required this.stream,
    required this.value,
    required this.onChanged,
  });

  final Stream<List<Barber>> stream;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Barber>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StreamErrorTile(
            title: 'Could not load barbers',
            error: snapshot.error,
          );
        }
        final items = snapshot.data ?? const <Barber>[];
        final selectedId = items.any((b) => b.id == value) ? value : null;
        return DropdownButtonFormField<String>(
          key: ValueKey('barber:$selectedId:${items.length}'),
          initialValue: selectedId,
          decoration: const InputDecoration(labelText: 'Barber'),
          items: items
              .map(
                (b) => DropdownMenuItem<String>(
                  value: b.id,
                  child: Text(b.name),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Select a barber.' : null,
        );
      },
    );
  }
}

class _ServiceField extends StatelessWidget {
  const _ServiceField({
    required this.stream,
    required this.value,
    required this.onChanged,
  });

  final Stream<List<ServiceItem>> stream;
  final String? value;
  final ValueChanged<ServiceItem?> onChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ServiceItem>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StreamErrorTile(
            title: 'Could not load services',
            error: snapshot.error,
          );
        }
        final items = snapshot.data ?? const <ServiceItem>[];
        final selected =
            items.where((s) => s.id == value).cast<ServiceItem?>().firstOrNull;
        return DropdownButtonFormField<String>(
          key: ValueKey('service:${selected?.id}:${items.length}'),
          initialValue: selected?.id,
          decoration: const InputDecoration(labelText: 'Service'),
          items: items
              .map(
                (s) => DropdownMenuItem<String>(
                  value: s.id,
                  child: Text('${s.name}  •  ${_formatMoney(s.defaultPrice)}'),
                ),
              )
              .toList(growable: false),
          onChanged: (id) {
            final service = items.where((s) => s.id == id).firstOrNull;
            onChanged(service);
          },
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Select a service.' : null,
        );
      },
    );
  }
}

class _PaymentMethodField extends StatelessWidget {
  const _PaymentMethodField({
    required this.stream,
    required this.value,
    required this.onChanged,
  });

  final Stream<List<PaymentMethodItem>> stream;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PaymentMethodItem>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StreamErrorTile(
            title: 'Could not load payment methods',
            error: snapshot.error,
          );
        }
        final items = snapshot.data ?? const <PaymentMethodItem>[];

        final defaultName = items.isEmpty ? null : items.first.name;
        final resolved = (value == null || value!.trim().isEmpty) ? defaultName : value;
        final selected = items.any((m) => m.name == resolved) ? resolved : defaultName;

        // Ensure "first active method" is selected by default without user action.
        if (value != selected) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onChanged(selected);
          });
        }

        return DropdownButtonFormField<String>(
          key: ValueKey('pm:$selected:${items.length}'),
          initialValue: selected,
          decoration:
              const InputDecoration(labelText: 'Payment method (optional)'),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('—'),
            ),
            ...items.map(
              (m) => DropdownMenuItem<String>(
                value: m.name,
                child: Text(m.name),
              ),
            ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

class _PromoField extends StatelessWidget {
  const _PromoField({
    required this.stream,
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  final Stream<List<Promo>> stream;
  final String? value;
  final ValueChanged<Promo?> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Promo>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StreamErrorTile(
            title: 'Could not load promos',
            error: snapshot.error,
          );
        }
        final items = snapshot.data ?? const <Promo>[];
        if (items.isEmpty) return const SizedBox.shrink();

        final selected = items.where((p) => p.id == value).firstOrNull;

        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('promo:${selected?.id}:${items.length}'),
                initialValue: selected?.id,
                decoration: const InputDecoration(labelText: 'Promo (optional)'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('—'),
                  ),
                  ...items.map(
                    (p) => DropdownMenuItem<String>(
                      value: p.id,
                      child: Text('${p.name}  •  ${_promoLabel(p)}'),
                    ),
                  ),
                ],
                onChanged: (id) {
                  final promo = items.where((p) => p.id == id).firstOrNull;
                  onChanged(promo);
                },
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Clear promo',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ],
        );
      },
    );
  }
}

double? _parsePrice(String? raw) {
  final cleaned = (raw ?? '').trim().replaceAll(',', '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

String _formatMoney(double value) {
  final fixed = value.toStringAsFixed(2);
  if (fixed.endsWith('.00')) return fixed.substring(0, fixed.length - 3);
  return fixed;
}

String _todayManilaDay() {
  final manilaNow = DateTime.now().toUtc().add(const Duration(hours: 8));
  final yyyy = manilaNow.year.toString().padLeft(4, '0');
  final mm = manilaNow.month.toString().padLeft(2, '0');
  final dd = manilaNow.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String _promoLabel(Promo promo) {
  switch (promo.type) {
    case PromoType.percentOff:
      return '${promo.value.toStringAsFixed(0)}% off';
    case PromoType.amountOff:
      return '₱${promo.value.toStringAsFixed(0)} off';
    case PromoType.free:
      return 'Free';
  }
}

class _PromoApplyResult {
  const _PromoApplyResult({
    required this.finalPrice,
    required this.discountAmount,
  });

  final double finalPrice;
  final double discountAmount;
}

_PromoApplyResult _applyPromo({
  required double original,
  required PromoType type,
  required double value,
}) {
  final safeOriginal = original < 0 ? 0 : original;
  late final double finalPrice;
  switch (type) {
    case PromoType.percentOff:
      finalPrice = safeOriginal * (1 - (value / 100));
      break;
    case PromoType.amountOff:
      finalPrice = safeOriginal - value;
      break;
    case PromoType.free:
      finalPrice = 0.0;
      break;
  }

  final clampedFinal = finalPrice < 0 ? 0.0 : finalPrice;
  final discount =
      (safeOriginal - clampedFinal) < 0 ? 0.0 : (safeOriginal - clampedFinal);
  return _PromoApplyResult(finalPrice: clampedFinal, discountAmount: discount);
}

class _StreamErrorTile extends StatelessWidget {
  const _StreamErrorTile({
    required this.title,
    required this.error,
  });

  final String title;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Error: ${error ?? 'Unknown'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

