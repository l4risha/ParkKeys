int _toInt(dynamic value) => value is int ? value : int.parse('$value');

DateTime _toDate(dynamic value) => DateTime.parse('$value').toLocal();

DateTime? _toDateOrNull(dynamic value) =>
    value == null ? null : DateTime.parse('$value').toLocal();

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final User user;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
    token: json['access_token'] as String,
    user: User.fromJson(json['user'] as Map<String, dynamic>),
  );
}

class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  final int id;
  final String email;
  final String fullName;
  final String role;
  final bool isActive;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: _toInt(json['id']),
    email: json['email'] as String,
    fullName: json['full_name'] as String,
    role: json['role'] as String,
    isActive: json['is_active'] as bool? ?? true,
  );
}

class RouteInfo {
  const RouteInfo({required this.id, required this.name, required this.active});

  final int id;
  final String name;
  final bool active;

  factory RouteInfo.fromJson(Map<String, dynamic> json) => RouteInfo(
    id: _toInt(json['id']),
    name: json['name'] as String,
    active: json['active'] as bool? ?? true,
  );
}

class QueueEntry {
  const QueueEntry({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.queueType,
    required this.queueNumber,
    required this.status,
    required this.position,
    required this.peopleAhead,
    required this.joinedAt,
    this.completedAt,
  });

  final int id;
  final int routeId;
  final String routeName;
  final String queueType;
  final int queueNumber;
  final String status;
  final int position;
  final int peopleAhead;
  final DateTime joinedAt;
  final DateTime? completedAt;

  bool get isActive => status == 'waiting' || status == 'on_deck';

  factory QueueEntry.fromJson(Map<String, dynamic> json) => QueueEntry(
    id: _toInt(json['id']),
    routeId: _toInt(json['route_id']),
    routeName: json['route_name'] as String,
    queueType: json['queue_type'] as String,
    queueNumber: _toInt(json['queue_number']),
    status: json['status'] as String,
    position: _toInt(json['position']),
    peopleAhead: _toInt(json['people_ahead']),
    joinedAt: _toDate(json['joined_at']),
    completedAt: _toDateOrNull(json['completed_at']),
  );
}

class DriverQueueView {
  const DriverQueueView({this.entry, required this.passengersWaiting});

  final QueueEntry? entry;
  final int passengersWaiting;

  factory DriverQueueView.fromJson(Map<String, dynamic> json) => DriverQueueView(
    entry: json['entry'] == null
        ? null
        : QueueEntry.fromJson(json['entry'] as Map<String, dynamic>),
    passengersWaiting: _toInt(json['passengers_waiting']),
  );
}

class ServeResult {
  const ServeResult({
    required this.message,
    required this.routeName,
    required this.driverQueueNumber,
    required this.passengerQueueNumber,
    required this.servedAt,
  });

  final String message;
  final String routeName;
  final int driverQueueNumber;
  final int passengerQueueNumber;
  final DateTime servedAt;

  factory ServeResult.fromJson(Map<String, dynamic> json) => ServeResult(
    message: json['message'] as String,
    routeName: json['route_name'] as String,
    driverQueueNumber: _toInt(json['driver_queue_number']),
    passengerQueueNumber: _toInt(json['passenger_queue_number']),
    servedAt: _toDate(json['served_at']),
  );
}

class PublicDriver {
  const PublicDriver({
    required this.queueNumber,
    required this.position,
    required this.fullName,
    this.tricycleNo,
  });

  final int queueNumber;
  final int position;
  final String fullName;
  final String? tricycleNo;

  factory PublicDriver.fromJson(Map<String, dynamic> json) => PublicDriver(
    queueNumber: _toInt(json['queue_number']),
    position: _toInt(json['position']),
    fullName: json['full_name'] as String,
    tricycleNo: json['tricycle_no'] as String?,
  );
}

class PublicRouteSummary {
  const PublicRouteSummary({
    required this.routeId,
    required this.routeName,
    required this.active,
    required this.driversInQueue,
    required this.passengersWaiting,
    required this.demandLevel,
    required this.demandSource,
  });

  final int routeId;
  final String routeName;
  final bool active;
  final int driversInQueue;
  final int passengersWaiting;
  final String demandLevel;
  final String demandSource;

  factory PublicRouteSummary.fromJson(Map<String, dynamic> json) =>
      PublicRouteSummary(
        routeId: _toInt(json['route_id']),
        routeName: json['route_name'] as String,
        active: json['active'] as bool? ?? true,
        driversInQueue: _toInt(json['drivers_in_queue']),
        passengersWaiting: _toInt(json['passengers_waiting']),
        demandLevel: json['demand_level'] as String,
        demandSource: json['demand_source'] as String? ?? 'fallback',
      );
}

class PublicRouteStatus {
  const PublicRouteStatus({
    required this.route,
    required this.drivers,
    required this.updatedAt,
  });

  final PublicRouteSummary route;
  final List<PublicDriver> drivers;
  final DateTime updatedAt;

  factory PublicRouteStatus.fromJson(Map<String, dynamic> json) =>
      PublicRouteStatus(
        route: PublicRouteSummary.fromJson(json),
        drivers: (json['drivers'] as List<dynamic>)
            .map((item) => PublicDriver.fromJson(item as Map<String, dynamic>))
            .toList(),
        updatedAt: _toDate(json['updated_at']),
      );
}

