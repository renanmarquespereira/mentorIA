import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MentorSessionsScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const MentorSessionsScreen({super.key, required this.userId, required this.userName});
  @override State<MentorSessionsScreen> createState() => _MentorSessionsScreenState();
}

class _MentorSessionsScreenState extends State<MentorSessionsScreen> {
  bool loading = true;
  Map<String,dynamic> data = {};

  @override void initState(){ super.initState(); reload(); }
  Future<void> reload() async {
    try {
      final result = await ApiService().mentorSessions(widget.userId);
      if(mounted) setState(() { data=result; loading=false; });
    } on ApiException catch(e) {
      if(mounted){ setState(()=>loading=false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.message))); }
    }
  }

  String fmt(dynamic raw){
    if(raw==null) return '—';
    final d=DateTime.tryParse(raw.toString())?.toLocal(); if(d==null) return raw.toString();
    String z(int n)=>n.toString().padLeft(2,'0');
    return '${z(d.day)}/${z(d.month)}/${d.year} às ${z(d.hour)}:${z(d.minute)}';
  }
  String statusLabel(String s)=>{'scheduled':'Agendada','completed':'Realizada','canceled':'Cancelada'}[s]??s;
  Color statusColor(String s)=>s=='completed'?Colors.green:s=='canceled'?Colors.red:Colors.orange;

  Future<void> editSession([Map<String,dynamic>? current]) async {
    DateTime when = DateTime.tryParse(current?['scheduled_at']?.toString() ?? '')?.toLocal() ?? DateTime.now().add(const Duration(days:7));
    String status=(current?['status']??'scheduled').toString();
    final summary=TextEditingController(text:(current?['summary']??'').toString());
    final decisions=TextEditingController(text:(current?['decisions']??'').toString());
    final nextSteps=TextEditingController(text:(current?['next_steps']??'').toString());
    final actions=List<Map<String,dynamic>>.from((data['available_actions']??const []).map((e)=>Map<String,dynamic>.from(e)));
    final selected=<String>{...List<dynamic>.from(current?['actions']??const []).map((e)=>e['id'].toString())};
    final isNew=current==null;
    final payload=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(
      title:Text(isNew?'Agendar mentoria':'Editar sessão'),
      content:SizedBox(width:560,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.event),title:Text(fmt(when.toIso8601String())),trailing:const Icon(Icons.edit_calendar),onTap:() async {
          final d=await showDatePicker(context:ctx,initialDate:when,firstDate:DateTime(2020),lastDate:DateTime(2100)); if(d==null)return;
          if(!ctx.mounted)return; final t=await showTimePicker(context:ctx,initialTime:TimeOfDay.fromDateTime(when)); if(t==null)return;
          setLocal(()=>when=DateTime(d.year,d.month,d.day,t.hour,t.minute));
        }),
        if(!isNew) DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'Status'),items:const [
          DropdownMenuItem(value:'scheduled',child:Text('Agendada')),DropdownMenuItem(value:'completed',child:Text('Realizada')),DropdownMenuItem(value:'canceled',child:Text('Cancelada')),
        ],onChanged:(v)=>setLocal(()=>status=v??status)),
        if(isNew) const Padding(padding:EdgeInsets.only(top:8),child:Text('A sessão será criada como Agendada. O resumo, as decisões e os próximos passos serão registrados quando a mentoria for realizada.')),
        if(!isNew && status=='completed') ...[
          const SizedBox(height:12),
          TextField(controller:summary,minLines:2,maxLines:5,decoration:const InputDecoration(labelText:'Resumo da sessão',border:OutlineInputBorder())),
          const SizedBox(height:10),
          TextField(controller:decisions,minLines:2,maxLines:5,decoration:const InputDecoration(labelText:'Decisões tomadas',border:OutlineInputBorder())),
          const SizedBox(height:10),
          TextField(controller:nextSteps,minLines:2,maxLines:5,decoration:const InputDecoration(labelText:'Próximos passos',border:OutlineInputBorder())),
          if(actions.isNotEmpty)...[const SizedBox(height:14),const Text('Ações do plano combinadas nesta sessão',style:TextStyle(fontWeight:FontWeight.bold)),
            ...actions.map((a)=>CheckboxListTile(contentPadding:EdgeInsets.zero,dense:true,value:selected.contains(a['id'].toString()),title:Text(a['title']??''),onChanged:(v)=>setLocal((){if(v==true)selected.add(a['id'].toString());else selected.remove(a['id'].toString());}))),
          ]
        ]
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(ctx,{
        'scheduled_at':when.toUtc().toIso8601String(),'status':isNew?'scheduled':status,
        'summary':(!isNew && status=='completed')?summary.text.trim():'',
        'decisions':(!isNew && status=='completed')?decisions.text.trim():'',
        'next_steps':(!isNew && status=='completed')?nextSteps.text.trim():'',
        'action_ids':(!isNew && status=='completed')?selected.toList():<String>[],
      }),child:Text(isNew?'Agendar':'Salvar'))],
    )));
    summary.dispose(); decisions.dispose(); nextSteps.dispose();
    if(payload==null)return;
    try { if(current==null) await ApiService().createMentorSession(widget.userId,payload); else await ApiService().updateMentorSession(widget.userId,current['id'].toString(),payload); await reload(); }
    on ApiException catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.message)));}
  }

  Future<void> remove(Map<String,dynamic> row) async {
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Excluir sessão?'),content:const Text('O registro desta sessão será excluído. As ações do plano não serão apagadas.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Excluir'))]))??false;
    if(!ok)return; await ApiService().deleteMentorSession(widget.userId,row['id'].toString()); await reload();
  }

  Widget highlight(String title,dynamic row,IconData icon){
    final r=row is Map?Map<String,dynamic>.from(row):null;
    return Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon),const SizedBox(height:6),Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:4),Text(r==null?'Nenhuma registrada':fmt(r['scheduled_at']))]))));
  }

  @override Widget build(BuildContext context){
    final sessions=List<dynamic>.from(data['sessions']??const []);
    return Scaffold(appBar:AppBar(title:Text('Mentorias de ${widget.userName}')),floatingActionButton:FloatingActionButton.extended(onPressed:()=>editSession(),icon:const Icon(Icons.add),label:const Text('Agendar')),body:loading?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:reload,child:ListView(padding:const EdgeInsets.all(16),children:[
      Row(children:[highlight('Última mentoria',data['last_session'],Icons.history),const SizedBox(width:8),highlight('Próxima mentoria',data['next_session'],Icons.event_available)]),
      const SizedBox(height:12),Text('Histórico de sessões',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),
      if(sessions.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('Nenhuma sessão registrada ainda.'))),
      ...sessions.map((x){final r=Map<String,dynamic>.from(x);final actions=List<dynamic>.from(r['actions']??const []);final st=(r['status']??'scheduled').toString();final color=statusColor(st);return Card(color:color.withOpacity(.08),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12),side:BorderSide(color:color,width:1.5)),child:ExpansionTile(leading:Icon(st=='completed'?Icons.check_circle_outline:st=='canceled'?Icons.cancel_outlined:Icons.schedule,color:color),title:Text(fmt(r['scheduled_at'])),subtitle:Text(statusLabel(st),style:TextStyle(color:color,fontWeight:FontWeight.w600)),children:[Padding(padding:const EdgeInsets.fromLTRB(16,0,16,16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        if((r['summary']??'').toString().isNotEmpty)Text('Resumo: ${r['summary']}'),if((r['decisions']??'').toString().isNotEmpty)Padding(padding:const EdgeInsets.only(top:6),child:Text('Decisões: ${r['decisions']}')),if((r['next_steps']??'').toString().isNotEmpty)Padding(padding:const EdgeInsets.only(top:6),child:Text('Próximos passos: ${r['next_steps']}')),
        if(actions.isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),child:Text('Ações vinculadas: ${actions.map((a)=>a['title']).join(', ')}')),
        const SizedBox(height:8),Row(children:[TextButton.icon(onPressed:()=>editSession(r),icon:const Icon(Icons.edit),label:const Text('Editar')),TextButton.icon(onPressed:()=>remove(r),icon:const Icon(Icons.delete_outline),label:const Text('Excluir'))])
      ]))]));}).toList(),const SizedBox(height:80)
    ])));
  }
}
