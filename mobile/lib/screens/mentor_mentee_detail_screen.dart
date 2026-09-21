import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/api_service.dart';
import '../widgets/mentor_ai_conversation.dart';
import 'mentor_edit_pillar_report_screen.dart';
import 'mentor_sessions_screen.dart';

class MentorMenteeDetailScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const MentorMenteeDetailScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<MentorMenteeDetailScreen> createState() =>
      _MentorMenteeDetailScreenState();
}

class _MentorMenteeDetailScreenState extends State<MentorMenteeDetailScreen> {
  Map<String, dynamic>? data;
  bool loading = true;
  bool generatingBrief = false;
  Map<String, dynamic>? intelligentBrief;
  Map<String, dynamic>? evolution;
  bool loadingEvolution = false;
  bool showEvolution = false;
  bool showBrief = false;
  List<dynamic> privateNotes = [];
  bool loadingNotes = false;

  static const pillarNames = {
    'positioning': 'Posicionamento Único',
    'promise': 'Promessa Atrativa',
    'funnel': 'Funil de Venda Poderoso',
    'closing': 'Fechamento Irrecusável',
  };

  String statusLabel(dynamic status) {
    switch ('$status') {
      case 'validated':
        return 'Concluído';
      case 'answered_ai':
        return 'Respondido';
      case 'needs_report_completion':
        return 'Aguardando complemento';
      case 'in_diagnosis':
        return 'Em andamento';
      case 'needs_review':
        return 'Aguardando revisão';
      case 'not_started':
      default:
        return 'Não iniciado';
    }
  }

  @override
  void initState() {
    super.initState();
    reload();
    loadPrivateNotes();
    loadCachedIntelligence();
  }

  Future<void> loadCachedIntelligence() async {
    try {
      final cached = await ApiService().menteeIntelligenceCache(widget.userId);
      if (!mounted) return;
      final cachedBrief = cached['brief'];
      final cachedEvolution = cached['evolution'];
      setState(() {
        if (cachedBrief is Map) intelligentBrief = Map<String, dynamic>.from(cachedBrief);
        if (cachedEvolution is Map) evolution = Map<String, dynamic>.from(cachedEvolution);
      });
    } catch (_) {
      // Cache é opcional: o painel continua funcionando mesmo sem snapshot anterior.
    }
  }

  Future<void> reload() async {
    final result = await ApiService().menteeOverview(widget.userId);
    if (!mounted) return;
    setState(() {
      data = result;
      loading = false;
    });
  }

  Future<bool> confirm(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> resetReport(String key) async {
    final ok = await confirm(
      'Resetar Plano do Pilar?',
      'A mentorada receberá um pedido de autorização. O plano só será resetado se ela aprovar.',
    );
    if (!ok) return;

    final result = await ApiService().resetPillarReport(widget.userId, key);
    await reload();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message'] ?? 'Solicitação enviada.')),
    );
  }

  Future<void> loadPrivateNotes() async {
    setState(() => loadingNotes = true);
    try {
      final rows = await ApiService().mentorPrivateNotes(widget.userId);
      if (mounted) setState(() => privateNotes = rows);
    } catch (_) {
      // Notas são um bloco independente: falha aqui não derruba o painel.
    } finally {
      if (mounted) setState(() => loadingNotes = false);
    }
  }

