import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
class RegisterScreen extends StatefulWidget{const RegisterScreen({super.key});@override State<RegisterScreen> createState()=>_S();}
class _S extends State<RegisterScreen>{
 final name=TextEditingController(),phone=TextEditingController(),email=TextEditingController(),password=TextEditingController(),confirmPassword=TextEditingController();
 bool loading=false;String? error;
 Future<void> submit() async{
  if(name.text.trim().isEmpty||phone.text.trim().isEmpty||email.text.trim().isEmpty||password.text.length<8){setState(()=>error='Preencha nome, telefone, e-mail e uma senha com pelo menos 8 caracteres.');return;}
  if(password.text!=confirmPassword.text){setState(()=>error='As senhas não coincidem.');return;}
  setState((){loading=true;error=null;});
  try{final ok=await ApiService().register(name.text.trim(),phone.text.trim(),email.text.trim(),password.text);if(!mounted)return;if(!ok){setState((){loading=false;error='Não foi possível realizar o cadastro.';});return;}Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder:(_)=>const LoginScreen(registrationMessage:'Cadastro realizado. Aguarde a permissão de acesso da mentora.')),(_)=>false);}catch(_){if(mounted)setState((){loading=false;error='Não foi possível realizar o cadastro.';});}
 }
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Criar cadastro')),body:ListView(padding:const EdgeInsets.all(24),children:[
  TextField(controller:name,decoration:const InputDecoration(labelText:'Nome completo')),const SizedBox(height:12),
  TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Telefone',hintText:'(11) 99999-9999')),const SizedBox(height:12),
  TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'E-mail')),const SizedBox(height:12),
  TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Senha',helperText:'Mínimo de 8 caracteres')),const SizedBox(height:12),
  TextField(controller:confirmPassword,obscureText:true,onSubmitted:(_)=>submit(),decoration:const InputDecoration(labelText:'Confirmar senha')),
  if(error!=null)Padding(padding:const EdgeInsets.only(top:12),child:Text(error!,style:const TextStyle(color:Colors.red))),const SizedBox(height:18),
  FilledButton(onPressed:loading?null:submit,child:Text(loading?'Cadastrando...':'Cadastrar'))
 ]));
}
