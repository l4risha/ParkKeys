import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../widgets/barangay_picker.dart';
import '../widgets/common.dart';
import '../widgets/polling.dart';

class PassengerDashboard extends StatefulWidget {
  const PassengerDashboard({super.key});

  @override
  State<PassengerDashboard> createState() => _PassengerDashboardState();
}

class _PassengerDashboardState extends State<PassengerDashboard>
    with PollingMixin<PassengerDashboard> {
  late final ApiClient _api;
  List<RouteInfo> _routes = const [];
  RouteInfo? _selected;
  QueueEntry? _entry;
  PublicRouteStatus? _routeStatus;
  bool _loading = true;
  bool _joining = false;
  bool _cancelling = false;
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
      final routes = await _api.routes();
      final entry = await _api.passengerQueue();
      PublicRouteStatus? status;
      if (entry != null) {
        status = await _api.publicRouteStatus(entry.routeId);
      } else if (_selected != null) {
        status = await _api.publicRouteStatus(_selected!.id);
      }
      if (!mounted) return;
      setState(() {
        _routes = routes;
        _entry = entry;
        _routeStatus = status;
        _loading = false;
        _error = null;
        if (entry != null) {
          _selected = routeById(entry.routeId, routes, entry.routeName);
        } else if (_selected != null &&
            !routes.any((route) => route.id == _selected!.id)) {
          _selected = null;
        }
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

  RouteInfo routeById(int id, List<RouteInfo> routes, String fallbackName) {
    for (final route in routes) {
      if (route.id == id) return route;
    }
    return RouteInfo(id: id, name: fallbackName, active: true);
  }

  Future<void> _join() async {
    final selected = _selected;
    if (selected == null) {
      showSnack(context, 'Select a barangay first.', error: true);
      return;
    }
    setState(() => _joining = true);
    try {
      final entry = await _api.joinPassengerQueue(selected.id);
      if (!mounted) return;
      setState(() => _entry = entry);
      showSnack(
        context,
        'Joined ${entry.routeName}. Your queue number is ${entry.queueNumber}.',
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancel queue?',
      message: 'Mawala ka sa linya. Pwede ka na pud mo-join balik.',
      confirmLabel: 'Cancel queue',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await _api.cancelPassengerQueue();
      if (!mounted) return;
      setState(() => _entry = null);
      showSnack(context, 'Queue entry cancelled.');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  void _viewTicket() {
    final entry = _entry;
    if (entry == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ticket #${entry.queueNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoRow(label: 'Barangay', value: entry.routeName),
            InfoRow(label: 'Status', value: entry.status),
            InfoRow(label: 'Position', value: '#${entry.position}'),
            InfoRow(
              label: 'Passengers ahead',
              value: '${entry.peopleAhead}',
            ),
            InfoRow(label: 'Joined', value: formatDateTime(entry.joinedAt)),
            const SizedBox(height: 8),
            const Text(
              'Mag-update kini every 3 seconds samtang bukas ang page.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final firstName = (auth.user?.fullName ?? 'Passenger').split(' ').first;

    return AppShell(
      title: 'ParkKeys',
      subtitle: 'Passenger',
      actions: [
        IconButton(
          tooltip: 'Refresh now',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ResponsiveBody(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Hello, $firstName',
                subtitle: _entry == null
                    ? 'Asa ka gusto moadto?'
                    : 'Naa kay aktibo nga queue entry.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorBanner(message: _error!, onRetry: _load),
              ],
              const SizedBox(height: 16),
              if (_loading)
                const LoadingView()
              else if (_entry != null)
                _EntrySection(
                  entry: _entry!,
                  status: _routeStatus,
                  cancelling: _cancelling,
                  onView: _viewTicket,
                  onCancel: _cancel,
                )
              else
                _JoinSection(
                  routes: _routes,
                  selected: _selected,
                  status: _routeStatus,
                  joining: _joining,
                  onSelect: (route) {
                    setState(() => _selected = route);
                    _load();
                  },
                  onJoin: _join,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinSection extends StatelessWidget {
  const _JoinSection({
    required this.routes,
    required this.selected,
    required this.status,
    required this.joining,
    required this.onSelect,
    required this.onJoin,
  });

  final List<RouteInfo> routes;
  final RouteInfo? selected;
  final PublicRouteStatus? status;
  final bool joining;
  final ValueChanged<RouteInfo?> onSelect;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.search, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Where do you want to go?',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Pilia ang barangay destination, dayon join sa passenger queue.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            BarangayPickerField(
              routes: routes,
              value: selected,
              onChanged: onSelect,
              enabled: !joining,
            ),
            if (selected != null) ...[
              const SizedBox(height: 16),
              _LiveRouteSummary(name: selected!.name, status: status),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: selected == null || joining ? null : onJoin,
              icon: joining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.queue),
              label: Text(joining ? 'Joining...' : 'Join Queue'),
            ),
            const SizedBox(height: 10),
            Text(
              'Tagaan ka namo og queue number ug makita nimo pila ka pasahero ang naa sa unahan.',
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

class _EntrySection extends StatelessWidget {
  const _EntrySection({
    required this.entry,
    required this.status,
    required this.cancelling,
    required this.onView,
    required this.onCancel,
  });

  final QueueEntry entry;
  final PublicRouteStatus? status;
  final bool cancelling;
  final VoidCallback onView;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 620;
                final ticket = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR QUEUE NUMBER',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '#${entry.queueNumber}',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        StatusChip(entry.status),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            entry.routeName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                );

                final metrics = Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Metric(
                      label: 'Passengers ahead',
                      value: '${entry.peopleAhead}',
                      icon: Icons.people_outline,
                    ),
                    _Metric(
                      label: 'Your position',
                      value: '#${entry.position}',
                      icon: Icons.format_list_numbered,
                    ),
                    _Metric(
                      label: 'Drivers in queue',
                      value: status == null ? '…' : '${status!.route.driversInQueue}',
                      icon: Icons.electric_rickshaw,
                    ),
                    _Metric(
                      label: 'Joined',
                      value: formatTime(entry.joinedAt),
                      icon: Icons.schedule,
                    ),
                  ],
                );

                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: ticket),
                          const SizedBox(width: 20),
                          Expanded(flex: 3, child: metrics),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [ticket, const SizedBox(height: 16), metrics],
                      );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (status != null) ...[
                  _LiveRouteSummary(name: entry.routeName, status: status),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onView,
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('View'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                        ),
                        onPressed: cancelling ? null : onCancel,
                        icon: cancelling
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.close),
                        label: const Text('Cancel Queue'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveRouteSummary extends StatelessWidget {
  const _LiveRouteSummary({required this.name, required this.status});

  final String name;
  final PublicRouteStatus? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = status;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (data != null) DemandChip(data.route.demandLevel),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Text(
                'Passengers waiting: ${data?.route.passengersWaiting ?? '…'}',
              ),
              Text('Drivers in queue: ${data?.route.driversInQueue ?? '…'}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
