import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../services/voice_service.dart';
import 'voice_player.dart';

class VoiceInput extends StatefulWidget {
  final String pillarKey, questionKey;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String?> onAttachment;
  final ValueChanged<bool> onBusy;
  const VoiceInput(
      {super.key,
      required this.pillarKey,
      required this.questionKey,
      required this.controller,
      required this.onAttachment,
      required this.onBusy,
      this.enabled = true});
  @override
  State<VoiceInput> createState() => _VoiceInputState();
}

class _VoiceInputState extends State<VoiceInput> with WidgetsBindingObserver {
  AudioRecorder? recorder;
  final service = VoiceService();
  String? path, id, uploadedId, error;
  bool recording = false, working = false, transcribed = false;
  int seconds = 0;
  Timer? timer;
  bool get blocksSending =>
      recording || working || (path != null && uploadedId == null);
  void update(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
    widget.onBusy(blocksSending);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && recording && !working) stop();
  }

  Future<void> start() async {
    update(() => working = true);
    try {
      recorder ??= AudioRecorder();
      if (!await recorder!.hasPermission()) {
        throw Exception(
            'Permita o microfone nas configurações do aplicativo para gravar.');
      }
      if (!mounted) return;
      id = newRequestId();
      final folder = await getTemporaryDirectory();
      if (!mounted) return;
      path = '${folder.path}/mentoria_$id.wav';
      await recorder!.start(
          const RecordConfig(
              encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
          path: path!);
      if (!mounted) return;
      update(() {
        recording = true;
        seconds = 0;
        error = null;
      });
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => seconds++);
        if (seconds >= 300) stop();
      });
    } catch (e) {
      path = null;
      update(() => error =
          'Não consegui iniciar a gravação. Verifique a permissão do microfone.');
    } finally {
      update(() => working = false);
    }
  }

  Future<void> stop() async {
    if (working || !recording) return;
    timer?.cancel();
    var ready = false;
    update(() => working = true);
    try {
      final saved = await recorder!.stop();
      if (saved == null) throw StateError('missing');
      update(() {
        path = saved;
        recording = false;
      });
      ready = true;
    } catch (e) {
      update(() {
        error = 'Não consegui finalizar a gravação. Grave novamente.';
        recording = false;
        path = null;
      });
    } finally {
      update(() => working = false);
    }
    if (ready && mounted) await sendAudio();
  }

  Future<void> sendAudio() async {
    update(() {
      working = true;
      error = null;
    });
    try {
      if (uploadedId == null) {
        final bytes = await File(path!).readAsBytes();
        final result = await service.upload(
            id!, widget.pillarKey, widget.questionKey, bytes);
        if (!mounted) return;
        uploadedId = result['id'];
        widget.onAttachment(uploadedId);
      }
      final result = await service.transcribe(uploadedId!);
      if (!mounted) return;
      if (!transcribed) {
        final original = widget.controller.text.trimRight();
        widget.controller.text = [
          if (original.isNotEmpty) original,
          result['transcript'] as String
        ].join('\n');
        transcribed = true;
      }
    } catch (e) {
      update(() => error = uploadedId == null
          ? 'Não consegui enviar o áudio. A gravação está nesta tela; tente novamente.'
          : '$e');
    } finally {
      update(() => working = false);
    }
  }

  Future<void> remove() async {
    update(() => working = true);
    try {
      if (uploadedId != null) await service.discard(uploadedId!);
      await deleteLocal(path);
      if (!mounted) return;
      widget.onAttachment(null);
      update(() {
        path = null;
        id = null;
        uploadedId = null;
        transcribed = false;
        error = null;
      });
    } catch (e) {
      update(() => error = '$e');
    } finally {
      update(() => working = false);
    }
  }

  Future<void> deleteLocal(String? file) async {
    if (file == null) return;
    try {
      final f = File(file);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    final currentRecorder = recorder;
    final currentPath = path;
    unawaited(() async {
      try {
        if (recording) await currentRecorder?.cancel();
        await currentRecorder?.dispose();
      } catch (_) {}
      await deleteLocal(currentPath);
    }());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !blocksSending,
        child: Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Prefere responder por áudio?'),
                      const Text(
                          'Até 5 minutos. Ao parar a gravação, o áudio será transcrito automaticamente. A mentora poderá ouvir o áudio e consultar a conversa com a IA.'),
                      if (recording)
                        Text(
                            'Gravando ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'),
                      if (path == null && uploadedId == null && !recording) ...[
                        OutlinedButton.icon(
                            onPressed:
                                working || !widget.enabled ? null : start,
                            icon: const Icon(Icons.mic),
                            label: const Text('Gravar áudio')),
                      ],
                      if (recording)
                        FilledButton.icon(
                            onPressed: working ? null : stop,
                            icon: const Icon(Icons.stop),
                            label: const Text('Parar gravação')),
                      if ((path != null || uploadedId != null) &&
                          !recording) ...[
                        VoicePlayer(localPath: path, audioId: uploadedId),
                        if (uploadedId != null)
                          const Text(
                              'Áudio anexado e transcrito automaticamente. Confira o texto e envie a resposta.'),
                        TextButton(
                            onPressed:
                                working || !widget.enabled ? null : remove,
                            child: const Text('Remover áudio (manter texto)')),
                      ],
                      if (working) const LinearProgressIndicator(),
                      if (error != null)
                        Text(error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                    ]))),
      );
}
