import 'package:flutter/material.dart';

import '../models/models.dart';

/// Searchable barangay dropdown. 31 ra ka barangay, pero search mas sayon.
class BarangayPickerField extends StatelessWidget {
  const BarangayPickerField({
    super.key,
    required this.routes,
    required this.value,
    required this.onChanged,
    this.label = 'Barangay / destination',
    this.enabled = true,
  });

  final List<RouteInfo> routes;
  final RouteInfo? value;
  final ValueChanged<RouteInfo?> onChanged;
  final String label;
  final bool enabled;

  Future<void> _open(BuildContext context) async {
    if (!enabled || routes.isEmpty) return;
    final selected = await showDialog<RouteInfo>(
      context: context,
      builder: (context) => _BarangaySearchDialog(routes: routes),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? () => _open(context) : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.place_outlined),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          enabled: enabled,
        ),
        child: Text(
          value?.name ?? 'Select a barangay',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: value == null ? theme.colorScheme.onSurfaceVariant : null,
            fontWeight: value == null ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _BarangaySearchDialog extends StatefulWidget {
  const _BarangaySearchDialog({required this.routes});

  final List<RouteInfo> routes;

  @override
  State<_BarangaySearchDialog> createState() => _BarangaySearchDialogState();
}

class _BarangaySearchDialogState extends State<_BarangaySearchDialog> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final filtered = widget.routes
        .where((route) => route.name.toLowerCase().contains(query))
        .toList();

    return AlertDialog(
      title: const Text('Select barangay'),
      content: SizedBox(
        width: 420,
        height: 440,
        child: Column(
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search barangay...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No barangay found'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final route = filtered[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.place_outlined),
                          title: Text(route.name),
                          onTap: () => Navigator.pop(context, route),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