  Future<void> addPrivateNote() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('Anotação privada da mentora'),
      content: TextField(controller: controller, autofocus: true, minLines: 3, maxLines: 7, decoration: const InputDecoration(
        hintText: 'Registre decisões, percepções ou pontos para a próxima sessão.',
        helperText: 'Esta anotação não aparece para a mentorada.',
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Salvar')),
      ],
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (note == null || note.isEmpty) return;
    try {
      await ApiService().addMentorPrivateNote(widget.userId, note);
      await loadPrivateNotes();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> deletePrivateNote(Map<String, dynamic> note) async {
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Excluir anotação?'),
      content: const Text('Esta anotação privada será apagada definitivamente.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
      ],
    )) ?? false;
    if (!ok) return;
    try {
      await ApiService().deleteMentorPrivateNote(widget.userId, note['id'].toString());
      await loadPrivateNotes();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> deleteMenteePermanently() async {
    final typed = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Excluir cadastro definitivamente?'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('O cadastro de ${widget.userName} e todos os dados relacionados serão apagados definitivamente. Esta ação não pode ser desfeita.'),
        const SizedBox(height: 12),
        const Text('Digite EXCLUIR para confirmar.'),
        const SizedBox(height: 8),
        TextField(controller: typed, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'EXCLUIR')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, typed.text.trim().toUpperCase() == 'EXCLUIR'), child: const Text('Excluir definitivamente')),
      ],
    )) ?? false;
    WidgetsBinding.instance.addPostFrameCallback((_) => typed.dispose());
    if (!ok) return;
    try {
      await ApiService().permanentlyDeleteMentee(widget.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastro excluído definitivamente.')));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget privateNotesCard() {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.lock_outline), const SizedBox(width: 8), Expanded(child: Text('Anotações privadas da mentora', style: Theme.of(context).textTheme.titleMedium)), IconButton(onPressed: addPrivateNote, icon: const Icon(Icons.add_comment_outlined), tooltip: 'Nova anotação')]),
      const Text('Visíveis somente para a mentora. A anotação mais recente também marca a última sessão para o resumo de mudanças.'),
      if (loadingNotes) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
      if (!loadingNotes && privateNotes.isEmpty) const Padding(padding: EdgeInsets.only(top: 10), child: Text('Nenhuma anotação privada ainda.')),
      for (final n in privateNotes.take(5)) ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.note_alt_outlined), title: Text(n['note'] ?? ''), trailing: IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Excluir anotação', onPressed: () => deletePrivateNote(Map<String, dynamic>.from(n)))),
      const SizedBox(height: 6),
      OutlinedButton.icon(onPressed: addPrivateNote, icon: const Icon(Icons.add), label: const Text('Adicionar anotação privada')),
    ])));
  }

  Future<void> loadEvolution() async {
    setState(() => loadingEvolution = true);
    try {
      final result = await ApiService().menteeEvolution(widget.userId);
      if (!mounted) return;
      setState(() { evolution = result; showEvolution = true; });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => loadingEvolution = false);
    }
  }

  String evolutionStatus(dynamic status) {
    switch ('$status') {
      case 'validated': return 'Validado';
      case 'in_progress': return 'Em andamento';
      case 'answered_ai': return 'Respondido';
      default: return 'Em evolução';
    }
  }

  Widget evolutionCard() {
    final evo = evolution;
    if (evo == null) return const SizedBox.shrink();
    final summary = Map<String, dynamic>.from(evo['summary'] ?? const {});
    final pillars = List<dynamic>.from(evo['pillars'] ?? const []);
    final alerts = List<dynamic>.from(evo['alerts'] ?? const []);
    final timeline = List<dynamic>.from(evo['timeline'] ?? const []);
    final actions = Map<String, dynamic>.from(evo['actions'] ?? const {});
    final pending = List<dynamic>.from(actions['pending'] ?? const []);
    final inProgress = List<dynamic>.from(actions['in_progress'] ?? const []);
    final completed = List<dynamic>.from(actions['completed'] ?? const []);

    Widget actionGroup(String title, List<dynamic> items, IconData icon) {
      if (items.isEmpty) return const SizedBox.shrink();
      return ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text('$title (${items.length})'),
        children: [for (final item in items) ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 12),
          title: Text(item['title'] ?? ''),
          subtitle: item['overdue'] == true ? const Text('Prazo vencido') : null,
        )],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.insights), const SizedBox(width: 8), Expanded(child: Text('Acompanhamento de Evolução', style: Theme.of(context).textTheme.titleMedium))]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Chip(label: Text('${summary['validated_pillars'] ?? 0}/4 pilares validados')),
            Chip(label: Text('${summary['completed_actions'] ?? 0}/${summary['total_actions'] ?? 0} ações concluídas')),
            if ((summary['overdue_actions'] ?? 0) > 0) Chip(label: Text('${summary['overdue_actions']} vencidas')),
          ]),
          const SizedBox(height: 10),
          if (Map<String, dynamic>.from(evo['since_last_session'] ?? const {})['baseline_at'] != null) ...[
            const Text('O que mudou desde a última vez', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (List<dynamic>.from(Map<String, dynamic>.from(evo['since_last_session'] ?? const {})['items'] ?? const []).isEmpty)
              const Text('Nenhuma mudança registrada desde a última anotação da mentora.')
            else
              for (final change in List<dynamic>.from(Map<String, dynamic>.from(evo['since_last_session'] ?? const {})['items'] ?? const []))
                ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.change_circle_outlined), title: Text(change['text'] ?? '')),
            const Divider(height: 22),
          ],
          const Text('Evolução por pilar', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          for (final p in pillars) Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(p['label'] ?? '')), Text('${p['score'] ?? 0}% • ${evolutionStatus(p['status'])}')]),
              const SizedBox(height: 3),
              LinearProgressIndicator(value: ((p['score'] ?? 0) as num).toDouble().clamp(0, 100) / 100),
            ]),
          ),
          if (alerts.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Alertas para a mentora', style: TextStyle(fontWeight: FontWeight.bold)),
            for (final a in alerts) ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.notification_important_outlined), title: Text(a['title'] ?? ''), subtitle: Text(a['detail'] ?? '')),
          ],
          const Divider(height: 24),
          const Text('Ações do plano', style: TextStyle(fontWeight: FontWeight.bold)),
          const Text('Compromissos e tarefas definidos para a mentorada executar.', style: TextStyle(fontSize: 12)),
          actionGroup('Em andamento', inProgress, Icons.timelapse),
          actionGroup('Pendentes', pending, Icons.pending_actions),
          actionGroup('Concluídas', completed, Icons.task_alt),
          if (timeline.isNotEmpty) ...[
            const Divider(height: 24),
            const Text('Atividades recentes', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('O que a mentorada fez recentemente no app: pilares, plano, IA e estratégia.', style: TextStyle(fontSize: 12)),
            for (final event in timeline.take(8)) ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.circle, size: 10), title: Text(event['title'] ?? ''), subtitle: Text(event['detail'] ?? '')),
          ],
          if ((evo['note'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(evo['note'], style: Theme.of(context).textTheme.bodySmall),
          ],
        ]),
      ),
    );
  }

  Future<void> generateIntelligentBrief() async {
    setState(() => generatingBrief = true);
    try {
      final result = await ApiService().generateMenteeIntelligentBrief(widget.userId);
      if (!mounted) return;
      setState(() { intelligentBrief = result; showBrief = true; });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível gerar o resumo inteligente agora.')),
      );
    } finally {
      if (mounted) setState(() => generatingBrief = false);
    }
  }

  Widget briefList(String title, dynamic values, IconData icon) {
    final items = List<dynamic>.from(values ?? const []);
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 19), const SizedBox(width: 7), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)))]),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 5, left: 4),
              child: Text('• $item'),
            ),
        ],
      ),
    );
  }

  Widget intelligentBriefCard() {
    final brief = intelligentBrief;
    if (brief == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.auto_awesome),
              const SizedBox(width: 8),
              Expanded(child: Text('Resumo Inteligente da Mentorada', style: Theme.of(context).textTheme.titleMedium)),
            ]),
            const SizedBox(height: 10),
            Text(brief['intelligent_summary'] ?? ''),
            if ((brief['current_moment'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Momento atual', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(brief['current_moment']),
            ],
            briefList('Evoluções e destaques', brief['progress_highlights'], Icons.trending_up),
            briefList('Pontos de atenção', brief['attention_points'], Icons.flag_outlined),
            if (List<dynamic>.from(brief['source_answers'] ?? const []).isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: const Icon(Icons.question_answer_outlined),
                title: const Text('Perguntas e respostas da mentorada'),
                subtitle: const Text('Visualizar / ocultar as respostas usadas como contexto'),
                children: [for (final item in List<dynamic>.from(brief['source_answers'] ?? const []))
                  ListTile(dense: true, contentPadding: const EdgeInsets.only(left: 12), title: Text(item['question'] ?? 'Pergunta'), subtitle: Text(item['answer'] ?? ''))],
              ),
            const Divider(height: 28),
            Text('Preparar Próxima Mentoria', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Objetivo principal', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(brief['next_mentoring_objective'] ?? ''),
            briefList('Pauta sugerida', brief['suggested_agenda'], Icons.view_agenda_outlined),
            briefList('Perguntas para aprofundar', brief['questions_to_ask'], Icons.help_outline),
            briefList('Ações para revisar', brief['actions_to_review'], Icons.task_alt),
            briefList('Notas para a mentora', brief['mentor_notes'], Icons.edit_note),
          ],
        ),
      ),
    );
  }

  Future<void> shareMentorPillarPdf(String key) async {
    try {
      final bytes = await ApiService().mentorPillarReportPdf(widget.userId, key);
      await Printing.sharePdf(bytes: bytes, filename: 'pilar-$key-${widget.userName.replaceAll(' ', '-').toLowerCase()}.pdf');
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível gerar o PDF agora.')));
    }
  }

  Future<void> resetJourney() async {
    final ok = await confirm(
      'Resetar toda a jornada?',
      'A mentorada receberá um pedido de autorização. Nada será apagado até que ela aprove o reset de toda a jornada.',
    );
    if (!ok) return;

    final result = await ApiService().resetMenteeJourney(widget.userId);
    await reload();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message'] ?? 'Solicitação enviada.')),
    );
  }

  Widget pillarCard(String key, Map<String, dynamic> pillar) {
    final progress = Map<String, dynamic>.from(pillar['progress'] ?? const {});
    final answers = List<dynamic>.from(pillar['answers'] ?? const []);
    final report = pillar['report'];
    final pending = List<dynamic>.from(data?['pending_reset_requests'] ?? const []);
    final pillarResetPending = pending.any((r) => r['reset_type'] == 'pillar_report' && r['pillar_key'] == key);

    return Card(
      child: ExpansionTile(
        title: Text(pillarNames[key] ?? key),
        subtitle: Text(
          '${progress['score'] ?? 0}% • ${statusLabel(progress['status'])}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (answers.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Nenhuma resposta registrada.'),
            )
          else ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Perguntas e respostas',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            for (final answer in answers)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  title: Text(
                    answer['question_text'] ?? answer['question_title'] ?? 'Pergunta registrada',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Resposta',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            answer['answer_text'] ?? '',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 12),
          MentorAiConversation(pillarKey: key, ownerId: widget.userId),
          if (report != null) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Plano do Pilar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(report['summary'] ?? ''),
            ),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
              onPressed: () => shareMentorPillarPdf(key),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Gerar PDF do Pilar'),
            )),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MentorEditPillarReportScreen(
                          userId: widget.userId,
                          pillarKey: key,
                          pillarName: pillarNames[key] ?? key,
                          report: Map<String, dynamic>.from(report),
                        ),
                      ),
                    ).then((changed) {
                      if (changed == true) reload();
                    }),
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar Plano'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: pillarResetPending ? null : () => resetReport(key),
                    icon: const Icon(Icons.restart_alt),
                    label: Text(pillarResetPending ? 'Aguardando autorização' : 'Solicitar reset'),
                  ),
                ),
              ],
            ),
            if ((report['mentor_review_status'] ?? 'none') != 'none') ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: const Icon(Icons.verified_user, size: 17),
                  label: const Text('Revisado pela mentora'),
                ),
              ),
            ],
          ] else
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Plano do pilar ainda não gerado.'),
            ),
        ],
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.userName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final user = Map<String, dynamic>.from(data?['user'] ?? const {});
    final pillars = Map<String, dynamic>.from(data?['pillars'] ?? const {});
    final pending = List<dynamic>.from(data?['pending_reset_requests'] ?? const []);
    final journeyResetPending = pending.any((r) => r['reset_type'] == 'journey');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                radius: 26,
                backgroundImage: photoProvider(user['profile_photo']),
                child: photoProvider(user['profile_photo']) == null ? const Icon(Icons.person) : null,
              ),
              title: Text(user['name'] ?? widget.userName),
              subtitle: Text(
                [
                  user['email'] ?? '',
                  if ((user['phone'] ?? '').toString().isNotEmpty)
                    user['phone'],
                ].join('\n'),
              ),
              trailing: Chip(
                label: Text(
                  user['access_status_label'] ?? 'Bloqueado',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(child:ListTile(
            leading:Builder(builder:(_){final count=(data?['pending_mentoring_count']??0) as num;return Badge(isLabelVisible:count>0,label:Text('${count.toInt()}'),child:const Icon(Icons.calendar_month));}),
            title:const Text('Sessões de mentoria'),
            subtitle:const Text('Agendar, concluir e consultar o histórico de encontros.'),
            trailing:const Icon(Icons.chevron_right),
            onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>MentorSessionsScreen(userId:widget.userId,userName:widget.userName))).then((_)=>reload()),
          )),
          const SizedBox(height: 12),
          if (data?['latest_checkin'] != null) ...[
            Builder(builder: (_) {
              final check = Map<String, dynamic>.from(data!['latest_checkin']);
              return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Icon(Icons.fact_check_outlined), const SizedBox(width: 8), Expanded(child: Text('Preparação para a próxima mentoria', style: Theme.of(context).textTheme.titleMedium))]),
                const SizedBox(height: 8),
                Text('Avanços: ${check['progress'] ?? ''}'),
                if ((check['blockers'] ?? '').toString().trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Onde precisa de ajuda: ${check['blockers']}', style: const TextStyle(fontWeight: FontWeight.w600))),
                const SizedBox(height: 6),
                Text('Quer discutir: ${check['next_session_topic'] ?? ''}'),
                const SizedBox(height: 6),
                Text('Confiança para a sessão: ${check['confidence_level'] ?? 3}/5'),
              ])));
            }),
            const SizedBox(height: 12),
          ],
          Text('Central de Inteligência da Mentorada', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Mudanças, alertas, preparação da próxima sessão e notas privadas em um só lugar.'),
          const SizedBox(height: 12),
          privateNotesCard(),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: generatingBrief ? null : generateIntelligentBrief,
            icon: generatingBrief
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(generatingBrief
                ? 'Gerando resumo e preparação...'
                : intelligentBrief == null
                    ? 'Resumo Inteligente + Preparar Próxima Mentoria'
                    : 'Atualizar Resumo + Próxima Mentoria'),
          ),
          if (intelligentBrief != null) ...[
            TextButton.icon(onPressed: () => setState(() => showBrief = !showBrief), icon: Icon(showBrief ? Icons.visibility_off_outlined : Icons.visibility_outlined), label: Text(showBrief ? 'Ocultar resumo e próxima mentoria' : 'Visualizar resumo e próxima mentoria')),
            if (showBrief) intelligentBriefCard(),
          ],
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: loadingEvolution ? null : loadEvolution,
            icon: loadingEvolution
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.insights),
            label: Text(loadingEvolution
                ? 'Atualizando evolução...'
                : evolution == null ? 'Acompanhamento de Evolução' : 'Atualizar Evolução'),
          ),
          if (evolution != null) ...[
            TextButton.icon(onPressed: () => setState(() => showEvolution = !showEvolution), icon: Icon(showEvolution ? Icons.visibility_off_outlined : Icons.visibility_outlined), label: Text(showEvolution ? 'Ocultar evolução' : 'Visualizar evolução')),
            if (showEvolution) evolutionCard(),
          ],
          const SizedBox(height: 16),
          Text(
            'Jornada da ${((user['name'] ?? widget.userName).toString().trim().split(' ').first)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final key in [
            'positioning',
            'promise',
            'funnel',
            'closing',
          ])
            pillarCard(
              key,
              Map<String, dynamic>.from(
                pillars[key] ?? const {},
              ),
            ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: journeyResetPending ? null : resetJourney,
            icon: const Icon(Icons.restart_alt),
            label: Text(journeyResetPending ? 'Reset aguardando autorização' : 'Solicitar reset de toda a jornada'),
          ),
          const SizedBox(height: 28),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Administração do cadastro', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text('Use esta opção somente quando os dados desta mentorada não precisarem mais permanecer no sistema.'),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: deleteMenteePermanently, icon: const Icon(Icons.delete_forever_outlined), label: const Text('Excluir cadastro')),
          ]))),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

