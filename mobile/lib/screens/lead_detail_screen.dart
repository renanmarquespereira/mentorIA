import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'crm_form_screen.dart';
import 'crm_labels.dart';

class LeadDetailScreen extends StatefulWidget {
  const LeadDetailScreen({super.key, required this.lead});
  final Map<String, dynamic> lead;
  @override
  State<LeadDetailScreen> createState() => _LeadState();
}

class _LeadState extends State<LeadDetailScreen> {
  late Map<String, dynamic> lead;
  List<dynamic> followUps = [], sales = [];
  bool loading = true, saving = false;
  String? error;
  int revision = 0;
  @override
  void initState() {
    super.initState();
    lead = widget.lead;
    reload();
  }

  Future<void> reload() async {
    try {
      final result = await Future.wait<dynamic>([
        ApiService().lead(lead['id']),
        ApiService().followUps(lead['id']),
        ApiService().sales()
      ]);
      if (mounted)
        setState(() {
          lead = Map<String, dynamic>.from(result[0]);
          followUps = result[1];
          sales = (result[2] as List)
              .where((x) => x['lead_id'] == lead['id'])
              .toList();
          loading = false;
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          loading = false;
          error = 'Não foi possível atualizar este contato. Tente novamente.';
        });
    }
  }

  Future<void> changeStage(String? value) async {
    if (value == null || value == lead['stage']) return;
    setState(() => saving = true);
    try {
      await ApiService().updateLeadStage(lead['id'], value);
      if (mounted) setState(() => lead = {...lead, 'stage': value});
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Não foi possível alterar o estágio.')));
    } finally {
      if (mounted)
        setState(() {
          saving = false;
          revision++;
        });
    }
  }

  Future<void> open(CrmFormKind kind) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CrmFormScreen(kind: kind, lead: lead)));
    if (mounted) await reload();
  }

  Future<void> toggle(dynamic item) async {
    setState(() => saving = true);
    try {
      await ApiService().setFollowUp(
          item['id'], item['status'] == 'done' ? 'pending' : 'done');
      await reload();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Não foi possível atualizar o retorno.')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = lead['stage'] ?? 'new';
    final ordered = [
      ...followUps.where((x) => x['status'] != 'done'),
      ...followUps.where((x) => x['status'] == 'done')
    ];
    return Scaffold(
        appBar: AppBar(title: Text(lead['name'] ?? 'Contato')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: reload,
                child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(18),
                    children: [
                      if (error != null) ...[
                        Text(error!, style: const TextStyle(color: Colors.red)),
                        TextButton(
                            onPressed: reload,
                            child: const Text('Tentar novamente'))
                      ],
                      Text(lead['name'] ?? '',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text('Contato: ${lead['contact'] ?? 'Não informado'}'),
                      Text(
                          'Origem: ${CrmLabels.label(CrmLabels.sources, lead['source'])}'),
                      Text(
                          'Funil: ${CrmLabels.label(CrmLabels.funnels, lead['funnel'])}'),
                      Text(
                          'Valor esperado: ${CrmLabels.money(lead['expected_value'])}'),
                      if ((lead['notes'] ?? '').toString().isNotEmpty)
                        Text('Observações: ${lead['notes']}'),
                      TextButton.icon(
                          onPressed:
                              saving ? null : () => open(CrmFormKind.contact),
                          icon: const Icon(Icons.edit),
                          label: const Text('Editar contato')),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                          key: ValueKey('stage-$revision-$stage'),
                          initialValue: stage,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Estágio'),
                          items: [
                            for (final e in CrmLabels.stages.entries)
                              DropdownMenuItem(
                                  value: e.key, child: Text(e.value)),
                            if (!CrmLabels.stages.containsKey(stage))
                              DropdownMenuItem(
                                  value: stage,
                                  child: Text(
                                      CrmLabels.label(CrmLabels.stages, stage)))
                          ],
                          onChanged: saving ? null : changeStage),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                          onPressed:
                              saving ? null : () => open(CrmFormKind.sale),
                          icon: const Icon(Icons.attach_money),
                          label: const Text('Registrar venda')),
                      const SizedBox(height: 20),
                      Text('Retornos ao contato',
                          style: Theme.of(context).textTheme.titleLarge),
                      OutlinedButton.icon(
                          onPressed:
                              saving ? null : () => open(CrmFormKind.followUp),
                          icon: const Icon(Icons.schedule),
                          label: const Text('Agendar retorno')),
                      if (ordered.isEmpty && error == null)
                        const Text('Nenhum retorno agendado.'),
                      for (final x in ordered)
                        Card(
                            child: CheckboxListTile(
                                value: x['status'] == 'done',
                                onChanged: saving ? null : (_) => toggle(x),
                                title: Text(
                                    '${CrmLabels.date(x['due_date'])} • ${x['status'] == 'done' ? 'Concluído' : CrmLabels.overdue(x['due_date']) ? 'Vencido' : 'Pendente'}'),
                                subtitle: Text(x['notes'] ?? ''))),
                      const SizedBox(height: 20),
                      Text('Histórico de vendas',
                          style: Theme.of(context).textTheme.titleLarge),
                      if (sales.isEmpty && error == null)
                        const Text('Nenhuma venda para este contato.'),
                      for (final x in sales)
                        Card(
                            child: ListTile(
                                title: Text(x['product'] ?? 'Mentoria'),
                                subtitle: Text(CrmLabels.date(x['created_at'])),
                                trailing: Text(CrmLabels.money(x['amount'])))),
                    ])));
  }
}
