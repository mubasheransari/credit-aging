import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';

import '../models/models.dart';
import 'auth_service.dart';

class StoredNotification {
  final int id;
  final String title;
  final String body;
  final DateTime dateTime;
  final int? requestId;

  /// Which role this notification was generated for (e.g. 'FINANCE_MANAGER',
  /// 'DIRECTOR') or 'REQUESTER' when it was sent to whoever raised the
  /// request. Older, pre-existing history entries won't have this, so it's
  /// nullable and defaults to an empty string when missing.
  final String role;
  final String? eventKey;

  const StoredNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.dateTime,
    this.requestId,
    this.role = '',
    this.eventKey,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'date_time': dateTime.toIso8601String(),
        'request_id': requestId,
        'role': role,
        'event_key': eventKey,
      };

  factory StoredNotification.fromJson(Map<String, dynamic> json) {
    return StoredNotification(
      id: int.tryParse('${json['id']}') ?? 0,
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? ''}',
      dateTime: DateTime.tryParse('${json['date_time']}') ?? DateTime.now(),
      requestId: json['request_id'] == null
          ? null
          : int.tryParse('${json['request_id']}'),
      role: '${json['role'] ?? ''}',
      eventKey: json['event_key']?.toString(),
    );
  }
}

/// Describes why a particular [CreditAgingRequest] update is relevant to the
/// currently signed-in user, and the copy that should be shown to them.
class _RoleNotificationContent {
  final String role;
  final String title;
  final String body;

