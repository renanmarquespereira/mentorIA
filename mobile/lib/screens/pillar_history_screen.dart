import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PillarHistoryScreen extends StatefulWidget {
  final String pillarKey, pillarName;
  const PillarHistoryScreen({super.key, required this.pillarKey, required this.pillarName});
  @override State<PillarHistoryScreen> createState() => _PillarHistoryScreenState();
}

class _PillarHistoryScreenState extends State<PillarHistoryScreen> {
  bool loading=true; String? error; List<dynamic> items=[];
  @override void initState(){super.initState(); load();}
  Future<void> load() async {
    try { final r=await ApiService().pillarHistory(widget.pillarKey); if(mounted)setState((){items=List<dynamic>.from(r['history']??[]);loading=false;}); }
    catch(e){if(mounted)setState((){error='$e';loading=false;});}
  }
  String date(dynamic value){
    final d=DateTime.tryParse('${value??''}')?.toLocal();
    if(d==null)return 'Data não disponível';
    String two(int n)=>n.toString().padLeft(2,'0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
  @override Widget build(BuildContext context){
    return Scaffold(appBar:AppBar(title:Text('Histórico • ${widget.pillarName}')),body:loading
      ? const Center(child:CircularProgressIndicator())
      : error!=null ? Center(child:Padding(padding:const EdgeInsets.all(20),child:Text(error!)))
      : items.isEmpty ? const Center(child:Padding(padding:EdgeInsets.all(20),child:Text('Ainda não há avaliações anteriores deste pilar.')))
      : ListView.builder(padding:const EdgeInsets.all(16),itemCount:items.length,itemBuilder:(c,i){
          final x=Map<String,dynamic>.from(items[i]); final report=Map<String,dynamic>.from(x['report']??{}); final answers=Map<String,dynamic>.from(x['answers']??{});
          return Card(child:ExpansionTile(
            title:Text('Avaliação anterior • ${date(x['started_at'])}'),
            subtitle:Text(x['status']=='in_progress'?'Nova avaliação em andamento':'Avaliação preservada'),
            children:[Padding(padding:const EdgeInsets.fromLTRB(16,0,16,16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              if('${report['summary']??''}'.trim().isNotEmpty)...[const Text('Resumo',style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:6),Text('${report['summary']}'),const SizedBox(height:14)],
              Text('${answers.length} resposta(s) preservada(s)',style:const TextStyle(fontWeight:FontWeight.w600)),
              ...answers.entries.map((e){final v=e.value is Map?Map<String,dynamic>.from(e.value):<String,dynamic>{};return Padding(padding:const EdgeInsets.only(top:10),child:Text(v['answer_text']?.toString()??''));}),
            ]))]
          ));
        }));
  }
}
