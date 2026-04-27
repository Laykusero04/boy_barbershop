import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/bloc/shifts/shifts_cubit.dart';
import 'package:boy_barbershop/bloc/shifts/shifts_state.dart';
import 'package:boy_barbershop/data/admin_repository.dart';
import 'package:boy_barbershop/data/catalog_repository.dart';
import 'package:boy_barbershop/data/disputes_repository.dart';
import 'package:boy_barbershop/data/promos_repository.dart';
import 'package:boy_barbershop/data/sales_repository.dart';
import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/barber.dart';
import 'package:boy_barbershop/models/payment_method_item.dart';
import 'package:boy_barbershop/models/promo.dart';
import 'package:boy_barbershop/models/sale.dart';
import 'package:boy_barbershop/models/sale_create.dart';
import 'package:boy_barbershop/models/service_item.dart';
import 'package:boy_barbershop/models/user_role.dart';

/// Opens the same add-sale form as [AddSaleScreen]’s first tab, in a dialog.
Future<void> showAddSaleDialog(BuildContext context, {required AppUser user}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Add sale'),
        content: SingleChildScrollView(
          child: AddSaleForm(
            user: user,
            onSaved: () => Navigator.of(dialogContext).pop(),
            useFormCard: false,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
}

/// Shared form for creating a sale (full [AddSaleScreen] tab or [showAddSaleDialog]).
class AddSaleForm extends StatefulWidget {
  const AddSaleForm({
    super.key,
    required this.user,
    this.onSaved,
    this.useFormCard = true,
  });

  final AppUser user;
  final VoidCallback? onSaved;

  /// When false (e.g. dialog), fields sit on the dialog surface without an inner [Card].
  final bool useFormCard;

  @override
  State<AddSaleForm> createState() => _AddSaleFormState();
}

class _AddSaleFormState extends State<AddSaleForm> {
  final _formKey = GlobalKey<FormState>();

  late final CatalogRepository _catalogRepo;
  late final SalesRepository _salesRepo;
  late final PromosRepository _promosRepo;
  bool _depsInitialized = false;

  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedBarberId;
  String? _selectedServiceId;
  String? _selectedPaymentMethodName;
  String? _selectedPromoId;
  double? _promoOriginalPrice;
  double? _promoDiscountAmount;
  bool _ownerCoversDiscount = false;

  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsInitialized) {
      _depsInitialized = true;
      _catalogRepo = context.read<CatalogRepository>();
      _salesRepo = context.read<SalesRepository>();
      _promosRepo = context.read<PromosRepository>();
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final price = _parsePrice(_priceController.text);
    if (price == null) return;

    final barberId = _selectedBarberId ?? '';
    final serviceId = _selectedServiceId ?? '';
    final barbers = await _catalogRepo.watchActiveBarbers().first;
    final services = await _catalogRepo.watchActiveServices().first;
    if (!mounted) return;
    final barber = barbers.firstWhere(
      (b) => b.id == barberId,
      orElse: () => Barber(
        id: barberId,
        name: 'Unknown',
        compensationType: BarberCompensationType.percentage,
        percentageShare: 0,
        dailyRate: 0,
        isActive: true,
      ),
    );
    final serviceName = services
        .firstWhere(
          (s) => s.id == serviceId,
          orElse: () => ServiceItem(
            id: serviceId,
            name: 'Unknown',
            defaultPrice: price,
            isActive: true,
          ),
        )
        .name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => _SaleReceiptDialog(
        user: widget.user,
        barber: barber,
        serviceName: serviceName,
        price: price,
        paymentMethodName: _selectedPaymentMethodName,
        notes: _notesController.text,
        ownerCoversDiscount: _ownerCoversDiscount,
        originalPrice: _promoOriginalPrice,
        discountAmount: _promoDiscountAmount,
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final saleId = await _salesRepo.createSale(
        SaleCreate(
          barberId: barberId,
          serviceId: serviceId,
          price: price,
          saleDayManila: _todayManilaDay(),
          paymentMethodName: _selectedPaymentMethodName,
          notes: _notesController.text,
          createdByUid: widget.user.uid,
          promoId: _selectedPromoId,
          originalPrice: _promoOriginalPrice,
          discountAmount: _promoDiscountAmount,
          ownerCoversDiscount: _ownerCoversDiscount,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sale saved (#$saleId).')),
      );

      widget.onSaved?.call();

      if (widget.onSaved == null) {
        setState(() {
          _selectedServiceId = null;
          _selectedPromoId = null;
          _promoOriginalPrice = null;
          _promoDiscountAmount = null;
          _ownerCoversDiscount = false;
          _priceController.clear();
          _notesController.clear();
        });
      }
    } on SaleCreateException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final form = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  _ownerCoversDiscount = false;
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
                      _ownerCoversDiscount = false;
                      if (restore != null) {
                        _priceController.text = _formatMoney(restore);
                      }
                    });
                  },
          ),
          if (_selectedPromoId != null) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Owner covers barber share'),
              subtitle: const Text('Barber gets paid based on original price'),
              value: _ownerCoversDiscount,
              onChanged: (v) => setState(() => _ownerCoversDiscount = v),
            ),
          ],
          const SizedBox(height: 12),
          _PaymentMethodField(
            stream: _catalogRepo.watchActivePaymentMethods(),
            value: _selectedPaymentMethodName,
            onChanged: (value) => setState(() => _selectedPaymentMethodName = value),
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
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.useFormCard)
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: form,
            ),
          )
        else
          form,
        SizedBox(height: widget.useFormCard ? 12 : 8),
        Text(
          'Tip: Services auto-fill the default price. You can still edit it.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class AddSaleScreen extends StatefulWidget {
  const AddSaleScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  late String _salesDay;
  int _salesRows = 20;

  @override
  void initState() {
    super.initState();
    _salesDay = _todayManilaDay();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        AddSaleForm(user: widget.user),
                      ],
                    ),
                    _SalesForDateTab(
                      user: widget.user,
                      initialSaleDay: _salesDay,
                      initialRows: _salesRows,
                      onSaleDayChanged: (v) => setState(() => _salesDay = v),
                      onRowsChanged: (v) => setState(() => _salesRows = v),
                    ),
                    _DailyBreakdownTab(
                      initialSaleDay: _salesDay,
                      onSaleDayChanged: (v) => setState(() => _salesDay = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SalesForDateTab extends StatefulWidget {
  const _SalesForDateTab({
    required this.user,
    required this.initialSaleDay,
    required this.initialRows,
    required this.onSaleDayChanged,
    required this.onRowsChanged,
  });

  final AppUser user;
  final String initialSaleDay;
  final int initialRows;
  final ValueChanged<String> onSaleDayChanged;
  final ValueChanged<int> onRowsChanged;

  @override
  State<_SalesForDateTab> createState() => _SalesForDateTabState();
}

class _SalesForDateTabState extends State<_SalesForDateTab> {
  late final CatalogRepository _catalogRepo;
  late final SalesRepository _salesRepo;
  late final AdminRepository _adminRepo;
  bool _depsInitialized = false;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsInitialized) {
      _depsInitialized = true;
      _catalogRepo = context.read<CatalogRepository>();
      _salesRepo = context.read<SalesRepository>();
      _adminRepo = context.read<AdminRepository>();
    }
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
        StreamBuilder<List<AppUser>>(
          stream: _adminRepo.watchAllUsers(),
          builder: (context, usersSnap) {
            final users = usersSnap.data ?? const <AppUser>[];
            final userById = {for (final u in users) u.uid: u};

            return StreamBuilder<List<Barber>>(
              stream: _catalogRepo.watchActiveBarbers(),
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
              stream: _catalogRepo.watchActiveServices(),
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
                  stream: _salesRepo.watchSalesForDay(
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

                    final isAdmin = widget.user.role == UserRole.admin;
                    return Column(
                      children: [
                        for (final sale in sales) ...[
                          _SaleTile(
                            sale: sale,
                            barberName: barberById[sale.barberId]?.name ?? 'Unknown',
                            barber: barberById[sale.barberId],
                            serviceName:
                                serviceById[sale.serviceId]?.name ?? 'Unknown',
                            isAdmin: isAdmin,
                            cashierName: sale.createdByUid != null
                                ? userById[sale.createdByUid]?.displayName
                                : null,
                            onEdit: isAdmin
                                ? () => _showEditSaleDialog(context, sale)
                                : () => _showRequestEditDialog(context, sale),
                            onDelete: isAdmin
                                ? () => _confirmDelete(context, sale)
                                : () => _showRequestDeleteDialog(context, sale),
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
      await _salesRepo.deleteSale(sale.id);
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

  // ── Cashier: Request Edit ──────────────────────────────────────────
  Future<void> _showRequestEditDialog(BuildContext context, Sale sale) async {
    final paymentMethodsStream = _catalogRepo.watchActivePaymentMethods();
    final result = await showDialog<_EditSaleResult>(
      context: context,
      builder: (context) => _EditSaleDialog(
        sale: sale,
        paymentMethods: paymentMethodsStream,
        submitLabel: 'Request',
      ),
    );
    if (!context.mounted || result == null) return;

    try {
      final changes = <String, dynamic>{
        'price': result.price,
      };
      if (result.paymentMethodName != null) {
        changes['payment_method'] = result.paymentMethodName;
      }
      if (result.notes != null && result.notes!.isNotEmpty) {
        changes['notes'] = result.notes;
      }

      await context.read<DisputesRepository>().requestEdit(
            saleId: sale.id,
            saleDay: sale.saleDay,
            reportedByUid: widget.user.uid,
            reportedByName: widget.user.displayName,
            reason: 'Edit request',
            proposedChanges: changes,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Edit request sent to admin.')),
      );
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send request. Try again.')),
      );
    }
  }

  // ── Cashier: Request Delete ─────────────────────────────────────────
  void _showRequestDeleteDialog(BuildContext context, Sale sale) {
    showDialog(
      context: context,
      builder: (_) => _RequestDeleteDialog(
        sale: sale,
        user: widget.user,
        disputesRepo: context.read<DisputesRepository>(),
      ),
    );
  }

  // ── Admin: Direct Edit ──────────────────────────────────────────────
  Future<void> _showEditSaleDialog(BuildContext context, Sale sale) async {
    final paymentMethodsStream = _catalogRepo.watchActivePaymentMethods();
    final result = await showDialog<_EditSaleResult>(
      context: context,
      builder: (context) => _EditSaleDialog(
        sale: sale,
        paymentMethods: paymentMethodsStream,
      ),
    );
    if (!context.mounted || result == null) return;

    try {
      await _salesRepo.updateSaleFields(
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
    required this.initialSaleDay,
    required this.onSaleDayChanged,
  });

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
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: _DailyBreakdownSheet(
            catalogRepo: context.read<CatalogRepository>(),
            salesRepo: context.read<SalesRepository>(),
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
    required this.saleDay,
  });

  final String saleDay;

  @override
  Widget build(BuildContext context) {
    return _DailyBreakdownContent(
      catalogRepo: context.read<CatalogRepository>(),
      salesRepo: context.read<SalesRepository>(),
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
                                    _barberEarningsSummaryLine(barber),
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
    required this.barber,
    required this.servicesCount,
    required this.salesTotal,
    required this.earnings,
    required this.services,
  });

  final String barberId;
  final String barberName;
  final Barber? barber;
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

    final totalSales = barberSales.fold<double>(0.0, (sum, s) => sum + s.price);
    final servicesCount = barberSales.length;
    final double earnings;
    if (barber != null &&
        barber.compensationType == BarberCompensationType.dailyRate) {
      earnings = barber.dailyRate *
          barberSales
              .map((s) => s.saleDay)
              .where((d) => d.trim().isNotEmpty)
              .toSet()
              .length;
    } else if (barber != null &&
        barber.compensationType == BarberCompensationType.guaranteedBase) {
      final dayTotals = <String, double>{};
      for (final s in barberSales) {
        final day = s.saleDay.trim();
        if (day.isEmpty) continue;
        final base = s.ownerCoversDiscount ? (s.originalPrice ?? s.price) : s.price;
        dayTotals[day] = (dayTotals[day] ?? 0) + base * (barber.percentageShare / 100.0);
      }
      var sum = 0.0;
      for (final commission in dayTotals.values) {
        sum += commission > barber.dailyRate ? commission : barber.dailyRate;
      }
      earnings = sum;
    } else {
      earnings = totalSales * ((barber?.percentageShare ?? 0.0) / 100);
    }

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
        barber: barber,
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

String _barberEarningsSummaryLine(_BreakdownBarber barber) {
  final b = barber.barber;
  if (b != null && b.compensationType == BarberCompensationType.dailyRate) {
    return 'Earnings (daily ₱${_formatMoney(b.dailyRate)}): ₱${_formatMoney(barber.earnings)}';
  }
  if (b != null && b.compensationType == BarberCompensationType.guaranteedBase) {
    return 'Earnings (${b.percentageShare.toStringAsFixed(0)}% min ₱${_formatMoney(b.dailyRate)}/day): ₱${_formatMoney(barber.earnings)}';
  }
  final pct = b?.percentageShare ?? 0.0;
  return 'Earnings (${pct.toStringAsFixed(0)}%): ₱${_formatMoney(barber.earnings)}';
}

String _saleRowEarningsLine({required Sale sale, required Barber? barber}) {
  if (barber != null &&
      barber.compensationType == BarberCompensationType.dailyRate) {
    return 'Daily rate: ₱${_formatMoney(barber.dailyRate)} / day';
  }
  if (barber != null &&
      barber.compensationType == BarberCompensationType.guaranteedBase) {
    final earn = sale.price * (barber.percentageShare / 100);
    return 'Earnings (${barber.percentageShare.toStringAsFixed(0)}%): ₱${_formatMoney(earn)} • min ₱${_formatMoney(barber.dailyRate)}/day';
  }
  final share = barber?.percentageShare ?? 0.0;
  final earn = sale.price * (share / 100);
  return 'Earnings (${share.toStringAsFixed(0)}%): ₱${_formatMoney(earn)}';
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({
    required this.sale,
    required this.barberName,
    required this.barber,
    required this.serviceName,
    required this.isAdmin,
    this.cashierName,
    required this.onEdit,
    required this.onDelete,
  });

  final Sale sale;
  final String barberName;
  final Barber? barber;
  final String serviceName;
  final bool isAdmin;
  final String? cashierName;
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
                  _saleRowEarningsLine(sale: sale, barber: barber),
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
                if (isAdmin && cashierName != null)
                  Text(
                    'Recorded by: $cashierName',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
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
                  label: Text(isAdmin ? 'Edit' : 'Request Edit'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(isAdmin ? 'Delete' : 'Request Delete'),
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
    this.submitLabel = 'Save',
  });

  final Sale sale;
  final Stream<List<PaymentMethodItem>> paymentMethods;
  final String submitLabel;

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
          child: Text(widget.submitLabel),
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

class _RequestDeleteDialog extends StatefulWidget {
  const _RequestDeleteDialog({
    required this.sale,
    required this.user,
    required this.disputesRepo,
  });

  final Sale sale;
  final AppUser user;
  final DisputesRepository disputesRepo;

  @override
  State<_RequestDeleteDialog> createState() => _RequestDeleteDialogState();
}

class _RequestDeleteDialogState extends State<_RequestDeleteDialog> {
  static const _templates = [
    'Duplicate entry',
    'Wrong barber selected',
    'Wrong service selected',
    'Sale was cancelled',
    'Customer did not pay',
    'Test entry',
  ];

  final _detailsCtrl = TextEditingController();
  String? _selectedTemplate;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  String get _finalReason {
    final parts = <String>[];
    if (_selectedTemplate != null) parts.add(_selectedTemplate!);
    final extra = _detailsCtrl.text.trim();
    if (extra.isNotEmpty) parts.add(extra);
    return parts.join(' — ');
  }

  Future<void> _submit() async {
    if (_selectedTemplate == null && _detailsCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Select a reason or add details.');
      return;
    }
    setState(() { _busy = true; _error = null; });

    try {
      await widget.disputesRepo.requestDelete(
        saleId: widget.sale.id,
        saleDay: widget.sale.saleDay,
        reportedByUid: widget.user.uid,
        reportedByName: widget.user.displayName,
        reason: _finalReason,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delete request sent to admin.')),
        );
      }
    } on Object {
      setState(() => _error = 'Could not send request. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Request to delete'),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sale: ₱${_formatMoney(widget.sale.price)} on ${widget.sale.saleDay}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: scheme.error)),
                const SizedBox(height: 8),
              ],
              Text('Why should this be deleted?', style: theme.textTheme.labelLarge),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _templates.map((t) {
                  final selected = _selectedTemplate == t;
                  return ChoiceChip(
                    label: Text(t),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        _selectedTemplate = val ? t : null;
                        _error = null;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _detailsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Additional details (optional)',
                  hintText: 'Add more info if needed...',
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
            ],
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
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Request'),
        ),
      ],
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
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Promo (optional)'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('—'),
                  ),
                  ...items.map(
                    (p) => DropdownMenuItem<String>(
                      value: p.id,
                      child: Text(
                        '${p.name}  •  ${_promoLabel(p)}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
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

class _SaleReceiptDialog extends StatelessWidget {
  const _SaleReceiptDialog({
    required this.user,
    required this.barber,
    required this.serviceName,
    required this.price,
    required this.paymentMethodName,
    required this.notes,
    required this.ownerCoversDiscount,
    required this.originalPrice,
    required this.discountAmount,
  });

  final AppUser user;
  final Barber barber;
  final String serviceName;
  final double price;
  final String? paymentMethodName;
  final String notes;
  final bool ownerCoversDiscount;
  final double? originalPrice;
  final double? discountAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cleanedNotes = notes.trim();
    return AlertDialog(
      title: const Text('Confirm sale'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReceiptRow(label: 'Barber', value: barber.name),
              _ReceiptRow(label: 'Service', value: serviceName),
              _ReceiptRow(
                label: 'Price',
                value: '₱${price.toStringAsFixed(2)}',
              ),
              if (originalPrice != null && discountAmount != null) ...[
                _ReceiptRow(
                  label: 'Original',
                  value: '₱${originalPrice!.toStringAsFixed(2)}',
                ),
                _ReceiptRow(
                  label: 'Discount',
                  value: '−₱${discountAmount!.toStringAsFixed(2)}',
                ),
                _ReceiptRow(
                  label: 'Owner covers',
                  value: ownerCoversDiscount ? 'Yes' : 'No',
                ),
              ],
              _ReceiptRow(
                label: 'Payment',
                value: (paymentMethodName ?? '').trim().isEmpty
                    ? '—'
                    : paymentMethodName!,
              ),
              if (cleanedNotes.isNotEmpty)
                _ReceiptRow(label: 'Notes', value: cleanedNotes),
              const SizedBox(height: 12),
              Divider(color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 8),
              _DutyStatusRow(barber: barber, currentUserUid: user.uid),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Edit'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Confirm & Save'),
        ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DutyStatusRow extends StatelessWidget {
  const _DutyStatusRow({
    required this.barber,
    required this.currentUserUid,
  });

  final Barber barber;
  final String currentUserUid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<ShiftsCubit, ShiftsState>(
      builder: (context, state) {
        final shift = state.openShiftFor(barber.id);
        if (shift != null) {
          final openedAt = shift.openedAt;
          final timeText = openedAt == null
              ? '—'
              : MaterialLocalizations.of(context).formatTimeOfDay(
                  TimeOfDay.fromDateTime(openedAt.toLocal()),
                  alwaysUse24HourFormat: false,
                );
          return Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'On duty since $timeText',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        }
        return Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade700, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Not on duty — open shift now?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: () async {
                final cubit = context.read<ShiftsCubit>();
                final id = await cubit.openShift(
                  barberId: barber.id,
                  openedByUid: currentUserUid,
                );
                if (!context.mounted) return;
                if (id == null) {
                  final msg = cubit.state.errorMessage ??
                      'Could not open shift.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg)),
                  );
                  cubit.clearError();
                }
              },
              child: const Text('Open shift'),
            ),
          ],
        );
      },
    );
  }
}
