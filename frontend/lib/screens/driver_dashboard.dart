import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../widgets/barangay_picker.dart';
import '../widgets/common.dart';
import '../widgets/polling.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard>
    with PollingMixin<DriverDashboard> {
  late final ApiClient _api;
  List<RouteInfo> _routes = const [];
  RouteInfo? _selected;
  DriverQueueView? _view;
  PublicRouteStatus? _routeStatus;
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
      final routes = await _api.routes();
      final view = await _api.driverQueue();
      PublicRouteStatus? status;
      if (view.entry != null) {
        status = await _api.publicRouteStatus(view.entry!.routeId);
      } else if (_selected != null) {
        status = await _api.publicRouteStatus(_selected!.id);
      }
      if (!mounted) return;
      setState(() {
        _routes = routes;
        _view = view;
        _routeStatus = status;
        _loading = false;
        _error = null;
        if (view.entry != null) {
          _selected = RouteInfo(
            id: view.entry!.routeId,
            name: view.entry!.routeName,
            active: true,
          );
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

  Future<void> _join() async {
    final selected = _selected;
    if (selected == null) {
      showSnack(context, 'Select a route first.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final entry = await _api.joinDriverQueue(selected.id);
      if (!mounted) return;
      showSnack(
        context,
        'Joined ${entry.routeName} driver queue. Number ${entry.queueNumber}.',
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setStatus(String status) async {
    final entry = _view?.entry;
    if (entry == null) return;
    setState(() => _busy = true);
    try {
      await _api.updateDriverStatus(entry.routeId, status);
      if (!mounted) return;
      showSnack(context, 'Status updated to ${status.replaceAll('_', ' ')}.');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _serve() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Complete this trip?',
      message:
          'Ang position 1 nga pasahero sa parehas nga route ma-complete usab.',
      confirmLabel: 'Serve passenger',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await _api.serveNextPassenger();
      if (!mounted) return;
      showSnack(
        context,
        'Trip served on ${result.routeName}. Passenger #${result.passengerQueueNumber} completed.',
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Leave driver queue?',
      message: 'Mawala imong position sa linya.',
      confirmLabel: 'Leave queue',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await _api.leaveDriverQueue();
      if (!mounted) return;
      showSnack(context, 'You left the driver queue.');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final view = _view;
    final entry = view?.entry;

    return AppShell(
      title: 'ParkKeys',
      subtitle: 'Driver • ${auth.user?.fullName ?? ''}',
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
                title: entry == null ? 'Join a route queue' : 'Your driver queue',
                subtitle: entry == null
                    ? 'Pilia ang ruta nga imong biyahehon.'
                    : 'Mag-update ang position every 3 seconds.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorBanner(message: _error!, onRetry: _load),
              ],
              const SizedBox(height: 16),
              if (_loading)
                const LoadingView()
              else if (entry == null)
                _DriverJoin(
                  routes: _routes,
                  selected: _selected,
                  status: _routeStatus,
                  busy: _busy,
                  onSelect: (route) {
                    setState(() => _selected = route);
                    _load();
                  },
                  onJoin: _join,
                )
              else
                _DriverQueueCard(
                  entry: entry,
                  passengersWaiting: view!.passengersWaiting,
                  busy: _busy,
                  onStatus: _setStatus,
                  onServe: _serve,
                  onLeave: _leave,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverJoin extends StatelessWidget {
  const _DriverJoin({
    required this.routes,
    required this.selected,
    required this.status,
    required this.busy,
    required this.onSelect,
    required this.onJoin,
  });

  final List<RouteInfo> routes;
  final RouteInfo? selected;
  final PublicRouteStatus? status;
  final bool busy;
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
            Text(
              'Select route',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            BarangayPickerField(
              routes: routes,
              value: selected,
              onChanged: onSelect,
              label: 'Route / barangay',
              enabled: !busy,
            ),
            if (selected != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.route, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            selected!.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (status != null)
                          DemandChip(status!.route.demandLevel),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        Text(
                          'Passengers waiting: '
                          '${status?.route.passengersWaiting ?? '…'}',
                        ),
                        Text(
                          'Drivers in queue: '
                          '${status?.route.driversInQueue ?? '…'}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: selected == null || busy ? null : onJoin,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(busy ? 'Joining...' : 'Join Driver Queue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverQueueCard extends StatelessWidget {
  const _DriverQueueCard({
    required this.entry,
    required this.passengersWaiting,
    required this.busy,
    required this.onStatus,
    required this.onServe,
    required this.onLeave,
  });

  final QueueEntry entry;
  final int passengersWaiting;
  final bool busy;
  final ValueChanged<String> onStatus;
  final VoidCallback onServe;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOnDeck = entry.status == 'on_deck';
    final canServe = entry.position == 1 && passengersWaiting > 0 && !busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 620;
                final position = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR POSITION',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '#${entry.position}',
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
                    _DriverMetric(
                      icon: Icons.confirmation_number_outlined,
                      label: 'Queue number',
                      value: '#${entry.queueNumber}',
                    ),
                    _DriverMetric(
                      icon: Icons.directions_car_outlined,
                      label: 'Drivers ahead',
                      value: '${entry.peopleAhead}',
                    ),
                    _DriverMetric(
                      icon: Icons.people_outline,
                      label: 'Passengers waiting',
                      value: '$passengersWaiting',
                    ),
                    _DriverMetric(
                      icon: Icons.schedule,
                      label: 'Joined',
                      value: formatTime(entry.joinedAt),
                    ),
                  ],
                );

                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: position),
                          const SizedBox(width: 20),
                          Expanded(flex: 3, child: metrics),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          position,
                          const SizedBox(height: 16),
                          metrics,
                        ],
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
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => onStatus(isOnDeck ? 'waiting' : 'on_deck'),
                  icon: Icon(
                    isOnDeck ? Icons.pause_circle_outline : Icons.play_circle_outline,
                  ),
                  label: Text(
                    isOnDeck ? 'Set status: Waiting' : 'Set status: On deck',
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: canServe ? onServe : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Complete Trip (serve passenger)'),
                ),
                if (!canServe) ...[
                  const SizedBox(height: 6),
                  Text(
                    entry.position != 1
                        ? 'Position 1 lang ang maka-serve sa sunod nga pasahero.'
                        : passengersWaiting == 0
                        ? 'Wala pay pasahero naghulat sa kining ruta.'
                        : 'Please wait...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: busy ? null : onLeave,
                  icon: const Icon(Icons.logout),
                  label: const Text('Leave Queue'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverMetric extends StatelessWidget {
  const _DriverMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 160,
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
