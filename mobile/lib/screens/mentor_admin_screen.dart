import 'dart:convert';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'mentor_settings_screen.dart';
import 'mentor_mentee_detail_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'mentor_agenda_screen.dart';

class MentorAdminScreen extends StatefulWidget {
  const MentorAdminScreen({super.key});
  @override
  State<MentorAdminScreen> createState() => _S();
}

class _S extends State<MentorAdminScreen> {
  List<dynamic> users = [];
  Map<String, dynamic>? currentUser;
  bool loading = true;
  final searchController = TextEditingController();
  String searchText = '';
  final Set<String> selectedStatuses = {
    'pending_approval',
    'active',
    'rejected',
  };
  Future<void> reload() async {
    final results = await Future.wait([
      ApiService().mentorMentees(),
      ApiService().profile(),
    ]);
    if (mounted)
      setState(() {
        users = List<dynamic>.from(results[0] as List);
        currentUser = Map<String, dynamic>.from(results[1] as Map);
        loading = false;
      });
  }

  Future<void> logout() async {
    await ApiService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> setApproval(dynamic u, String s) async {
    await ApiService().setMenteeApproval(u['id'], s);
    await reload();
  }

  String statusLabel(String s) => s == 'active'
      ? 'Desbloqueado'
      : s == 'rejected'
          ? 'Bloqueado'
          : 'Pendente';
  Color statusColor(String s) => s == 'active'
      ? Colors.green
      : s == 'rejected'
          ? Colors.red
          : Colors.orange;
  Future<void> showFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (c, setSheet) {
          void toggle(String s) {
            setState(() {
              selectedStatuses.contains(s)
                  ? selectedStatuses.remove(s)
                  : selectedStatuses.add(s);
            });
            setSheet(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtrar por status',
                    style: Theme.of(c).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pendentes'),
                    value: selectedStatuses.contains('pending_approval'),
                    onChanged: (_) => toggle('pending_approval'),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Desbloqueados'),
                    value: selectedStatuses.contains('active'),
                    onChanged: (_) => toggle('active'),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bloqueados'),
                    value: selectedStatuses.contains('rejected'),
                    onChanged: (_) => toggle('rejected'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              selectedStatuses
                                ..clear()
                                ..addAll({
                                  'pending_approval',
                                  'active',
                                  'rejected',
                                });
                            });
                            setSheet(() {});
                          },
                          child: const Text('Mostrar todos'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(sheet),
                          child: const Text('Aplicar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  ImageProvider? photoProvider(dynamic value) {
    final photo = (value ?? '').toString();
    if (!photo.startsWith('data:') || !photo.contains(',')) return null;
    try {
      return MemoryImage(base64Decode(photo.split(',').last));
    } catch (_) {
      return null;
    }
  }

  String _formatSessionDate(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (d == null) return '—';
    String z(int n) => n.toString().padLeft(2, '0');
    return '${z(d.day)}/${z(d.month)}/${d.year} ${z(d.hour)}:${z(d.minute)}';
  }

  @override
  Widget build(BuildContext c) {
    final q = searchText.trim().toLowerCase();
    final orderedUsers = [
      ...users.where((u) => u['approval_status'] == 'active'),
      ...users.where((u) => u['approval_status'] != 'active'),
    ];
    final filtered = orderedUsers.where((u) {
      final status = u['approval_status'] ?? 'pending_approval';
      if (selectedStatuses.isNotEmpty && !selectedStatuses.contains(status))
        return false;
      if (q.isEmpty) return true;
      return (u['name'] ?? '').toString().toLowerCase().contains(q) ||
          (u['email'] ?? '').toString().toLowerCase().contains(q) ||
          (u['phone'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('MentorIA'),
        actions: [
          IconButton(tooltip: 'Agenda', onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const MentorAgendaScreen())), icon: const Icon(Icons.calendar_month_outlined)),
          IconButton(tooltip: 'Avisos', onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const NotificationsScreen())), icon: const Icon(Icons.notifications_outlined)),
          PopupMenuButton<String>(
            tooltip: 'Usuário',
            onSelected: (v) {
              if (v == 'data') Navigator.push(c, MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_)=>reload());
              if (v == 'method') Navigator.push(c, MaterialPageRoute(builder: (_) => const MentorSettingsScreen()));
              if (v == 'logout') logout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value:'data', child:ListTile(leading:Icon(Icons.person_outline), title:Text('Dados'))),
              PopupMenuItem(value:'method', child:ListTile(leading:Icon(Icons.psychology_outlined), title:Text('Minha metodologia para a IA'))),
              PopupMenuDivider(),
              PopupMenuItem(value:'logout', child:ListTile(leading:Icon(Icons.logout), title:Text('Logout'))),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Builder(builder: (_) {
                  final image = photoProvider(currentUser?['profile_photo']);
                  final name = (currentUser?['name'] ?? '').toString().trim();
                  return CircleAvatar(
                    radius: 16,
                    backgroundImage: image,
                    child: image == null ? Text(name.isEmpty ? '?' : name[0].toUpperCase()) : null,
                  );
                }),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    (currentUser?['name'] ?? 'Usuário').toString(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down),
              ]),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Mentoradas', style: Theme.of(c).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    onChanged: (v) => setState(() => searchText = v),
                    decoration: InputDecoration(
                      labelText: 'Buscar mentorada',
                      hintText: 'Nome, telefone ou e-mail',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (searchText.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                searchController.clear();
                                setState(() => searchText = '');
                              },
                              icon: const Icon(Icons.clear),
                              tooltip: 'Limpar busca',
                            ),
                          IconButton(
                            onPressed: showFilters,
                            icon: const Icon(Icons.filter_list),
                            tooltip: 'Filtros',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final u in filtered)
                    Card(
                      child: InkWell(
                        onTap: () => Navigator.push(
                          c,
                          MaterialPageRoute(
                            builder: (_) => MentorMenteeDetailScreen(
                              userId: u['id'],
                              userName: u['name'] ?? 'Mentorada',
                            ),
                          ),
                        ).then((_) => reload()),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundImage: photoProvider(u['profile_photo']),
                                child: photoProvider(u['profile_photo']) == null ? const Icon(Icons.person) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      u['name'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(u['email'] ?? ''),
                                    if ((u['phone'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Text(u['phone']),
                                    const SizedBox(height: 8),
                                    Builder(builder: (_) {
                                      final a = Map<String, dynamic>.from(u['active_summary'] ?? const {});
                                      final overdue = (a['overdue_actions'] ?? 0) as num;
                                      final blockers = (a['latest_blockers'] ?? '').toString().trim();
                                      final topic = (a['next_session_topic'] ?? '').toString().trim();
                                      final nextMentoring = a['next_mentoring_at'];
                                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Wrap(spacing: 6, runSpacing: 4, children: [
                                          if ((a['total_actions'] ?? 0) > 0) Chip(visualDensity: VisualDensity.compact, label: Text('${a['completed_actions'] ?? 0}/${a['total_actions']} ações')),
                                          if (overdue > 0) Chip(visualDensity: VisualDensity.compact, avatar: const Icon(Icons.warning_amber, size: 16), label: Text('${overdue.toInt()} vencida${overdue == 1 ? '' : 's'}')),
                                          if (a['latest_checkin_at'] != null) const Chip(visualDensity: VisualDensity.compact, avatar: Icon(Icons.fact_check_outlined, size: 16), label: Text('Preparação recebida')),
                                        ]),
                                        if (blockers.isNotEmpty) Text('Precisa de ajuda: $blockers', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        if (topic.isNotEmpty) Text('Próxima sessão: $topic', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                        if (nextMentoring != null) Text('Mentoria agendada: ${_formatSessionDate(nextMentoring)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      ]);
                                    }),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    statusLabel(
                                      u['approval_status'] ??
                                          'pending_approval',
                                    ),
                                    style: TextStyle(
                                      color: statusColor(
                                        u['approval_status'] ??
                                            'pending_approval',
                                      ),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (u['approval_status'] == 'active')
                                    OutlinedButton(
                                      onPressed: () =>
                                          setApproval(u, 'rejected'),
                                      child: const Text('Bloquear'),
                                    )
                                  else
                                    FilledButton(
                                      onPressed: () => setApproval(u, 'active'),
                                      child: const Text('Desbloquear'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Nenhuma mentorada encontrada.'),
                    ),
                ],
              ),
            ),
    );
  }
}
