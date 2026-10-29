import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/ph_time.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../data/notification_service.dart';
import '../domain/notification_message.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({required this.onLocaleChanged, super.key});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _service = NotificationService();
  late Future<List<AppNotification>> _items;

  @override
  void initState() {
    super.initState();
    _items = _service.list();
  }

  void _refresh() => setState(() => _items = _service.list());

  Future<void> _open(AppNotification notification) async {
    final route = notificationRoute(notification.target, notification.type);
    try {
      if (!notification.isRead) await _service.markRead(notification.id);
    } on Object {
      // Opening the screen still works if marking it read fails.
    }
    if (!mounted) return;
    if (route != null) {
      context.go(route);
    } else {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications),
        leading: BackButton(onPressed: () => context.go('/admin')),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          LanguageToggle(onChanged: widget.onLocaleChanged),
        ],
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.adminLoadError, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _refresh, child: Text(l10n.retry)),
                ],
              ),
            );
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(child: Text(l10n.noNotifications));
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final when =
                    '${formatPhDate(phDateOf(item.createdAt))} '
                    '${formatPhTime(item.createdAt)}';
                return Card(
                  child: ListTile(
                    leading: Icon(
                      item.isRead
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      color: item.isRead
                          ? null
                          : Theme.of(context).colorScheme.secondary,
                    ),
                    title: Text(
                      notificationText(l10n, item.type, item.params),
                      style: item.isRead
                          ? null
                          : const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(when),
                    isThreeLine: false,
                    onTap: () => _open(item),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
