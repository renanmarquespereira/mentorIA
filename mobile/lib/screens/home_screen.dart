import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'pillar_screen.dart';
import 'report_screen.dart';
import 'action_plan_screen.dart';
import 'crm_screen.dart';
import 'metrics_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'checkin_screen.dart';
import 'my_reports_screen.dart';
import 'notifications_screen.dart';
import 'mentee_agenda_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? data;
  List<dynamic> resetRequests = [];
  bool loading = true;
  String? error;

  Future<void> reload() async {
    try {
      final results = await Future.wait([
        ApiService().dashboard(),
        ApiService().resetRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        data = Map<String, dynamic>.from(results[0] as Map);
        resetRequests = List<dynamic>.from(results[1] as List);
        loading = false;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() { error = '$e'; loading = false; });
    }
  }

  @override
  void initState() { super.initState(); reload(); }

  Future<void> logout() async {
    await ApiService().logout();
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  String statusLabel(dynamic status) {
    switch ('$status') {
      case 'validated': return 'Concluído';
      case 'answered_ai': return 'Respondido • Falta gerar o Plano do Pilar';
      case 'needs_report_completion': return 'Aguardando complemento';
      case 'in_diagnosis': return 'Em andamento';
      case 'needs_review': return 'Aguardando revisão';
      default: return 'Não iniciado';
    }
  }

  String resetLabel(Map<String, dynamic> request) {
    if (request['reset_type'] == 'journey') return 'Reset de toda a jornada';
    const names = {
      'positioning': 'Posicionamento Único', 'promise': 'Promessa Atrativa',
      'funnel': 'Funil de Venda Poderoso', 'closing': 'Fechamento Irrecusável',
    };
    return 'Reset do plano: ${names[request['pillar_key']] ?? request['pillar_key']}';
  }

  Future<void> respondReset(Map<String, dynamic> request, bool approve) async {
    final decision = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(approve ? 'Autorizar reset?' : 'Recusar reset?'),
      content: Text(approve
          ? 'Ao autorizar, ${request['reset_type'] == 'journey' ? 'a jornada será resetada e os dados relacionados serão apagados' : 'o plano deste pilar será apagado para poder ser gerado novamente'}. Esta ação não será executada sem sua confirmação.'
          : 'O reset não será realizado e seus dados permanecerão como estão.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(approve ? 'Autorizar' : 'Recusar')),
      ],
    ));
    if (decision != true) return;
    try {
      final result = await ApiService().respondResetRequest(request['id'], approve);
      await reload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Solicitação respondida.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  ImageProvider? _profilePhoto(dynamic value) {
    final photo = (value ?? '').toString();
    if (!photo.startsWith('data:') || !photo.contains(',')) return null;
    try {
      return MemoryImage(base64Decode(photo.split(',').last));
    } catch (_) {
      return null;
    }
  }

  Widget _userMenu() {
    final name = (data?['user_name'] ?? '').toString().trim();
    final image = _profilePhoto(data?['profile_photo']);
    return PopupMenuButton<String>(
      tooltip: 'Usuário',
      onSelected: (v) {
        if (v == 'data') Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_) => reload());
        if (v == 'logout') logout();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value:'data',child:ListTile(leading:Icon(Icons.person_outline),title:Text('Dados'))),
        PopupMenuDivider(),
        PopupMenuItem(value:'logout',child:ListTile(leading:Icon(Icons.logout),title:Text('Logout'))),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: image,
            child: image == null ? Text(name.isEmpty ? '?' : name[0].toUpperCase()) : null,
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(name.isEmpty ? 'Usuário' : name, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.arrow_drop_down),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final pillars = data?['pillars'] as List? ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('MentorIA'), actions: [
        IconButton(tooltip: 'Agenda', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MenteeAgendaScreen())), icon: const Icon(Icons.calendar_month_outlined)),
        IconButton(tooltip: 'Avisos', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())), icon: const Icon(Icons.notifications_outlined)),
        _userMenu(),
      ]),
      body: RefreshIndicator(
        onRefresh: reload,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(data?['greeting'] ?? 'Olá', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Continue de onde parou', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6), Text(data?['next_action'] ?? ''),
            if (data?['current_pillar'] != null) ...[const SizedBox(height: 8), FilledButton.icon(onPressed: () { final p=Map<String,dynamic>.from(data!['current_pillar']); Navigator.push(context, MaterialPageRoute(builder: (_) => PillarScreen(keyName:p['key'],name:p['name']))).then((_)=>reload()); }, icon: const Icon(Icons.play_arrow), label: const Text('Continuar jornada'))]
          ]))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(icon: const Icon(Icons.edit_note), label: const Text('Preparar próxima mentoria'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckInScreen()))),
            OutlinedButton.icon(icon: const Icon(Icons.picture_as_pdf), label: const Text('Meus relatórios'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyReportsScreen()))),
          ]),
          if (resetRequests.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final raw in resetRequests)
              Builder(builder: (context) {
                final request = Map<String, dynamic>.from(raw);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [Icon(Icons.security), SizedBox(width: 8), Expanded(child: Text('Autorização de reset', style: TextStyle(fontWeight: FontWeight.bold)))]),
                      const SizedBox(height: 8),
                      Text('Sua mentora solicitou: ${resetLabel(request)}.'),
                      const SizedBox(height: 4),
                      const Text('Nada será resetado sem a sua autorização.'),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: OutlinedButton(onPressed: () => respondReset(request, false), child: const Text('Recusar'))),
                        const SizedBox(width: 10),
                        Expanded(child: FilledButton(onPressed: () => respondReset(request, true), child: const Text('Autorizar'))),
                      ]),
                    ]),
                  ),
                );
              }),
          ],
          const SizedBox(height: 16),
          if (data?['journey_status'] == 'diagnosis_completed')
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Diagnóstico concluído', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(data?['strategy_generated'] == true ? 'Sua estratégia já foi gerada.' : 'Gere agora sua estratégia completa.'),
              const SizedBox(height: 10),
              FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen())).then((_) => reload()), child: const Text('Abrir estratégia')),
            ]))),
          const SizedBox(height: 10),
          Text('Sua jornada', style: Theme.of(context).textTheme.titleLarge),
          for (final p in pillars)
            Card(child: ListTile(
              title: Text(p['name'] ?? ''),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 6),
                LinearProgressIndicator(value: ((p['score'] ?? 0) as num).toDouble() / 100),
                Text('${p['score'] ?? 0}% • ${statusLabel(p['status'])}'),
              ]),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PillarScreen(keyName: p['key'], name: p['name']))).then((_) => reload()),
            )),
          const SizedBox(height: 12),
          Text('Execução', style: Theme.of(context).textTheme.titleLarge),
          if (data?['action_focus'] != null)
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children:[Icon(Icons.flag_outlined),SizedBox(width:8),Text('Foco agora',style:TextStyle(fontWeight:FontWeight.bold))]),
              const SizedBox(height:8), Text('${data!['action_focus']['title']}'), const SizedBox(height:8),
              LinearProgressIndicator(value: (((data!['action_focus']['progress_percent'] ?? 0) as num).clamp(0, 100)) / 100),
              const SizedBox(height:4), Text('${data!['action_focus']['progress_percent'] ?? 0}% concluído'),
              const SizedBox(height:8), TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const ActionPlanScreen())).then((_)=>reload()),child:const Text('Abrir plano de ação'))
            ]))),
          Card(child: ListTile(leading: const Icon(Icons.task_alt), title: const Text('Plano de ação'), subtitle: Text((data?['total_actions'] ?? 0) > 0 ? '${data?['completed_actions'] ?? 0} de ${data?['total_actions']} concluídas • ${data?['in_progress_actions'] ?? 0} em andamento${(data?['overdue_actions'] ?? 0) > 0 ? ' • ${data?['overdue_actions']} atrasadas' : ''}' : 'Nenhuma ação disponível'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActionPlanScreen())).then((_) => reload()))),
          Card(child: ListTile(leading: const Icon(Icons.people), title: const Text('CRM'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrmScreen())))),
          Card(child: ListTile(leading: const Icon(Icons.insights), title: const Text('Métricas'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MetricsScreen())))),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
        ]),
      ),
    );
  }
}
