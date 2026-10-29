import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import '../../widgets/polling.dart';
import 'admin_layout.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with PollingMixin<AdminDashboardScreen> {
  late final ApiClient _api;
  DashboardStats? _stats;
  int _totalDrivers = 0;
  List<Prediction> _predictions = const [];
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
  Future<void> refreshData() => _load();

  Future<void> _load({bool initial = false}) async {
    if (initial && mounted) setState(() => _loading = true);
    try {
      final stats = await _api.dashboard();
      final drivers = await _api.drivers();
      final predictions = await _api.predictions();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _totalDrivers = drivers.length;
        _predictions = predictions;
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
    final stats = _stats;
    final activeQueues = stats == null
        ? 0
        : stats.passengersWaiting + stats.driversInQueue;

    return AdminLayout(
      currentPath: '/admin',
      child: ResponsiveBody(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Admin dashboard',
                subtitle: stats == null
                    ? 'Loading live counts...'
                    : 'As of ${formatDateTime(stats.asOf)} • updates every 3s',
                actions: [
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
              const SizedBox(height: 16),
              if (_loading && stats == null)
                const LoadingView()
              else if (stats != null) ...[
                _StatsGrid(
                  cards: [
                    StatCard(
                      label: 'Total drivers',
                      value: '$_totalDrivers',
                      icon: Icons.badge_outlined,
                      hint: '${stats.driversActive} active',
                    ),
                    StatCard(
                      label: 'Active drivers',
                      value: '${stats.driversActive}',
                      icon: Icons.verified_user_outlined,
                      color: const Color(0xFF2E7D32),
                    ),
                    StatCard(
                      label: 'Passengers served today',
                      value: '${stats.completedToday}',
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF1565C0),
                      hint: '${stats.cancelledToday} cancelled today',
                    ),
                    StatCard(
                      label: 'Active queues',
                      value: '$activeQueues',
                      icon: Icons.people_outline,
                      color: const Color(0xFFEF6C00),
                      hint:
                          '${stats.passengersWaiting} passengers • '
                          '${stats.driversInQueue} drivers',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _StatsGrid(
                  cards: [
                    StatCard(
                      label: 'Active barangays',
                      value: '${stats.routesActive}',
                      icon: Icons.place_outlined,
                    ),
                    StatCard(
                      label: 'Passengers waiting',
                      value: '${stats.passengersWaiting}',
                      icon: Icons.hourglass_empty,
                    ),
                    StatCard(
                      label: 'Drivers in queue',
                      value: '${stats.driversInQueue}',
                      icon: Icons.electric_rickshaw,
                    ),
                    StatCard(
                      label: 'Cancelled today',
                      value: '${stats.cancelledToday}',
                      icon: Icons.cancel_outlined,
                      color: const Color(0xFFC62828),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _PredictionsCard(predictions: _predictions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = constraints.maxWidth >= 950
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

class _PredictionsCard extends StatelessWidget {
  const _PredictionsCard({required this.predictions});

  final List<Prediction> predictions;

  static const _rank = {'HIGH': 0, 'MEDIUM': 1, 'LOW': 2};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...predictions]
      ..sort((a, b) {
        final byRank =
            (_rank[a.demandLevel] ?? 3).compareTo(_rank[b.demandLevel] ?? 3);
        return byRank != 0 ? byRank : a.routeName.compareTo(b.routeName);
      });
    final high = sorted.where((p) => p.demandLevel == 'HIGH').length;
    final medium = sorted.where((p) => p.demandLevel == 'MEDIUM').length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              'ML demand prediction (now)',
              trailing: Text(
                '$high HIGH • $medium MEDIUM',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Random Forest per barangay. Automatic refresh every 30 minutes.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            if (sorted.isEmpty)
              const Text('No predictions available.')
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 10.0;
                  final columns = constraints.maxWidth >= 860
                      ? 3
                      : constraints.maxWidth >= 560
                      ? 2
                      : 1;
                  final width =
                      (constraints.maxWidth - spacing * (columns - 1)) /
                      columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final prediction in sorted)
                        SizedBox(
                          width: width,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prediction.routeName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        prediction.predictedCount == null
                                            ? prediction.source
                                            : '${prediction.predictedCount!.toStringAsFixed(1)} '
                                                  'expected • ${prediction.source}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                DemandChip(prediction.demandLevel),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
