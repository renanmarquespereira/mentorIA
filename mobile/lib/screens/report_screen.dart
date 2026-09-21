import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'action_plan_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportState();
}

class _ReportState extends State<ReportScreen> {
  Map<String, dynamic>? report;
  bool loading = true, generating = false, ready = false;
  String? error;
  static const pillars = {
    'positioning': 'Posicionamento Único',
    'promise': 'Promessa Atrativa',
    'funnel': 'Funil de Venda Poderoso',
    'closing': 'Fechamento Irrecusável'
  };
  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      Map<String, dynamic>? result;
      bool canGenerate = false;
      try {
        result = await ApiService().fullReport();
      } on ApiException catch (e) {
        if (e.statusCode != 404) rethrow;
        final dashboard = await ApiService().dashboard();
        canGenerate = dashboard['journey_status'] == 'diagnosis_completed';
      }
      if (mounted)
        setState(() {
          report = result;
          ready = canGenerate;
          loading = false;
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          loading = false;
          error = 'Não foi possível carregar a estratégia. Tente novamente.';
        });
    }
  }

  Future<void> generate() async {
    setState(() {
      generating = true;
      error = null;
    });
    try {
      await ApiService().generateStrategy();
      await reload();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  Widget section(String title, List values) => values.isEmpty
      ? const SizedBox.shrink()
      : Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final value in values)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('• $value')),
                  ])));
  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
        appBar: AppBar(title: const Text('Estratégia')),
        body: RefreshIndicator(
            onRefresh: reload,
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  if (error != null) ...[
                    Text(error!, style: const TextStyle(color: Colors.red)),
                    TextButton(
                        onPressed: generating ? null : reload,
                        child: const Text('Tentar novamente'))
                  ],
                  if (report == null && error == null) ...[
                    Text(ready
                        ? 'Os quatro pilares estão validados. Gere sua estratégia e transforme o diagnóstico em ações.'
                        : 'Valide os planos dos quatro pilares para liberar sua estratégia completa.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                        onPressed: ready && !generating ? generate : null,
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(generating
                            ? 'Gerando estratégia e ações...'
                            : 'Gerar estratégia completa')),
                  ] else if (report != null) ...[
                    Text('Resumo executivo',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(report!['executive_summary'] ?? ''),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ActionPlanScreen())),
                        icon: const Icon(Icons.task_alt),
                        label: const Text('Acompanhar plano de ação')),
                    if ((report!['stage_summary'] ?? '').toString().isNotEmpty)
                      section('Seu momento atual', [report!['stage_summary']]),
                    section('Prioridades', report!['priorities'] ?? []),
                    for (final entry in pillars.entries)
                      if ((report!['pillar_summaries']?[entry.key] ?? '')
                          .toString()
                          .isNotEmpty)
                        section(entry.value,
                            [report!['pillar_summaries'][entry.key]]),
                    section('Pontos fortes', report!['strengths'] ?? []),
                    section('Pontos a melhorar', report!['gaps'] ?? []),
                    section('Recomendações', report!['recommendations'] ?? []),
                  ],
                ])));
  }
}
