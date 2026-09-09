// Handles login against the Oracle APEX / ORDS login API and persists the
// signed-in session (role + email + designation) locally using GetStorage.
//
// Storage contract:
//   - box.read('role')  -> null/empty  => nobody is logged in
//   - box.read('role')  -> 'FINANCE_MANAGER' / 'FINANCE_CFO' / ... => logged in
//   - box.read('designation') -> human-readable level name for that role
//     (e.g. "Manager", "Senior Manager", "CFO"), looked up server-side from
//     approval_hierarchy_levels. May be null if the role isn't part of a
//     configured hierarchy - the app falls back to showing the raw role.
//
// The rest of the app (AuthGate in main.dart) only ever needs to check
// whether 'role' is null to decide whether to show the login screen or the
// home screen, and clearing it on logout sends the user straight back.
import 'dart:convert';

import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

class LoginResult {
  final bool success;
  final String message;
  final String? role;
  final String? designation;
  final String? email;

  const LoginResult({
    required this.success,
    required this.message,
    this.role,
    this.designation,
    this.email,
  });
}

class AuthService {
  // Real ORDS host, confirmed working throughout this project.
  static const String _loginUrl =
      'http://tapex.mezangrp.com/ords/hrms/creditaginglogin/auth';

  static const String _keyRole = 'role';
  static const String _keyEmail = 'email';
  static const String _keyDesignation = 'designation';

  final http.Client _client;
  final GetStorage _box = GetStorage();

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(_loginUrl).replace(
      queryParameters: {
        'email': email.trim(),
        'password': password,
      },
    );

    late final http.Response response;

    try {
      response = await _client.post(uri).timeout(const Duration(seconds: 20));
    } catch (_) {
      return const LoginResult(
        success: false,
        message: 'Could not reach the server. Check your connection.',
      );
    }

    Map<String, dynamic>? decoded;
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        decoded = Map<String, dynamic>.from(body);
      }
    } catch (_) {
      decoded = null;
    }

    final result = (decoded?['result'] ?? '').toString().toUpperCase();
    final role = (decoded?['role'] ?? '').toString().trim();
    final designation = (decoded?['designation'] ?? '').toString().trim();

    if (response.statusCode == 200 && result == 'SUCCESS') {
      await _persistSession(
        email: email.trim(),
        role: role,
        designation: designation,
      );
      return LoginResult(
        success: true,
        message: 'Logged in successfully.',
        role: role,
        designation: designation.isEmpty ? null : designation,
        email: email.trim(),
      );
    }

    return const LoginResult(
      success: false,
      message: 'Invalid email or password.',
    );
  }

  Future<void> _persistSession({
    required String email,
    required String role,
    required String designation,
  }) async {
    await _box.write(_keyRole, role);
    await _box.write(_keyEmail, email);
    await _box.write(_keyDesignation, designation);
  }

  /// Returns the stored role, or null if nobody is logged in.
  static String? get storedRole {
    final value = GetStorage().read(_keyRole);
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String? get storedEmail {
    final value = GetStorage().read(_keyEmail);
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// Human-readable level name for the signed-in role (e.g. "Senior
  /// Manager"), or null if the backend didn't have one for this role.
  static String? get storedDesignation {
    final value = GetStorage().read(_keyDesignation);
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static bool get isLoggedIn => storedRole != null;

  /// Clears the session. After this, [storedRole] is null again, which is
  /// exactly what AuthGate watches for to send the user back to the login
  /// screen.
  static Future<void> logout() async {
    final box = GetStorage();
    await box.remove(_keyRole);
    await box.remove(_keyEmail);
    await box.remove(_keyDesignation);
  }

  void dispose() {
    _client.close();
  }
}