class DriverRecord {
  const DriverRecord({
    required this.id,
    required this.userId,
    required this.email,
    required this.fullName,
    required this.tricycleNo,
    this.phone,
    required this.isActive,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String email;
  final String fullName;
  final String tricycleNo;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;

  factory DriverRecord.fromJson(Map<String, dynamic> json) => DriverRecord(
    id: _toInt(json['id']),
    userId: _toInt(json['user_id']),
    email: json['email'] as String,
    fullName: json['full_name'] as String,
    tricycleNo: json['tricycle_no'] as String,
    phone: json['phone'] as String?,
    isActive: json['is_active'] as bool? ?? true,
    createdAt: _toDate(json['created_at']),
  );
}

class DashboardStats {
  const DashboardStats({
    required this.routesActive,
    required this.driversActive,
    required this.passengersWaiting,
    required this.driversInQueue,
    required this.completedToday,
    required this.cancelledToday,
    required this.asOf,
  });

  final int routesActive;
  final int driversActive;
  final int passengersWaiting;
  final int driversInQueue;
  final int completedToday;
  final int cancelledToday;
  final DateTime asOf;

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
    routesActive: _toInt(json['routes_active']),
    driversActive: _toInt(json['drivers_active']),
    passengersWaiting: _toInt(json['passengers_waiting']),
    driversInQueue: _toInt(json['drivers_in_queue']),
    completedToday: _toInt(json['completed_today']),
    cancelledToday: _toInt(json['cancelled_today']),
    asOf: _toDate(json['as_of']),
  );
}

class Prediction {
  const Prediction({
    required this.routeId,
    required this.routeName,
    required this.predictedFor,
    required this.demandLevel,
    required this.predictedCount,
    required this.modelVersion,
    required this.source,
  });

  final int routeId;
  final String routeName;
  final DateTime predictedFor;
  final String demandLevel;
  final double? predictedCount;
  final String modelVersion;
  final String source;

  factory Prediction.fromJson(Map<String, dynamic> json) => Prediction(
    routeId: _toInt(json['route_id']),
    routeName: json['route_name'] as String,
    predictedFor: _toDate(json['predicted_for']),
    demandLevel: json['demand_level'] as String,
    predictedCount: json['predicted_count'] == null
        ? null
        : double.parse('${json['predicted_count']}'),
    modelVersion: json['model_version'] as String,
    source: json['source'] as String,
  );
}

class ReportRow {
  const ReportRow({
    required this.routeId,
    required this.routeName,
    required this.completedTrips,
    required this.cancelled,
    required this.skipped,
    required this.removed,
  });

  final int routeId;
  final String routeName;
  final int completedTrips;
  final int cancelled;
  final int skipped;
  final int removed;

  factory ReportRow.fromJson(Map<String, dynamic> json) => ReportRow(
    routeId: _toInt(json['route_id']),
    routeName: json['route_name'] as String,
    completedTrips: _toInt(json['completed_trips']),
    cancelled: _toInt(json['cancelled']),
    skipped: _toInt(json['skipped']),
    removed: _toInt(json['removed']),
  );
}

class ReportSummary {
  const ReportSummary({required this.days, required this.rows});

  final int days;
  final List<ReportRow> rows;

  int get completed => rows.fold(0, (sum, row) => sum + row.completedTrips);
  int get cancelled => rows.fold(0, (sum, row) => sum + row.cancelled);
  int get skipped => rows.fold(0, (sum, row) => sum + row.skipped);
  int get removed => rows.fold(0, (sum, row) => sum + row.removed);

  factory ReportSummary.fromJson(Map<String, dynamic> json) => ReportSummary(
    days: _toInt(json['days']),
    rows: (json['rows'] as List<dynamic>)
        .map((item) => ReportRow.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

class AdminQueueEntry {
  const AdminQueueEntry({
    required this.entry,
    required this.userId,
    required this.fullName,
    required this.email,
    this.tricycleNo,
    this.reasonCode,
  });

  final QueueEntry entry;
  final int userId;
  final String fullName;
  final String email;
  final String? tricycleNo;
  final String? reasonCode;

  factory AdminQueueEntry.fromJson(Map<String, dynamic> json) => AdminQueueEntry(
    entry: QueueEntry.fromJson(json),
    userId: _toInt(json['user_id']),
    fullName: json['full_name'] as String,
    email: json['email'] as String,
    tricycleNo: json['tricycle_no'] as String?,
    reasonCode: json['reason_code'] as String?,
  );
}

class AdminRouteQueue {
  const AdminRouteQueue({
    required this.routeId,
    required this.routeName,
    required this.active,
    required this.passengersWaiting,
    required this.driversInQueue,
    required this.passengers,
    required this.drivers,
    required this.demandLevel,
  });

  final int routeId;
  final String routeName;
  final bool active;
  final int passengersWaiting;
  final int driversInQueue;
  final List<AdminQueueEntry> passengers;
  final List<AdminQueueEntry> drivers;
  final String demandLevel;

  factory AdminRouteQueue.fromJson(Map<String, dynamic> json) =>
      AdminRouteQueue(
        routeId: _toInt(json['route_id']),
        routeName: json['route_name'] as String,
        active: json['active'] as bool? ?? true,
        passengersWaiting: _toInt(json['passengers_waiting']),
        driversInQueue: _toInt(json['drivers_in_queue']),
        passengers: (json['passengers'] as List<dynamic>)
            .map((item) => AdminQueueEntry.fromJson(item as Map<String, dynamic>))
            .toList(),
        drivers: (json['drivers'] as List<dynamic>)
            .map((item) => AdminQueueEntry.fromJson(item as Map<String, dynamic>))
            .toList(),
        demandLevel: json['demand_level'] as String,
      );
}
