import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/voice_service.dart';

class VoicePlayer extends StatefulWidget {
  final String? audioId, localPath;
  const VoicePlayer({super.key, this.audioId, this.localPath});
  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> with WidgetsBindingObserver {
  AudioPlayer? player;
  StreamSubscription<void>? complete;
  bool playing = false, loading = false, paused = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      player?.pause();
      if (mounted)
        setState(() {
          paused = playing || paused;
          playing = false;
        });
    }
  }

  Future<void> toggle() async {
    setState(() => loading = true);
    try {
      player ??= AudioPlayer();
      complete ??= player!.onPlayerComplete.listen((_) {
        if (mounted)
          setState(() {
            playing = false;
            paused = false;
          });
      });
      if (playing) {
        await player!.pause();
        paused = true;
      } else if (paused) {
        await player!.resume();
        paused = false;
      } else {
        final source = widget.localPath != null
            ? DeviceFileSource(widget.localPath!)
            : BytesSource(await VoiceService().audio(widget.audioId!),
                mimeType: 'audio/wav');
        if (!mounted) return;
        await player!.play(source);
      }
      if (mounted)
        setState(() {
          playing = !playing;
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() => error = 'Não consegui reproduzir. Tente novamente.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    complete?.cancel();
    player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextButton.icon(
            onPressed: loading ? null : toggle,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            label: Text(loading
                ? 'Carregando áudio...'
                : playing
                    ? 'Pausar áudio'
                    : 'Ouvir áudio')),
        if (error != null) Text(error!),
      ]);
}

class VoiceHistory extends StatefulWidget {
  final String pillarKey;
  final String? ownerId;
  const VoiceHistory({super.key, required this.pillarKey, this.ownerId});
  @override
  State<VoiceHistory> createState() => _VoiceHistoryState();
}

class _VoiceHistoryState extends State<VoiceHistory> {
  List<dynamic>? rows;
  bool loading = false;
  String? error;
  Future<void> load() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final data =
          await VoiceService().list(widget.pillarKey, ownerId: widget.ownerId);
      if (mounted)
        setState(() {
          rows = data;
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() => error = 'Não consegui carregar as gravações.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
        title: const Text('Áudios das respostas'),
        onExpansionChanged: (open) {
          if (open) load();
        },
        children: [
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            TextButton(onPressed: load, child: Text('$error Tentar novamente')),
          if (rows?.isEmpty == true)
            const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Nenhum áudio enviado neste pilar.')),
          for (final row in rows ?? [])
            ListTile(
                title: Text(row['question_text'] ?? 'Resposta'),
                subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${((row['duration'] ?? 0) as num).round()} segundos'),
                      Text(row['submitted_text'] ?? ''),
                      VoicePlayer(key: ValueKey(row['id']), audioId: row['id']),
                    ])),
        ],
      );
}
