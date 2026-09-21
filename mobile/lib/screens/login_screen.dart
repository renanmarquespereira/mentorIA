import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'pending_approval_screen.dart';
import 'mentor_admin_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? registrationMessage;
  const LoginScreen({super.key, this.registrationMessage});
  @override State<LoginScreen> createState()=>_S();
}
class _S extends State<LoginScreen>{
 final email=TextEditingController(), password=TextEditingController();
 bool loading=false,messageShown=false,passwordVisible=false; String? error;
 @override void didChangeDependencies(){super.didChangeDependencies();if(!messageShown&&widget.registrationMessage!=null&&widget.registrationMessage!.isNotEmpty){messageShown=true;WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(widget.registrationMessage!),duration:const Duration(seconds:5)));});}}
 Future<void> submit() async{
  setState((){loading=true;error=null;});
  try{
   final me=await ApiService().loginAndGetUser(email.text.trim(),password.text);
   if(!mounted)return;
   if(me==null){setState((){loading=false;error='E-mail ou senha inválidos.';});return;}
   if(me['role']=='mentor'||me['role']=='admin') Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const MentorAdminScreen()));
   else if(me['approval_status']=='active') Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const HomeScreen()));
   else Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const PendingApprovalScreen()));
  }catch(_){if(mounted)setState((){loading=false;error='Não foi possível conectar ao servidor.';});}
 }
 @override Widget build(BuildContext c)=>Scaffold(body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:430),child:ListView(shrinkWrap:true,padding:const EdgeInsets.all(24),children:[
  const Icon(Icons.auto_awesome,size:56),const SizedBox(height:16),Text('Mentoria IA',textAlign:TextAlign.center,style:Theme.of(c).textTheme.headlineMedium),const SizedBox(height:24),
  TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'E-mail')),const SizedBox(height:12),
  TextField(controller:password,obscureText:!passwordVisible,onSubmitted:(_)=>submit(),decoration:InputDecoration(labelText:'Senha',suffixIcon:IconButton(tooltip:passwordVisible?'Ocultar senha':'Mostrar senha',onPressed:()=>setState(()=>passwordVisible=!passwordVisible),icon:Icon(passwordVisible?Icons.visibility_off:Icons.visibility)))),
  if(error!=null)Padding(padding:const EdgeInsets.only(top:12),child:Text(error!,style:const TextStyle(color:Colors.red))),
  const SizedBox(height:18),FilledButton(onPressed:loading?null:submit,child:Text(loading?'Entrando...':'Entrar')),const SizedBox(height:8),
  TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const RegisterScreen())),child:const Text('Criar cadastro'))
 ])))));
}
