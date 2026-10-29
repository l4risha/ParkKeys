import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import '../../widgets/polling.dart';
import 'admin_layout.dart';

class ManageRoutesScreen extends StatefulWidget {
  const ManageRoutesScreen({super.key});

  @override
  State<ManageRoutesScreen> createState() => _ManageRoutesScreenState();
}

class _ManageRoutesScreenState extends State<ManageRoutesScreen>
    with PollingMixin<ManageRoutesScreen> {
  late final ApiClient _api;
  List<RouteInfo> _routes = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<AuthState>().api;
    _load(initial: true);
    startPolling();
  }

  @override
  Future<void> refreshData() => _load();

  Future<void> _load({bool initial = false}) async {
    if (initial && mounted) setState(() => _loading = true);
    try {
      final routes = await _api.adminRoutes();
      if (!mounted) return;
      setState(() {
        _routes = routes;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        await context.read<AuthState>().logout();
        return;
      }
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<String?> _askName({RouteInfo? route}) {
    final controller = TextEditingController(text: route?.name ?? '');
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(route == null ? 'Add barangay route' : 'Rename route'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Barangay name'),
            validator: (value) =>
                (value?.trim().length ?? 0) < 2 ? 'Enter a name' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text(route == null ? 'Add route' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final name = await _askName();
    if (name == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.createRoute(name);
      if (mounted) showSnack(context, 'Route "$name" added.');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(RouteInfo route) async {
    final name = await _askName(route: route);
    if (name == null || name == route.name || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.updateRoute(route.id, name: name);
      if (mounted) showSnack(context, 'Route renamed.');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleActive(RouteInfo route) async {
    if (route.active) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Disable ${route.name}?',
        message:
            'Dili na pwede mo-join og bag-o nga queue sa kining barangay. '
            'Ang existing entries magpabilin.',
        confirmLabel: 'Disable route',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      if (route.active) {
        await _api.disableRoute(route.id);
      } else {
        await _api.updateRoute(route.id, active: true);
      }
      if (mounted) {
        showSnack(
          context,
          route.active ? 'Route disabled.' : 'Route enabled.',
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _routes.where((route) => route.active).length;
    return AdminLayout(
      currentPath: '/admin/routes',
      child: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Manage routes / barangays',
              subtitle: '$activeCount active of ${_routes.length} barangays',
              actions: [
                IconButton.filledTonal(
                  tooltip: 'Refresh now',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _add,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Add route'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(message: _error!, onRetry: _load),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const LoadingView()
                  : _routes.isEmpty
                  ? const SingleChildScrollView(
                      child: EmptyState(
                        icon: Icons.place_outlined,
                        title: 'No routes yet',
                        message: 'Add the barangays served by tricycles.',
                      ),
                    )
                  : ListView.separated(
                      itemCount: _routes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final route = _routes[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: route.active
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.place_outlined,
                                color: route.active
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            title: Text(
                              route.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              route.active ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: route.active
                                    ? const Color(0xFF2E7D32)
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              enabled: !_busy,
                              tooltip: 'Route actions',
                              onSelected: (value) {
                                if (value == 'rename') _rename(route);
                                if (value == 'toggle') _toggleActive(route);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('Rename'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      route.active
                                          ? Icons.block
                                          : Icons.check_circle_outline,
                                    ),
                                    title: Text(
                                      route.active ? 'Disable' : 'Enable',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
