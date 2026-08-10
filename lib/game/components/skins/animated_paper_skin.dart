import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show Alignment, LinearGradient, PaintingStyle;

import '../../../core/enums/game_enums.dart';

/// Eight-frame sprite-sheet overlay for premium animated paper skins.
///
/// Frames are rasterized once when the skin is equipped, then played by Flame's
/// [SpriteAnimationComponent] rather than issuing a bespoke canvas animation on
/// every frame. The generated sheet keeps the project asset-light while using
/// the same production path as an imported flipbook texture would.
class AnimatedPaperSkin extends PositionComponent {
  AnimatedPaperSkin({
    required this.skin,
    required Vector2 planeSize,
  }) : super(
          size: planeSize,
          position: Vector2.zero(),
          anchor: Anchor.topLeft,
        );

  static const int frameCount = 8;
  static const int _frameWidth = 96;
  static const int _frameHeight = 64;

  /// Premium sheets are immutable after generation, so re-equipping a skin
  /// reuses its image rather than rasterizing another eight frames.
  static final Map<PaperSkin, Future<ui.Image>> _spriteSheetCache = {};

  final PaperSkin skin;

  @override
  Future<void> onLoad() async {
    final spriteSheet = await _spriteSheetCache.putIfAbsent(
      skin,
      () => _buildSpriteSheet(skin),
    );
    final frameSize = Vector2(_frameWidth.toDouble(), _frameHeight.toDouble());
    final sprites = List<Sprite>.generate(
      frameCount,
      (frame) => Sprite(
        spriteSheet,
        srcPosition: Vector2(_frameWidth.toDouble() * frame.toDouble(), 0),
        srcSize: frameSize,
      ),
    );
    final animation = SpriteAnimation.spriteList(
      sprites,
      stepTime: skin == PaperSkin.lavaLamp ? .14 : .105,
      loop: true,
    );
    final overlay = SpriteAnimationComponent(
      animation: animation,
      size: size.clone(),
      position: size / 2,
      anchor: Anchor.center,
    )..angle = -math.pi / 2;
    add(overlay);
    await super.onLoad();
  }

