import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MySessionsScreen extends StatefulWidget {
  const MySessionsScreen({super.key});
  @override
  State<MySessionsScreen> createState() => _MySessionsScreenState();
}

class _MySessionsScreenState extends State<MySessionsScreen> {
  bool loading = true;
  List<dynamic> rows = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await ApiService().mySessions();
      if (mounted) setState(() { rows = result; loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  String formatDate(dynamic raw) {
    final d = DateTime.tryParse('$raw')?.toLocal();
    if (d == null) return '—';
    String z(int n) => '$n'.padLeft(2, '0');
    return '${z(d.day)}/${z(d.month)}/${d.year} às ${z(d.hour)}:${z(d.minute)}';
  }

  String statusLabel(String status) => const {
    'scheduled': 'Agendada',
    'completed': 'Realizada',
    'canceled': 'Cancelada',
  }[status] ?? status;

  Future<void> hide(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remover da minha agenda?'),
        content: const Text('A sessão deixará de aparecer para você. O histórico da mentora será preservado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remover')),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    try {
      await ApiService().hideMySession(id);
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minha agenda de mentorias')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (rows.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Nenhuma mentoria disponível.'))),
                  for (final raw in rows) _sessionCard(Map<String, dynamic>.from(raw)),
                ],
              ),
            ),
    );
  }

  Color statusColor(String status) => status == 'completed' ? Colors.green : status == 'canceled' ? Colors.red : Colors.orange;

  Widget _sessionCard(Map<String, dynamic> r) {
    final summary = '${r['summary'] ?? ''}'.trim();
    final decisions = '${r['decisions'] ?? ''}'.trim();
    final nextSteps = '${r['next_steps'] ?? ''}'.trim();
    final status = '${r['status'] ?? 'scheduled'}';
    final color = statusColor(status);
    return Card(
      color: color.withOpacity(.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color, width: 1.5)),
      child: ExpansionTile(
        leading: Icon(Icons.event_note, color: color),
        title: Text('${r['subject'] ?? 'Mentoria'}'),
        subtitle: Text('${formatDate(r['scheduled_at'])} • ${statusLabel(status)}', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary.isNotEmpty) Text('O que foi tratado: $summary'),
                if (decisions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Decisões: $decisions')),
                if (nextSteps.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Próximos passos: $nextSteps')),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => hide('${r['id']}'),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remover da minha agenda'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
