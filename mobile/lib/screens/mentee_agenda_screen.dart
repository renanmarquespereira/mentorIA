import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MenteeAgendaScreen extends StatefulWidget {
  const MenteeAgendaScreen({super.key});

  @override
  State<MenteeAgendaScreen> createState() => _MenteeAgendaScreenState();
}

class _MenteeAgendaScreenState extends State<MenteeAgendaScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> data = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await ApiService().myMentorSessions();
      if (!mounted) return;
      setState(() {
        data = result;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = '$e';
      });
    }
  }

  String fmt(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return '—';
    String z(int n) => n.toString().padLeft(2, '0');
    return '${z(date.day)}/${z(date.month)}/${date.year} às ${z(date.hour)}:${z(date.minute)}';
  }

  String label(dynamic status) {
    if (status == 'completed') return 'Realizada';
    if (status == 'canceled') return 'Cancelada';
    return 'Agendada';
  }

  Color statusColor(dynamic status) {
    if (status == 'completed') return Colors.green;
    if (status == 'canceled') return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final rows = List<dynamic>.from(data['sessions'] ?? const []);
    final next = data['next_session'];

    return Scaffold(
      appBar: AppBar(title: const Text('Minha agenda')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (next != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.event_available),
                        title: const Text('Próxima mentoria'),
                        subtitle: Text(fmt(next['scheduled_at'])),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Sessões de mentoria',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (rows.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('Nenhuma mentoria agendada ainda.'),
                      ),
                    ),
                  ...rows.map((item) {
                    final row = Map<String, dynamic>.from(item);
                    final color = statusColor(row['status']);
                    return Card(
                      color: color.withOpacity(.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: color, width: 1.5),
                      ),
                      child: ListTile(
                        leading: Icon(
                          row['status'] == 'completed'
                              ? Icons.check_circle_outline
                              : row['status'] == 'canceled'
                                  ? Icons.cancel_outlined
                                  : Icons.schedule,
                          color: color,
                        ),
                        title: Text(fmt(row['scheduled_at'])),
                        subtitle: Text(label(row['status']), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                      ),
                    );
                  }),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
