import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/bloc/inventory/inventory_cubit.dart';
import 'package:boy_barbershop/bloc/inventory/inventory_state.dart';
import 'package:boy_barbershop/data/inventory_repository.dart';
import 'package:boy_barbershop/models/inventory_item.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _showCreateDialog(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add item'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Track stock and get low-stock alerts. Items marked inactive won\u2019t be used for service inventory usage.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: 16),
            BlocBuilder<InventoryCubit, InventoryState>(
              builder: (context, state) {
                return switch (state) {
                  InventoryLoading() =>
                    const Center(child: CircularProgressIndicator()),
                  InventoryError(:final message) =>
                    _ErrorCard(title: 'Could not load inventory', error: message),
                  InventoryLoaded(:final items) => items.isEmpty
                      ? _EmptyState(onAdd: () => _showCreateDialog(context))
                      : Column(
                          children: [
                            for (final item in items) ...[
                              _InventoryTile(
                                item: item,
                                onEdit: () => _showEditDialog(context, item),
                                onDeactivate:
                                    item.isActive ? () => _confirmDeactivate(context, item) : null,
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
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final result = await showDialog<_InventoryDialogResult>(
      context: context,
      builder: (ctx) => const _InventoryDialog(title: 'Add item'),
    );
    if (!context.mounted || result == null) return;

    try {
      await context.read<InventoryRepository>().create(
            itemName: result.itemName,
            stockQty: result.stockQty,
            lowStockThreshold: result.lowStockThreshold,
            unit: result.unit,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item added.')),
      );
    } on InventoryWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _showEditDialog(BuildContext context, InventoryItem item) async {
    final result = await showDialog<_InventoryDialogResult>(
      context: context,
      builder: (ctx) => _InventoryDialog(
        title: 'Edit item',
        initialItemName: item.itemName,
        initialStockQty: item.stockQty,
        initialLowStockThreshold: item.lowStockThreshold,
        initialUnit: item.unit,
      ),
    );
    if (!context.mounted || result == null) return;

    try {
      await context.read<InventoryRepository>().update(
            id: item.id,
            itemName: result.itemName,
            stockQty: result.stockQty,
            lowStockThreshold: result.lowStockThreshold,
            unit: result.unit,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved.')),
      );
    } on InventoryWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _confirmDeactivate(
      BuildContext context, InventoryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate item?'),
        content: Text(
          '"${item.itemName}" will be hidden from service inventory usage and ignored by stock checks.',
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
      await context.read<InventoryRepository>().deactivate(item.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item deactivated.')),
      );
    } on InventoryWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}

class _InventoryTile extends StatelessWidget {
  const _InventoryTile({
    required this.item,
    required this.onEdit,
    required this.onDeactivate,
  });

  final InventoryItem item;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = item.isActive
        ? (item.isLowStock ? 'Low' : 'OK')
        : 'Inactive';

    final statusColor = !item.isActive
        ? theme.colorScheme.onSurfaceVariant
        : (item.isLowStock ? theme.colorScheme.error : theme.colorScheme.secondary);

    final cardColor = theme.colorScheme.surfaceContainerHighest;

    final unit = (item.unit == null || item.unit!.trim().isEmpty) ? null : item.unit!.trim();
    final stockLabel = unit == null ? _formatQty(item.stockQty) : '${_formatQty(item.stockQty)} $unit';

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: item.isLowStock
            ? BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.55), width: 1.5)
            : BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.itemName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  statusText,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
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
                  'Stock: $stockLabel',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Low threshold: ${item.lowStockThreshold}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
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
              'No inventory items yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Add items you consume during services (blades, alcohol, gel\u2026).',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: onAdd,
                child: const Text('Add item'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryDialogResult {
  const _InventoryDialogResult({
    required this.itemName,
    required this.stockQty,
    required this.lowStockThreshold,
    required this.unit,
  });

  final String itemName;
  final double stockQty;
  final int lowStockThreshold;
  final String? unit;
}

class _InventoryDialog extends StatefulWidget {
  const _InventoryDialog({
    required this.title,
    this.initialItemName,
    this.initialStockQty,
    this.initialLowStockThreshold,
    this.initialUnit,
  });

  final String title;
  final String? initialItemName;
  final double? initialStockQty;
  final int? initialLowStockThreshold;
  final String? initialUnit;

  @override
  State<_InventoryDialog> createState() => _InventoryDialogState();
}

class _InventoryDialogState extends State<_InventoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _stockController;
  late final TextEditingController _thresholdController;
  late final TextEditingController _unitController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialItemName ?? '');
    _stockController = TextEditingController(
      text: widget.initialStockQty != null ? _formatQty(widget.initialStockQty!) : '0',
    );
    _thresholdController = TextEditingController(
      text: (widget.initialLowStockThreshold ?? 5).toString(),
    );
    _unitController = TextEditingController(text: widget.initialUnit ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    _unitController.dispose();
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
                  decoration: const InputDecoration(labelText: 'Item name'),
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Item name is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stockController,
                  decoration: const InputDecoration(labelText: 'Stock'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final value = _parseQty(v);
                    if (value == null) return 'Enter a valid stock value.';
                    if (value < 0) return 'Stock must be 0 or greater.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _unitController,
                  decoration: const InputDecoration(labelText: 'Unit (optional)'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _thresholdController,
                  decoration: const InputDecoration(labelText: 'Low-stock threshold'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    final value = _parseInt(v);
                    if (value == null) return 'Enter a valid threshold.';
                    if (value < 0) return 'Threshold must be 0 or greater.';
                    return null;
                  },
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

    final stock = _parseQty(_stockController.text);
    final threshold = _parseInt(_thresholdController.text);
    if (stock == null || threshold == null) return;

    Navigator.of(context).pop(
      _InventoryDialogResult(
        itemName: _nameController.text,
        stockQty: stock,
        lowStockThreshold: threshold,
        unit: _unitController.text,
      ),
    );
  }
}

double? _parseQty(String? raw) {
  final cleaned = (raw ?? '').trim().replaceAll(',', '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

int? _parseInt(String? raw) {
  final cleaned = (raw ?? '').trim().replaceAll(',', '');
  if (cleaned.isEmpty) return null;
  return int.tryParse(cleaned);
}

String _formatQty(double value) {
  if (value.isNaN || value.isInfinite) return '0';
  final fixed = value.toStringAsFixed(3);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
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
