import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'api_service.dart';

String newRequestId() {
  final r = Random.secure();
  final b = List.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class VoiceService {
  Future<List<dynamic>> drafts(String pillar, String question) async =>
      List<dynamic>.from(decode(await http
          .get(
              Uri.parse('${ApiService.baseUrl}/voice/drafts').replace(
                  queryParameters: {
                    'pillar_key': pillar,
                    'question_key': question
                  }),
              headers: await api.headers())
          .timeout(const Duration(seconds: 30))));
  final api = ApiService();
  dynamic decode(http.Response r) {
    dynamic value;
    try {
      value = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      throw ApiException(
          r.statusCode, 'Não consegui acessar o servidor. Tente novamente.');
    }
    if (r.statusCode >= 400)
      throw ApiException(
          r.statusCode,
          value is Map && value['detail'] is String
              ? value['detail']
              : 'Não consegui concluir. Tente novamente.');
    return value;
  }

  Future<Map<String, dynamic>> upload(
      String id, String pillar, String question, Uint8List bytes) async {
    final uri = Uri.parse('${ApiService.baseUrl}/voice/$id').replace(
        queryParameters: {'pillar_key': pillar, 'question_key': question});
    return Map<String, dynamic>.from(decode(await http
        .put(uri,
            headers: {...await api.headers(), 'Content-Type': 'audio/wav'},
            body: bytes)
        .timeout(const Duration(seconds: 90))));
  }

  Future<Map<String, dynamic>> transcribe(String id) async =>
      Map<String, dynamic>.from(decode(await http
          .post(Uri.parse('${ApiService.baseUrl}/voice/$id/transcribe'),
              headers: await api.headers())
          .timeout(const Duration(seconds: 110))));
  Future<void> discard(String id) async {
    decode(await http
        .delete(Uri.parse('${ApiService.baseUrl}/voice/$id'),
            headers: await api.headers())
        .timeout(const Duration(seconds: 30)));
  }

  Future<Uint8List> audio(String id) async {
    final r = await http
        .get(Uri.parse('${ApiService.baseUrl}/voice/$id/audio'),
            headers: await api.headers())
        .timeout(const Duration(seconds: 60));
    if (r.statusCode >= 400) decode(r);
    return r.bodyBytes;
  }

  Future<List<dynamic>> list(String pillar, {String? ownerId}) async =>
      List<dynamic>.from(decode(await http
          .get(
              Uri.parse('${ApiService.baseUrl}/voice').replace(
                  queryParameters: {
                    'pillar_key': pillar,
                    if (ownerId != null) 'owner_id': ownerId
                  }),
              headers: await api.headers())
          .timeout(const Duration(seconds: 30))));
  Future<List<dynamic>> conversations(String pillar, {String? ownerId}) async =>
      List<dynamic>.from(decode(await http
          .get(Uri.parse('${ApiService.baseUrl}/plan-conversations/$pillar').replace(
              queryParameters: {if (ownerId != null) 'owner_id': ownerId}),
              headers: await api.headers())
          .timeout(const Duration(seconds: 30))));
  Future<Map<String, dynamic>> ask(String pillar, String id, String question,
          {String? audioId}) async =>
      Map<String, dynamic>.from(decode(await http
          .post(Uri.parse('${ApiService.baseUrl}/plan-conversations/$pillar'),
              headers: await api.headers(),
              body: jsonEncode({
                'request_id': id,
                'question': question,
                if (audioId != null) 'audio_id': audioId
              }))
          .timeout(const Duration(seconds: 110))));
}
