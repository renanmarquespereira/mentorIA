import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'crm_labels.dart';

class MetricFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const MetricFormScreen({super.key, this.initial});
  @override
  State<MetricFormScreen> createState() => _MetricFormScreenState();
}

class _MetricFormScreenState extends State<MetricFormScreen> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  static const labels = {
    'period': 'Período (AAAA-MM)',
    'leads': 'Contatos',
    'calls': 'Reuniões realizadas',
    'sales_count': 'Vendas',
    'revenue': 'Receita (R\$)',
    'ad_spend': 'Gasto com anúncios (R\$)'
  };
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    for (final key in labels.keys) {
      fields[key] = TextEditingController(
          text: (widget.initial?[key] ??
                  (key == 'period'
                      ? '${now.year}-${now.month.toString().padLeft(2, '0')}'
                      : 0))
              .toString());
    }
  }

  @override
  void dispose() {
    for (final f in fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ApiService().saveMetric({
        for (final key in fields.keys)
          key: key == 'period'
              ? fields[key]!.text.trim()
              : ['revenue', 'ad_spend'].contains(key)
                  ? CrmLabels.amount(fields[key]!.text)
                  : int.parse(fields[key]!.text.trim())
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() => error =
            'Não consegui salvar. Confira a conexão e tente novamente.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Resumo do mês')),
        body: Form(
            key: form,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              const Text(
                  'Preencha os totais do mês. Salvar o mesmo período atualiza o resumo mais recente daquele mês. Os dados manuais ficam separados do CRM.'),
              for (final key in fields.keys)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TextFormField(
                        controller: fields[key],
                        enabled: !saving,
                        decoration: InputDecoration(
                            labelText: labels[key],
                            border: const OutlineInputBorder()),
                        keyboardType: key == 'period'
                            ? TextInputType.datetime
                            : const TextInputType.numberWithOptions(
                                decimal: true),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (key == 'period')
                            return RegExp(r'^[1-9][0-9]{3}-(0[1-9]|1[0-2])$')
                                    .hasMatch(text)
                                ? null
                                : 'Use AAAA-MM, por exemplo 2026-09.';
                          if (['revenue', 'ad_spend'].contains(key))
                            return CrmLabels.amount(text) != null
                                ? null
                                : 'Informe um valor válido, como 1.200,50.';
                          final count = int.tryParse(text);
                          return count != null && count >= 0
                              ? null
                              : 'Informe um número inteiro a partir de zero.';
                        })),
              if (error != null)
                Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              FilledButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? 'Salvando...' : 'Salvar resumo do mês')),
            ])),
      );
}
