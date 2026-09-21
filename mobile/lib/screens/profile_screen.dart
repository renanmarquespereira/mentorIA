import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends State<ProfileScreen> {
  Map<String, dynamic>? d;
  bool loading = true, saving = false;
  String? error;
  final f = <String, TextEditingController>{};
  String photo = '';
  final keys = ['name','phone','city_state','education','experience_months','active_clients','current_ticket','monthly_revenue','main_difficulty','main_goal'];

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final x = await ApiService().profile();
      for (final c in f.values) { c.dispose(); }
      f.clear();
      for (final k in keys) { f[k] = TextEditingController(text: '${x[k] ?? ''}'); }
      if (mounted) setState(() { d=x; photo='${x['profile_photo'] ?? ''}'; loading=false; error=null; });
    } catch (e) {
      if (mounted) setState(() { error='$e'; loading=false; });
    }
  }

  @override
  void dispose() { for (final c in f.values) { c.dispose(); } super.dispose(); }

  Future<void> pick() async {
    final x=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:72,maxWidth:700);
    if(x==null)return;
    final b=await x.readAsBytes();
    if(mounted)setState(()=>photo='data:image/jpeg;base64,${base64Encode(b)}');
  }

  int i(String k)=>int.tryParse(f[k]!.text)??0;
  double n(String k)=>double.tryParse(f[k]!.text.replaceAll('.','').replaceAll(',','.'))??0;

  Future<void> save() async {
    setState(()=>saving=true);
    try {
      await ApiService().updateProfile({
        'name':f['name']!.text.trim(),'phone':f['phone']!.text.trim(),'profile_photo':photo,
        'city_state':f['city_state']!.text.trim(),'education':f['education']!.text.trim(),
        'experience_months':i('experience_months'),'has_clients':d?['has_clients']==true,
        'sells_mentoring':d?['sells_mentoring']==true,'has_professional_instagram':d?['has_professional_instagram']==true,
        'active_clients':i('active_clients'),'current_ticket':n('current_ticket'),'monthly_revenue':n('monthly_revenue'),
        'main_difficulty':f['main_difficulty']!.text.trim(),'main_goal':f['main_goal']!.text.trim(),
      });
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Perfil atualizado.')));Navigator.pop(context,true);}
    } catch(e) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));
    } finally {
      if(mounted)setState(()=>saving=false);
    }
  }

  Widget field(String k,String label,{int lines=1,TextInputType? type}) => Padding(
    padding:const EdgeInsets.only(bottom:12),
    child:TextField(controller:f[k],maxLines:lines,keyboardType:type,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder())),
  );

  @override
  Widget build(BuildContext context) {
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(error!=null||d==null){
      return Scaffold(appBar:AppBar(title:const Text('Meus dados')),body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Icon(Icons.error_outline,size:42),const SizedBox(height:12),Text(error??'Não foi possível carregar seus dados.',textAlign:TextAlign.center),const SizedBox(height:12),
        FilledButton.icon(onPressed:(){setState((){loading=true;error=null;});load();},icon:const Icon(Icons.refresh),label:const Text('Tentar novamente')),
      ]))));
    }
    return Scaffold(
      appBar:AppBar(title:const Text('Meus dados')),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        Center(child:Column(children:[
          CircleAvatar(radius:48,backgroundImage:photo.startsWith('data:')?MemoryImage(base64Decode(photo.split(',').last)):null,child:photo.isEmpty?const Icon(Icons.person,size:48):null),
          TextButton.icon(onPressed:pick,icon:const Icon(Icons.photo),label:const Text('Alterar foto')),
        ])),
        field('name','Nome'),
        TextFormField(initialValue:'${d?['email']??''}',enabled:false,decoration:const InputDecoration(labelText:'E-mail (login)',border:OutlineInputBorder())),
        const SizedBox(height:12),
        field('phone','Telefone'),field('city_state','Cidade / Estado'),field('education','Formação',lines:2),
        field('experience_months','Experiência (meses)',type:TextInputType.number),field('active_clients','Clientes ativos',type:TextInputType.number),
        field('current_ticket','Ticket atual',type:TextInputType.number),field('monthly_revenue','Faturamento mensal',type:TextInputType.number),
        SwitchListTile(title:const Text('Já possui clientes'),value:d?['has_clients']==true,onChanged:(v)=>setState(()=>d!['has_clients']=v)),
        SwitchListTile(title:const Text('Vende mentoria'),value:d?['sells_mentoring']==true,onChanged:(v)=>setState(()=>d!['sells_mentoring']=v)),
        SwitchListTile(title:const Text('Instagram profissional'),value:d?['has_professional_instagram']==true,onChanged:(v)=>setState(()=>d!['has_professional_instagram']=v)),
        field('main_difficulty','Principal dificuldade',lines:3),field('main_goal','Principal objetivo',lines:3),
        FilledButton.icon(onPressed:saving?null:save,icon:const Icon(Icons.save),label:Text(saving?'Salvando...':'Salvar meus dados')),
      ]),
    );
  }
}
