import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import '../../widgets/polling.dart';
import 'admin_layout.dart';

class QueueMonitoringScreen extends StatefulWidget {
  const QueueMonitoringScreen({super.key});

  @override
  State<QueueMonitoringScreen> createState() => _QueueMonitoringScreenState();
}

class _QueueMonitoringScreenState extends State<QueueMonitoringScreen>
    with PollingMixin<QueueMonitoringScreen> {
  late final ApiClient _api;
  final _search = TextEditingController();
  List<PublicRouteSummary> _routes = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<AuthState>().api;
    _load(initial: true);
    startPolling();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Future<void> refreshData() => _load();

  Future<void> _load({bool initial = false}) async {
    if (initial && mounted) setState(() => _loading = true);
    try {
      final routes = await _api.adminQueues();
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

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final filtered = _routes
        .where((route) => route.routeName.toLowerCase().contains(query))
        .toList();
    final waitingPassengers = _routes.fold<int>(
      0,
      (sum, route) => sum + route.passengersWaiting,
    );
    final waitingDrivers = _routes.fold<int>(
      0,
      (sum, route) => sum + route.driversInQueue,
    );

    return AdminLayout(
      currentPath: '/admin/queues',
      child: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Queue monitoring',
              subtitle:
                  '$waitingPassengers passengers waiting • '
                  '$waitingDrivers drivers in queue',
              actions: [
                IconButton.filledTonal(
                  tooltip: 'Refresh now',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search barangay...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(message: _error!, onRetry: _load),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const LoadingView()
                  : filtered.isEmpty
                  ? SingleChildScrollView(
                      child: EmptyState(
                        icon: Icons.people_outline,
                        title: 'No barangay found',
                        message: query.isEmpty
                            ? 'No routes available.'
                            : 'Try a different search.',
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final route = filtered[index];
                        return Card(
                          child: ListTile(
                            onTap: () =>
                                context.go('/admin/queues/${route.routeId}'),
                            leading: CircleAvatar(
                              backgroundColor: route.active
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.place_outlined),
                            ),
                            title: Text(
                              route.routeName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    '${route.passengersWaiting} waiting • '
                                    '${route.driversInQueue} drivers',
                                  ),
                                  DemandChip(route.demandLevel),
                                  if (!route.active)
                                    const Text(
                                      'Inactive',
                                      style: TextStyle(
                                        color: Color(0xFFC62828),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right),
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

class QueueDetailScreen extends StatefulWidget {
  const QueueDetailScreen({super.key, required this.routeId});

  final int routeId;

  @override
  State<QueueDetailScreen> createState() => _QueueDetailScreenState();
}

class _QueueDetailScreenState extends State<QueueDetailScreen>
    with PollingMixin<QueueDetailScreen> {
  late final ApiClient _api;
  AdminRouteQueue? _data;
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
      final data = await _api.adminRouteQueue(widget.routeId);
      if (!mounted) return;
      setState(() {
        _data = data;
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

  Future<void> _closeEntry(AdminQueueEntry entry, String action) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _ReasonDialog(action: action),
    );
    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await _api.closeQueueEntry(entry.entry.id, action, reason);
      if (mounted) {
        showSnack(
          context,
          'Entry ${action == 'skip' ? 'skipped' : 'removed'} '
          '(${reason.replaceAll('_', ' ')}).',
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
    final data = _data;
    return AdminLayout(
      currentPath: '/admin/queues',
      child: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: data?.routeName ?? 'Queue detail',
              subtitle: data == null
                  ? 'Loading...'
                  : '${data.passengersWaiting} passengers waiting • '
                        '${data.driversInQueue} drivers in queue',
              actions: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/admin/queues'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('All queues'),
                ),
                IconButton.filledTonal(
                  tooltip: 'Refresh now',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(message: _error!, onRetry: _load),
            ],
            const SizedBox(height: 12),
            if (data != null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DemandChip(data.demandLevel),
                  if (!data.active)
                    const Text(
                      'Route inactive — no new joins',
                      style: TextStyle(
                        color: Color(0xFFC62828),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    'Skip/remove needs a reason code.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading && data == null
                  ? const LoadingView()
                  : data == null
                  ? const SizedBox.shrink()
                  : ListView(
                      children: [
                        _EntryListCard(
                          title: 'Passengers waiting',
                          icon: Icons.people_outline,
                          entries: data.passengers,
                          busy: _busy,
                          onAction: _closeEntry,
                        ),
                        const SizedBox(height: 12),
                        _EntryListCard(
                          title: 'Drivers in queue',
                          icon: Icons.electric_rickshaw,
                          entries: data.drivers,
                          busy: _busy,
                          onAction: _closeEntry,
                          showTricycle: true,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryListCard extends StatelessWidget {
  const _EntryListCard({
    required this.title,
    required this.icon,
    required this.entries,
    required this.busy,
    required this.onAction,
    this.showTricycle = false,
  });

  final String title;
  final IconData icon;
  final List<AdminQueueEntry> entries;
  final bool busy;
  final void Function(AdminQueueEntry entry, String action) onAction;
  final bool showTricycle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              title,
              trailing: Text(
                '${entries.length}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (entries.isEmpty)
              const EmptyState(
                icon: Icons.inbox_outlined,
                title: 'Empty queue',
                message: 'Wala pay tao sa kining linya.',
              )
            else
              for (final item in entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    child: Text('${item.entry.position}'),
                  ),
                  title: Text(
                    item.fullName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '#${item.entry.queueNumber} • ${item.entry.status}'
                    '${showTricycle && item.tricycleNo != null ? ' • ${item.tricycleNo}' : ''}'
                    '\n${item.email}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    enabled: !busy,
                    tooltip: 'Actions',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) => onAction(item, value),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'skip',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.skip_next_outlined),
                          title: Text('Skip'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.person_remove_outlined),
                          title: Text('Remove'),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.action});

  final String action;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _reason;

  static const _options = <String, String>{
    'no_show': 'No show',
    'vehicle_issue': 'Vehicle issue',
    'driver_request': 'Driver request',
    'other': 'Other',
  };

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _reason);
  }

  @override
  Widget build(BuildContext context) {
    final isSkip = widget.action == 'skip';
    return AlertDialog(
      title: Text(isSkip ? 'Skip queue entry' : 'Remove queue entry'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Required ang reason code (spec rule 3).'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(labelText: 'Reason code'),
              items: [
                for (final entry in _options.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
              ],
              onChanged: (value) => setState(() => _reason = value),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Reason is required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: isSkip
              ? null
              : FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
          onPressed: _submit,
          child: Text(isSkip ? 'Skip entry' : 'Remove entry'),
        ),
      ],
    );
  }
}
