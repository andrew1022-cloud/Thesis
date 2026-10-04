import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'home_widgets.dart' show kMaroon, kGold, primaryTextColor, secondaryTextColor;

/// Generic gold medal with ribbons. Set [animate] to play the
/// "unlock" animation once when it first appears.
class MedalIcon extends StatefulWidget {
  final double size;
  final IconData icon;
  final bool animate;
  final bool locked;

  const MedalIcon({
    super.key,
    this.size = 56,
    this.icon = Icons.star_rounded,
    this.animate = false,
    this.locked = false,
  });

  @override
  State<MedalIcon> createState() => _MedalIconState();
}

class _MedalIconState extends State<MedalIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      value: widget.animate ? 0 : 1,
    );
    if (widget.animate) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _phase(double start, double end, Curve curve) {
    final t = ((_c.value - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final d = s * 0.75; // medal diameter
    final rw = s * 0.2; // ribbon width
    final locked = widget.locked;

    final gold1 = locked ? Colors.grey.shade300 : const Color(0xFFF1D98A);
    final gold2 = locked ? Colors.grey.shade500 : kGold;
    final gold3 = locked ? Colors.grey.shade600 : const Color(0xFF9A7424);
    final ribbon = locked ? Colors.grey.shade500 : kMaroon;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final pop = _phase(0.0, 0.55, Curves.elasticOut);
        final ribbonT = _phase(0.15, 0.6, Curves.easeOutBack);
        final shineT = _phase(0.55, 0.95, Curves.easeInOut);
        final sparkleT = _phase(0.5, 1.0, Curves.easeOut);

        Widget ribbonTail(double angle, double left) => Positioned(
              top: d * 0.62,
              left: left,
              child: Opacity(
                opacity: ribbonT.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, -(1 - ribbonT) * s * 0.2),
                  child: Transform.rotate(
                    angle: angle,
                    child: Container(
                      width: rw,
                      height: s * 0.5,
                      decoration: BoxDecoration(
                        color: ribbon,
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(3)),
                        border: Border(
                          left: BorderSide(color: gold2, width: 1.2),
                          right: BorderSide(color: gold2, width: 1.2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );

        return SizedBox(
          width: s,
          height: s * 1.25,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ribbonTail(0.28, s * 0.5 - rw * 1.1),
              ribbonTail(-0.28, s * 0.5 + rw * 0.1),

              // Medal face
              Positioned(
                top: 0,
                left: (s - d) / 2,
                child: Transform.scale(
                  scale: pop.clamp(0.0, 1.3),
                  child: Container(
                    width: d,
                    height: d,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [gold1, gold2, gold3],
                      ),
                      boxShadow: locked
                          ? []
                          : [
                              BoxShadow(
                                color: kGold.withOpacity(0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: ClipOval(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // inner ring
                          Container(
                            width: d * 0.78,
                            height: d * 0.78,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.6),
                                width: 1.5,
                              ),
                            ),
                          ),
                          Icon(
                            locked ? Icons.lock_rounded : widget.icon,
                            color: locked ? Colors.white : kMaroon,
                            size: d * 0.46,
                          ),
                          // shine sweep
                          if (!locked &&
                              widget.animate &&
                              shineT > 0 &&
                              shineT < 1)
                            Transform.translate(
                              offset: Offset((shineT * 2 - 1) * d, 0),
                              child: Transform.rotate(
                                angle: 0.5,
                                child: Container(
                                  width: d * 0.22,
                                  height: d * 1.6,
                                  color: Colors.white.withOpacity(0.55),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Sparkles
              if (!locked && widget.animate && sparkleT > 0 && sparkleT < 1)
                for (var i = 0; i < 6; i++)
                  Builder(builder: (_) {
                    final angle = i * math.pi / 3 + 0.3;
                    final radius = d * 0.55 + sparkleT * s * 0.22;
                    final cx = s / 2 + math.cos(angle) * radius;
                    final cy = d / 2 + math.sin(angle) * radius;
                    return Positioned(
                      left: cx - 6,
                      top: cy - 6,
                      child: Opacity(
                        opacity: math.sin(math.pi * sparkleT),
                        child: const Icon(Icons.star_rounded,
                            size: 12, color: kGold),
                      ),
                    );
                  }),
            ],
          ),
        );
      },
    );
  }
}

/// Celebration popup — call when a badge is earned.
Future<void> showMedalUnlocked(
  BuildContext context, {
  required String label,
  IconData icon = Icons.star_rounded,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Theme.of(ctx).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MedalIcon(size: 110, icon: icon, animate: true),
            const SizedBox(height: 12),
            Text(
              'Badge Unlocked!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                fontFamily: 'Georgia',
                color: primaryTextColor(ctx),
              ),
            ),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(color: secondaryTextColor(ctx))),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kMaroon,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text('Awesome!',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
