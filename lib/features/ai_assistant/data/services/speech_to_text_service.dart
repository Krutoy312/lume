import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records audio and transcribes it via the Alem AI speech-to-text API.
/// Works on both mobile and web.
class SpeechToTextService {
  static String get _apiKey => dotenv.env['ALEM_STT_KEY'] ?? '';
  static const _endpoint = 'https://llm.alem.ai/v1/audio/transcriptions';

  final AudioRecorder _recorder = AudioRecorder();

  /// Whether the recorder is currently capturing audio.
  Future<bool> get isRecording => _recorder.isRecording();

  /// Starts recording. Throws if microphone permission is denied.
  Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) throw Exception('Microphone permission denied');

    // On web the recorder ignores the path and writes to memory (blob).
    // On mobile we write to a real temp file.
    final String path;
    if (kIsWeb) {
      path = 'stt_recording.wav';
    } else {
      final dir = await getTemporaryDirectory();
      path = '${dir.path}/stt_${DateTime.now().millisecondsSinceEpoch}.wav';
    }

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
  }

  /// Stops recording and sends the audio to the API.
  /// Returns the transcribed text, or throws on failure.
  Future<String> stopAndTranscribe() async {
    final path = await _recorder.stop();
    if (path == null) throw Exception('Recording failed: no output file');

    // XFile handles both local file paths (mobile) and blob: URLs (web).
    final bytes = await XFile(path).readAsBytes();
    if (bytes.isEmpty) throw Exception('Recorded audio is empty');

    final request = http.MultipartRequest('POST', Uri.parse(_endpoint))
      ..headers['Authorization'] = 'Bearer $_apiKey'
      ..fields['model'] = 'speech-to-text'
      ..fields['language'] = 'ru'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'recording.wav',
        ),
      );

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw Exception('STT API error ${streamed.statusCode}: $body');
    }

    // Response is plain text transcript or JSON {"text":"..."}.
    final trimmed = body.trim();
    if (trimmed.startsWith('{')) {
      final match = RegExp(r'"text"\s*:\s*"([^"]*)"').firstMatch(trimmed);
      if (match != null) return match.group(1)!;
    }
    return trimmed;
  }

  /// Cancels an in-progress recording without transcribing.
  Future<void> cancelRecording() => _recorder.cancel();

  Future<void> dispose() => _recorder.dispose();
}
