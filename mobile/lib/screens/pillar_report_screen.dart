import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/api_service.dart';
import 'pillar_screen.dart';
import 'report_screen.dart';
import 'plan_conversation_screen.dart';
import '../widgets/voice_input.dart';

class PillarReportScreen extends StatefulWidget {
  final String pillarKey;
  final String pillarName;

  const PillarReportScreen({
    super.key,
    required this.pillarKey,
    required this.pillarName,
  });

  @override
  State<PillarReportScreen> createState() => _PillarReportScreenState();
}

class _PillarReportScreenState extends State<PillarReportScreen> {
  Map<String, dynamic>? report;
  bool loading = true;
  bool generating = false;
  bool sendingComplement = false;
  String? error, audioId;
  bool voiceBusy = false;
  bool conversationOpen = false,
      conversationCreated = false,
      conversationBusy = false;
  int voiceRevision = 0;
  final complement = TextEditingController();

  static const modules = [
    ('positioning', 'Posicionamento Único'),
    ('promise', 'Promessa Atrativa'),
    ('funnel', 'Funil de Venda Poderoso'),
    ('closing', 'Fechamento Irrecusável'),
  ];

  bool get isLastModule => widget.pillarKey == modules.last.$1;

  void continueJourney() {
    final index = modules.indexWhere((module) => module.$1 == widget.pillarKey);
    if (index < 0) return;
    if (isLastModule) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const ReportScreen()));
    } else {
      final next = modules[index + 1];
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => PillarScreen(keyName: next.$1, name: next.$2)));
    }
  }

  @override
  void dispose() {
    complement.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await ApiService().pillarReport(widget.pillarKey);
      if (!mounted) return;
      setState(() {
        report = r;
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

  Future<void> sharePdf() async {
    try {
      final bytes = await ApiService().pillarReportPdf(widget.pillarKey);
      await Printing.sharePdf(bytes: bytes, filename: 'pilar-${widget.pillarKey}.pdf');
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível gerar o PDF agora.')));
    }
  }

  Future<void> generate() async {
    setState(() {
      generating = true;
      error = null;
    });

    try {
      final r = await ApiService().generatePillarReport(widget.pillarKey);
      if (!mounted) return;
      setState(() => report = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  Future<void> sendComplement() async {
    final answer = complement.text.trim();
    if (answer.length < 10) {
      setState(
          () => error = 'Escreva um pouco mais para complementar a análise.');
      return;
    }

    setState(() {
      sendingComplement = true;
      error = null;
    });

    try {
      final r = await ApiService().completePillarReport(
        widget.pillarKey,
        answer,
        audioId: audioId,
      );

      if (!mounted) return;

      setState(() {
        report = r;
        complement.clear();
        audioId = null;
        voiceRevision++;
        voiceBusy = false;
      });

      if (r['ready_for_next'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilar validado. O próximo módulo foi liberado.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => sendingComplement = false);
    }
  }

  Future<void> recoverQuestion() async {
    setState(() {
      sendingComplement = true;
      error = null;
    });
    try {
      final r = await ApiService().recoverCompletionQuestion(widget.pillarKey);
      if (mounted) setState(() => report = r);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => sendingComplement = false);
    }
  }

  Widget bullets(String title, List items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            for (final x in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $x'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final ready = report?['ready_for_next'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.pillarName} • Plano'),
        actions: [if (report != null) IconButton(onPressed: sharePdf, tooltip: 'Gerar PDF do Pilar', icon: const Icon(Icons.picture_as_pdf_outlined))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (report == null) ...[
            const Text(
              'Gere o plano deste pilar para validar se ele está realmente completo.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: generating ? null : generate,
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                generating ? 'Analisando...' : 'Gerar plano do pilar',
              ),
            ),
          ] else ...[
            if ((report!['mentor_review_status'] ?? 'none') != 'none')
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Editado pela mentora',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            Text(
              report!['summary'] ?? '',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 14),
            if ((report!['mentor_review_note'] ?? '').toString().isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Observação da mentora',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        report!['mentor_review_note'],
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            if ((report!['perceived_authority'] ?? '').toString().isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Autoridade percebida',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(report!['perceived_authority']),
                    ],
                  ),
                ),
              ),
            bullets('Pontos fortes', report!['strengths'] ?? []),
            bullets('Pontos a melhorar', report!['gaps'] ?? []),
            bullets('Respostas complementares enviadas', [
              for (final answer in (report!['complement_answers'] ?? []))
                answer['answer_text'],
            ]),
            bullets('O que falta', report!['missing_information'] ?? []),
            bullets(
              'Plano prático',
              [
                for (final x in (report!['practical_plan'] ?? []))
                  '${x['title']}: ${x['description']}',
              ],
            ),
            FilledButton.tonalIcon(
                onPressed: voiceBusy || sendingComplement || conversationBusy
                    ? null
                    : () => setState(() {
                          conversationOpen = !conversationOpen;
                          conversationCreated = true;
                        }),
                icon: Icon(conversationOpen
                    ? Icons.expand_less
                    : Icons.chat_bubble_outline),
                label: Text(conversationOpen
                    ? 'Recolher conversa'
                    : 'Conversar sobre meu plano')),
            if (conversationCreated)
              Visibility(
                  visible: conversationOpen,
                  maintainState: true,
                  child: PlanConversationScreen(
                      pillarKey: widget.pillarKey,
                      pillarName: widget.pillarName,
                      embedded: true,
                      enabled: !voiceBusy && !sendingComplement,
                      onBusy: (busy) =>
                          setState(() => conversationBusy = busy))),
            if (ready) ...[
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isLastModule
                              ? 'Pilares concluídos. Continue para sua estratégia.'
                              : 'Pilar validado. O próximo módulo está liberado.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: conversationBusy ? null : continueJourney,
                icon: const Icon(Icons.arrow_forward),
                label: Text(isLastModule
                    ? 'Continuar para a estratégia'
                    : 'Continuar para o próximo módulo'),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Preciso que você complemente uma informação',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        report!['completion_question'] ??
                            'A pergunta deste plano antigo não foi salva. Formule uma nova pergunta com a metodologia da mentora, mantendo seu plano e suas respostas.',
                      ),
                      if ((report!['completion_question'] ?? '')
                          .toString()
                          .trim()
                          .isEmpty)
                        TextButton(
                            onPressed:
                                sendingComplement ? null : recoverQuestion,
                            child:
                                const Text('Formular pergunta complementar')),
                      const SizedBox(height: 14),
                      TextField(
                        controller: complement,
                        enabled: !sendingComplement && !conversationBusy,
                        minLines: 4,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Escreva sua resposta complementar...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      VoiceInput(
                          key: ValueKey(voiceRevision),
                          pillarKey: widget.pillarKey,
                          questionKey: 'report_complement',
                          controller: complement,
                          enabled: !sendingComplement && !conversationBusy,
                          onAttachment: (id) => setState(() => audioId = id),
                          onBusy: (busy) => setState(() => voiceBusy = busy)),
                      FilledButton.icon(
                        onPressed:
                            sendingComplement || voiceBusy || conversationBusy
                                ? null
                                : sendComplement,
                        icon: const Icon(Icons.send),
                        label: Text(
                          sendingComplement
                              ? 'Reanalisando...'
                              : 'Enviar complemento',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}