  static Future<ui.Image> _buildSpriteSheet(PaperSkin skin) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    for (var frame = 0; frame < frameCount; frame++) {
      canvas.save();
      canvas.translate(_frameWidth.toDouble() * frame.toDouble(), 0);
      _drawFrame(canvas, skin, frame);
      canvas.restore();
    }
    final picture = recorder.endRecording();
    return picture.toImage(_frameWidth * frameCount, _frameHeight);
  }

  static void _drawFrame(ui.Canvas canvas, PaperSkin skin, int frame) {
    final frameRect = ui.Rect.fromLTWH(
      0,
      0,
      _frameWidth.toDouble(),
      _frameHeight.toDouble(),
    );
    final paperMask = _paperPlaneMask();

    canvas.save();
    canvas.clipPath(paperMask);
    switch (skin) {
      case PaperSkin.lavaLamp:
        _drawLavaFrame(canvas, frame, frameRect);
        break;
      case PaperSkin.flipbook:
        _drawFlipbookFrame(canvas, frame, frameRect);
        break;
      default:
        _drawHologramFrame(canvas, frame, frameRect);
        break;
    }
    canvas.restore();

    // A single thin edge makes the overlay read as paper rather than a floating
    // rectangular effect, including on the less dart-like plane silhouettes.
    final rim = ui.Paint()
      ..color = const ui.Color(0x99FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(paperMask, rim);
  }

  static ui.Path _paperPlaneMask() {
    const w = 96.0;
    const h = 64.0;
    final cy = h / 2;
    return ui.Path()
      ..moveTo(w - 2, cy)
      ..lineTo(w * .34, cy)
      ..lineTo(0, h * .08)
      ..lineTo(w * .20, cy)
      ..lineTo(0, h * .92)
      ..lineTo(w * .34, cy)
      ..close();
  }

  static void _drawHologramFrame(
    ui.Canvas canvas,
    int frame,
    ui.Rect rect,
  ) {
    const palette = <ui.Color>[
      ui.Color(0xFFE040FB),
      ui.Color(0xFF00E5FF),
      ui.Color(0xFF76FF03),
      ui.Color(0xFFFFD740),
      ui.Color(0xFFFF4081),
      ui.Color(0xFF7C4DFF),
      ui.Color(0xFF40C4FF),
      ui.Color(0xFFFFEA00),
    ];
    final c1 = palette[frame % palette.length].withOpacity(.62);
    final c2 = palette[(frame + 3) % palette.length].withOpacity(.55);
    final c3 = palette[(frame + 5) % palette.length].withOpacity(.48);
    final base = ui.Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c1, c2, c3, c1],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, base);

    final sweepX = ((frame / frameCount) * (_frameWidth + 36) - 18).toDouble();
    final sweep = ui.Path()
      ..moveTo(sweepX - 18, 0)
      ..lineTo(sweepX + 6, 0)
      ..lineTo(sweepX + 42, _frameHeight.toDouble())
      ..lineTo(sweepX + 18, _frameHeight.toDouble())
      ..close();
    canvas.drawPath(
      sweep,
      ui.Paint()..color = const ui.Color(0xCCFFFFFF).withOpacity(.45),
    );
  }

  static void _drawLavaFrame(
    ui.Canvas canvas,
    int frame,
    ui.Rect rect,
  ) {
    canvas.drawRect(
      rect,
      ui.Paint()..color = const ui.Color(0xAA4A148C),
    );
    final phase = frame / frameCount * math.pi * 2;
    final pink = ui.Paint()
      ..color = const ui.Color(0xCCFF4081)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 7);
    final cyan = ui.Paint()
      ..color = const ui.Color(0xCC00E5FF)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
    final width = _frameWidth.toDouble();
    final height = _frameHeight.toDouble();
    canvas.drawCircle(
      ui.Offset(
        width * (.38 + math.sin(phase) * .16),
        height * (.48 + math.cos(phase * 1.3) * .18),
      ),
      18.0,
      pink,
    );
    canvas.drawCircle(
      ui.Offset(
        width * (.66 + math.cos(phase * 1.4) * .13),
        height * (.54 + math.sin(phase * 1.8) * .16),
      ),
      15.0,
      cyan,
    );
  }

  static void _drawFlipbookFrame(
    ui.Canvas canvas,
    int frame,
    ui.Rect rect,
  ) {
    final page = ui.Paint()
      ..color = const ui.Color(0xCC7C4DFF)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, page);

    final frameProgress = frame / (frameCount - 1);
    final width = _frameWidth.toDouble();
    final height = _frameHeight.toDouble();
    final ink = ui.Paint()
      ..color = const ui.Color(0xCCFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    // The moving crease and page-corner are intentionally discrete frame
    // states, making the skin read like a hand-flipped paper animation.
    final creaseX = width * (.18 + frameProgress * .62);
    canvas.drawLine(
      ui.Offset(creaseX, 7.0),
      ui.Offset(creaseX - 14.0, height - 7.0),
      ink,
    );
    final corner = ui.Path()
      ..moveTo(width - 24.0 + frameProgress * 10.0, 5.0)
      ..lineTo(width - 5.0, 5.0)
      ..lineTo(width - 5.0, 22.0 + frameProgress * 10.0)
      ..close();
    canvas.drawPath(
      corner,
      ui.Paint()..color = const ui.Color(0x99E1BEE7),
    );

    final tick = ui.Paint()
      ..color = const ui.Color(0xFFB2FF59)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      ui.Offset(width * (.28 + frameProgress * .42), height * .52),
      3.0 + (frame % 3).toDouble(),
      tick,
    );
  }
}
