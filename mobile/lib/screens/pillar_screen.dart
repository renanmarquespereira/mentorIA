import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'pillar_report_screen.dart';
import 'pillar_history_screen.dart';
import '../widgets/voice_input.dart';

class PillarScreen extends StatefulWidget {
  final String keyName, name;
  const PillarScreen({super.key, required this.keyName, required this.name});
  @override
  State<PillarScreen> createState() => _S();
}

class _S extends State<PillarScreen> {
  Map<String, dynamic>? d;
  final a = TextEditingController();
  bool load = true, send = false;
  String? fb, err, audioId;
  bool voiceBusy = false;
  int voiceRevision = 0;
  int questionIndex = 0;
  final Map<String, String> drafts = {};
  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get questions =>
      List<dynamic>.from(d?["questions"] ?? const [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  void loadQuestionText() {
    final qs = questions;
    if (qs.isEmpty) {
      a.clear();
      return;
    }
    questionIndex = questionIndex.clamp(0, qs.length - 1).toInt();
    final key = qs[questionIndex]['key'].toString();
    final saved = Map<String, dynamic>.from(d?["answers"] ?? const {})[key];
    a.text = drafts[key] ?? (saved is Map ? '${saved['answer_text'] ?? ''}' : '');
    a.selection = TextSelection.collapsed(offset: a.text.length);
    audioId = null;
    voiceRevision++;
    fb = null;
  }

  Future<void> reload({int? preferredIndex}) async {
    try {
      final x = await ApiService().pillar(widget.keyName);
      if (!mounted) return;
      setState(() {
        d = x;
        load = false;
        final qs = List<dynamic>.from(x['questions'] ?? const []);
        if (qs.isNotEmpty) {
          if (preferredIndex != null) {
            questionIndex = preferredIndex.clamp(0, qs.length - 1).toInt();
          } else {
            final next = x['next_question'];
            final nextKey = next is Map ? next['key'] : null;
            final idx = qs.indexWhere((item) => item is Map && item['key'] == nextKey);
            questionIndex = idx >= 0 ? idx : qs.length - 1;
          }
        }
        loadQuestionText();
      });
    } catch (e) {
      if (mounted) setState(() { err = '$e'; load = false; });
    }
  }

  void moveQuestion(int delta) {
    final qs = questions;
    if (qs.isEmpty) return;
    final currentKey = qs[questionIndex]['key'].toString();
    drafts[currentKey] = a.text;
    setState(() {
      questionIndex = (questionIndex + delta).clamp(0, qs.length - 1).toInt();
      loadQuestionText();
    });
  }

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> submit() async {
    final qs = questions;
    if (qs.isEmpty || a.text.trim().isEmpty) return;
    final q = qs[questionIndex];
    setState(() => send = true);
    try {
      final r = await ApiService()
          .answer(widget.keyName, q['key'], a.text.trim(), audioId: audioId);
      if (!mounted) return;
      setState(() {
        audioId = null;
        voiceRevision++;
        voiceBusy = false;
      });
      final ai = r['ai_analysis'];
      if (mounted) setState(() => fb = ai?['feedback']);
      if (r['status'] == 'answered_ai' || r['status'] == 'answered') {
        drafts[q['key'].toString()] = a.text.trim();
        final nextIndex = questionIndex < qs.length - 1 ? questionIndex + 1 : questionIndex;
        await reload(preferredIndex: nextIndex);
      }
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => send = false);
    }
  }

  Future<void> openCoach(Map<String,dynamic> q) async {
    final msg = TextEditingController();
    final history = <Map<String,String>>[];
    bool busy = false;
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx,setLocal) => AlertDialog(
      title: const Text('Conversar com a IA'),
      content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Tire dúvidas sobre como melhorar sua resposta. A IA orienta, mas a resposta final continua sendo sua.'),
        const SizedBox(height:12),
        Flexible(child: SingleChildScrollView(child: Column(crossAxisAlignment:CrossAxisAlignment.stretch,children: history.map((m)=>Padding(padding:const EdgeInsets.only(bottom:8),child:Text('${m['role']=='user'?'Você':'IA'}: ${m['content']}'))).toList()))),
        TextField(controller:msg,minLines:2,maxLines:4,decoration:const InputDecoration(hintText:'Ex.: O que está faltando na minha resposta?')),
      ])),
      actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(ctx),child:const Text('Fechar')),FilledButton(onPressed:busy?null:() async {final text=msg.text.trim();if(text.isEmpty)return;setLocal((){busy=true;history.add({'role':'user','content':text});msg.clear();});try{final r=await ApiService().answerCoach(widget.keyName,q['key'].toString(),a.text.trim(),text,history);setLocal(()=>history.add({'role':'assistant','content':r['reply']?.toString()??''}));}catch(e){setLocal(()=>history.add({'role':'assistant','content':'Não consegui responder agora. Tente novamente.'}));}finally{setLocal(()=>busy=false);}},child:Text(busy?'Pensando...':'Enviar'))]
    )));
    msg.dispose();
  }

  Future<void> redoPillar() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Refazer este pilar?'),
      content: const Text('Será iniciada uma nova avaliação. Suas respostas e a avaliação anterior serão preservadas no histórico e continuarão válidas até você concluir a nova rodada.'),
      actions: [
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Refazer pilar')),
      ],
    ));
    if(ok!=true)return;
    setState((){load=true;err=null;fb=null;a.clear();});
    try { await ApiService().redoPillar(widget.keyName); await reload(); }
    catch(e){if(mounted)setState((){err='$e';load=false;});}
  }

  Future<void> cancelRedo() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar nova avaliação?'),
        content: const Text('As respostas desta nova tentativa serão descartadas e a avaliação anterior será restaurada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancelar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() { load = true; err = null; fb = null; drafts.clear(); });
    try {
      await ApiService().cancelRedoPillar(widget.keyName);
      await reload();
    } catch (e) {
      if (mounted) setState(() { err = '$e'; load = false; });
    }
  }

  @override
  Widget build(BuildContext c) {
    if (load)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final qs = questions;
    final q = qs.isEmpty ? null : qs[questionIndex];
    final allAnswered = d?['next_question'] == null && qs.isNotEmpty;
    final completed = d?['report_generated'] == true && d?['redo_in_progress'] != true;
    final prog = ((d?['progress'] ?? 0) as num).toDouble();
    return Scaffold(
        appBar: AppBar(title: Text(widget.name)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          LinearProgressIndicator(value: prog / 100),
          const SizedBox(height: 6),
          Text('${prog.toInt()}% concluído'),
          if (d?['redo_in_progress'] == true) ...[
            const SizedBox(height: 12),
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Nova avaliação em andamento. A avaliação anterior está preservada e só será substituída quando esta rodada for concluída.'),
              const SizedBox(height: 8),
              TextButton.icon(onPressed: cancelRedo, icon: const Icon(Icons.close), label: const Text('Cancelar')),
            ]))),
          ],
          const SizedBox(height: 24),
          if (d?['unlocked'] != true)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('Conclua o pilar anterior para desbloquear.')))
          else if (completed)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [Icon(Icons.check_circle_outline), SizedBox(width: 8), Text('Pilar concluído', style: TextStyle(fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 8),
                      const Text('Este pilar já foi concluído. As perguntas ficam ocultas; abra o plano para consultar o resultado.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PillarReportScreen(pillarKey: widget.keyName, pillarName: widget.name))).then((_) => reload()),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Visualizar plano'),
                      ),
                    ])))
          else if (q == null)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Perguntas concluídas.', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Agora gere o Plano do Pilar. O próximo módulo só será liberado quando a IA confirmar que não falta nenhuma informação essencial.'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PillarReportScreen(pillarKey: widget.keyName, pillarName: widget.name))).then((_) => reload()),
                        child: const Text('Gerar / abrir Plano do Pilar'),
                      )
                    ])))
          else ...[
            Text('Pergunta ${questionIndex + 1} de ${qs.length}', style: Theme.of(c).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(q['title'] ?? '', style: Theme.of(c).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(q['question'] ?? ''),
            const SizedBox(height: 16),
            TextField(
                controller: a,
                enabled: !send,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Escreva sua resposta...')),
            const SizedBox(height: 12),
            VoiceInput(
                key: ValueKey('${q['key']}_$voiceRevision'),
                pillarKey: widget.keyName,
                questionKey: q['key'],
                controller: a,
                enabled: !send,
                onAttachment: (id) => setState(() => audioId = id),
                onBusy: (busy) => setState(() => voiceBusy = busy)),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: send || voiceBusy || questionIndex == 0 ? null : () => moveQuestion(-1),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Anterior'),
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                onPressed: send || voiceBusy || questionIndex >= qs.length - 1 ? null : () => moveQuestion(1),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Próxima'),
              )),
            ]),
            const SizedBox(height: 10),
            FilledButton(
                onPressed: send || voiceBusy ? null : submit,
                child: Text(send ? 'Analisando...' : 'Salvar resposta'))
          ],
          if (allAnswered && !completed) ...[
            const SizedBox(height: 14),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Perguntas concluídas.', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Você ainda pode voltar às perguntas acima e reformular qualquer resposta antes de abrir o plano do pilar.'),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PillarReportScreen(pillarKey: widget.keyName, pillarName: widget.name))).then((_) => reload()),
                child: Text(d?['report_generated'] == true ? 'Visualizar plano' : 'Gerar / abrir Plano do Pilar'),
              ),
            ]))),
          ],
          if (d?['report_generated'] == true && d?['redo_in_progress'] != true) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: redoPillar, icon: const Icon(Icons.refresh), label: const Text('Refazer este pilar')),
          ],
          if (d?['report_generated'] == true) ...[
            const SizedBox(height: 8),
            TextButton.icon(onPressed: ()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>PillarHistoryScreen(pillarKey:widget.keyName,pillarName:widget.name))), icon: const Icon(Icons.history), label: const Text('Ver histórico de avaliações')),
          ],
          if (fb != null)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                          Text(fb!),
                          if (q != null && a.text.trim().isNotEmpty) ...[
                            const SizedBox(height:12),
                            OutlinedButton.icon(onPressed:()=>openCoach(Map<String,dynamic>.from(q)),icon:const Icon(Icons.chat_bubble_outline),label:const Text('Conversar com a IA sobre esta resposta'))
                          ]
                        ])))),
          if (err != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(err!, style: const TextStyle(color: Colors.red)))
        ]));
  }
}
