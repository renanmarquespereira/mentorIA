import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/pending_approval_screen.dart';
import 'screens/mentor_admin_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/my_sessions_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/mentor_settings_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<int> appRouteDepth = ValueNotifier<int>(0);

class AppRouteObserver extends NavigatorObserver {
  void _set(int value) => appRouteDepth.value = value < 0 ? 0 : value;
  @override void didPush(Route route, Route? previousRoute) { super.didPush(route, previousRoute); _set(appRouteDepth.value + 1); }
  @override void didPop(Route route, Route? previousRoute) { super.didPop(route, previousRoute); _set(appRouteDepth.value - 1); }
  @override void didRemove(Route route, Route? previousRoute) { super.didRemove(route, previousRoute); _set(appRouteDepth.value - 1); }
}
final AppRouteObserver appRouteObserver = AppRouteObserver();

void main() => runApp(const MentoriaApp());

class MentoriaApp extends StatelessWidget {
  const MentoriaApp({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
      navigatorKey: appNavigatorKey,
      navigatorObservers: [appRouteObserver],
      debugShowCheckedModeBanner: false,
      title: 'Mentoria IA',
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF1B5E55)),
      // The authenticated shell contains interactive Material widgets (IconButton,
      // PopupMenuButton, tooltips) outside the Navigator passed as `child`.
      // Give that shell its own Overlay so RawTooltip/menus always have an
      // Overlay ancestor on Flutter Web.
      builder: (context, child) => Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (_) => _AuthenticatedShell(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      home: const _SessionGate());
}

class _AuthenticatedShell extends StatefulWidget {
  final Widget child;
  const _AuthenticatedShell({required this.child});
  @override State<_AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<_AuthenticatedShell> {
  Map<String, dynamic>? me;
  bool checking = true;
  int lastRevision = -1;

  @override
  void initState() {
    super.initState();
    ApiService.currentIdentity.addListener(_identityChanged);
    final cached = ApiService.currentIdentity.value;
    me = cached;
    checking = cached == null;
  }

  @override
  void dispose() {
    ApiService.currentIdentity.removeListener(_identityChanged);
    super.dispose();
  }

  void _identityChanged() {
    if (!mounted) return;
    setState(() { me = ApiService.currentIdentity.value; checking = false; });
  }

  Future<void> _refreshIdentity() async {
    final revision = ApiService.sessionRevision.value;
    lastRevision = revision;
    final api = ApiService();
    final token = await api.token();
    if (token == null || token.isEmpty) {
      if (mounted) setState(() { me = null; checking = false; });
      return;
    }
    try {
      final current = await api.me();
      ApiService.currentIdentity.value = current;
      if (mounted && lastRevision == revision) setState(() { me = current; checking = false; });
    } catch (_) {
      if (mounted && lastRevision == revision) setState(() { checking = false; });
    }
  }

  void _replace(Widget page) {
    appNavigatorKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => page), (_) => false);
  }

  Future<dynamic>? _push(Widget page) => appNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => page));

  Future<void> _logout() async {
    await ApiService().logout();
    _replace(const LoginScreen());
  }

  Widget _avatar(String photo, String name) {
    ImageProvider? image;
    if (photo.startsWith('data:') && photo.contains(',')) {
      try { image = MemoryImage(base64Decode(photo.split(',').last)); } catch (_) {}
    }
    return CircleAvatar(
      radius: 18,
      backgroundImage: image,
      child: image == null ? Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase()) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cached = ApiService.currentIdentity.value;
    if (cached != null && me == null) me = cached;
    if (checking || me == null) return widget.child;
    final role = '${me!['role'] ?? 'mentee'}';
    final mentor = role == 'mentor' || role == 'admin';
    final name = '${me!['name'] ?? ''}';
    final photo = '${me!['profile_photo'] ?? ''}';
    return Column(children: [
      Material(),
      Expanded(child: widget.child),
    ]);
  }
}

class _SessionGate extends StatefulWidget {
  const _SessionGate();
  @override State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  Widget? destination;
  @override void initState() { super.initState(); _restoreSession(); }

  Future<void> _restoreSession() async {
    final api = ApiService();
    final token = await api.token();
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => destination = const LoginScreen());
      return;
    }
    try {
      final me = await api.me();
      ApiService.currentIdentity.value = me;
      if (!mounted) return;
      if (me['role'] == 'mentor' || me['role'] == 'admin') {
        setState(() => destination = const MentorAdminScreen());
      } else if (me['approval_status'] == 'active') {
        setState(() => destination = const HomeScreen());
      } else {
        setState(() => destination = const PendingApprovalScreen());
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) await api.logout();
      if (mounted) setState(() => destination = const LoginScreen());
    } catch (_) {
      if (mounted) setState(() => destination = const LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (destination != null) return destination!;
    return const Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Carregando sua sessão...')])));
  }
}
