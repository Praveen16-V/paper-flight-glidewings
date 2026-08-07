import 'dart:math' as math;
import 'dart:typed_data';

/// Tiny runtime audio synthesizer for game-feel sounds that have no bundled
/// asset file (the paper-crease flutter and the coin-combo chime melody).
///
/// Everything is generated on the fly as raw 16-bit mono WAV bytes and played
/// through an `AudioPlayer` (`BytesSource`) — so we never depend on missing
/// audio files, and chime pitches are fully controllable per combo count.
///
/// All synthesis is cheap (sub-millisecond for these short buffers), so it is
/// safe to call from the game loop.
class AudioSynth {
  AudioSynth._();

  static const int sampleRate = 22050;

  /// Ascending major-pentatonic scale (mid octave). The coin-combo count maps
  /// onto this list to produce a rising melody as the combo grows, wrapping
  /// back to the top for a musical loop once it maxes out.
  static const List<double> chimeScaleHz = [
    523.25,  // C5
    587.33,  // D5
    659.25,  // E5
    783.99,  // G5
    880.00,  // A5
    1046.50, // C6
    1174.66, // D6
    1318.51, // E6
    1567.98, // G6
  ];

  /// A soft, bell-like chime at [frequency]. [harmonicLevel] brightens the
  /// tone (used so higher combos sound richer).
  static Uint8List chime(
    double frequency, {
    double harmonicLevel = 1.0,
    double volume = 0.5,
  }) {
    const double dur = 0.42;
    final int n = (dur * sampleRate).round();
    final samples = Float64List(n);
    final twoPi = 2 * math.pi;
    for (int i = 0; i < n; i++) {
      final t = i / sampleRate;
      final decay = math.exp(-t * 6.0);
      final attack = math.min(1.0, t / 0.006);
      final s = math.sin(twoPi * frequency * t) +
          0.40 * math.sin(twoPi * frequency * 2 * t) +
          0.16 * harmonicLevel * math.sin(twoPi * frequency * 3 * t) +
          0.06 * harmonicLevel * math.sin(twoPi * frequency * 4 * t);
      samples[i] = s * attack * decay * volume;
    }
    return _encode(samples);
  }

  /// A short, papery flutter/crease — a few sharp noise transients riding on a
  /// soft rustle, high-passed so it reads as "paper folding" not "wind rumble".
  static Uint8List paperCrease({
    double volume = 0.5,
    int burstCount = 4,
  }) {
    const double dur = 0.14;
    final int n = (dur * sampleRate).round();
    final out = Float64List(n);
    final rand = math.Random(7);

    const double burstLen = 0.026;
    // One-pole high-pass state (removes DC + low rumble for a crisper paper).
    double xPrev = 0, yPrev = 0;
    const double alpha = 0.985;

    for (int i = 0; i < n; i++) {
      final t = i / sampleRate;
      double s = 0;
      for (int b = 0; b < burstCount; b++) {
        final start = b * 0.030;
        final local = t - start;
        if (local >= 0 && local < burstLen) {
          final env = math.sin(math.pi * local / burstLen);
          final brightness = math.pow(2, 2 + (b % 2)).toDouble();
          s += (rand.nextDouble() * 2 - 1) * env * brightness;
        }
      }
      // Soft rustling bed underneath.
      s += (rand.nextDouble() * 2 - 1) * 0.35;

      final y = alpha * (yPrev + s - xPrev);
      xPrev = s;
      yPrev = y;
      out[i] = y * 0.30 * volume;
    }
    return _encode(out);
  }

  /// A slow, warm ambient pad for Zen Flight — a soft major-9 chord with a
  /// barely-there airy noise bed and a very gentle amplitude LFO, faded in and
  /// out at both ends so it loops seamlessly. ~10 s, generated once per Zen
  /// session and played on a looping player.
  static Uint8List ambientPad({
    double volume = 0.5,
    double seconds = 10.0,
  }) {
    // Cmaj9 voiced softly: C4, E4, G4, B4, D5 (plus a hint of G3 for warmth).
    const List<double> chordHz = [196.00, 261.63, 329.63, 392.00, 493.88, 587.33];
    final int n = (seconds * sampleRate).round();
    final samples = Float64List(n);
    final rand = math.Random(11);

    // One-pole low-pass state for the noise bed (soft "breeze" rumble).
    double xPrev = 0, yPrev = 0;
    const double alpha = 0.90;

    for (int i = 0; i < n; i++) {
      final t = i / sampleRate;

      // Loop-safe fade: raised-cosine envelope over the whole buffer.
      final fadeIn = 0.5 - 0.5 * math.cos(math.pi * (t / 1.5).clamp(0.0, 1.0));
      final fadeOut = 0.5 + 0.5 * math.cos(math.pi * ((t - (seconds - 1.5)) / 1.5).clamp(0.0, 1.0));
      final edge = fadeIn * fadeOut;

      // Very slow amplitude swell (~0.14 Hz, ±18%) so the pad breathes.
      final swell = 1.0 + 0.18 * math.sin(2 * math.pi * 0.14 * t);

      double s = 0;
      for (int c = 0; c < chordHz.length; c++) {
        final f = chordHz[c];
        // Slight per-voice detune for a wide, organic chorus.
        final detune = 1.0 + (c - 2) * 0.0006;
        final voice = math.sin(2 * math.pi * f * detune * t) +
            0.18 * math.sin(2 * math.pi * f * 2 * detune * t) +
            0.06 * math.sin(2 * math.pi * f * 3 * detune * t);
        // Per-voice slow attack so notes "bloom" instead of starting.
        final voiceEnv = 1.0 - math.exp(-t * 1.2);
        s += voice * voiceEnv * (1.0 / chordHz.length);
      }

      // Airy noise bed, low-passed into a soft breeze.
      final noise = (rand.nextDouble() * 2 - 1) * 0.22;
      final filtered = alpha * (yPrev + noise - xPrev);
      xPrev = noise;
      yPrev = filtered;

      samples[i] = (s * swell + filtered) * edge * volume * 0.55;
    }
    return _encode(samples);
  }

  /// Encodes a float sample buffer (normalised -1..1) as a 16-bit mono WAV.
  static Uint8List _encode(Float64List samples) {
    final sampleCount = samples.length;
    final dataSize = sampleCount * 2;
    final bytes = ByteData(44 + dataSize);

    void ascii(int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        bytes.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little); // fmt chunk size
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    bytes.setUint16(32, 2, Endian.little); // block align
    bytes.setUint16(34, 16, Endian.little); // bits per sample
    ascii(36, 'data');
    bytes.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < sampleCount; i++) {
      final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
      bytes.setInt16(44 + i * 2, v, Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}
