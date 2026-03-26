import 'package:flutter/material.dart';

import 'package:boy_barbershop/data/inventory_repository.dart';
import 'package:boy_barbershop/data/services_repository.dart';
import 'package:boy_barbershop/models/inventory_item.dart';
import 'package:boy_barbershop/models/service_item.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _servicesRepo = ServicesRepository();
  final _inventoryRepo = InventoryRepository();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Services',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              FilledButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add service'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tip: Inactive services won’t appear in Add Sale, but old sales stay intact.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<ServiceItem>>(
            stream: _servicesRepo.watchAllServices(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorCard(
                  title: 'Could not load services',
                  error: snapshot.error,
                );
              }
              final services = snapshot.data ?? const <ServiceItem>[];
              if (snapshot.connectionState == ConnectionState.waiting &&
                  services.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (services.isEmpty) {
                return _EmptyState(onAdd: _showCreateDialog);
              }

              return Column(
                children: [
                  for (final s in services) ...[
                    _ServiceTile(
                      service: s,
                      onEdit: () => _showEditDialog(s),
                      onDeactivate:
                          s.isActive ? () => _confirmDeactivate(s) : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final result = await showDialog<_ServiceDialogResult>(
      context: context,
      builder: (context) => _ServiceDialog(
        title: 'Add service',
        inventoryItemsStream: _inventoryRepo.watchActiveInventoryItems(),
        loadExistingUsage: null,
      ),
    );
    if (!mounted || result == null) return;

    try {
      await _servicesRepo.createService(
        name: result.name,
        defaultPrice: result.defaultPrice,
        inventoryUsage: result.inventoryUsage,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service added.')),
      );
    } on ServiceWriteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _showEditDialog(ServiceItem service) async {
    final result = await showDialog<_ServiceDialogResult>(
      context: context,
      builder: (context) => _ServiceDialog(
        title: 'Edit service',
        initialName: service.name,
        initialDefaultPrice: service.defaultPrice,
        inventoryItemsStream: _inventoryRepo.watchActiveInventoryItems(),
        loadExistingUsage: () => _servicesRepo.fetchInventoryUsage(service.id),
      ),
    );
    if (!mounted || result == null) return;

    try {
      await _servicesRepo.updateService(
        serviceId: service.id,
        name: result.name,
        defaultPrice: result.defaultPrice,
        inventoryUsage: result.inventoryUsage,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved.')),
      );
    } on ServiceWriteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _confirmDeactivate(ServiceItem service) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate service?'),
        content: Text(
          '"${service.name}" will be hidden from Add Sale, but old sales stay intact.',
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
    if (!mounted || ok != true) return;

    try {
      await _servicesRepo.deactivateService(service.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service deactivated.')),
      );
    } on ServiceWriteException catch (e) {
      if (!mounted) return;
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
              'No services yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first service to start recording sales.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: onAdd,
                child: const Text('Add service'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.service,
    required this.onEdit,
    required this.onDeactivate,
  });

  final ServiceItem service;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = service.isActive ? 'Active' : 'Inactive';
    final statusColor = service.isActive
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
                    service.name,
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
              'Default price: ${_formatMoney(service.defaultPrice)}',
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

typedef _LoadUsage = Future<Map<String, double>> Function();

class _ServiceDialogResult {
  const _ServiceDialogResult({
    required this.name,
    required this.defaultPrice,
    required this.inventoryUsage,
  });

  final String name;
  final double defaultPrice;
  final Map<String, double> inventoryUsage;
}

class _ServiceDialog extends StatefulWidget {
  const _ServiceDialog({
    required this.title,
    required this.inventoryItemsStream,
    required this.loadExistingUsage,
    this.initialName,
    this.initialDefaultPrice,
  });

  final String title;
  final Stream<List<InventoryItem>> inventoryItemsStream;
  final _LoadUsage? loadExistingUsage;
  final String? initialName;
  final double? initialDefaultPrice;

  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;

  Map<String, double> _initialUsage = const {};
  bool _loadingUsage = false;
  final Map<String, TextEditingController> _usageControllers = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _priceController = TextEditingController(
      text: (widget.initialDefaultPrice ?? 0).toStringAsFixed(2),
    );
    _loadUsageIfNeeded();
  }

  Future<void> _loadUsageIfNeeded() async {
    final loader = widget.loadExistingUsage;
    if (loader == null) return;
    setState(() => _loadingUsage = true);
    try {
      final usage = await loader();
      if (!mounted) return;
      setState(() => _initialUsage = usage);
    } finally {
      if (mounted) setState(() => _loadingUsage = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    for (final c in _usageControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  decoration: const InputDecoration(labelText: 'Service name'),
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Service name is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Default price'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: false,
                  ),
                  validator: (v) {
                    final value = _parseMoney(v);
                    if (value == null) return 'Enter a valid price.';
                    if (value < 0) return 'Price must be 0 or greater.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                StreamBuilder<List<InventoryItem>>(
                  stream: widget.inventoryItemsStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _ErrorCard(
                        title: 'Could not load inventory items',
                        error: snapshot.error,
                      );
                    }
                    final items = snapshot.data ?? const <InventoryItem>[];
                    if (_loadingUsage) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      );
                    }
                    if (items.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inventory used per service (optional)',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        for (final item in items) ...[
                          _usageField(item),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
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
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _usageField(InventoryItem item) {
    final existing = _initialUsage[item.id] ?? 0;
    final controller = _usageControllers.putIfAbsent(
      item.id,
      () => TextEditingController(text: existing == 0 ? '' : existing.toString()),
    );

    final unitLabel = (item.unit == null || item.unit!.isEmpty) ? '' : ' (${item.unit})';
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: '${item.itemName}$unitLabel',
        hintText: '0',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) {
        final cleaned = (v ?? '').trim();
        if (cleaned.isEmpty) return null;
        final value = double.tryParse(cleaned.replaceAll(',', ''));
        if (value == null) return 'Invalid number.';
        if (value < 0) return 'Must be 0 or greater.';
        return null;
      },
    );
  }

  void _save() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    final price = _parseMoney(_priceController.text);
    if (price == null) return;

    final usage = <String, double>{};
    _usageControllers.forEach((id, c) {
      final raw = c.text.trim();
      if (raw.isEmpty) return;
      final value = double.tryParse(raw.replaceAll(',', ''));
      if (value == null || value <= 0) return;
      usage[id] = value;
    });

    Navigator.of(context).pop(
      _ServiceDialogResult(
        name: _nameController.text,
        defaultPrice: price,
        inventoryUsage: usage,
      ),
    );
  }
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

