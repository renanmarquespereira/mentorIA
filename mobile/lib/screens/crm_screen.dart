import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'lead_detail_screen.dart';
import 'crm_form_screen.dart';
import 'crm_labels.dart';

class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key});
  @override
  State<CrmScreen> createState() => _CrmState();
}

class _CrmState extends State<CrmScreen> {
  List<dynamic> leads = [], sales = [];
  bool loading = true;
  String? error;
  String stage = 'all', search = '';
  Future<void> reload() async {
    try {
      final data =
          await Future.wait([ApiService().leads(), ApiService().sales()]);
      if (mounted)
        setState(() {
          leads = data[0];
          sales = data[1];
          loading = false;
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          loading = false;
          error = 'Não foi possível carregar o CRM. Tente novamente.';
        });
    }
  }

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> add() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const CrmFormScreen(kind: CrmFormKind.contact)));
    if (mounted) await reload();
  }

  Widget failure() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(error!, style: const TextStyle(color: Colors.red)),
        TextButton(onPressed: reload, child: const Text('Tentar novamente'))
      ]);
  @override
  Widget build(BuildContext context) {
    final q = search.trim().toLowerCase();
    final filtered = leads
        .where((x) =>
            (stage == 'all' || x['stage'] == stage) &&
            [
              'name',
              'contact',
              'notes'
            ].any((key) => (x[key] ?? '').toString().toLowerCase().contains(q)))
        .toList();
    final total = sales.fold<double>(
        0, (a, x) => a + ((x['amount'] ?? 0) as num).toDouble());
    return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
              title: const Text('CRM e vendas'),
              bottom: const TabBar(
                  tabs: [Tab(text: 'Contatos'), Tab(text: 'Vendas')])),
          floatingActionButton: FloatingActionButton.extended(
              onPressed: add,
              icon: const Icon(Icons.person_add),
              label: const Text('Novo contato')),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(children: [
                  RefreshIndicator(
                      onRefresh: reload,
                      child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          children: [
                            if (error != null) failure(),
                            Text('${leads.length} contatos',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 12),
                            TextField(
                                onChanged: (v) => setState(() => search = v),
                                decoration: const InputDecoration(
                                    labelText: 'Buscar contato',
                                    hintText:
                                        'Nome, telefone, e-mail ou observação',
                                    prefixIcon: Icon(Icons.search))),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                                initialValue: stage,
                                isExpanded: true,
                                decoration:
                                    const InputDecoration(labelText: 'Estágio'),
                                items: [
                                  const DropdownMenuItem(
                                      value: 'all',
                                      child: Text('Todos os estágios')),
                                  for (final e in CrmLabels.stages.entries)
                                    DropdownMenuItem(
                                        value: e.key, child: Text(e.value))
                                ],
                                onChanged: (v) =>
                                    setState(() => stage = v ?? 'all')),
                            const SizedBox(height: 12),
                            for (final x in filtered)
                              Card(
                                  child: ListTile(
                                      title: Text(x['name'] ?? ''),
                                      subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                '${CrmLabels.label(CrmLabels.stages, x['stage'])} • ${CrmLabels.label(CrmLabels.sources, x['source'])}'),
                                            Text(x['contact'] ?? ''),
                                            if (x['next_follow_up'] != null)
                                              Text(
                                                  'Retorno: ${CrmLabels.date(x['next_follow_up'])}${CrmLabels.overdue(x['next_follow_up']) ? ' • Vencido' : ''}',
                                                  style: TextStyle(
                                                      color: CrmLabels.overdue(x[
                                                              'next_follow_up'])
                                                          ? Colors.red
                                                          : null)),
                                          ]),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => LeadDetailScreen(
                                                  lead:
                                                      Map<String, dynamic>.from(
                                                          x)))).then(
                                          (_) => reload()))),
                            if (filtered.isEmpty && error == null)
                              const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('Nenhum contato encontrado.')),
                          ])),
                  RefreshIndicator(
                      onRefresh: reload,
                      child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          children: [
                            if (error != null) failure(),
                            Text('Vendas registradas',
                                style: Theme.of(context).textTheme.titleLarge),
                            Text(
                                '${sales.length} vendas • ${CrmLabels.money(total)}'),
                            const SizedBox(height: 16),
                            for (final x in sales)
                              Card(
                                  child: ListTile(
                                      title: Text(x['product'] ?? 'Mentoria'),
                                      subtitle: Text(
                                          '${x['lead_name'] ?? 'Contato não vinculado'}\n${CrmLabels.date(x['created_at'])} • ${CrmLabels.label(CrmLabels.sources, x['source'])}'),
                                      trailing:
                                          Text(CrmLabels.money(x['amount'])))),
                            if (sales.isEmpty && error == null)
                              const Text(
                                  'Nenhuma venda registrada. Abra um contato para registrar a venda.'),
                          ])),
                ]),
        ));
  }
}
