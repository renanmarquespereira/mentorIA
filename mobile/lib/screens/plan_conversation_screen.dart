import 'package:flutter/material.dart';
import '../services/voice_service.dart';
import '../widgets/voice_input.dart';
import '../widgets/voice_player.dart';

class PlanConversationScreen extends StatefulWidget {
  final String pillarKey, pillarName;
  final bool embedded, enabled;
  final ValueChanged<bool>? onBusy;
  const PlanConversationScreen(
      {super.key,
      required this.pillarKey,
      required this.pillarName,
      this.embedded = false,
      this.enabled = true,
      this.onBusy});
  @override
  State<PlanConversationScreen> createState() => _PlanConversationScreenState();
}

class _PlanConversationScreenState extends State<PlanConversationScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  String? audioId, lastAudioId;
  bool voiceBusy = false;
  int voiceRevision = 0;
  void busyChanged() => widget.onBusy?.call(sending || voiceBusy);
  final input = TextEditingController();
  final service = VoiceService();
  List<dynamic> messages = [];
  bool loading = true, sending = false;
  String? error, requestId, lastQuestion;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final rows = await service.conversations(widget.pillarKey);
      if (mounted)
        setState(() {
          messages = rows;
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(
            () => error = 'Não consegui carregar a conversa. Tente novamente.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> send() async {
    final text = input.text.trim();
    if (text.length < 2 || text.length > 4000) {
      setState(() => error = 'Escreva uma dúvida entre 2 e 4.000 caracteres.');
      return;
    }
    if (text != lastQuestion || audioId != lastAudioId) {
      lastQuestion = text;
      lastAudioId = audioId;
      requestId = newRequestId();
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      busyChanged();
      final row = await service.ask(widget.pillarKey, requestId!, text,
          audioId: audioId);
      if (!mounted) return;
      setState(() {
        if (!messages.any((m) => m['id'] == row['id'])) messages.add(row);
        input.clear();
        audioId = null;
        lastAudioId = null;
        voiceRevision++;
        voiceBusy = false;
        lastQuestion = null;
        requestId = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) {
        setState(() => sending = false);
        busyChanged();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Converse sobre seu plano',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 8),
      const Text(
          'Você pode rolar esta tela para consultar o plano e voltar aqui para perguntar. Sua dúvida pode ser digitada ou gravada.'),
      if (loading) const LinearProgressIndicator(),
      for (final m in messages) ...[
        Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Você', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (m['audio_id'] != null) ...[
                        const SizedBox(height: 6),
                        VoicePlayer(key: ValueKey(m['audio_id']), audioId: m['audio_id']),
                      ],
                      if ((m['transcript'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Transcrição: ${m['transcript']}'),
                      ] else ...[
                        const SizedBox(height: 8),
                        Text(m['question'] ?? ''),
                      ],
                    ]))),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Resposta da IA', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  SelectableText(m['reply'] ?? ''),
                ]))),
      ],
      if (error != null) ...[
        Text(error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
        TextButton(
            onPressed: sending || voiceBusy ? null : load,
            child: const Text('Recarregar conversa'))
      ],
      const SizedBox(height: 12),
      TextField(
          controller: input,
          enabled: !sending && widget.enabled,
          minLines: 2,
          maxLines: 5,
          maxLength: 4000,
          decoration: const InputDecoration(
              labelText: 'O que você quer entender melhor?',
              border: OutlineInputBorder())),
      VoiceInput(
          key: ValueKey(voiceRevision),
          pillarKey: widget.pillarKey,
          questionKey: 'plan_chat',
          controller: input,
          enabled: !sending && widget.enabled,
          onAttachment: (id) => setState(() => audioId = id),
          onBusy: (value) {
            setState(() => voiceBusy = value);
            busyChanged();
          }),
      FilledButton.icon(
          onPressed: sending || voiceBusy || !widget.enabled ? null : send,
          icon: const Icon(Icons.send),
          label: Text(sending ? 'Respondendo...' : 'Enviar dúvida')),
    ]);
    if (widget.embedded)
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12), child: content);
    return Scaffold(
        appBar: AppBar(title: Text('${widget.pillarName} • Conversa')),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(16), child: content));
  }
}
