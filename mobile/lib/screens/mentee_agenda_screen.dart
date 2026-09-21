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

  Future<void> cancelSession(Map<String,dynamic> row) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: const Text('Cancelar mentoria'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Informe o motivo do cancelamento:'), const SizedBox(height: 10),
        TextField(controller: controller, maxLines: 4, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Motivo do cancelamento')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Voltar')), FilledButton(onPressed: () { final v=controller.text.trim(); if(v.length>=3) Navigator.pop(c,v); }, child: const Text('Confirmar cancelamento'))],
    ));
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    try { await ApiService().cancelMySession('${row['id']}', reason); await load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  void showMinutes(Map<String,dynamic> row) {
    final summary='${row['summary'] ?? ''}'.trim();
    final decisions='${row['decisions'] ?? ''}'.trim();
    final nextSteps='${row['next_steps'] ?? ''}'.trim();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('Ata da reunião'),
      content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Data: ${fmt(row['scheduled_at'])}'), const SizedBox(height: 16),
        const Text('Resumo', style: TextStyle(fontWeight: FontWeight.bold)), Text(summary.isEmpty ? 'Não informado.' : summary), const SizedBox(height: 12),
        const Text('Decisões', style: TextStyle(fontWeight: FontWeight.bold)), Text(decisions.isEmpty ? 'Não informado.' : decisions), const SizedBox(height: 12),
        const Text('Próximos passos', style: TextStyle(fontWeight: FontWeight.bold)), Text(nextSteps.isEmpty ? 'Não informado.' : nextSteps),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Fechar'))],
    ));
  }

  Future<void> clearCompleted() async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Limpar mentorias realizadas?'),
      content: const Text('Elas deixarão de aparecer para você, mas a mentora continuará com o histórico e as atas.'),
      actions: [TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Limpar'))],
    )) ?? false;
    if (!ok) return;
    try { await ApiService().hideCompletedMySessions(); await load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
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
                  if (rows.any((e) => e is Map && e['status'] == 'completed'))
                    Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: clearCompleted, icon: const Icon(Icons.cleaning_services_outlined), label: const Text('Limpar realizadas'))),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: color, width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          ListTile(contentPadding: EdgeInsets.zero,
                            leading: Icon(row['status'] == 'completed' ? Icons.check_circle_outline : row['status'] == 'canceled' ? Icons.cancel_outlined : Icons.schedule, color: color),
                            title: Text(fmt(row['scheduled_at'])),
                            subtitle: Text(label(row['status']), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                          ),
                          if (row['status'] == 'canceled' && '${row['cancellation_reason'] ?? ''}'.trim().isNotEmpty)
                            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Motivo: ${row['cancellation_reason']}')),
                          if (row['status'] == 'scheduled')
                            Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(onPressed: () => cancelSession(row), icon: const Icon(Icons.cancel_outlined), label: const Text('Cancelar mentoria'))),
                          if (row['status'] == 'completed')
                            Align(alignment: Alignment.centerRight, child: FilledButton.tonalIcon(onPressed: () => showMinutes(row), icon: const Icon(Icons.description_outlined), label: const Text('Ver ata da reunião'))),
                        ]),
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
