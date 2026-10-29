import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../widgets/common.dart';
import '../widgets/polling.dart';

/// Public no-login board. Wala ni JWT; public endpoints ra ang gigamit.
class PublicStatusScreen extends StatefulWidget {
  const PublicStatusScreen({super.key});

  @override
  State<PublicStatusScreen> createState() => _PublicStatusScreenState();
}

class _PublicStatusScreenState extends State<PublicStatusScreen>
    with PollingMixin<PublicStatusScreen> {
  late final ApiClient _api;
  final _search = TextEditingController();
  List<PublicRouteSummary> _routes = const [];
  bool _loading = true;
  DateTime? _updatedAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
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
      final routes = await _api.publicRoutes();
      if (!mounted) return;
      setState(() {
        _routes = routes;
        _updatedAt = DateTime.now();
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loggedIn = context.watch<AuthState>().isAuthenticated;
    final query = _search.text.trim().toLowerCase();
    final filtered = _routes
        .where((route) => route.routeName.toLowerCase().contains(query))
        .toList();
    final totalPassengers = _routes.fold<int>(
      0,
      (sum, route) => sum + route.passengersWaiting,
    );
    final totalDrivers = _routes.fold<int>(
      0,
      (sum, route) => sum + route.driversInQueue,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.public, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'ParkKeys Public Board',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.go(loggedIn ? '/login' : '/login'),
            icon: const Icon(Icons.login),
            label: Text(loggedIn ? 'My account' : 'Staff login'),
          ),
        ],
      ),
      body: ResponsiveBody(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Live queue board',
                subtitle: _updatedAt == null
                    ? 'Loading live counts...'
                    : 'Drivers in queue + passengers waiting per barangay • '
                          'updated ${formatTime(_updatedAt)}',
                actions: [
                  IconButton.filledTonal(
                    tooltip: 'Refresh now',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PublicCount(
                    icon: Icons.people_outline,
                    label: 'Passengers waiting',
                    value: totalPassengers,
                  ),
                  _PublicCount(
                    icon: Icons.electric_rickshaw,
                    label: 'Drivers in queue',
                    value: totalDrivers,
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
              const SizedBox(height: 16),
              if (_loading)
                const LoadingView()
              else if (filtered.isEmpty)
                const EmptyState(
                  icon: Icons.search_off,
                  title: 'No barangay found',
                  message: 'Try a different search.',
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 12.0;
                    final columns = constraints.maxWidth >= 980
                        ? 3
                        : constraints.maxWidth >= 640
                        ? 2
                        : 1;
                    final width =
                        (constraints.maxWidth - spacing * (columns - 1)) /
                        columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final route in filtered)
                          SizedBox(
                            width: width,
                            child: _PublicRouteCard(
                              route: route,
                              onTap: () => _showRouteStatus(route),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 16),
              Text(
                'Demo lang ni nga page. Refresh automatic every 3 seconds.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRouteStatus(PublicRouteSummary route) {
    return showDialog<void>(
      context: context,
      builder: (context) => _RouteStatusDialog(
        api: _api,
        routeId: route.routeId,
        initial: route,
      ),
    );
  }
}

class _PublicCount extends StatelessWidget {
  const _PublicCount({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$value',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _PublicRouteCard extends StatelessWidget {
  const _PublicRouteCard({required this.route, required this.onTap});

  final PublicRouteSummary route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.place, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      route.routeName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!route.active)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Inactive',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MiniMetric(
                      icon: Icons.people_outline,
                      label: 'Passengers waiting',
                      value: '${route.passengersWaiting}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniMetric(
                      icon: Icons.electric_rickshaw,
                      label: 'Drivers in queue',
                      value: '${route.driversInQueue}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  DemandChip(route.demandLevel),
                  const Spacer(),
                  Text(
                    'View drivers',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
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

class _RouteStatusDialog extends StatefulWidget {
  const _RouteStatusDialog({
    required this.api,
    required this.routeId,
    required this.initial,
  });

  final ApiClient api;
  final int routeId;
  final PublicRouteSummary initial;

  @override
  State<_RouteStatusDialog> createState() => _RouteStatusDialogState();
}

class _RouteStatusDialogState extends State<_RouteStatusDialog> {
  late Future<PublicRouteStatus> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.publicRouteStatus(widget.routeId);
  }

  void _reload() {
    setState(() {
      _future = widget.api.publicRouteStatus(widget.routeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.place),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.initial.routeName)),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        height: 380,
        child: FutureBuilder<PublicRouteStatus>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView();
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  snapshot.error is ApiException
                      ? (snapshot.error as ApiException).message
                      : 'Failed to load drivers.',
                ),
              );
            }
            final status = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${status.route.passengersWaiting} passengers waiting',
                    ),
                    Text('${status.route.driversInQueue} drivers in queue'),
                    DemandChip(status.route.demandLevel),
                  ],
                ),
                const Divider(height: 20),
                Expanded(
                  child: status.drivers.isEmpty
                      ? const Center(
                          child: Text('Wala pay driver sa linya karon.'),
                        )
                      : ListView.separated(
                          itemCount: status.drivers.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final driver = status.drivers[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 16,
                                child: Text('${driver.queueNumber}'),
                              ),
                              title: Text(driver.fullName),
                              subtitle: Text(
                                driver.tricycleNo == null
                                    ? 'Position #${driver.position}'
                                    : 'Tricycle ${driver.tricycleNo} • '
                                          'position #${driver.position}',
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
