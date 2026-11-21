import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../features/contracts/domain/entities/lex_models.dart';
import '../theme/app_theme.dart';
import 'glass_surface.dart';

/// 🎯 3D Effect Radial Legal Health Gauge for Mobile (Glanceable, minimal text)
class GlanceableRiskGauge extends StatelessWidget {
  const GlanceableRiskGauge({
    super.key,
    required this.analysis,
    this.onTapFinding,
  });

  final ContractAnalysis analysis;
  final ValueChanged<ClauseFinding>? onTapFinding;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final redCount = analysis.countByColor(RiskColor.red);
    final yellowCount = analysis.countByColor(RiskColor.yellow);
    final greenCount = analysis.countByColor(RiskColor.green);
    final grayCount = analysis.countByColor(RiskColor.gray);

    // Xavfsizlik indeksi (100 = mukammal)
    final safetyScore = math.max(10, 100 - (redCount * 25 + yellowCount * 10));

    final Color ringColor = safetyScore >= 75
        ? const Color(0xFF10B981)
        : safetyScore >= 45
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return GlassCard(
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 1. Katta Radial Gauge (3D Glow bilan)
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _Radial3DGaugePainter(
                    score: safetyScore,
                    ringColor: ringColor,
                    trackColor: c.textSecondary.withValues(alpha: 0.15),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$safetyScore',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            color: ringColor,
                          ),
                        ),
                        Text(
                          '/100',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // 2. 4-Pill Glanceable Matritsa (Tezkor va yozuvsiz)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      safetyScore >= 75
                          ? 'YUQORI XAVFSIZLIK'
                          : safetyScore >= 45
                              ? 'O‘RTACHA ASIMMETRIYA'
                              : 'KRITIK HUQUQIY XAVF',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: ringColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _MiniCountBadge(
                          color: const Color(0xFFEF4444),
                          label: '🔴 $redCount',
                        ),
                        _MiniCountBadge(
                          color: const Color(0xFFF59E0B),
                          label: '🟡 $yellowCount',
                        ),
                        _MiniCountBadge(
                          color: const Color(0xFF10B981),
                          label: '🟢 $greenCount',
                        ),
                        _MiniCountBadge(
                          color: const Color(0xFF6B7280),
                          label: '⚪ $grayCount',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'O‘RQ-547 Anonimlashtirilgan · FK 4-modda Temporal RAG',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 3. DNA BARCODE HEATMAP STRIP (Moddalar Lentasini ko'rgandayoq tushunish)
          Text(
            'SHARTNOMA MODDALARI DNA LENTASI:',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 24,
              color: c.textSecondary.withValues(alpha: 0.08),
              child: Row(
                children: analysis.findings.map((f) {
                  final Color barColor = switch (f.riskColor) {
                    RiskColor.red => const Color(0xFFEF4444),
                    RiskColor.yellow => const Color(0xFFF59E0B),
                    RiskColor.green => const Color(0xFF10B981),
                    RiskColor.gray => const Color(0xFF9CA3AF),
                  };

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTapFinding?.call(f),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCountBadge extends StatelessWidget {
  const _MiniCountBadge({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _Radial3DGaugePainter extends CustomPainter {
  _Radial3DGaugePainter({
    required this.score,
    required this.ringColor,
    required this.trackColor,
  });

  final int score;
  final Color ringColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;
    const strokeWidth = 10.0;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Active Arc
    final sweepAngle = (score / 100.0) * 2 * math.pi;
    final arcPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Outer Glow effect
    final glowPaint = Paint()
      ..color = ringColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      glowPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _Radial3DGaugePainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.ringColor != ringColor;
}

/// 🎙️ Mobile AI Live Voice Assistant Bar (Ovozli tahlil & Audio briefing)
class MobileVoiceAssistantBar extends StatefulWidget {
  const MobileVoiceAssistantBar({
    super.key,
    required this.analysis,
  });

  final ContractAnalysis analysis;

  @override
  State<MobileVoiceAssistantBar> createState() => _MobileVoiceAssistantBarState();
}

class _MobileVoiceAssistantBarState extends State<MobileVoiceAssistantBar>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _animCtrl.repeat(reverse: true);
      } else {
        _animCtrl.stop();
      }
    });

    if (_isPlaying) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🎙️ LexGuard Ovozli Yurist: 30 soniyalik audio brifing o‘qilmoqda...',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;

    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Play / Pause Circle
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    c.rolePrimary,
                    c.rolePrimaryDark,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: c.rolePrimary.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Waveform Animation / Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'AI Ovozli Brifing (30s)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                AnimatedBuilder(
                  animation: _animCtrl,
                  builder: (context, _) {
                    return ClipRect(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(8, (i) {
                          final wave = _isPlaying
                              ? (math.sin(_animCtrl.value * math.pi * 2 + i * 0.6)
                                          .abs() *
                                      10 +
                                  3)
                              : 3.0;
                          return Container(
                            margin: const EdgeInsets.only(right: 2.5),
                            width: 2.5,
                            height: wave,
                            decoration: BoxDecoration(
                              color: _isPlaying
                                  ? c.rolePrimary
                                  : c.textSecondary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Savol berish mikrofoni
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '🎤 Ovozli savol: "Penya qancha?", "Bekor qilish mumkinmi?"',
                  ),
                ),
              );
            },
            icon: Icon(
              CupertinoIcons.mic_fill,
              color: c.rolePrimary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
