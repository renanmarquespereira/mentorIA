import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override String toString() => message;
}

class ApiService {
  // Estado compartilhado da sessao. Mantido aqui porque main.dart e as telas
  // dependem destes notifiers para refletir login/logout sem nova chamada.
  static final ValueNotifier<Map<String,dynamic>?> currentIdentity = ValueNotifier<Map<String,dynamic>?>(null);
  static final ValueNotifier<int> sessionRevision = ValueNotifier<int>(0);

  // v2.17.1: URL explicita para evitar build Web gerando 'http://auth/login'.
  // Android e Web usam o mesmo backend da rede local.
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://mentoria-s9sr.onrender.com/api/v1');
  Future<String?> token() async => (await SharedPreferences.getInstance()).getString('access_token');
  Future<Map<String,String>> headers() async => {'Content-Type':'application/json', if(await token()!=null) 'Authorization':'Bearer ${await token()}'};

  Future<Map<String,dynamic>?> loginAndGetUser(String email,String password) async {
    final r=await http.post(Uri.parse('$baseUrl/auth/login'),headers:{'Content-Type':'application/json'},body:jsonEncode({'email':email,'password':password}));
    if(r.statusCode!=200)return null;
    final body=Map<String,dynamic>.from(jsonDecode(r.body));
    await (await SharedPreferences.getInstance()).setString('access_token',body['access_token']);
    final embedded=body['user'];
    final user = embedded is Map ? Map<String,dynamic>.from(embedded) : await me();
    currentIdentity.value = user;
    sessionRevision.value++;
    return user;
  }

