import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CheckInScreen extends StatefulWidget { const CheckInScreen({super.key}); @override State<CheckInScreen> createState()=>_S(); }
class _S extends State<CheckInScreen>{
  final a=TextEditingController(),b=TextEditingController(),c=TextEditingController(); bool saving=false; List<dynamic> history=[]; int confidence=3;
  @override void initState(){super.initState();ApiService().checkIns().then((x){if(mounted)setState(()=>history=x);});}
  @override void dispose(){a.dispose();b.dispose();c.dispose();super.dispose();}
  Future<void> save()async{if(a.text.trim().length<3||c.text.trim().length<3)return;setState(()=>saving=true);try{await ApiService().createCheckIn({'progress':a.text.trim(),'blockers':b.text.trim(),'next_session_topic':c.text.trim(),'confidence_level':confidence});if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Check-in salvo e disponível para sua mentora.')));Navigator.pop(context,true);}}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Não foi possível salvar o check-in. Tente novamente.')));}finally{if(mounted)setState(()=>saving=false);}}
  String conf(dynamic v){switch(v){case 1:return 'Muito insegura';case 2:return 'Insegura';case 4:return 'Confiante';case 5:return 'Muito confiante';default:return 'Neutra';}}
  @override Widget build(BuildContext x)=>Scaffold(appBar:AppBar(title:const Text('Preparar próxima mentoria')),body:ListView(padding:const EdgeInsets.all(16),children:[
    const Text('Um check-in curto ajuda sua mentora a preparar uma sessão mais objetiva.'),const SizedBox(height:16),
    TextField(controller:a,maxLines:4,decoration:const InputDecoration(labelText:'O que avancei desde a última mentoria?',border:OutlineInputBorder())),const SizedBox(height:12),
    TextField(controller:b,maxLines:4,decoration:const InputDecoration(labelText:'Onde travei ou preciso de ajuda?',border:OutlineInputBorder())),const SizedBox(height:12),
    TextField(controller:c,maxLines:4,decoration:const InputDecoration(labelText:'O que quero discutir na próxima mentoria?',border:OutlineInputBorder())),const SizedBox(height:16),
    Text('Como você chega para a próxima sessão?',style:Theme.of(context).textTheme.titleSmall),Slider(value:confidence.toDouble(),min:1,max:5,divisions:4,label:conf(confidence),onChanged:saving?null:(v)=>setState(()=>confidence=v.round())),Center(child:Text(conf(confidence))),const SizedBox(height:16),
    FilledButton(onPressed:saving?null:save,child:Text(saving?'Salvando...':'Enviar check-in')),
    if(history.isNotEmpty)...[const SizedBox(height:24),Text('Check-ins anteriores',style:Theme.of(context).textTheme.titleMedium),for(final h in history.take(3))ExpansionTile(title:Text('${h['created_at']??'Check-in'}'),subtitle:Text('Confiança: ${conf(h['confidence_level']??3)}'),children:[ListTile(title:const Text('Avanços'),subtitle:Text('${h['progress']??''}')),ListTile(title:const Text('Bloqueios'),subtitle:Text('${h['blockers']??''}')),ListTile(title:const Text('Próxima sessão'),subtitle:Text('${h['next_session_topic']??''}'))])]
  ]));
}
