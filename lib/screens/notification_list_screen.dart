import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../services/notification_service.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen>
    with WidgetsBindingObserver {
  List<StoredNotification> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  void _load() {
    if (!mounted) return;
    setState(() => _items = NotificationService.history);
  }

  Future<void> _clear() async {
    if (_items.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear notifications?'),
        content: const Text('This will remove the notification history from the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await NotificationService.clearHistory();
    _load();
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _date(DateTime value) {
    return '${_two(value.day)}/${_two(value.month)}/${value.year}';
  }

  String _time(DateTime value) {
    return '${_two(value.hour)}:${_two(value.minute)}:${_two(value.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageBg,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            color: kInk,
          ),
        ),
        actions: [
          if (_items.isNotEmpty)
            TextButton.icon(
              onPressed: _clear,
              icon: const Icon(Icons.delete_outline_rounded, size: 19),
              label: const Text('Clear'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: kSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: kMutedInk,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'No notifications yet',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'New Credit Aging requests will appear here automatically.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: kMutedInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final item = _items[index];
                return Container(
                  padding: const EdgeInsets.all(17),
                  decoration: softCardDecoration(radius: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: kInk,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              item.body,
                              style: GoogleFonts.manrope(
                                color: kMutedInk,
                                fontSize: 12.5,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 13,
                                  color: kMutedInk,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _date(item.dateTime),
                                  style: GoogleFonts.manrope(
                                    color: kMutedInk,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: kMutedInk,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _time(item.dateTime),
                                  style: GoogleFonts.manrope(
                                    color: kMutedInk,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
