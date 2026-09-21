import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'report_screen.dart';

class ActionPlanScreen extends StatefulWidget {
  const ActionPlanScreen({super.key});
  @override
  State<ActionPlanScreen> createState() => _ActionPlanState();
}

class _ActionPlanState extends State<ActionPlanScreen> {
  List<dynamic> items = [];
  bool loading = true;
  int actionRevision = 0;
  String? error, savingId;
  String statusFilter = 'all', pillarFilter = 'all';
  static const statuses = {
    'pending': 'A fazer',
    'in_progress': 'Em andamento',
    'done': 'Concluída'
  };
  static const priorities = {'high': 'Alta', 'medium': 'Média', 'low': 'Baixa'};
  static const pillars = {
    'positioning': 'Posicionamento Único',
    'promise': 'Promessa Atrativa',
    'funnel': 'Funil de Venda Poderoso',
    'closing': 'Fechamento Irrecusável',
    'general': 'Geral'
  };

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final result = await ApiService().actionPlan();
      if (mounted)
        setState(() {
          items = result;
          loading = false;
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          loading = false;
          error = 'Não foi possível carregar o plano. Tente novamente.';
        });
    }
  }

  DateTime? due(dynamic item) => DateTime.tryParse(item['due_date'] ?? '');
  bool overdue(dynamic item) {
    final now = DateTime.now(), date = due(item);
    return item['status'] != 'done' &&
        date != null &&
        date.isBefore(DateTime(now.year, now.month, now.day));
  }

  String dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<bool> update(dynamic item, Map<String, dynamic> changes) async {
    setState(() => savingId = item['id']);
    try {
      await ApiService().updateAction(item['id'], changes);
      if (mounted)
        setState(() {
          items = [
            for (final current in items)
              if (current['id'] == item['id'])
                {...Map<String, dynamic>.from(current), ...changes}
              else
                current
          ];
        });
      await reload();
      return true;
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Não foi possível salvar. Sua alteração não foi confirmada.')));
      return false;
    } finally {
      if (mounted)
        setState(() {
          savingId = null;
          actionRevision++;
        });
    }
  }

  Future<void> edit(dynamic item) async {
    String priority =
        priorities.containsKey(item['priority']) ? item['priority'] : 'medium';
    DateTime? date = due(item);
    String notes = item['notes'] ?? '';
    int progress = ((item['progress_percent'] ?? (item['status'] == 'done' ? 100 : 0)) as num).round().clamp(0, 100);
    bool savingSheet = false;
    String? sheetError;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
          builder: (c, setSheet) => SafeArea(
                  child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    20, 8, 20, MediaQuery.of(c).viewInsets.bottom + 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Organizar ação',
                          style: Theme.of(c).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(item['title'] ?? ''),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                          initialValue: priority,
                          decoration:
                              const InputDecoration(labelText: 'Prioridade'),
                          items: [
                            for (final e in priorities.entries)
                              DropdownMenuItem(
                                  value: e.key, child: Text(e.value))
                          ],
                          onChanged: savingSheet
                              ? null
                              : (v) {
                                  if (v != null) setSheet(() => priority = v);
                                }),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, children: [
                        OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today),
                            label: Text(date == null
                                ? 'Definir prazo'
                                : dateLabel(date!)),
                            onPressed: savingSheet
                                ? null
                                : () async {
                                    final now = DateTime.now(),
                                        current = date ?? DateTime.now();
                                    final picked = await showDatePicker(
                                        context: c,
                                        initialDate: current,
                                        firstDate: DateTime(current.year < 2000
                                            ? current.year
                                            : 2000),
                                        lastDate: DateTime(
                                            current.year > now.year + 20
                                                ? current.year
                                                : now.year + 20,
                                            12,
                                            31),
                                        helpText: 'Definir prazo',
                                        cancelText: 'Cancelar',
                                        confirmText: 'Salvar');
                                    if (picked != null && c.mounted)
                                      setSheet(() => date = picked);
                                  }),
                        if (date != null)
                          TextButton(
                              onPressed: savingSheet
                                  ? null
                                  : () => setSheet(() => date = null),
                              child: const Text('Remover prazo')),
                      ]),
                      const SizedBox(height: 12),
                      Text('Progresso da ação: $progress%', style: Theme.of(c).textTheme.titleSmall),
                      Slider(
                        value: progress.toDouble(), min: 0, max: 100, divisions: 10,
                        label: '$progress%',
                        onChanged: savingSheet ? null : (v) => setSheet(() => progress = v.round()),
                      ),
                      Text(progress == 100 ? 'Ao salvar, esta ação será marcada como concluída.' : progress > 0 ? 'O progresso indica quanto desta ação já foi executado.' : 'A ação ainda não foi iniciada.'),
                      const SizedBox(height: 12),
                      TextFormField(
                          enabled: !savingSheet,
                          initialValue: notes,
                          onChanged: (value) => notes = value,
                          maxLines: 4,
                          maxLength: 5000,
                          decoration: const InputDecoration(
                              labelText: 'Observações',
                              hintText:
                                  'Registre o andamento e os próximos passos.')),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: savingSheet
                              ? null
                              : () async {
                                  setSheet(() {
                                    savingSheet = true;
                                    sheetError = null;
                                  });
                                  final saved = await update(item, {
                                    'priority': priority,
                                    'due_date': date == null
                                        ? null
                                        : '${date!.year.toString().padLeft(4, '0')}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
                                    'notes': notes.trim(),
                                    'progress_percent': progress,
                                  });
                                  if (!c.mounted) return;
                                  if (saved) {
                                    Navigator.pop(sheet);
                                  } else {
                                    setSheet(() {
                                      savingSheet = false;
                                      sheetError =
                                          'Não foi possível salvar. Revise e tente novamente.';
                                    });
                                  }
                                },
                          child: Text(
                              savingSheet ? 'Salvando...' : 'Salvar ação')),
                      if (sheetError != null)
                        Text(sheetError!,
                            style: const TextStyle(color: Colors.red)),
                    ]),
              ))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = items.where((x) => x['status'] == 'done').length;
    final late = items.where(overdue).length;
    final filtered = items
        .where((x) =>
            (statusFilter == 'all' || x['status'] == statusFilter) &&
            (pillarFilter == 'all' || x['pillar_key'] == pillarFilter))
        .toList();
    int rank(dynamic x) => x['status'] == 'done'
        ? 4
        : overdue(x)
            ? 0
            : ({'high': 1, 'medium': 2, 'low': 3}[x['priority']] ?? 2);
    filtered.sort((a, b) {
      final priority = rank(a).compareTo(rank(b));
      if (priority != 0) return priority;
      final date =
          (due(a) ?? DateTime(9999)).compareTo(due(b) ?? DateTime(9999));
      return date != 0
          ? date
          : ((a['sort_order'] ?? 0) as num)
              .compareTo((b['sort_order'] ?? 0) as num);
    });
    return Scaffold(
        appBar: AppBar(title: const Text('Plano de ação')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: reload,
                child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (error != null) ...[
                        Text(error!, style: const TextStyle(color: Colors.red)),
                        TextButton(
                            onPressed: reload,
                            child: const Text('Tentar novamente'))
                      ],
                      if (items.isEmpty && error == null) ...[
                        const Text(
                            'Seu plano de ação aparecerá após gerar a estratégia dos quatro pilares.'),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const ReportScreen()))
                                .then((_) => reload()),
                            child: const Text('Abrir estratégia')),
                      ] else if (items.isNotEmpty) ...[
                        Text('$done de ${items.length} ações concluídas',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: done / items.length),
                        const SizedBox(height: 8),
                        Text('$late ações com prazo vencido'),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                            initialValue: statusFilter,
                            decoration:
                                const InputDecoration(labelText: 'Situação'),
                            items: [
                              const DropdownMenuItem(
                                  value: 'all',
                                  child: Text('Todas as situações')),
                              for (final e in statuses.entries)
                                DropdownMenuItem(
                                    value: e.key, child: Text(e.value))
                            ],
                            onChanged: (v) =>
                                setState(() => statusFilter = v ?? 'all')),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                            initialValue: pillarFilter,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: 'Pilar'),
                            items: [
                              const DropdownMenuItem(
                                  value: 'all',
                                  child: Text('Todos os pilares')),
                              for (final e in pillars.entries)
                                DropdownMenuItem(
                                    value: e.key, child: Text(e.value))
                            ],
                            onChanged: (v) =>
                                setState(() => pillarFilter = v ?? 'all')),
                        const SizedBox(height: 16),
                        if (filtered.isEmpty)
                          const Text('Nenhuma ação corresponde aos filtros.'),
                        for (final item in filtered)
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(item['title'] ?? '',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                        const SizedBox(height: 6),
                                        Text(
                                            '${pillars[item['pillar_key']] ?? 'Geral'} • Prioridade ${priorities[item['priority']] ?? 'Média'}'),
                                        const SizedBox(height: 8),
                                        Text(item['description'] ?? ''),
                                        const SizedBox(height: 8),
                                        Row(children: [Expanded(child: LinearProgressIndicator(value: (((item['progress_percent'] ?? (item['status'] == 'done' ? 100 : 0)) as num).clamp(0,100))/100)), const SizedBox(width: 10), Text('${((item['progress_percent'] ?? (item['status'] == 'done' ? 100 : 0)) as num).round()}%')]),
                                        const SizedBox(height: 8),
                                        Text(
                                            due(item) == null
                                                ? 'Sem prazo definido'
                                                : 'Prazo: ${dateLabel(due(item)!)}${overdue(item) ? ' • Vencido' : ''}',
                                            style: TextStyle(
                                                color: overdue(item)
                                                    ? Colors.red
                                                    : null)),
                                        if ((item['notes'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                          Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 8),
                                              child: Text(
                                                  'Observações: ${item['notes']}')),
                                        const SizedBox(height: 12),
                                        DropdownButtonFormField<String>(
                                            key: ValueKey(
                                                '${item['id']}-${item['status']}-$actionRevision'),
                                            initialValue: statuses
                                                    .containsKey(item['status'])
                                                ? item['status']
                                                : 'pending',
                                            decoration: const InputDecoration(
                                                labelText: 'Andamento'),
                                            items: [
                                              for (final e in statuses.entries)
                                                DropdownMenuItem(
                                                    value: e.key,
                                                    child: Text(e.value))
                                            ],
                                            onChanged: savingId != null
                                                ? null
                                                : (v) {
                                                    if (v != null &&
                                                        v != item['status'])
                                                      update(
                                                          item, {'status': v});
                                                  }),
                                        TextButton.icon(
                                            onPressed: savingId != null
                                                ? null
                                                : () => edit(item),
                                            icon:
                                                const Icon(Icons.edit_calendar),
                                            label: Text(savingId == item['id']
                                                ? 'Salvando...'
                                                : 'Progresso, prazo e observações')),
                                      ]))),
                      ],
                    ]),
              ));
  }
}
