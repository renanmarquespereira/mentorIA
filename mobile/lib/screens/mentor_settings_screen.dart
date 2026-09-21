import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MentorSettingsScreen extends StatefulWidget {
  const MentorSettingsScreen({super.key});
  @override
  State<MentorSettingsScreen> createState() => _S();
}

class _S extends State<MentorSettingsScreen> {
  final strong = TextEditingController();
  final weak = TextEditingController();
  final relevant = TextEditingController();
  final lowRelevant = TextEditingController();
  final valued = TextEditingController();
  final recommended = TextEditingController();
  final avoided = TextEditingController();
  final tone = TextEditingController();
  final ideal = TextEditingController();
  final notes = TextEditingController();

  bool loading = true, saving = false;
  Map<String, dynamic> pillarRules = {};
  String? error;

  List<String> lines(TextEditingController c) => c.text
      .split('\n')
      .map((x) => x.trim())
      .where((x) => x.isNotEmpty)
      .toList();

  String join(dynamic x) => x is List ? x.join('\n') : '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final d = await ApiService().mentorSettings();
      if (!mounted) return;
      pillarRules = Map<String, dynamic>.from(d['pillar_rules'] ?? {});
      strong.text = join(d['authority_strong']);
      weak.text = join(d['authority_weak']);
      relevant.text = join(d['relevant_certifications']);
      lowRelevant.text = join(d['low_relevance_certifications']);
      valued.text = join(d['valued_experiences']);
      recommended.text = join(d['recommended_strategies']);
      avoided.text = join(d['avoided_strategies']);
      tone.text = d['tone_of_voice'] ?? '';
      ideal.text = d['ideal_client_profile'] ?? '';
      notes.text = d['freeform_methodology_notes'] ?? '';
      if (mounted) setState(() => loading = false);
    } catch (_) {
      if (mounted)
        setState(() {
          loading = false;
          error =
              "Não consegui carregar a metodologia. Tente novamente antes de editar.";
        });
    }
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await ApiService().saveMentorSettings({
        'authority_strong': lines(strong),
        'authority_weak': lines(weak),
        'relevant_certifications': lines(relevant),
        'low_relevance_certifications': lines(lowRelevant),
        'valued_experiences': lines(valued),
        'recommended_strategies': lines(recommended),
        'avoided_strategies': lines(avoided),
        'tone_of_voice': tone.text.trim(),
        'ideal_client_profile': ideal.text.trim(),
        'freeform_methodology_notes': notes.text.trim(),
        'pillar_rules': pillarRules
      });
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orientações para a IA salvas.')));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Não consegui salvar. Suas alterações foram mantidas.')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      strong,
      weak,
      relevant,
      lowRelevant,
      valued,
      recommended,
      avoided,
      tone,
      ideal,
      notes
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(String label, TextEditingController c, {int minLines = 3}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          minLines: minLines,
          maxLines: 8,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
            helperText: minLines > 1
                ? 'Uma regra por linha, quando fizer sentido.'
                : null,
          ),
        ),
      );

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Minha metodologia para a IA')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (error != null) ...[
                    Text(error!),
                    TextButton(
                        onPressed: () {
                          setState(() {
                            loading = true;
                            error = null;
                          });
                          load();
                        },
                        child: const Text('Tentar novamente'))
                  ],
                  const Text(
                    'Este é o guia de trabalho da IA. Ela combina estas orientações com respostas, evolução, plano de ação, conversas e preparação de cada mentorada para apoiar sua condução — sem substituir suas decisões.',
                  ),
                  const SizedBox(height: 14),
                  const Text('Critérios da minha mentoria', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  field('Autoridades que considero fortes', strong),
                  field('Autoridades que considero fracas', weak),
                  field('Certificações relevantes', relevant),
                  field('Certificações de baixa relevância', lowRelevant),
                  field('Experiências que valorizo', valued),
                  field('Estratégias que recomendo', recommended),
                  field('Estratégias que evito', avoided),
                  const SizedBox(height: 8),
                  const Text('Como quero que a IA trabalhe comigo', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                      'Seu jeito de conversar: registre expressões que usa, palavras que prefere evitar e como costuma orientar. Exemplo: show de bola, sensacional, pontos a melhorar e o que falta. Essas preferências também orientam a conversa sobre cada plano.'),
                  field('Tom de comunicação', tone, minLines: 2),
                  field('Perfil de cliente ideal', ideal, minLines: 3),
                  field('Orientações adicionais para a IA', notes,
                      minLines: 5),
                  FilledButton.icon(
                    onPressed: saving || error != null ? null : save,
                    icon: const Icon(Icons.save),
                    label: Text(saving ? 'Salvando...' : 'Salvar orientações para a IA'),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
      );
}
