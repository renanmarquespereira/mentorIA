class CrmLabels {
  static const stages = {
    'new': 'Novo contato',
    'qualified': 'Qualificado',
    'scheduled': 'Reunião agendada',
    'proposal': 'Proposta enviada',
    'closed_won': 'Venda concluída',
    'closed_lost': 'Não avançou'
  };
  static const sources = {
    'instagram': 'Instagram',
    'indicacao': 'Indicação',
    'whatsapp': 'WhatsApp',
    'evento': 'Evento',
    'manual': 'Cadastro manual'
  };
  static const funnels = {
    'aplicacao_direta': 'Aplicação direta',
    'demanda_reprimida': 'Demanda reprimida',
    'indicacao': 'Indicação',
    'social_selling': 'Relacionamento nas redes sociais'
  };
  static String label(Map<String, String> options, dynamic value) =>
      options[value] ??
      (value?.toString().replaceAll('_', ' ') ?? 'Não informado');
  static String money(dynamic value) {
    final parts = ((value as num?) ?? 0).toStringAsFixed(2).split('.');
    final whole = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
    return 'R\$ $whole,${parts[1]}';
  }

  static double? amount(String text) {
    var value = text.trim().replaceFirst(RegExp(r'^R\$\s*'), '');
    if (value.contains(',')) {
      if (!RegExp(r'^(?:\d+|\d{1,3}(?:\.\d{3})+),\d{1,2}$').hasMatch(value))
        return null;
      value = value.replaceAll('.', '').replaceAll(',', '.');
    } else if (RegExp(r'^\d{1,3}(?:\.\d{3})+$').hasMatch(value)) {
      value = value.replaceAll('.', '');
    } else if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(value)) return null;
    final parsed = double.tryParse(value);
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  static String date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null
        ? 'Sem data'
        : '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  static bool overdue(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    final now = DateTime.now();
    return parsed != null &&
        parsed.isBefore(DateTime(now.year, now.month, now.day));
  }
}
