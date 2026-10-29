import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import '../../widgets/polling.dart';
import 'admin_layout.dart';

class ManageDriversScreen extends StatefulWidget {
  const ManageDriversScreen({super.key});

  @override
  State<ManageDriversScreen> createState() => _ManageDriversScreenState();
}

class _ManageDriversScreenState extends State<ManageDriversScreen>
    with PollingMixin<ManageDriversScreen> {
  late final ApiClient _api;
  List<DriverRecord> _drivers = const [];
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
      final drivers = await _api.drivers();
      if (!mounted) return;
      setState(() {
        _drivers = drivers;
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

  Future<void> _openForm([DriverRecord? driver]) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _DriverFormDialog(driver: driver),
    );
    if (payload == null || !mounted) return;

    setState(() => _busy = true);
    try {
      if (driver == null) {
        await _api.createDriver(payload);
        if (mounted) showSnack(context, 'Driver added.');
      } else {
        await _api.updateDriver(driver.id, payload);
        if (mounted) showSnack(context, 'Driver updated.');
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleActive(DriverRecord driver) async {
    if (driver.isActive) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Deactivate ${driver.fullName}?',
        message:
            'Dili na siya kamao mo-login o mo-join sa queue. Tangtangon usab '
            'iyang aktibo nga queue entry.',
        confirmLabel: 'Deactivate',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      if (driver.isActive) {
        await _api.deactivateDriver(driver.id);
      } else {
        await _api.updateDriver(driver.id, {'is_active': true});
      }
      if (mounted) {
        showSnack(
          context,
          driver.isActive ? 'Driver deactivated.' : 'Driver activated.',
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
    return AdminLayout(
      currentPath: '/admin/drivers',
      child: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Manage drivers',
              subtitle: '${_drivers.length} registered driver(s)',
              actions: [
                IconButton.filledTonal(
                  tooltip: 'Refresh now',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _openForm(),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add driver'),
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
                  : _drivers.isEmpty
                  ? const SingleChildScrollView(
                      child: EmptyState(
                        icon: Icons.badge_outlined,
                        title: 'No drivers yet',
                        message: 'Add the first tricycle driver account.',
                      ),
                    )
                  : ListView.separated(
                      itemCount: _drivers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final driver = _drivers[index];
                        return _DriverTile(
                          driver: driver,
                          busy: _busy,
                          onEdit: () => _openForm(driver),
                          onToggleActive: () => _toggleActive(driver),
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

class _DriverTile extends StatelessWidget {
  const _DriverTile({
    required this.driver,
    required this.busy,
    required this.onEdit,
    required this.onToggleActive,
  });

  final DriverRecord driver;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          child: Text(
            driver.fullName.isEmpty ? '?' : driver.fullName[0].toUpperCase(),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                driver.fullName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (driver.isActive
                        ? const Color(0xFF2E7D32)
                        : theme.colorScheme.error)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                driver.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: driver.isActive
                      ? const Color(0xFF2E7D32)
                      : theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(driver.email),
            Text(
              'Tricycle ${driver.tricycleNo}'
              '${driver.phone == null || driver.phone!.isEmpty ? '' : ' • ${driver.phone}'}',
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          enabled: !busy,
          tooltip: 'Driver actions',
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'toggle') onToggleActive();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit_outlined),
                title: Text('Edit'),
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  driver.isActive ? Icons.block : Icons.check_circle_outline,
                ),
                title: Text(driver.isActive ? 'Deactivate' : 'Activate'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverFormDialog extends StatefulWidget {
  const _DriverFormDialog({this.driver});

  final DriverRecord? driver;

  @override
  State<_DriverFormDialog> createState() => _DriverFormDialogState();
}

class _DriverFormDialogState extends State<_DriverFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _tricycle;
  late final TextEditingController _phone;
  final _password = TextEditingController();
  bool _showPassword = false;

  bool get _isEdit => widget.driver != null;

  @override
  void initState() {
    super.initState();
    final driver = widget.driver;
    _name = TextEditingController(text: driver?.fullName ?? '');
    _email = TextEditingController(text: driver?.email ?? '');
    _tricycle = TextEditingController(text: driver?.tricycleNo ?? '');
    _phone = TextEditingController(text: driver?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _tricycle.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final payload = <String, dynamic>{
      'email': _email.text.trim(),
      'full_name': _name.text.trim(),
      'tricycle_no': _tricycle.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
    };
    if (!_isEdit || _password.text.isNotEmpty) {
      payload['password'] = _password.text;
    }
    Navigator.pop(context, payload);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit driver' : 'Add driver'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) =>
                      (value?.trim().length ?? 0) < 2 ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (!text.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tricycle,
                  decoration: const InputDecoration(
                    labelText: 'Tricycle number',
                  ),
                  validator: (value) =>
                      (value?.trim().length ?? 0) < 2 ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: _isEdit
                        ? 'New password (optional)'
                        : 'Password (min 8 characters)',
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (_isEdit && (value == null || value.isEmpty)) return null;
                    if (value == null || value.length < 8) {
                      return 'Use at least 8 characters';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEdit ? 'Save changes' : 'Add driver'),
        ),
      ],
    );
  }
}
