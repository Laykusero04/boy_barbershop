import 'package:flutter/material.dart';

import 'package:boy_barbershop/data/catalog_repository.dart';
import 'package:boy_barbershop/data/promos_repository.dart';
import 'package:boy_barbershop/data/sales_repository.dart';
import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/barber.dart';
import 'package:boy_barbershop/models/payment_method_item.dart';
import 'package:boy_barbershop/models/promo.dart';
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
  final _salesRepo = SalesRepository();
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

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Add sale', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
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
                          _priceController.text =
                              _formatMoney(service.defaultPrice);
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
      ),
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

