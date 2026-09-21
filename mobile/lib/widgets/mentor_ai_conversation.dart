import 'package:flutter/material.dart';
import '../services/voice_service.dart';
import 'voice_player.dart';

class MentorAiConversation extends StatefulWidget {
  final String pillarKey, ownerId;
  const MentorAiConversation({super.key, required this.pillarKey, required this.ownerId});

  @override
  State<MentorAiConversation> createState() => _MentorAiConversationState();
}

class _MentorAiConversationState extends State<MentorAiConversation> {
  final service = VoiceService();
  List<dynamic> messages = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final rows = await service.conversations(widget.pillarKey, ownerId: widget.ownerId);
      if (!mounted) return;
      setState(() { messages = rows; loading = false; error = null; });
    } catch (_) {
      if (mounted) setState(() { loading = false; error = 'Não consegui carregar as conversas com a IA.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
    if (error != null) return Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error));
    if (messages.isEmpty) return const Align(alignment: Alignment.centerLeft, child: Text('Nenhuma conversa com a IA neste pilar.'));
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text(
          'Conversas com a IA (${messages.length})',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          for (final m in messages) ...[
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Mentorada', style: TextStyle(fontWeight: FontWeight.bold)),
            if (m['audio_id'] != null) ...[
              const SizedBox(height: 6),
              VoicePlayer(key: ValueKey(m['audio_id']), audioId: m['audio_id']),
            ],
            if ((m['transcript'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Transcrição: ${m['transcript']}'),
            ] else ...[
              const SizedBox(height: 6),
              Text(m['question'] ?? ''),
            ],
          ])),
        ),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Resposta da IA', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          SelectableText(m['reply'] ?? ''),
        ]))),
          ],
        ],
      ),
    );
  }
}
