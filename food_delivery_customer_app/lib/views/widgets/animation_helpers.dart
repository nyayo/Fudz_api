import 'package:flutter/material.dart';

/// Reusable staggered fade-slide animation for list items.
/// Animation removed for performance — just returns the child.
class StaggeredFadeSlide extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final Widget child;
  final double maxDelay;
  final Offset slideOffset;

  const StaggeredFadeSlide({
    super.key,
    required this.index,
    required this.controller,
    required this.child,
    this.maxDelay = 0.6,
    this.slideOffset = const Offset(0, 0.15),
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// A simple fade + slide entrance — animation removed for performance.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset slideOffset;
  final Curve curve;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
    this.slideOffset = const Offset(0, 0.08),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// Scale pop-in — animation removed for performance.
class ScalePopIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;

  const ScalePopIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutBack,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
