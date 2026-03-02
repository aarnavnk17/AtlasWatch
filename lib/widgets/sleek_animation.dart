import 'package:flutter/material.dart';

enum SleekAnimationType { fade, slide, scale }

class SleekAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final SleekAnimationType type;
  final Offset slideOffset;

  const SleekAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 800),
    this.delay = Duration.zero,
    this.type = SleekAnimationType.fade,
    this.slideOffset = const Offset(0, 0.2),
  });

  @override
  State<SleekAnimation> createState() => _SleekAnimationState();
}

class _SleekAnimationState extends State<SleekAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _slide = Tween<Offset>(begin: widget.slideOffset, end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _scale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        Widget result = child!;

        if (widget.type == SleekAnimationType.fade || true) {
          result = Opacity(opacity: _opacity.value, child: result);
        }

        if (widget.type == SleekAnimationType.slide) {
          result = FractionalTranslation(
            translation: _slide.value,
            child: result,
          );
        } else if (widget.type == SleekAnimationType.scale) {
          result = Transform.scale(scale: _scale.value, child: result);
        }

        return result;
      },
      child: widget.child,
    );
  }
}
