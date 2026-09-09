// Data models used across the app.

class CreditAgingRequest {
  final int requestId;
  final String requestNo;
  final String customerCode;
  final String requestType;
  final String status;

  final double snapCreditLimit;
  final double snapUsedCredit;
  final double snapAvailableCredit;
  final int snapAllowedAgingDays;
  final int snapMaxAgingDays;
  final double snapOverdueAmount;

  final double requestedAmount;
  final int? requestedAgingDays;
  final String? requestReason;
  final String priority;

  final double? l1ReviewedAmount;
  final int? l1ReviewedAgingDays;
  final String? l1Action;
  final String? l1Remarks;

  final double? l2ApprovedAmount;
  final int? l2ApprovedAgingDays;
  final String? l2Action;
  final String? l2Remarks;

  final double? l3ApprovedAmount;
  final int? l3ApprovedAgingDays;
  final String? l3Action;
  final String? l3Remarks;

  final double? finalApprovedAmount;
  final int? finalApprovedAgingDays;

  final String? effectiveFromDate;
  final String? effectiveToDate;

  final String? requestedBy;
  final String? requestedDate;
  final String? lastUpdatedBy;
  final String? lastUpdatedDate;

  final String isApplied;
  final String? subCustomer;
  final String? region;
  final String? salesPerson;
  final String? channel;

  // Dynamic hierarchy info, joined in by the backend (v_credit_aging_pending)
  // so the app never has to hardcode role/level names anywhere. All are
  // null/false when the backend hasn't sent them (e.g. an older API
  // response), which keeps this backward compatible.
  final int? pendingLevelNo;
  final String? pendingLevelName; // e.g. "Manager", "Senior Manager", "CFO"
  final String? pendingApproverRole; // e.g. "FINANCE_MANAGER"
  final bool isFinalLevel;
  final String? nextLevelName;

  const CreditAgingRequest({
    required this.requestId,
    required this.requestNo,
    required this.customerCode,
    required this.requestType,
    required this.status,
    required this.snapCreditLimit,
    required this.snapUsedCredit,
    required this.snapAvailableCredit,
    required this.snapAllowedAgingDays,
    required this.snapMaxAgingDays,
    required this.snapOverdueAmount,
    required this.requestedAmount,
    required this.requestedAgingDays,
    required this.requestReason,
    required this.priority,
    required this.l1ReviewedAmount,
    required this.l1ReviewedAgingDays,
    required this.l1Action,
    required this.l1Remarks,
    required this.l2ApprovedAmount,
    required this.l2ApprovedAgingDays,
    required this.l2Action,
    required this.l2Remarks,
    required this.l3ApprovedAmount,
    required this.l3ApprovedAgingDays,
    required this.l3Action,
    required this.l3Remarks,
    required this.finalApprovedAmount,
    required this.finalApprovedAgingDays,
    required this.effectiveFromDate,
    required this.effectiveToDate,
    required this.requestedBy,
    required this.requestedDate,
    required this.lastUpdatedBy,
    required this.lastUpdatedDate,
    required this.isApplied,
    required this.subCustomer,
    required this.region,
    required this.salesPerson,
    required this.channel,
    this.pendingLevelNo,
    this.pendingLevelName,
    this.pendingApproverRole,
    this.isFinalLevel = false,
    this.nextLevelName,
  });

  factory CreditAgingRequest.fromJson(Map<String, dynamic> json) {
    return CreditAgingRequest(
      requestId: _toInt(json['request_id']) ?? 0,
      requestNo: _toString(json['request_no']) ?? '',
      customerCode: _toString(json['customer_code']) ?? '',
      requestType: _toString(json['request_type']) ?? '',
      status: _toString(json['status']) ?? '',
      snapCreditLimit: _toDouble(json['snap_credit_limit']) ?? 0,
      snapUsedCredit: _toDouble(json['snap_used_credit']) ?? 0,
      snapAvailableCredit: _toDouble(json['snap_available_credit']) ?? 0,
      snapAllowedAgingDays:
          _toInt(json['snap_allowed_aging_days']) ?? 0,
      snapMaxAgingDays: _toInt(json['snap_max_aging_days']) ?? 0,
      snapOverdueAmount: _toDouble(json['snap_overdue_amount']) ?? 0,
      requestedAmount: _toDouble(json['requested_amount']) ?? 0,
      requestedAgingDays: _toInt(json['requested_aging_days']),
      requestReason: _toString(json['request_reason']),
      priority: _toString(json['priority']) ?? '',
      l1ReviewedAmount: _toDouble(json['l1_reviewed_amount']),
      l1ReviewedAgingDays: _toInt(json['l1_reviewed_aging_days']),
      l1Action: _toString(json['l1_action']),
      l1Remarks: _toString(json['l1_remarks']),
      l2ApprovedAmount: _toDouble(json['l2_approved_amount']),
      l2ApprovedAgingDays: _toInt(json['l2_approved_aging_days']),
      l2Action: _toString(json['l2_action']),
      l2Remarks: _toString(json['l2_remarks']),
      l3ApprovedAmount: _toDouble(json['l3_approved_amount']),
      l3ApprovedAgingDays: _toInt(json['l3_approved_aging_days']),
      l3Action: _toString(json['l3_action']),
      l3Remarks: _toString(json['l3_remarks']),
      finalApprovedAmount: _toDouble(json['final_approved_amount']),
      finalApprovedAgingDays: _toInt(json['final_approved_aging_days']),
      effectiveFromDate: _toString(json['effective_from_date']),
      effectiveToDate: _toString(json['effective_to_date']),
      requestedBy: _toString(json['requested_by']),
      requestedDate: _toString(json['requested_date']),
      lastUpdatedBy: _toString(json['last_updated_by']),
      lastUpdatedDate: _toString(json['last_updated_date']),
      isApplied: _toString(json['is_applied']) ?? 'N',
      subCustomer: _toString(json['sub_customer']),
      region: _toString(json['region']),
      salesPerson: _toString(json['sales_person']),
      channel: _toString(json['channel']),
      pendingLevelNo: _toInt(json['pending_level_no']),
      pendingLevelName: _toString(json['pending_level_name']),
      pendingApproverRole: _toString(json['pending_approver_role']),
      isFinalLevel:
          (_toString(json['is_final_level']) ?? 'N').toUpperCase() == 'Y',
      nextLevelName: _toString(json['next_level_name']),
    );
  }

  /// True if [role] is exactly the role whose turn it is right now,
  /// according to the backend's hierarchy view. This is the ONLY thing
  /// that should decide whether the signed-in user can act on a request -
  /// it comes straight from the API, so the app never hardcodes
  /// department names, role names, or level counts anywhere.
  bool isPendingFor(String? role) {
    if (role == null || pendingApproverRole == null) return false;
    return pendingApproverRole!.toUpperCase() == role.toUpperCase();
  }

  bool get canTakeL2Action {
    final normalizedStatus = status.toUpperCase();
    return l2Action == null &&
        normalizedStatus != 'APPROVED' &&
        normalizedStatus != 'REJECTED' &&
        isApplied.toUpperCase() != 'Y';
  }

  static String? _toString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class Customer {
  final String code;
  final String name;
  final String? address;
  final double? creditLimit;
  final int? creditDays;

  const Customer({
    required this.code,
    required this.name,
    this.address,
    this.creditLimit,
    this.creditDays,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      code: _string(json['acode']) ?? '',
      name: _string(json['aname']) ?? 'Unknown Customer',
      address: _string(json['address']),
      creditLimit: _double(json['limit']),
      creditDays: _int(json['crdays']),
    );
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _int(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _double(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

