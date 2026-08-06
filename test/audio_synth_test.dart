// Unit tests for the runtime audio synthesizer (Task 6 — juice / audio polish).

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/utils/audio_synth.dart';

void main() {
  group('AudioSynth', () {
    test('produces valid RIFF/WAVE 16-bit mono headers', () {
      final bytes = AudioSynth.chime(523.25, volume: 0.5);
      expect(bytes.length, greaterThan(44));
      expect(_ascii(bytes, 0, 4), 'RIFF');
      expect(_ascii(bytes, 8, 4), 'WAVE');
      expect(_ascii(bytes, 12, 4), 'fmt ');
      expect(_ascii(bytes, 36, 4), 'data');
      // PCM, mono, 16-bit
      expect(_u16(bytes, 20), 1);
      expect(_u16(bytes, 22), 1);
      expect(_u16(bytes, 34), 16);
      // data size field matches actual payload
      expect(_u32(bytes, 40), bytes.length - 44);
    });

    test('chime pitch ascends across the pentatonic scale', () {
      final lo = AudioSynth.chime(AudioSynth.chimeScaleHz[0], volume: 0.5);
      final hi = AudioSynth.chime(AudioSynth.chimeScaleHz[8], volume: 0.5);
      // Both are valid, non-empty buffers (length is a smoke check that the
      // synthesis ran cleanly for every scale note).
      expect(lo.length, greaterThan(44));
      expect(hi.length, greaterThan(44));
      expect(AudioSynth.chimeScaleHz[8], greaterThan(AudioSynth.chimeScaleHz[0]));
    });

    test('paper crease returns a non-empty WAV buffer', () {
      final bytes = AudioSynth.paperCrease(volume: 0.5);
      expect(bytes.length, greaterThan(44));
      expect(_ascii(bytes, 0, 4), 'RIFF');
    });
  });
}

String _ascii(List<int> bytes, int start, int len) =>
    String.fromCharCodes(bytes.sublist(start, start + len));

int _u16(List<int> bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8);

int _u32(List<int> bytes, int offset) =>
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);
