import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});
  @override State<PendingApprovalScreen> createState()=>_S();
}

class _S extends State<PendingApprovalScreen>{
  bool checking=false;

  Future<void> check() async {
    setState(()=>checking=true);
    try{
      final me=await ApiService().me();
      if(!mounted)return;
      if(me['approval_status']=='active'){
        Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const HomeScreen()));
      }else{
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('Seu cadastro ainda está pendente de análise pela mentora.'))
        );
      }
    }finally{
      if(mounted)setState(()=>checking=false);
    }
  }

  Future<void> logout() async{
    await ApiService().logout();
    if(!mounted)return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder:(_)=>const LoginScreen()),
      (_)=>false
    );
  }

  @override Widget build(BuildContext c)=>Scaffold(
    body:SafeArea(
      child:Center(
        child:Padding(
          padding:const EdgeInsets.all(28),
          child:Column(
            mainAxisAlignment:MainAxisAlignment.center,
            children:[
              const Icon(Icons.hourglass_top,size:64),
              const SizedBox(height:18),
              Text('Acesso pendente',style:Theme.of(c).textTheme.headlineSmall),
              const SizedBox(height:12),
              const Text(
                'Seu cadastro foi recebido e está pendente de análise. A mentora precisa liberar seu acesso antes de você iniciar os módulos da mentoria.',
                textAlign:TextAlign.center,
              ),
              const SizedBox(height:20),
              FilledButton(
                onPressed:checking?null:check,
                child:Text(checking?'Verificando...':'Verificar status'),
              ),
              TextButton(onPressed:logout,child:const Text('Sair'))
            ],
          ),
        ),
      ),
    ),
  );
}
