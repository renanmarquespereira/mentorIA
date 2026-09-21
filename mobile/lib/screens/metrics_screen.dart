import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'crm_labels.dart';
import 'metric_form_screen.dart';

class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  Map<String, dynamic>? summary;
  List<dynamic> history = [];
  bool loading = true;
  String? error, selectedPeriod;
  String ratio(dynamic value, {String suffix = "%"}) => value == null
      ? "Sem base de cálculo"
      : "${(value as num).toStringAsFixed(2).replaceAll(".", ",")}$suffix";

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final values = await Future.wait(
          [ApiService().metrics(), ApiService().metricsHistory()]);
      if (!mounted) return;
      setState(() {
        summary = values[0] as Map<String, dynamic>;
        history = values[1] as List<dynamic>;
        error = null;
      });
    } catch (_) {
      if (mounted)
        setState(() =>
            error = 'Não consegui atualizar as métricas. Tente novamente.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String money(dynamic value) =>
      value == null ? 'Sem base de cálculo' : CrmLabels.money(value);

  Widget metricCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
            Flexible(
                child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            )),
          ],
        ),
      ),
    );
  }

  Future<void> addMetric([Map<String, dynamic>? initial]) async {
    final saved = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => MetricFormScreen(initial: initial)));
    if (saved == true) await reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Métricas'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addMetric(),
        icon: const Icon(Icons.add_chart),
        label: const Text('Registrar período'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('CRM • todo o período',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text(
                      'Conversão = contatos com pelo menos uma venda ÷ contatos cadastrados. Vendas sem contato entram na receita, mas não na conversão.'),
                  if (error != null) ...[
                    Text(error!),
                    TextButton(
                        onPressed: reload,
                        child: const Text('Tentar novamente'))
                  ],
                  metricCard('Ticket médio', money(summary?['average_ticket']),
                      Icons.receipt_long),
                  metricCard(
                      'Retornos atrasados',
                      '${summary?['overdue_follow_ups'] ?? 0}',
                      Icons.event_busy),
                  metricCard(
                    'Contatos',
                    '${summary?['leads'] ?? 0}',
                    Icons.people_outline,
                  ),
                  metricCard(
                    'Vendas',
                    '${summary?['sales_count'] ?? 0}',
                    Icons.shopping_bag_outlined,
                  ),
                  metricCard(
                    'Receita',
                    money(summary?['revenue'] ?? 0),
                    Icons.payments_outlined,
                  ),
                  metricCard(
                    'Contatos que compraram',
                    ratio(summary?['conversion_rate']),
                    Icons.trending_up,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Resumos mensais • registro manual',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                      'Estes valores não são somados aos do CRM. Indicadores sem denominador aparecem como sem base de cálculo. Receita/anúncios não representa lucro nem retorno atribuído à publicidade.'),
                  DropdownButtonFormField<String>(
                      initialValue: selectedPeriod ?? '',
                      decoration:
                          const InputDecoration(labelText: 'Filtrar mês'),
                      items: [
                        const DropdownMenuItem(
                            value: '', child: Text('Todos os meses')),
                        for (final p in history
                            .map((x) => x['period'].toString())
                            .toSet())
                          DropdownMenuItem(value: p, child: Text(p))
                      ],
                      onChanged: (value) => setState(
                          () => selectedPeriod = value == '' ? null : value)),
                  if (history.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Nenhum resumo mensal registrado.')),
                  for (final item in history.where((x) =>
                      selectedPeriod == null || x['period'] == selectedPeriod))
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextButton(
                                onPressed: () =>
                                    addMetric(Map<String, dynamic>.from(item)),
                                child:
                                    const Text('Atualizar resumo deste mês')),
                            Text(
                              item['period'] ?? '',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Contatos: ${item['leads'] ?? 0} • '
                              'Reuniões: ${item['calls'] ?? 0} • '
                              'Vendas: ${item['sales_count'] ?? 0}',
                            ),
                            Text(
                              'Receita: ${money(item['revenue'] ?? 0)} • '
                              'Anúncios: ${money(item['ad_spend'] ?? 0)}',
                            ),
                            Text(
                              'Vendas/reuniões: ${ratio(item['conversion_rate'])} • '
                              'Anúncios por contato: ${money(item['cpl'])}',
                            ),
                            Text(
                              'Anúncios por venda: ${money(item['cac'])} • '
                              'Receita/anúncios: ${ratio(item['revenue_ad_ratio'], suffix: "x")}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}
