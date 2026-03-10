import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records audio and transcribes it via the Alem AI speech-to-text API.
class SpeechToTextService {
  static String get _apiKey => dotenv.env['ALEM_STT_KEY'] ?? '';
  static const _endpoint = 'https://llm.alem.ai/v1/audio/transcriptions';

  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingPath;

  /// Whether the recorder is currently capturing audio.
  Future<bool> get isRecording => _recorder.isRecording();

  /// Starts recording. Throws if microphone permission is denied.
  Future<void> startRecording() async {
    if (kIsWeb) throw UnsupportedError('Speech recording is not supported on web');

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) throw Exception('Microphone permission denied');

    final dir = await getTemporaryDirectory();
    _recordingPath = '${dir.path}/stt_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _recordingPath!,
    );
  }

  /// Stops recording and sends the audio to the API.
  /// Returns the transcribed text, or throws on failure.
  Future<String> stopAndTranscribe() async {
    if (kIsWeb) throw UnsupportedError('Speech recording is not supported on web');

    final path = await _recorder.stop();
    if (path == null) throw Exception('Recording failed: no output file');

    final file = File(path);
    if (!file.existsSync()) throw Exception('Audio file not found');

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_endpoint))
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..fields['model'] = 'speech-to-text'
        ..fields['language'] = 'ru'
        ..files.add(await http.MultipartFile.fromPath('file', path));

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode != 200) {
        throw Exception('STT API error ${streamed.statusCode}: $body');
      }

      // Response is plain text transcript (not JSON from this endpoint).
      // Some OpenAI-compatible servers return JSON {"text":"..."}
      // Try JSON first, fall back to plain text.
      final trimmed = body.trim();
      if (trimmed.startsWith('{')) {
        // Quick manual parse — avoid adding dart:convert complexity.
        final match = RegExp(r'"text"\s*:\s*"([^"]*)"').firstMatch(trimmed);
        if (match != null) return match.group(1)!;
      }
      return trimmed;
    } finally {
      // Clean up temp file.
      file.deleteSync();
    }
  }

  /// Cancels an in-progress recording without transcribing.
  Future<void> cancelRecording() async {
    if (kIsWeb) return;
    await _recorder.cancel();
    if (_recordingPath != null) {
      final f = File(_recordingPath!);
      if (f.existsSync()) f.deleteSync();
      _recordingPath = null;
    }
  }

  Future<void> dispose() => _recorder.dispose();
}
