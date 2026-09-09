// Handles all credit-aging related REST calls (list, customer lookup,
// status update). The update-status call goes through the backend's
// credit_aging_workflow_pkg, which enforces the approval hierarchy in
// order server-side - this service just passes through who is acting,
// what they're doing, and when.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class ApiService {
  static const String creditAgingUrl =
      'http://tapex.mezangrp.com/ords/hrms/credit-aging/list';

  static const String customerBaseUrl =
      'http://tapex.mezangrp.com/ords/hrms/master/customers/';

  static const String updateStatusUrl =
      'http://tapex.mezangrp.com/ords/hrms/credit-aging/update-status/';

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<CreditAgingRequest>> getCreditAgingRequests() async {
    final response = await _client
        .get(Uri.parse(creditAgingUrl))
        .timeout(const Duration(seconds: 30));

    _checkResponse(response);

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid credit-aging API response.');
    }

    final items = decoded['items'];

    if (items is! List) {
      return <CreditAgingRequest>[];
    }

    return items
        .whereType<Map>()
        .map(
          (item) => CreditAgingRequest.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<Customer?> getCustomer(String customerCode) async {
    final response = await _client
        .get(
          Uri.parse(
            '$customerBaseUrl${Uri.encodeComponent(customerCode)}',
          ),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 404) {
      return null;
    }

    _checkResponse(response);

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      return null;
    }

    final json = Map<String, dynamic>.from(decoded);

    // Supports both a direct customer object and a possible ORDS-style
    // { "items": [ ... ] } response.
    if (json['items'] is List && (json['items'] as List).isNotEmpty) {
      final first = (json['items'] as List).first;
      if (first is Map) {
        return Customer.fromJson(Map<String, dynamic>.from(first));
      }
    }

    return Customer.fromJson(json);
  }

  /// Acts on a request's current pending approval step.
  ///
  /// [actorEmail] / [actorRole] identify who is acting - the backend
  /// rejects the call if [actorRole] doesn't match the role assigned to
  /// the request's current pending level (and also re-verifies the role
  /// against the login table server-side), which is what actually
  /// enforces "follow the hierarchy in order".
  ///
  /// [action] is 'APPROVE' or 'REJECT'. The backend decides what status
  /// results - APPROVED if this was the last level, UNDER_REVIEW if
  /// there's another level after this one, REJECTED either way on reject -
  /// so nothing about level counts is hardcoded here. Returns the new
  /// status as reported by the server.
  ///
  /// The current date/time is always sent as `acted_on` (ISO 8601, no
  /// timezone suffix) so the backend records exactly when the app-side
  /// action happened.
  Future<String> updateStatus({
    required int requestId,
    required String actorEmail,
    required String actorRole,
    required String action, // 'APPROVE' or 'REJECT'
    double? approvedAmount,
    int? approvedAgingDays,
    String? remarks,
    DateTime? actedOn,
  }) async {
    final timestamp = _formatTimestamp(actedOn ?? DateTime.now());

    // The live API expects the *target* status ('APPROVED' / 'REJECTED'),
    // not the verb ('APPROVE' / 'REJECT') the rest of the app uses.
    final targetStatus = action.toUpperCase() == 'APPROVE'
        ? 'APPROVED'
        : 'REJECTED';

    // The live API expects a standard x-www-form-urlencoded POST body,
    // not query parameters on the URL.
    final body = <String, String>{
      'request_id': requestId.toString(),
      'actor_email': actorEmail,
      'actor_role': actorRole,
      'status': targetStatus,
      'acted_on': timestamp,
      if (approvedAmount != null) 'amount': approvedAmount.toString(),
      if (approvedAgingDays != null) 'days': approvedAgingDays.toString(),
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    };

    final response = await _client
        .post(
          Uri.parse(updateStatusUrl),
          headers: const {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    _checkResponse(response);

    final decoded = jsonDecode(response.body);
    if (decoded is Map) {
      final success = decoded['success'];
      final newStatus = decoded['new_status'];

      if (success == false) {
        throw Exception(
          (decoded['message'] ?? 'The request could not be updated.')
              .toString(),
        );
      }

      if (newStatus != null) {
        return newStatus.toString();
      }
    }

    throw Exception('Unexpected response from update-status.');
  }

  /// Formats as 'YYYY-MM-DDTHH:MM:SS', matching the
  /// TO_TIMESTAMP(:acted_on, 'YYYY-MM-DD"T"HH24:MI:SS') the ORDS handler
  /// expects.
  String _formatTimestamp(DateTime dateTime) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)}'
        'T${two(dateTime.hour)}:${two(dateTime.minute)}:${two(dateTime.second)}';
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Request failed (${response.statusCode}).';

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          message = (decoded['message'] ??
                  decoded['error'] ??
                  decoded['detail'] ??
                  message)
              .toString();
        }
      } catch (_) {
        if (response.body.trim().isNotEmpty) {
          message = response.body.trim();
        }
      }

      throw Exception(message);
    }
  }

  void dispose() {
    _client.close();
  }
}
