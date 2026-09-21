import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MentorEditPillarReportScreen extends StatefulWidget {
  final String userId;
  final String pillarKey;
  final String pillarName;
  final Map<String, dynamic> report;

  const MentorEditPillarReportScreen({
    super.key,
    required this.userId,
    required this.pillarKey,
    required this.pillarName,
    required this.report,
  });

  @override
  State<MentorEditPillarReportScreen> createState() =>
      _MentorEditPillarReportScreenState();
}

class _MentorEditPillarReportScreenState
    extends State<MentorEditPillarReportScreen> {
  late TextEditingController summary;
  late TextEditingController authority;
  late TextEditingController strengths;
  late TextEditingController gaps;
  late TextEditingController missing;
  late TextEditingController plan;
  late TextEditingController note;

  bool saving = false;

  String priorityLabel(dynamic value) => switch ('$value'.toLowerCase()) {
        'high' || 'alta' => 'Alta',
        'low' || 'baixa' => 'Baixa',
        _ => 'Média',
      };

  String priorityValue(String value) => switch (value.toLowerCase()) {
        'alta' || 'high' => 'high',
        'baixa' || 'low' => 'low',
        _ => 'medium',
      };

  String joinLines(dynamic value) {
    if (value is List) {
      return value.map((e) {
        if (e is Map) {
          final title = e['title'] ?? '';
          final description = e['description'] ?? '';
          final priority = priorityLabel(e['priority']);
          return '$title | $description | $priority';
        }
        return '$e';
      }).join('\n');
    }
    return '';
  }

  List<String> simpleLines(TextEditingController c) => c.text
      .split('\n')
      .map((x) => x.trim())
      .where((x) => x.isNotEmpty)
      .toList();

  List<Map<String, dynamic>> planLines() {
    final result = <Map<String, dynamic>>[];

    for (final line in plan.text.split('\n')) {
      final clean = line.trim();
      if (clean.isEmpty) continue;

      final parts = clean.split('|').map((e) => e.trim()).toList();

      result.add({
        'title': parts.isNotEmpty ? parts[0] : 'Ação',
        'description': parts.length > 1 ? parts[1] : '',
        'priority': parts.length > 2 ? priorityValue(parts[2]) : 'medium',
      });
    }

    return result;
  }

  @override
  void initState() {
    super.initState();

    summary = TextEditingController(
      text: widget.report['summary'] ?? '',
    );

    authority = TextEditingController(
      text: widget.report['perceived_authority'] ?? '',
    );

    strengths = TextEditingController(
      text: joinLines(widget.report['strengths']),
    );

    gaps = TextEditingController(
      text: joinLines(widget.report['gaps']),
    );

    missing = TextEditingController(
      text: joinLines(widget.report['missing_information']),
    );

    plan = TextEditingController(
      text: joinLines(widget.report['practical_plan']),
    );

    note = TextEditingController(
      text: widget.report['mentor_review_note'] ?? '',
    );
  }

  Future<void> save() async {
    setState(() => saving = true);

    await ApiService().mentorEditPillarReport(
      widget.userId,
      widget.pillarKey,
      {
        'summary': summary.text.trim(),
        'perceived_authority': authority.text.trim(),
        'strengths': simpleLines(strengths),
        'gaps': simpleLines(gaps),
        'missing_information': simpleLines(missing),
        'practical_plan': planLines(),
        'mentor_review_note': note.text.trim(),
      },
    );

    if (!mounted) return;

    setState(() => saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Plano revisado pela mentora.'),
      ),
    );

    Navigator.pop(context, true);
  }

  Widget field(
    String label,
    TextEditingController controller, {
    int minLines = 4,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: 14,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          alignLabelWithHint: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Revisar ${widget.pillarName}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Você pode ajustar o material gerado pela IA antes de devolvê-lo à mentorada.',
          ),
          const SizedBox(height: 16),
          field('Resumo', summary, minLines: 5),
          field('Autoridade percebida', authority, minLines: 4),
          field(
            'Pontos fortes',
            strengths,
            helper: 'Um item por linha.',
          ),
          field(
            'Pontos a melhorar',
            gaps,
            helper: 'Uma lacuna por linha.',
          ),
          field(
            'O que falta',
            missing,
            helper: 'Uma informação por linha.',
          ),
          field(
            'Plano prático',
            plan,
            minLines: 6,
            helper:
                'Uma ação por linha: Título | Descrição | prioridade (Alta/Média/Baixa)',
          ),
          field(
            'Observação da mentora',
            note,
            minLines: 3,
            helper: 'Opcional. Esta observação pode ser exibida à mentorada.',
          ),
          FilledButton.icon(
            onPressed: saving ? null : save,
            icon: const Icon(Icons.save),
            label: Text(
              saving ? 'Salvando...' : 'Salvar revisão',
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
