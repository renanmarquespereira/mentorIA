import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState()=>_S();
}
class _S extends State<NotificationsScreen>{
  List<dynamic> rows=[]; bool loading=true, busy=false;
  @override void initState(){super.initState();load();}
  Future<void> load()async{try{final x=await ApiService().notifications();if(mounted)setState((){rows=x;loading=false;});}catch(e){if(mounted){setState(()=>loading=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}}
  Future<bool> confirm(String title,String text)async=>await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(title),content:Text(text),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Apagar'))]))??false;
  Future<void> removeOne(Map<String,dynamic> n)async{if(!await confirm('Apagar aviso?','Este aviso será removido da sua lista.'))return;final old=[...rows];setState(()=>rows.removeWhere((x)=>x['id']==n['id']));try{await ApiService().deleteNotification(n['id'].toString());}catch(e){if(mounted){setState(()=>rows=old);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}}
  Future<void> clearAll()async{if(rows.isEmpty||busy)return;if(!await confirm('Limpar avisos?','Todos os avisos serão apagados. Esta ação não pode ser desfeita.'))return;final old=[...rows];setState((){rows=[];busy=true;});try{await ApiService().clearNotifications();}catch(e){if(mounted){setState(()=>rows=old);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}finally{if(mounted)setState(()=>busy=false);}}
  @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Avisos'),actions:[if(rows.isNotEmpty)TextButton.icon(onPressed:busy?null:clearAll,icon:const Icon(Icons.delete_sweep_outlined),label:const Text('Limpar'))]),body:loading?const Center(child:CircularProgressIndicator()):rows.isEmpty?const Center(child:Text('Nenhum aviso no momento.')):RefreshIndicator(onRefresh:load,child:ListView(children:[for(final raw in rows)Builder(builder:(_){final n=Map<String,dynamic>.from(raw);return ListTile(leading:Icon(n['is_read']==true?Icons.notifications_none:Icons.notifications_active),title:Text('${n['title']}'),subtitle:Text('${n['message']}'),onTap:()async{await ApiService().readNotification(n['id'].toString());if(mounted)setState(()=>n['is_read']=true);await load();},trailing:IconButton(onPressed:()=>removeOne(n),icon:const Icon(Icons.delete_outline),tooltip:'Apagar aviso'));})])));
}