  const _RoleNotificationContent({
    required this.role,
    required this.title,
    required this.body,
  });
}

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static final GetStorage _box = GetStorage();

  static const String _knownIdsKey = 'credit_aging_known_request_ids';
  static const String _knownStatusesKey =
      'credit_aging_known_request_statuses';
  static const String _historyKey = 'credit_aging_notification_history';

  static const String newRequestChannelId = 'credit_aging_new_requests';
  static const String newRequestChannelName = 'New Credit Aging Requests';
  static const String newRequestChannelDescription =
      'Notifications for newly submitted Credit Aging requests.';

  static const int maxHistoryItems = 100;

  static bool _initialized = false;

  static Future<void> initialize({bool requestPermission = true}) async {
    const android = AndroidInitializationSettings('ic_stat_credit_aging');

    const iOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: android,
      iOS: iOS,
    );

    if (_initialized) {
      if (requestPermission) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission();
      }
      return;
    }

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        newRequestChannelId,
        newRequestChannelName,
        description: newRequestChannelDescription,
        importance: Importance.max,
      ),
    );

    if (requestPermission) {
      await androidPlugin?.requestNotificationsPermission();
    }

    await GetStorage.init();
    _initialized = true;
  }

  static Future<void> _onNotificationResponse(
    NotificationResponse response,
  ) async {
    // The payload is intentionally kept simple. The app's notification list
    // is persistent and is opened from the UI bell icon.
  }

  static List<StoredNotification> get history {
    final stored = _box.read<dynamic>(_historyKey);
    final raw = stored is List ? stored : <dynamic>[];

    return raw
        .whereType<dynamic>()
        .map((item) {
          try {
            if (item is Map) {
              return StoredNotification.fromJson(
                Map<String, dynamic>.from(item),
              );
            }
          } catch (_) {}
          return null;
        })
        .whereType<StoredNotification>()
        .toList();
  }

  static int get unreadCount => history.length;

  static Set<int> get knownRequestIds {
    final stored = _box.read<dynamic>(_knownIdsKey);
    final raw = stored is List ? stored : <dynamic>[];
    return raw.map((e) => int.tryParse('$e')).whereType<int>().toSet();
  }

  /// Maps requestId -> last known workflow state. The value contains
  /// status + pending approval role + pending level, because Oracle keeps the
  /// request status as UNDER_REVIEW while the approval moves from one level
  /// to the next. Tracking status alone would therefore miss Senior Manager
  /// -> CFO and CFO -> Director transitions.
  static Map<int, String> get _knownStatuses {
    final stored = _box.read<dynamic>(_knownStatusesKey);

    if (stored is Map) {
      final result = <int, String>{};
      var hasLegacyState = false;
      stored.forEach((key, value) {
        final id = int.tryParse('$key');
        if (id == null) return;
        final state = '$value'.toUpperCase();
        if (!state.contains('|')) hasLegacyState = true;
        result[id] = state;
      });

      // One-time migration from the previous status-only format. Returning
      // an empty map makes the next sync establish a quiet baseline rather
      // than firing notifications for every currently pending request.
      if (hasLegacyState) return <int, String>{};
      return result;
    }

    // Older builds stored only the request status. Do not generate a wave
    // of notifications after upgrading; the first sync with the new state
    // format will establish a fresh baseline. Subsequent syncs will detect
    // both status changes and pending-role changes.
    return <int, String>{};
  }

  static Future<void> _saveKnownStatuses(Map<int, String> statuses) async {
    final entries = statuses.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // Keep the persisted map bounded, same rationale as the id set below.
    final bounded = entries.length > 1000
        ? entries.sublist(entries.length - 1000)
        : entries;

    await _box.write(
      _knownStatusesKey,
      {for (final entry in bounded) '${entry.key}': entry.value},
    );
  }

  /// First sync establishes the baseline and deliberately does not notify
  /// for every existing database record.
  static Future<List<CreditAgingRequest>> syncRequests(
    List<CreditAgingRequest> requests, {
    bool notifyNewEntries = true,
  }) async {
    final previousStatuses = _knownStatuses;
    final isBaseline = previousStatuses.isEmpty && requests.isNotEmpty;

    // The Oracle workflow can keep STATUS = UNDER_REVIEW while the
    // pending approver changes. Include the pending role/level in the saved
    // state so each hierarchy hand-off is treated as a new event.
    final currentStatuses = <int, String>{
      for (final request in requests)
        if (request.requestId > 0)
          request.requestId: _workflowState(request),
    };

    if (isBaseline) {
      await _saveKnownStatuses(currentStatuses);
      await _saveKnownIds(requests.map((e) => e.requestId));
      return const <CreditAgingRequest>[];
    }

    final role = (AuthService.storedRole ?? '').trim().toUpperCase();
    final email = (AuthService.storedEmail ?? '').trim().toLowerCase();

    final changedRequests = <CreditAgingRequest>[];

    for (final request in requests) {
      if (request.requestId <= 0) continue;

      final status = request.status.toUpperCase();
      final currentState = _workflowState(request);
      final previousState = previousStatuses[request.requestId];
      final isNewRequest = previousState == null;
      final workflowChanged = !isNewRequest && previousState != currentState;

      if (!isNewRequest && !workflowChanged) continue;

      changedRequests.add(request);

      if (!notifyNewEntries) continue;

      final content = _relevantContentFor(
        request: request,
        status: status,
        role: role,
        email: email,
      );

      if (content == null) continue;

      await _showRoleNotification(request: request, content: content);
    }

    await _saveKnownStatuses(currentStatuses);
    await _saveKnownIds(requests.map((e) => e.requestId));

    return changedRequests;
  }

  static Future<void> _saveKnownIds(Iterable<int> ids) async {
    final current = knownRequestIds;
    current.addAll(ids.where((id) => id > 0));

    // Keep the persisted set bounded. Request IDs are numeric and normally
    // increase, so keeping the latest 1000 is enough for duplicate prevention.
    final values = current.toList()..sort();
    final bounded = values.length > 1000
        ? values.sublist(values.length - 1000)
        : values;

    await _box.write(_knownIdsKey, bounded);
  }

  /// Decides whether the currently signed-in user should be told about this
  /// request's current status, and with what copy. Returns null when this
  /// particular update isn't relevant to this role, so no notification (and
  /// no history entry) is created for it.
  ///
  /// Rules (fully dynamic - no role/department names hardcoded):
  ///  - The signed-in user is notified whenever it becomes their turn to
  ///    act on a request (`request.isPendingFor(role)`), whatever level or
  ///    role that happens to be - Manager, Senior Manager, CFO, Director,
  ///    or any future level added purely as data.
  ///  - Whoever raised the request (matched by their signed-in email
  ///    against `requested_by`) is notified when it's finally APPROVED or
  ///    REJECTED, regardless of their role.
  static _RoleNotificationContent? _relevantContentFor({
    required CreditAgingRequest request,
    required String status,
    required String role,
    required String email,
  }) {
    final customer = request.subCustomer?.trim().isNotEmpty == true
        ? request.subCustomer!.trim()
        : request.customerCode;

    final requester = (request.requestedBy ?? '').trim().toLowerCase();
    final isOwnRequest =
        email.isNotEmpty && requester.isNotEmpty && requester == email;

    if (request.isPendingFor(role)) {
      final levelName = request.pendingLevelName ?? 'review';
      return _RoleNotificationContent(
        role: role,
        title: 'Awaiting your $levelName review',
        body: '${request.requestNo} • $customer needs your review.',
      );
    }

    if (status == 'APPROVED' && isOwnRequest) {
      return _RoleNotificationContent(
        role: 'REQUESTER',
        title: 'Request approved',
        body: '${request.requestNo} • $customer has been approved.',
      );
    }

    if (status == 'REJECTED' && isOwnRequest) {
      return _RoleNotificationContent(
        role: 'REQUESTER',
        title: 'Request rejected',
        body: '${request.requestNo} • $customer has been rejected.',
      );
    }

    return null;
  }

  static String _workflowState(CreditAgingRequest request) {
    final status = request.status.trim().toUpperCase();
    final role = (request.pendingApproverRole ?? '').trim().toUpperCase();
    final level = request.pendingLevelNo?.toString() ?? '';
    return '$status|$role|$level';
  }

  static String _notificationEventKey(
    CreditAgingRequest request,
    String role,
  ) {
    return '${request.requestId}|${_workflowState(request)}|${role.toUpperCase()}';
  }

  static String _notificationEventKeyFromStored(StoredNotification item) {
    // Existing notification records do not contain workflow-state metadata,
    // so fall back to a stable legacy key. New records use the full event
    // key below.
    return item.eventKey ?? '${item.requestId}|LEGACY|${item.role.toUpperCase()}';
  }

  static int _notificationId(String eventKey) {
    // Stable positive 31-bit hash so separate hierarchy hand-offs can appear
    // as separate Android notifications instead of replacing one another.
    var hash = 0x811c9dc5;
    for (final codeUnit in eventKey.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  static Future<void> _showRoleNotification({
    required CreditAgingRequest request,
    required _RoleNotificationContent content,
  }) async {
    final eventKey = _notificationEventKey(request, content.role);
    final notificationId = _notificationId(eventKey);

    // Avoid duplicates for the same request + workflow event. The role alone
    // is not enough because the same role may receive the request again after
    // a later resubmission.
    final alreadyStored = history.any(
      (item) => item.requestId == request.requestId &&
          item.role == content.role &&
          _notificationEventKeyFromStored(item) == eventKey,
    );

    if (alreadyStored) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        newRequestChannelId,
        newRequestChannelName,
        channelDescription: newRequestChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        icon: 'ic_stat_credit_aging',
        styleInformation: const BigTextStyleInformation(''),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      id: notificationId,
      title: content.title,
      body: content.body,
      notificationDetails: details,
      payload: '${request.requestId}',
    );

    final item = StoredNotification(
      id: notificationId,
      title: content.title,
      body: content.body,
      dateTime: DateTime.now(),
      requestId: request.requestId,
      role: content.role,
      eventKey: eventKey,
    );

    final items = history;
    items.insert(0, item);
    final bounded = items.take(maxHistoryItems).map((e) => e.toJson()).toList();
    await _box.write(_historyKey, bounded);
  }

  /// Kept for backwards compatibility with any older call sites; routes the
  /// generic "new request" case through the same role-aware pipeline so a
  /// direct call still respects who's signed in.
  static Future<void> showNewRequest(CreditAgingRequest request) async {
    final role = (AuthService.storedRole ?? '').trim().toUpperCase();
    final email = (AuthService.storedEmail ?? '').trim().toLowerCase();

    final content = _relevantContentFor(
      request: request,
      status: request.status.toUpperCase(),
      role: role,
      email: email,
    );

    if (content == null) return;

    await _showRoleNotification(request: request, content: content);
  }

  static Future<void> clearHistory() async {
    await _box.remove(_historyKey);
  }

  static Future<void> clearAllNotifications() async {
    await _plugin.cancelAll();
    await clearHistory();
  }

  static String exportHistory() {
    return jsonEncode(history.map((e) => e.toJson()).toList());
  }
}
