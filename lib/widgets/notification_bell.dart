import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../screens/auth_screen.dart';
import '../screens/notifications_screen.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int? count;
  int generation = 0;
  StreamSubscription<AuthState>? auth;
  @override
  void initState() {
    super.initState();
    NotificationService.changes.addListener(refresh);
    auth = SupabaseService.authStateChanges?.listen((_) => refresh());
    refresh();
  }

  Future<void> refresh() async {
    final ticket = ++generation;
    final owner = SupabaseService.currentUser?.id;
    if (mounted) setState(() => count = null);
    if (owner == null || !SupabaseService.isLoggedIn) return;
    try {
      final value = await NotificationService.unread(owner);
      if (mounted &&
          ticket == generation &&
          SupabaseService.currentUser?.id == owner) {
        setState(() => count = value);
      }
    } catch (_) {
      /* Hide an unavailable count; do not fabricate zero. */
    }
  }

  @override
  void dispose() {
    generation++;
    auth?.cancel();
    NotificationService.changes.removeListener(refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: count != null && count! > 0 ? '읽지 않은 알림 $count개' : '알림',
    onPressed: () async {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder:
              (_) =>
                  SupabaseService.isLoggedIn
                      ? const NotificationsScreen()
                      : const AuthScreen(),
        ),
      );
      if (mounted) await refresh();
    },
    icon: Badge(
      isLabelVisible: count != null && count! > 0,
      backgroundColor: const Color(0xFFD92D20),
      textColor: Colors.white,
      label: Text(
        count != null && count! > 99 ? '99+' : '${count ?? 0}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      child: const Icon(Icons.notifications_outlined),
    ),
  );
}
