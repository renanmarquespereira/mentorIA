import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'crm_labels.dart';

enum CrmFormKind { contact, sale, followUp }

class CrmFormScreen extends StatefulWidget {
  const CrmFormScreen({super.key, required this.kind, this.lead});
  final CrmFormKind kind;
  final Map<String, dynamic>? lead;
  @override
  State<CrmFormScreen> createState() => _CrmFormState();
}

class _CrmFormState extends State<CrmFormScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, contact, notes, amount, product;
  late String source, funnel;
  DateTime date = DateTime.now();
  bool saving = false;
  String? error;
  final requestId = List.generate(16,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
      .join();
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.lead?['name'] ?? '');
    contact = TextEditingController(text: widget.lead?['contact'] ?? '');
    notes = TextEditingController(
        text: widget.kind == CrmFormKind.contact
            ? (widget.lead?['notes'] ?? '')
            : '');
    amount = TextEditingController(
        text: ((widget.lead?['expected_value'] ?? 0) as num)
            .toStringAsFixed(2)
            .replaceAll('.', ','));
    product = TextEditingController(text: 'Mentoria');
    source = widget.lead?['source'] ?? 'manual';
    funnel = widget.lead?['funnel'] ?? 'aplicacao_direta';
  }

  @override
  void dispose() {
    for (final c in [name, contact, notes, amount, product]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    if (!form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final api = ApiService();
      switch (widget.kind) {
        case CrmFormKind.contact:
          final data = {
            'name': name.text.trim(),
            'contact': contact.text.trim(),
            'source': source,
            'funnel': funnel,
            'notes': notes.text.trim(),
            'expected_value': CrmLabels.amount(amount.text)
          };
          if (widget.lead == null) {
            await api.createLead(data);
          } else {
            await api.editLead(widget.lead!['id'], data);
          }
        case CrmFormKind.sale:
          await api.createSale({
            'lead_id': widget.lead!['id'],
            'amount': CrmLabels.amount(amount.text),
            'product': product.text.trim(),
            'source': source,
            'request_id': requestId
          });
        case CrmFormKind.followUp:
          await api.createFollowUp(widget.lead!['id'], {
            'due_date':
                '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            'notes': notes.text.trim()
          });
      }
      if (mounted) {
        setState(() => saving = false);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted)
        setState(() {
          saving = false;
          error = e is ApiException
              ? e.message
              : 'Não foi possível salvar. Confira sua conexão e tente novamente.';
        });
    }
  }

  Widget field(String label, TextEditingController controller,
          {int lines = 1,
          int? limit,
          String? Function(String?)? validate,
          bool numeric = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
              controller: controller,
              minLines: lines,
              maxLines: lines,
              maxLength: limit,
              keyboardType: numeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : null,
              validator: validate,
              decoration: InputDecoration(
                  labelText: label, border: const OutlineInputBorder())));
  Widget choices(String label, Map<String, String> options, String selected,
          void Function(String) onChanged) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
              initialValue: selected,
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: [
                for (final e in options.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
                if (!options.containsKey(selected))
                  DropdownMenuItem(
                      value: selected,
                      child: Text(CrmLabels.label(options, selected)))
              ],
              onChanged: (v) {
                if (v != null) setState(() => onChanged(v));
              }));
  @override
  Widget build(BuildContext context) {
    final isContact = widget.kind == CrmFormKind.contact,
        isSale = widget.kind == CrmFormKind.sale;
    final title = isContact
        ? (widget.lead == null ? 'Novo contato' : 'Editar contato')
        : isSale
            ? 'Registrar venda'
            : 'Agendar retorno';
    return PopScope(
        canPop: !saving,
        child: Scaffold(
            appBar: AppBar(title: Text(title)),
            body: AbsorbPointer(
                absorbing: saving,
                child: Form(
                    key: form,
                    child:
                        ListView(padding: const EdgeInsets.all(18), children: [
                      if (!isContact) ...[
                        Text(widget.lead?['name'] ?? '',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 14)
                      ],
                      if (isContact) ...[
                        field('Nome', name,
                            limit: 160,
                            validate: (v) => (v ?? '').trim().length < 2
                                ? 'Informe pelo menos dois caracteres.'
                                : null),
                        field('Telefone ou e-mail', contact, limit: 200),
                        choices('Origem', CrmLabels.sources, source,
                            (v) => source = v),
                        choices('Funil', CrmLabels.funnels, funnel,
                            (v) => funnel = v),
                      ],
                      if (isSale)
                        field('Produto', product,
                            limit: 160,
                            validate: (v) => (v ?? '').trim().isEmpty
                                ? 'Informe o produto.'
                                : null),
                      if (isContact || isSale)
                        field(
                            isSale
                                ? 'Valor da venda (R\$)'
                                : 'Valor esperado (R\$)',
                            amount,
                            numeric: true, validate: (v) {
                          final n = CrmLabels.amount(v ?? '');
                          return n == null || n < 0 || (isSale && n == 0)
                              ? 'Informe um valor válido, como 1.200,50.'
                              : null;
                        }),
                      if (!isContact && !isSale) ...[
                        OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                                'Data do retorno: ${CrmLabels.date(date.toIso8601String())}'),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                  context: context,
                                  initialDate: date,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(DateTime.now().year + 20),
                                  helpText: 'Data do retorno',
                                  confirmText: 'Salvar',
                                  cancelText: 'Cancelar');
                              if (picked != null && mounted)
                                setState(() => date = picked);
                            }),
                        const SizedBox(height: 14),
                      ],
                      if (!isSale)
                        field('Observações', notes, lines: 4, limit: 5000),
                      if (error != null)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(error!,
                                style: const TextStyle(color: Colors.red))),
                      FilledButton(
                          onPressed: saving ? null : save,
                          child: Text(saving
                              ? 'Salvando...'
                              : isSale
                                  ? 'Confirmar venda'
                                  : 'Salvar')),
                    ])))));
  }
}