  Future<bool> login(String email,String password) async => (await loginAndGetUser(email,password)) != null;
  Future<bool> register(String name,String phone,String email,String password) async {
    final r=await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers:{'Content-Type':'application/json'},
      body:jsonEncode({'name':name,'phone':phone,'email':email,'password':password}),
    );
    return r.statusCode>=200 && r.statusCode<300;
  }

  Future<void> logout() async {
    await (await SharedPreferences.getInstance()).remove('access_token');
    currentIdentity.value = null;
    sessionRevision.value++;
  }

  dynamic _ok(http.Response r){
    final d=r.body.isEmpty?{}:jsonDecode(r.body);
    if(r.statusCode>=400) throw ApiException(r.statusCode, (d is Map ? (d['detail']??'Erro ${r.statusCode}') : 'Erro ${r.statusCode}').toString());
    return d;
  }

  Future<Map<String,dynamic>> me() async =>
      Map<String,dynamic>.from(_ok(await http.get(
        Uri.parse('$baseUrl/me'),
        headers:await headers(),
      )));

  Future<List<dynamic>> mentorMentees({String? status}) async {
    final suffix = status == null ? '' : '?status=$status';
    return List<dynamic>.from(_ok(await http.get(
      Uri.parse('$baseUrl/mentor/mentees$suffix'),
      headers:await headers(),
    )));
  }

  Future<Map<String,dynamic>> menteeOverview(String id) async =>
      Map<String,dynamic>.from(_ok(await http.get(
        Uri.parse('$baseUrl/mentor/mentees/$id/overview'),
        headers:await headers(),
      )));

  Future<Map<String,dynamic>> menteeIntelligenceCache(String id) async =>
      Map<String,dynamic>.from(_ok(await http.get(
        Uri.parse('$baseUrl/mentor/mentees/$id/intelligence-cache'),
        headers:await headers(),
      )));

  Future<Map<String,dynamic>> menteeEvolution(String id) async =>
      Map<String,dynamic>.from(_ok(await http.get(
        Uri.parse('$baseUrl/mentor/mentees/$id/evolution'),
        headers:await headers(),
      )));

  Future<List<dynamic>> mentorPrivateNotes(String id) async =>
      List<dynamic>.from(_ok(await http.get(
        Uri.parse('$baseUrl/mentor/mentees/$id/private-notes'),
        headers:await headers(),
      )));

  Future<Map<String,dynamic>> addMentorPrivateNote(String id,String note) async =>
      Map<String,dynamic>.from(_ok(await http.post(
        Uri.parse('$baseUrl/mentor/mentees/$id/private-notes'),
        headers:await headers(),
        body:jsonEncode({'note':note}),
      )));

  Future<void> deleteMentorPrivateNote(String id,String noteId) async =>
      _ok(await http.delete(
        Uri.parse('$baseUrl/mentor/mentees/$id/private-notes/$noteId'),
        headers:await headers(),
      ));

  Future<void> permanentlyDeleteMentee(String id) async =>
      _ok(await http.delete(
        Uri.parse('$baseUrl/mentor/mentees/$id'),
        headers:await headers(),
      ));

  Future<Map<String,dynamic>> mentorSessions(String id) async =>
      Map<String,dynamic>.from(_ok(await http.get(Uri.parse('$baseUrl/mentor/mentees/$id/sessions'), headers:await headers())));
  Future<Map<String,dynamic>> createMentorSession(String id,Map<String,dynamic> data) async =>
      Map<String,dynamic>.from(_ok(await http.post(Uri.parse('$baseUrl/mentor/mentees/$id/sessions'), headers:await headers(), body:jsonEncode(data))));
  Future<Map<String,dynamic>> updateMentorSession(String id,String sessionId,Map<String,dynamic> data) async =>
      Map<String,dynamic>.from(_ok(await http.put(Uri.parse('$baseUrl/mentor/mentees/$id/sessions/$sessionId'), headers:await headers(), body:jsonEncode(data))));
  Future<void> deleteMentorSession(String id,String sessionId) async =>
      _ok(await http.delete(Uri.parse('$baseUrl/mentor/mentees/$id/sessions/$sessionId'), headers:await headers()));

  Future<Map<String,dynamic>> generateMenteeIntelligentBrief(String id) async =>
      Map<String,dynamic>.from(_ok(await http.post(
        Uri.parse('$baseUrl/mentor/mentees/$id/intelligent-brief'),
        headers:await headers(),
      )));

  Future<void> mentorEditPillarReport(
    String userId,
    String pillarKey,
    Map<String,dynamic> data,
  ) async {
    _ok(await http.put(
      Uri.parse('$baseUrl/mentor/mentees/$userId/pillar-report/$pillarKey'),
      headers:await headers(),
      body:jsonEncode(data),
    ));
  }

  Future<Map<String,dynamic>> resetPillarReport(String id,String pillarKey) async =>
      Map<String,dynamic>.from(_ok(await http.post(
        Uri.parse('$baseUrl/mentor/mentees/$id/reset-pillar-report/$pillarKey'),
        headers:await headers(),
      )));

  Future<Map<String,dynamic>> resetMenteeJourney(String id) async =>
      Map<String,dynamic>.from(_ok(await http.post(
        Uri.parse('$baseUrl/mentor/mentees/$id/reset-journey'),
        headers:await headers(),
      )));

  Future<List<dynamic>> resetRequests() async => List<dynamic>.from(_ok(await http.get(
    Uri.parse('$baseUrl/mentor/reset-requests'), headers:await headers(),
  )));

  Future<Map<String,dynamic>> respondResetRequest(String id, bool approve) async =>
      Map<String,dynamic>.from(_ok(await http.post(
        Uri.parse('$baseUrl/mentor/reset-requests/$id/respond'),
        headers:await headers(),
        body:jsonEncode({'decision': approve ? 'approve' : 'reject'}),
      )));

  Future<void> setMenteeApproval(String id,String status) async {
    _ok(await http.patch(
      Uri.parse('$baseUrl/mentor/mentees/$id/approval'),
      headers:await headers(),
      body:jsonEncode({'status':status}),
    ));
  }

  Future<Map<String,dynamic>> mentorSettings() async =>
      Map<String,dynamic>.from(_ok(await http.get(
        Uri.parse('$baseUrl/mentor/settings'),
        headers:await headers(),
      )));

  Future<void> saveMentorSettings(Map<String,dynamic> data) async {
    _ok(await http.put(
      Uri.parse('$baseUrl/mentor/settings'),
      headers:await headers(),
      body:jsonEncode(data),
    ));
  }

  Future<Map<String,dynamic>> dashboard() async => Map<String,dynamic>.from(_ok(await http.get(Uri.parse('$baseUrl/dashboard'),headers:await headers())));
  Future<Map<String,dynamic>> pillar(String key) async => Map<String,dynamic>.from(_ok(await http.get(Uri.parse('$baseUrl/pillars/$key'),headers:await headers())));
  Future<Map<String,dynamic>> answer(String pk,String qk,String txt, {String? audioId}) async => Map<String,dynamic>.from(_ok(await http.post(Uri.parse('$baseUrl/pillars/$pk/answer'),headers:await headers(),body:jsonEncode({'question_key':qk,'answer_text':txt, if(audioId!=null) 'audio_id':audioId}))));
  Future<Map<String,dynamic>> answerCoach(String pk,String qk,String answer,String message,List<Map<String,String>> history) async => Map<String,dynamic>.from(_ok(await http.post(Uri.parse('$baseUrl/pillars/$pk/answer-coach'),headers:await headers(),body:jsonEncode({'question_key':qk,'answer_text':answer,'message':message,'history':history}))));
  Future<Map<String,dynamic>> redoPillar(String key) async => Map<String,dynamic>.from(_ok(await http.post(Uri.parse('$baseUrl/pillars/$key/redo'),headers:await headers())));
  Future<Map<String,dynamic>> cancelRedoPillar(String key) async => Map<String,dynamic>.from(_ok(await http.post(Uri.parse('$baseUrl/pillars/$key/cancel-redo'),headers:await headers())));
  Future<Map<String,dynamic>> pillarHistory(String key) async => Map<String,dynamic>.from(_ok(await http.get(Uri.parse('$baseUrl/pillars/$key/history'),headers:await headers())));  Future<Map<String,dynamic>> fullReport() async => Map<String,dynamic>.from(_ok(await http.get(Uri.parse('$baseUrl/strategy/full-report'),headers:await headers())));
  Future<Map<String,dynamic>> generatePillarReport(String key) async =>
      Map<String,dynamic>.from(_ok(await http.post(
        Uri.parse('$baseUrl/pillar-reports/$key/generate'),
        headers:await headers(),
      )));

  Future<Map<String,dynamic>> completePillarReport(String key, String answer, {String? audioId}) async =>
      Map<String,dynamic>.from(_ok(await http.post(
        Uri.parse('$baseUrl/pillar-reports/$key/complete'),
        headers:await headers(),
        body:jsonEncode({'answer_text':answer, if(audioId!=null) 'audio_id':audioId}),
      )));

  Future<Map<String,dynamic>> pillarReport(String key) async =>
      Map<String,dynamic>.from(_ok(await http.get(
        Uri.parse('$baseUrl/pillar-reports/$key'),
        headers:await headers(),
      )));

  Future<Uint8List> pillarReportPdf(String key) async {
    final r = await http.get(Uri.parse('$baseUrl/pillar-reports/$key/pdf'), headers: await headers());
    if (r.statusCode >= 400) _ok(r);
    return r.bodyBytes;
  }

  Future<Uint8List> mentorPillarReportPdf(String userId, String key) async {
    final r = await http.get(Uri.parse('$baseUrl/mentor/mentees/$userId/pillar-report/$key/pdf'), headers: await headers());
    if (r.statusCode >= 400) _ok(r);
    return r.bodyBytes;
  }

  Future<Map<String,dynamic>> recoverCompletionQuestion(String key) async =>
      Map<String,dynamic>.from(_ok(await http.post(
        Uri.parse('$baseUrl/pillar-reports/$key/recover-completion-question'),
        headers:await headers(),
      )));

  Future<Map<String,dynamic>> generateStrategy() async => Map<String,dynamic>.from(_ok(await http.post(Uri.parse('$baseUrl/strategy/generate-full'),headers:await headers())));
  Future<List<dynamic>> actionPlan() async => List<dynamic>.from(_ok(await http.get(Uri.parse('$baseUrl/strategy/action-plan'),headers:await headers())));
  Future<void> setAction(String id,String status) async { _ok(await http.patch(Uri.parse('$baseUrl/strategy/action-plan/$id'),headers:await headers(),body:jsonEncode({'status':status}))); }
  Future<void> updateAction(String id, Map<String,dynamic> changes) async {
    _ok(await http.patch(Uri.parse('$baseUrl/strategy/action-plan/$id'), headers:await headers(), body:jsonEncode(changes)));
  }
  Future<List<dynamic>> leads() async => List<dynamic>.from(_ok(await http.get(Uri.parse('$baseUrl/crm/leads'),headers:await headers())));
  Future<Map<String,dynamic>> lead(String id) async => Map<String,dynamic>.from(_ok(await http.get(Uri.parse('$baseUrl/crm/leads/$id'),headers:await headers())));
  Future<void> editLead(String id, Map<String,dynamic> data) async { _ok(await http.patch(Uri.parse('$baseUrl/crm/leads/$id'),headers:await headers(),body:jsonEncode(data))); }
  Future<List<dynamic>> followUps(String id) async => List<dynamic>.from(_ok(await http.get(Uri.parse('$baseUrl/crm/leads/$id/follow-ups'),headers:await headers())));
  Future<void> createFollowUp(String id, Map<String,dynamic> data) async { _ok(await http.post(Uri.parse('$baseUrl/crm/leads/$id/follow-ups'),headers:await headers(),body:jsonEncode(data))); }
  Future<void> setFollowUp(String id,String status) async { _ok(await http.patch(Uri.parse('$baseUrl/crm/follow-ups/$id'),headers:await headers(),body:jsonEncode({'status':status}))); }
  Future<Map<String,dynamic>> createLead(Map<String,dynamic> data) async => Map<String,dynamic>.from(_ok(await http.post(Uri.parse('$baseUrl/crm/leads'),headers:await headers(),body:jsonEncode(data))));
  Future<void> updateLeadStage(String id,String stage) async { _ok(await http.patch(Uri.parse('$baseUrl/crm/leads/$id/stage'),headers:await headers(),body:jsonEncode({'stage':stage}))); }
  Future<List<dynamic>> sales() async => List<dynamic>.from(_ok(await http.get(Uri.parse('$baseUrl/crm/sales'),headers:await headers())));
  Future<Map<String,dynamic>> createSale(Map<String,dynamic> data) async => Map<String,dynamic>.from(_ok(await http.post(Uri.parse('$baseUrl/crm/sales'),headers:await headers(),body:jsonEncode(data))));
  Future<Map<String,dynamic>> metrics() async => Map<String,dynamic>.from(_ok(await http.get(Uri.parse('$baseUrl/metrics/summary'),headers:await headers())));
  Future<List<dynamic>> metricsHistory() async => List<dynamic>.from(_ok(await http.get(Uri.parse('$baseUrl/metrics/history'),headers:await headers())));
  Future<Map<String,dynamic>> saveMetric(Map<String,dynamic> data) async => Map<String,dynamic>.from(_ok(await http.post(Uri.parse('$baseUrl/metrics'),headers:await headers(),body:jsonEncode(data))));
  Future<Map<String,dynamic>> profile() async => Map<String,dynamic>.from(_ok(await http.get(Uri.parse('$baseUrl/profile'),headers:await headers())));
  Future<Map<String,dynamic>> updateProfile(Map<String,dynamic> data) async => Map<String,dynamic>.from(_ok(await http.put(Uri.parse('$baseUrl/profile'),headers:await headers(),body:jsonEncode(data))));
  Future<List<dynamic>> myReports() async => List<dynamic>.from(_ok(await http.get(Uri.parse('$baseUrl/my-reports'),headers:await headers())));
  Future<List<dynamic>> checkIns() async => List<dynamic>.from(_ok(await http.get(Uri.parse('$baseUrl/check-ins'),headers:await headers())));
  Future<Map<String,dynamic>> createCheckIn(Map<String,dynamic> data) async => Map<String,dynamic>.from(_ok(await http.post(Uri.parse('$baseUrl/check-ins'),headers:await headers(),body:jsonEncode(data))));
  Future<List<dynamic>> notifications() async => List<dynamic>.from(_ok(await http.get(Uri.parse('$baseUrl/notifications'),headers:await headers())));
  Future<void> readNotification(String id) async { _ok(await http.patch(Uri.parse('$baseUrl/notifications/$id/read'),headers:await headers())); }
  Future<void> deleteNotification(String id) async { _ok(await http.delete(Uri.parse('$baseUrl/notifications/$id'),headers:await headers())); }
  Future<void> clearNotifications() async { _ok(await http.delete(Uri.parse('$baseUrl/notifications'),headers:await headers())); }

  // Compatibilidade entre as telas de agenda introduzidas em versoes diferentes.
  Future<Map<String,dynamic>> myMentorSessions() async =>
      Map<String,dynamic>.from(_ok(await http.get(Uri.parse('$baseUrl/my-sessions'),headers:await headers())));
  Future<Map<String,dynamic>> myMentoringSessions() => myMentorSessions();
  Future<List<dynamic>> mySessions() async {
    final data = await myMentorSessions();
    return List<dynamic>.from(data['sessions'] ?? const []);
  }
  Future<void> hideMySession(String id) async {
    _ok(await http.patch(Uri.parse('$baseUrl/my-sessions/$id/hide'),headers:await headers()));
  }
  Future<List<dynamic>> mentorAgenda() async =>
      List<dynamic>.from(_ok(await http.get(Uri.parse('$baseUrl/mentor/sessions'),headers:await headers())));

}

