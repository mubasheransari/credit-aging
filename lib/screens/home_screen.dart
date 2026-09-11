
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/background_monitor_service.dart';
import '../services/notification_service.dart';
import 'notification_list_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ApiService _api = ApiService();
  final String? _role = AuthService.storedRole;
  final String? _email = AuthService.storedEmail;

  final Map<String, Customer?> _customerCache = {};
  final TextEditingController _searchController = TextEditingController();

  List<CreditAgingRequest> _requests = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _filter = 'ALL';

  Timer? _dynamicPollTimer;
  bool _polling = false;
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationCount = NotificationService.history.length;
    setAppInForeground(true);
    _loadRequests(initialLoad: true);
    _dynamicPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollRequests(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setAppInForeground(true);
      _pollRequests();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      setAppInForeground(false);
    }
  }

  @override
  void dispose() {
    _dynamicPollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    setAppInForeground(false);
    _api.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _roleLabel {
    final designation = AuthService.storedDesignation;
    if (designation != null && designation.isNotEmpty) return designation;
    return prettyStatus(_role ?? 'User');
  }

  List<CreditAgingRequest> get _visibleRequests {
    return _requests.where((r) {
      final status = r.status.toUpperCase();

      // Draft and the internal COO stage are never shown in this app.
      if (status == 'COO_REVIEW' || status == 'DRAFT') return false;

      // Final states are visible to everyone as a record, regardless of
      // which level acted on them.
      if (status == 'APPROVED' || status == 'REJECTED') return true;

      // Otherwise, a request is only visible if it's this signed-in
      // user's turn to act on it right now, according to the backend's
      // hierarchy view (pending_approver_role). This is fully dynamic -
      // it works the same whether Finance has 2 levels or 7, and never
      // hardcodes a role or department name.
      return r.isPendingFor(_role);
    }).toList();
  }

  List<CreditAgingRequest> get _filteredRequests {
    final query = _searchQuery.trim().toLowerCase();

    return _visibleRequests.where((r) {
      final matchesFilter = switch (_filter) {
        'ACTION' => _canAct(r),
        'APPROVED' => r.status.toUpperCase() == 'APPROVED',
        'REJECTED' => r.status.toUpperCase() == 'REJECTED',
        _ => true,
      };

      if (!matchesFilter) return false;
      if (query.isEmpty) return true;

      final customer =
          (_customerCache[r.customerCode]?.name ?? r.subCustomer ?? '')
              .toLowerCase();

      return customer.contains(query) ||
          r.requestNo.toLowerCase().contains(query) ||
          r.customerCode.toLowerCase().contains(query);
    }).toList();
  }

  /// Whether the signed-in role can act (Approve/Reject) on this request
  /// right now - purely a function of whose turn it is according to the
  /// backend's hierarchy data. No role/department names hardcoded here.
  bool _canAct(CreditAgingRequest request) => request.isPendingFor(_role);

  int _count(String status) => _visibleRequests
      .where((r) => r.status.toUpperCase() == status)
      .length;

  int get _actionCount => _visibleRequests.where(_canAct).length;

  Future<void> _loadRequests({bool initialLoad = false}) async {
    if (_polling) return;
    _polling = true;

    if (mounted && initialLoad) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final requests = await _api.getCreditAgingRequests();
      final codes = requests
          .map((e) => e.customerCode)
          .where((e) => e.isNotEmpty)
          .toSet();

      await Future.wait(
        codes.map((code) async {
          if (_customerCache.containsKey(code)) return;
          try {
            _customerCache[code] = await _api.getCustomer(code);
          } catch (_) {
            _customerCache[code] = null;
          }
        }),
      );

      await NotificationService.syncRequests(requests);

      if (!mounted) return;
      setState(() {
        _requests = requests;
        _isLoading = false;
        _error = null;
        _notificationCount = NotificationService.history.length;
      });
    } catch (e) {
      if (!mounted) return;
      if (initialLoad || _requests.isEmpty) {
        setState(() {
          _error = _cleanError(e);
          _isLoading = false;
        });
      }
      // Background polling failures are intentionally silent so the current
      // list remains usable while the server/network is temporarily down.
    } finally {
      _polling = false;
    }
  }

  Future<void> _pollRequests() async {
    if (!mounted) return;
    await _loadRequests();
  }

  Future<bool> _approve(CreditAgingRequest request) {
    final isFinal = request.isFinalLevel;
    final nextName = request.nextLevelName ?? 'Next Level';

    return _showApprovalDialog(
      request,
      title: isFinal ? 'Approve request' : 'Approve & send to $nextName',
      submitLabel: isFinal ? 'Approve' : 'Send to $nextName',
      submitIcon: isFinal ? Icons.check_rounded : Icons.arrow_forward_rounded,
      requireRemarks: false,
    );
  }

  Future<bool> _approveWithRemarks(CreditAgingRequest request) {
    final isFinal = request.isFinalLevel;
    final nextName = request.nextLevelName ?? 'Next Level';

    return _showApprovalDialog(
      request,
      title: 'Approve with remarks',
      submitLabel: isFinal ? 'Approve' : 'Send to $nextName',
      submitIcon: isFinal ? Icons.check_rounded : Icons.arrow_forward_rounded,
      requireRemarks: true,
    );
  }

  Future<bool> _showApprovalDialog(
    CreditAgingRequest request, {
    required String title,
    required String submitLabel,
    required IconData submitIcon,
    required bool requireRemarks,
  }) async {
    final result = await showDialog<_ApprovalData>(
      context: context,
      builder: (_) => _ApprovalDialog(
        request: request,
        title: title,
        submitLabel: submitLabel,
        submitIcon: submitIcon,
        requireRemarks: requireRemarks,
      ),
    );

    if (result == null || !mounted) return false;

    return _submitAction(
      request: request,
      action: 'APPROVE',
      amount: result.amount,
      days: result.days,
      remarks: result.remarks,
    );
  }

  Future<bool> _reject(CreditAgingRequest request) async {
    final remarks = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );

    if (remarks == null || !mounted) return false;

    return _submitAction(
      request: request,
      action: 'REJECT',
      remarks: remarks,
    );
  }

  Future<bool> _submitAction({
    required CreditAgingRequest request,
    required String action, // 'APPROVE' or 'REJECT'
    double? amount,
    int? days,
    String? remarks,
  }) async {
    _showLoading(action == 'REJECT' ? 'Rejecting request…' : 'Submitting…');

    try {
      // The backend decides the resulting status (APPROVED, UNDER_REVIEW,
      // or REJECTED) based on the hierarchy it already knows about - the
      // app never computes this itself, so it stays correct no matter how
      // many levels exist.
      final newStatus = await _api.updateStatus(
        requestId: request.requestId,
        actorEmail: AuthService.storedEmail ?? '',
        actorRole: _role ?? '',
        action: action,
        approvedAmount: amount,
        approvedAgingDays: days,
        remarks: remarks,
      );

      if (!mounted) return true;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSnack(
        switch (newStatus) {
          'APPROVED' => 'Approved. ${request.requestNo} is fully approved.',
          'UNDER_REVIEW' => request.nextLevelName != null
              ? 'Approved. ${request.requestNo} forwarded to ${request.nextLevelName}.'
              : 'Approved. ${request.requestNo} sent for further review.',
          'REJECTED' => '${request.requestNo} rejected.',
          _ => '${request.requestNo} updated.',
        },
        error: newStatus == 'REJECTED',
      );

      await _pollRequests();
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSnack(_cleanError(e), error: true);
      return false;
    }
  }

  void _showLoading(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 30),
          behavior: SnackBarBehavior.floating,
          backgroundColor: kInk,
          margin: const EdgeInsets.all(18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: Row(
            children: [
              const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                message,
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? kRed : kInk,
        margin: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Text(
          message,
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _AppDialogShell(
        icon: Icons.logout_rounded,
        iconColor: kRed,
        title: 'Log out?',
        message: 'You will need to sign in again to access this workspace.',
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: kRed),
              child: const Text('Log out'),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await stopBackgroundMonitoring();
    await AuthService.logout();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _openDetails(CreditAgingRequest request) {
    final customer = _customerCache[request.customerCode];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RequestDetailScreen(
          request: request,
          customer: customer,
          role: _role,
          onApprove: _canAct(request) ? () => _approve(request) : null,
          onReject: _canAct(request) ? () => _reject(request) : null,
          onApproveWithRemarks:
              _canAct(request) ? () => _approveWithRemarks(request) : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildToolbar()),
            SliverToBoxAdapter(child: _buildStats()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              sliver: SliverToBoxAdapter(child: _buildRequestArea()),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildHeader() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(0, 18, 20, 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 10,),
        // Logo - LEFT
        SizedBox(
          width: 82,
          height: 72,
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.contain,
          ),
        ),

        // Push notification + account to the RIGHT
        const Spacer(),

        // Notification
        _HeaderNotificationButton(
          count: _notificationCount,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationListScreen(),
              ),
            );

            if (!mounted) return;

            setState(() {
              _notificationCount =
                  NotificationService.history.length;
            });
          },
        ),

        const SizedBox(width: 8),

        // Account
        PopupMenuButton<String>(
          tooltip: 'Account',
          onSelected: (value) {
            if (value == 'logout') {
              _confirmLogout();
            }
          },
          color: kSurface,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          itemBuilder: (_) => [
            PopupMenuItem<String>(
              enabled: false,
              child: SizedBox(
                width: 190,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _roleLabel,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((_email ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        _email!,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: kMutedInk,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const PopupMenuDivider(),

            PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  const Icon(
                    Icons.logout_rounded,
                    color: kRed,
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Log out',
                    style: GoogleFonts.manrope(
                      color: kRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kInk,
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Text(
              (_role ?? 'U').substring(0, 1).toUpperCase(),
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  // Widget _buildHeader() {
  //   return Padding(
  //     padding: const EdgeInsets.fromLTRB(0, 18, 20, 4),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.center,
  //       children: [
  //              Expanded(
  //                child: Container(
  //                          width: 54,
  //                          height: 54,
  //                          // decoration: BoxDecoration(
  //                          //   color: inverted ? Colors.white : kInk,
  //                          //   borderRadius: BorderRadius.circular(11),
  //                          // ),
  //                          child: Image.asset("assets/logo.png"),
  //                          // child: Icon(
  //                          //   Icons.show_chart_rounded,
  //                          //   color: inverted ? kInk : Colors.white,
  //                          //   size: 19,
  //                          // ),
  //                        ),
  //              ),
  //         //const _LogoMark(),
  //         // const SizedBox(width: 12),
  //         // Expanded(
  //         //   child: Column(
  //         //     crossAxisAlignment: CrossAxisAlignment.start,
  //         //     children: [
  //         //       Text(
  //         //         'MEZAN',
  //         //         style: GoogleFonts.manrope(
  //         //           fontSize: 11,
  //         //           letterSpacing: 2.1,
  //         //           fontWeight: FontWeight.w800,
  //         //         ),
  //         //       ),
  //         //       Text(
  //         //         'Credit aging',
  //         //         style: GoogleFonts.manrope(
  //         //           fontSize: 12,
  //         //           color: kMutedInk,
  //         //           fontWeight: FontWeight.w600,
  //         //         ),
  //         //       ),
  //         //     ],
  //         //   ),
  //         // ),
  //         // 
  //         _HeaderNotificationButton(
  //           count: _notificationCount,
  //           onTap: () async {
  //             await Navigator.of(context).push(
  //               MaterialPageRoute(
  //                 builder: (_) => const NotificationListScreen(),
  //               ),
  //             );
  //             if (!mounted) return;
  //             setState(() {
  //               _notificationCount = NotificationService.history.length;
  //             });
  //           },
  //         ),
  //         const SizedBox(width: 8),
  //         PopupMenuButton<String>(
  //           tooltip: 'Account',
  //           onSelected: (value) {
  //             if (value == 'logout') _confirmLogout();
  //           },
  //           color: kSurface,
  //           elevation: 8,
  //           shape:
  //               RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  //           itemBuilder: (_) => [
  //             PopupMenuItem<String>(
  //               enabled: false,
  //               child: SizedBox(
  //                 width: 190,
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       _roleLabel,
  //                       style: GoogleFonts.manrope(
  //                         fontWeight: FontWeight.w800,
  //                       ),
  //                     ),
  //                     if ((_email ?? '').isNotEmpty) ...[
  //                       const SizedBox(height: 3),
  //                       Text(
  //                         _email!,
  //                         overflow: TextOverflow.ellipsis,
  //                         style: GoogleFonts.manrope(
  //                           fontSize: 11,
  //                           color: kMutedInk,
  //                           fontWeight: FontWeight.w500,
  //                         ),
  //                       ),
  //                     ],
  //                   ],
  //                 ),
  //               ),
  //             ),
  //             const PopupMenuDivider(),
  //             PopupMenuItem<String>(
  //               value: 'logout',
  //               child: Row(
  //                 children: [
  //                   const Icon(Icons.logout_rounded, color: kRed, size: 19),
  //                   const SizedBox(width: 10),
  //                   Text(
  //                     'Log out',
  //                     style: GoogleFonts.manrope(
  //                       color: kRed,
  //                       fontWeight: FontWeight.w700,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ],
  //           child: Container(
  //             width: 42,
  //             height: 42,
  //             decoration: BoxDecoration(
  //               color: kInk,
  //               borderRadius: BorderRadius.circular(13),
  //             ),
  //             alignment: Alignment.center,
  //             child: Text(
  //               (_role ?? 'U').substring(0, 1).toUpperCase(),
  //               style: GoogleFonts.manrope(
  //                 color: Colors.white,
  //                 fontWeight: FontWeight.w800,
  //               ),
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;

          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning.',
                style: GoogleFonts.manrope(
                  color: kMutedInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Requests & decisions',
                style: GoogleFonts.manrope(
                  fontSize: compact ? 30 : 36,
                  height: 1.05,
                  letterSpacing: -1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Review and move credit aging requests through the workflow.',
                style: GoogleFonts.manrope(
                  color: kMutedInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );

          final search = SizedBox(
            width: compact ? double.infinity : 310,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search request or customer',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 19),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
              ),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 22),
                search,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: title),
              search,
            ],
          );
        },
      ),
    );
  }

  Widget _buildStats() {
    final tabs = [
      ('ALL', 'All', _visibleRequests.length),
      ('ACTION', 'Action needed', _actionCount),
      ('APPROVED', 'Approved', _count('APPROVED')),
      ('REJECTED', 'Rejected', _count('REJECTED')),
    ];

    return SizedBox(
      height: 74,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (_, index) {
          final item = tabs[index];
          return _FilterPill(
            label: item.$2,
            count: item.$3,
            selected: _filter == item.$1,
            onTap: () => setState(() => _filter = item.$1),
          );
        },
      ),
    );
  }

  Widget _buildRequestArea() {
    if (_isLoading && _requests.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 70),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _requests.isEmpty) {
      return _ErrorState(
        message: _error!,
        onRetry: () => _loadRequests(initialLoad: true),
      );
    }

    final items = _filteredRequests;

    if (items.isEmpty) {
      return _EmptyState(
        filtered: _searchQuery.isNotEmpty || _filter != 'ALL',
        onClear: () {
          _searchController.clear();
          setState(() {
            _searchQuery = '';
            _filter = 'ALL';
          });
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${items.length.toString().padLeft(2, '0')} requests',
              style: GoogleFonts.manrope(
                color: kMutedInk,
                fontSize: 11,
                letterSpacing: .5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            _LiveUpdateIndicator(isUpdating: _polling),
          ],
        ),
        const SizedBox(height: 10),
        ...items.map(
          (request) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RequestCard(
              request: request,
              customer: _customerCache[request.customerCode],
              canAct: _canAct(request),
              onTap: () => _openDetails(request),
              onApprove: () => _approve(request),
              onReject: () => _reject(request),
            ),
          ),
        ),
      ],
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: kInk,
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Icon(
        Icons.show_chart_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}

class _HeaderNotificationButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _HeaderNotificationButton({
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Notifications',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: kLine),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 21,
                color: kInk,
              ),
            ),
            if (count > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: kRed,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: kPageBg, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveUpdateIndicator extends StatelessWidget {
  final bool isUpdating;

  const _LiveUpdateIndicator({required this.isUpdating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: isUpdating ? kOrange : kGreen,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isUpdating ? 'Checking' : 'Live',
          style: GoogleFonts.manrope(
            color: kMutedInk,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kInk : kSurface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? kInk : kLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                color: selected ? Colors.white : kInk,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withOpacity(.13) : kSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.manrope(
                  color: selected ? Colors.white : kMutedInk,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final CreditAgingRequest request;
  final Customer? customer;
  final bool canAct;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCard({
    required this.request,
    required this.customer,
    required this.canAct,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        customer?.name ?? request.subCustomer ?? 'Customer ${request.customerCode}';

    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: kLine),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 650;

              final main = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StatusChip(status: request.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${request.requestNo}  ·  ${request.customerCode}',
                    style: GoogleFonts.manrope(
                      color: kMutedInk,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _CardMetric(
                        label: 'Requested',
                        value: _money(request.requestedAmount),
                      ),
                      const SizedBox(width: 30),
                      _CardMetric(
                        label: 'Priority',
                        value: request.priority == null
                            ? '—'
                            : '${request.priority}',
                      ),
                      // if (!compact) ...[
                      //   const SizedBox(width: 30),
                      //   _CardMetric(
                      //     label: 'Priority',
                      //     value: request.priority.isEmpty
                      //         ? 'Normal'
                      //         : request.priority,
                      //   ),
                      // ],
                    ],
                  ),
                ],
              );

              final actions = canAct
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          onPressed: onReject,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kRed,
                            side: const BorderSide(color: kRedSoft),
                            backgroundColor: kRedSoft.withOpacity(.45),
                            minimumSize: const Size(0, 42),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          child: const Text('Reject'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: onApprove,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                request.status.toUpperCase() == 'SUBMITTED'
                                    ? 'Review'
                                    : 'Approve',
                              ),
                              const SizedBox(width: 7),
                              const Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ),
                        ),
                      ],
                    )
                  : _Arrow();

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    main,
                    const SizedBox(height: 15),
                    actions,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: main),
                  const SizedBox(width: 20),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CardMetric extends StatelessWidget {
  final String label;
  final String value;

  const _CardMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.manrope(
            color: kMutedInk,
            fontSize: 9,
            letterSpacing: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: kSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.arrow_outward_rounded, size: 18),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toUpperCase();
    final bg = switch (s) {
      'APPROVED' => kGreenSoft,
      'REJECTED' => kRedSoft,
      'UNDER_REVIEW' => kOrangeSoft,
      'SUBMITTED' => kBlueSoft,
      _ => kSoft,
    };
    final fg = switch (s) {
      'APPROVED' => kGreen,
      'REJECTED' => kRed,
      'UNDER_REVIEW' => kOrange,
      'SUBMITTED' => kBlue,
      _ => kMutedInk,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
      child: Text(
        prettyStatus(status),
        style: GoogleFonts.manrope(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: softCardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 30, color: kRed),
          const SizedBox(height: 12),
          Text(
            'Could not load requests',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(color: kMutedInk, fontSize: 12),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool filtered;
  final VoidCallback onClear;

  const _EmptyState({required this.filtered, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 24),
      decoration: softCardDecoration(),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: kSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.inbox_outlined, color: kMutedInk),
          ),
          const SizedBox(height: 16),
          Text(
            filtered ? 'Nothing matches' : 'No requests yet',
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            filtered
                ? 'Try another search or filter.'
                : 'Credit aging requests will appear here.',
            style: GoogleFonts.manrope(
              color: kMutedInk,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (filtered) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onClear, child: const Text('Clear filters')),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Detail
// -----------------------------------------------------------------------------

class RequestDetailScreen extends StatefulWidget {
  final CreditAgingRequest request;
  final Customer? customer;
  final String? role;
  final Future<bool> Function()? onApprove;
  final Future<bool> Function()? onReject;
  final Future<bool> Function()? onApproveWithRemarks;

  const RequestDetailScreen({
    super.key,
    required this.request,
    required this.customer,
    required this.role,
    this.onApprove,
    this.onReject,
    this.onApproveWithRemarks,
  });

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  bool _busy = false;

  String get _name =>
      widget.customer?.name ??
      widget.request.subCustomer ??
      'Customer ${widget.request.customerCode}';

  Future<void> _run(Future<bool> Function()? action) async {
    if (action == null || _busy) return;
    setState(() => _busy = true);
    final success = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (success) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasActions = widget.onApprove != null ||
        widget.onReject != null ||
        widget.onApproveWithRemarks != null;

    return Scaffold(
      backgroundColor: kPageBg,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
                  sliver: SliverToBoxAdapter(
                    child: _buildContent(hasActions),
                  ),
                ),
              ],
            ),
            if (hasActions) _buildActionBar(),
            if (_busy)
              Positioned.fill(
                child: Container(
                  color: kPageBg.withOpacity(.72),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 18, 18),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${widget.request.requestNo}  ·  ${widget.request.customerCode}',
                  style: GoogleFonts.manrope(
                    color: kMutedInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatusChip(status: widget.request.status),
        ],
      ),
    );
  }

  Widget _buildContent(bool hasActions) {
    final r = widget.request;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailHero(request: r),
        const SizedBox(height: 12),
        _DetailSection(
          title: 'Credit position',
          icon: Icons.account_balance_wallet_outlined,
          child: _MetricGrid(
            items: [
              ('Credit limit', _money(r.snapCreditLimit)),
              ('Used credit', _money(r.snapUsedCredit)),
              ('Available', _money(r.snapAvailableCredit)),
              ('Overdue', _money(r.snapOverdueAmount)),
              ('Allowed aging', '${r.snapAllowedAgingDays} days'),
              ('Maximum aging', '${r.snapMaxAgingDays} days'),
            ],
          ),
        ),
        if (_hasSalesData(r)) ...[
          const SizedBox(height: 12),
          _DetailSection(
            title: 'Customer & sales',
            icon: Icons.storefront_outlined,
            child: _MetricGrid(
              items: [
                if ((r.subCustomer ?? '').isNotEmpty)
                  ('Sub customer', r.subCustomer!),
                if ((r.region ?? '').isNotEmpty) ('Region', r.region!),
                if ((r.salesPerson ?? '').isNotEmpty)
                  ('Sales person', r.salesPerson!),
                if ((r.channel ?? '').isNotEmpty) ('Channel', r.channel!),
                if ((widget.customer?.address ?? '').isNotEmpty)
                  ('Address', widget.customer!.address!),
              ],
            ),
          ),
        ],
        if ((r.requestReason ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          _DetailSection(
            title: 'Request reason',
            icon: Icons.subject_rounded,
            child: Text(
              r.requestReason!,
              style: GoogleFonts.manrope(
                color: kMutedInk,
                height: 1.55,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        if (_hasL1(r)) ...[
          const SizedBox(height: 12),
          _ReviewSection(
            title: 'L1 review',
            action: r.l1Action,
            amount: r.l1ReviewedAmount,
            days: r.l1ReviewedAgingDays,
            remarks: r.l1Remarks,
          ),
        ],
        if (_hasL2(r)) ...[
          const SizedBox(height: 12),
          _ReviewSection(
            title: 'L2 review',
            action: r.l2Action,
            amount: r.l2ApprovedAmount,
            days: r.l2ApprovedAgingDays,
            remarks: r.l2Remarks,
          ),
        ],
        if (r.finalApprovedAmount != null ||
            r.finalApprovedAgingDays != null) ...[
          const SizedBox(height: 12),
          _DetailSection(
            title: 'Final approval',
            icon: Icons.verified_outlined,
            child: _MetricGrid(
              items: [
                if (r.finalApprovedAmount != null)
                  ('Amount', _money(r.finalApprovedAmount!)),
                if (r.finalApprovedAgingDays != null)
                  ('Aging', '${r.finalApprovedAgingDays} days'),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _DetailSection(
          title: 'Request information',
          icon: Icons.info_outline_rounded,
          child: _MetricGrid(
            items: [
              ('Type', _pretty(r.requestType)),
              ('Priority', r.priority.isEmpty ? 'Normal' : r.priority),
              if ((r.requestedBy ?? '').isNotEmpty)
                ('Requested by', r.requestedBy!),
              if ((r.requestedDate ?? '').isNotEmpty)
                ('Requested on', r.requestedDate!),
              if ((r.lastUpdatedBy ?? '').isNotEmpty)
                ('Updated by', r.lastUpdatedBy!),
              if ((r.lastUpdatedDate ?? '').isNotEmpty)
                ('Updated on', r.lastUpdatedDate!),
            ],
          ),
        ),
        if (!hasActions) ...[
          const SizedBox(height: 12),
          _DetailSection(
            title: 'Workflow',
            icon: Icons.route_outlined,
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: kMutedInk, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _statusInfoMessage(r),
                    style: GoogleFonts.manrope(
                      color: kMutedInk,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  bool _hasSalesData(CreditAgingRequest r) =>
      (r.subCustomer ?? '').isNotEmpty ||
      (r.region ?? '').isNotEmpty ||
      (r.salesPerson ?? '').isNotEmpty ||
      (r.channel ?? '').isNotEmpty ||
      (widget.customer?.address ?? '').isNotEmpty;

  bool _hasL1(CreditAgingRequest r) =>
      r.l1Action != null ||
      r.l1ReviewedAmount != null ||
      r.l1ReviewedAgingDays != null ||
      (r.l1Remarks ?? '').isNotEmpty;

  bool _hasL2(CreditAgingRequest r) =>
      r.l2Action != null ||
      r.l2ApprovedAmount != null ||
      r.l2ApprovedAgingDays != null ||
      (r.l2Remarks ?? '').isNotEmpty;

  Widget _buildActionBar() {
    final isFinal = widget.request.isFinalLevel;
    final nextName = widget.request.nextLevelName ?? 'Next Level';

    return Positioned(
      left: 16,
      right: 16,
      bottom: 14,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: kSurface.withOpacity(.97),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: kLine),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.10),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              if (widget.onReject != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _run(widget.onReject),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kRed,
                      side: const BorderSide(color: kRed),
                      backgroundColor: kRedSoft.withOpacity(.35),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
                  ),
                ),
              if (widget.onReject != null && widget.onApprove != null)
                const SizedBox(width: 8),
              if (widget.onApprove != null)
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => _run(widget.onApprove),
                    icon: Icon(
                      isFinal
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
                    label: Text(isFinal ? 'Approve' : 'Send to $nextName'),
                  ),
                ),
              if (widget.onApproveWithRemarks != null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  child: OutlinedButton(
                    onPressed: () => _run(widget.onApproveWithRemarks),
                    child: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailHero extends StatelessWidget {
  final CreditAgingRequest request;

  const _DetailHero({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kInk,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REQUESTED AMOUNT',
                  style: GoogleFonts.manrope(
                    color: Colors.white.withOpacity(.48),
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _money(request.requestedAmount),
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 29,
                    letterSpacing: -1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${request.requestedAgingDays ?? '—'} days requested',
                  style: GoogleFonts.manrope(
                    color: Colors.white.withOpacity(.64),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _DetailSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: softCardDecoration(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: kInk),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final List<(String, String)> items;

  const _MetricGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 480
                ? 2
                : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: kPageBg,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          style: GoogleFonts.manrope(
                            color: kMutedInk,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.$2,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ReviewSection extends StatelessWidget {
  final String title;
  final String? action;
  final double? amount;
  final int? days;
  final String? remarks;

  const _ReviewSection({
    required this.title,
    required this.action,
    required this.amount,
    required this.days,
    required this.remarks,
  });

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      title: title,
      icon: Icons.fact_check_outlined,
      child: _MetricGrid(
        items: [
          ('Action', action ?? '—'),
          ('Amount', amount == null ? '—' : _money(amount!)),
          ('Days', days == null ? '—' : '$days days'),
          if ((remarks ?? '').isNotEmpty) ('Remarks', remarks!),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Dialogs
// -----------------------------------------------------------------------------

class _AppDialogShell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final List<Widget> actions;

  const _AppDialogShell({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        padding: const EdgeInsets.all(24),
        decoration: softCardDecoration(
          radius: 25,
          border: false,
          shadow: true,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(.10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: iconColor, size: 21),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              style: GoogleFonts.manrope(
                color: kMutedInk,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 22),
            Row(children: actions),
          ],
        ),
      ),
    );
  }
}

class _ApprovalDialog extends StatefulWidget {
  final CreditAgingRequest request;
  final String title;
  final String submitLabel;
  final IconData submitIcon;
  final bool requireRemarks;

  const _ApprovalDialog({
    required this.request,
    required this.title,
    required this.submitLabel,
    required this.submitIcon,
    required this.requireRemarks,
  });

  @override
  State<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<_ApprovalDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _daysController;
  late final TextEditingController _remarksController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.request.l1ReviewedAmount?.toString() ??
          widget.request.requestedAmount.toStringAsFixed(0),
    );
    _daysController = TextEditingController(
      text: (widget.request.l1ReviewedAgingDays ??
              widget.request.requestedAgingDays ??
              widget.request.snapAllowedAgingDays)
          .toString(),
    );
    _remarksController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _daysController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    final days = int.tryParse(_daysController.text.trim());
    final remarks = _remarksController.text.trim();

    if (amount == null || amount < 0) {
      _showError('Enter a valid approved amount.');
      return;
    }
    if (days == null || days < 0) {
      _showError('Enter valid aging days.');
      return;
    }
    if (widget.requireRemarks && remarks.isEmpty) {
      _showError('Remarks are required.');
      return;
    }

    Navigator.of(context).pop(
      _ApprovalData(
        amount: amount,
        days: days,
        remarks: remarks,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: kRed,
          content: Text(
            message,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Text(
        widget.title,
        style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 19),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 430,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DialogContext(request: widget.request),
              const SizedBox(height: 20),
              Text(
                'Approval values',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: kMutedInk,
                  letterSpacing: .7,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Approved amount',
                  prefixText: 'PKR  ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _daysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Approved aging days',
                  suffixText: 'days',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _remarksController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  hintText: 'Add a note for the next reviewer…',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: Icon(widget.submitIcon, size: 17),
                label: Text(widget.submitLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: kRed,
          content: Text(
            'Please add a rejection reason.',
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      title: Text(
        'Reject request',
        style: GoogleFonts.manrope(fontSize: 19, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 430,
        child: TextField(
          controller: _controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Why is this request being rejected?',
            alignLabelWithHint: true,
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: FilledButton.icon(
                onPressed: _submit,
                style: FilledButton.styleFrom(backgroundColor: kRed),
                icon: const Icon(Icons.close_rounded, size: 17),
                label: const Text('Reject'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DialogContext extends StatelessWidget {
  final CreditAgingRequest request;

  const _DialogContext({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPageBg,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              request.requestNo,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            _money(request.requestedAmount),
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalData {
  final double amount;
  final int days;
  final String remarks;

  const _ApprovalData({
    required this.amount,
    required this.days,
    required this.remarks,
  });
}

String _cleanError(Object error) {
  final text = error.toString();
  if (text.startsWith('Exception: ')) return text.substring(11);
  return text;
}

String _pretty(String value) {
  return prettyStatus(value);
}

String _money(double value) {
  final rounded = value.roundToDouble();
  final text = rounded == value
      ? rounded.toInt().toString()
      : value.toStringAsFixed(2);
  final parts = text.split('.');
  final integer = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  return 'PKR $integer${parts.length > 1 ? '.${parts[1]}' : ''}';
}

/// Message shown when there's no action button for the signed-in role at
/// the request's current stage. Uses whatever level name the backend says
/// is currently pending - never a hardcoded department/role name - so it
/// reads correctly no matter how many levels a hierarchy has.
String _statusInfoMessage(CreditAgingRequest request) {
  final s = request.status.toUpperCase();
  if (s == 'APPROVED') return 'This request has completed the approval stage.';
  if (s == 'REJECTED') return 'This request has been rejected.';

  final pending = request.pendingLevelName;
  return pending != null
      ? "This request is awaiting $pending's review."
      : 'No action is available for this request at the moment.';
}
