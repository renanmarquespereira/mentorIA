import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'mentor_sessions_screen.dart';

class MentorAgendaScreen extends StatefulWidget {
  const MentorAgendaScreen({super.key});

  @override
  State<MentorAgendaScreen> createState() => _MentorAgendaScreenState();
}

class _MentorAgendaScreenState extends State<MentorAgendaScreen> {
  bool loading = true;
  String? error;
  List<dynamic> rows = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await ApiService().mentorAgenda();
      if (!mounted) return;
      setState(() {
        rows = result;
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

  Color statusColor(dynamic status) => status == 'completed' ? Colors.green : status == 'canceled' ? Colors.red : Colors.orange;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agenda de mentorias')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (rows.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('Nenhuma mentoria agendada.'),
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
                        leading: Icon(Icons.event, color: color),
                        title: Text(row['mentee_name'] ?? 'Mentorada'),
                        subtitle: Text(fmt(row['scheduled_at'])),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MentorSessionsScreen(
                              userId: row['mentee_user_id'].toString(),
                              userName: row['mentee_name'] ?? 'Mentorada',
                            ),
                          ),
                        ).then((_) => load()),
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
