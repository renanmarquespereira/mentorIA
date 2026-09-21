import 'package:flutter/material.dart';

/// Web-safe voice input. The first web release keeps text answers fully
/// functional and deliberately disables local WAV recording, which currently
/// depends on dart:io/path_provider. Browser recording can be added separately.
class VoiceInput extends StatelessWidget {
  final String pillarKey, questionKey;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String?> onAttachment;
  final ValueChanged<bool> onBusy;

  const VoiceInput({
    super.key,
    required this.pillarKey,
    required this.questionKey,
    required this.controller,
    required this.onAttachment,
    required this.onBusy,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          Icon(Icons.language, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'No navegador, responda por texto. A gravação de áudio continua disponível no aplicativo.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ]),
      );
}
