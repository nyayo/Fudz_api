import 'package:flutter/material.dart';

// ──────────────────────────────────────────────────────────────
// Staggered fade + slide for list items (drives off parent controller)
// ──────────────────────────────────────────────────────────────
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
    this.slideOffset = const Offset(0, 0.12),
  });

  @override
  Widget build(BuildContext context) {
    final double start = (index * 0.08).clamp(0.0, maxDelay);
    final double end = (start + 0.4).clamp(start, 1.0);

    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: slideOffset, end: Offset.zero)
            .animate(curved),
        child: child,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Autonomous fade + slide entrance (self-managing controller)
// ──────────────────────────────────────────────────────────────
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset slideOffset;
  final Curve curve;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.slideOffset = const Offset(0, 0.06),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _ctrl, curve: widget.curve);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _offset =
        Tween<Offset>(begin: widget.slideOffset, end: Offset.zero).animate(curved);

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Scale pop-in (e.g. for badges, FABs, icons)
// ──────────────────────────────────────────────────────────────
class ScalePopIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;

  const ScalePopIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 450),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutBack,
  });

  @override
  State<ScalePopIn> createState() => _ScalePopInState();
}

class _ScalePopInState extends State<ScalePopIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _ctrl, curve: widget.curve);
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Smooth page route transition  (shared across all Get.to calls)
// ──────────────────────────────────────────────────────────────
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  SmoothPageRoute({required Widget page, RouteSettings? settings})
      : super(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

// ──────────────────────────────────────────────────────────────
// Animated list item wrapper – animates children as they enter
// ──────────────────────────────────────────────────────────────
class AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration duration;

  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _offset = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(curved);

    // Stagger based on index – cap delay at 600ms
    final delay = Duration(milliseconds: (widget.index * 60).clamp(0, 600));
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Custom GetX transition for route-level usage
// ──────────────────────────────────────────────────────────────
CustomTransition get smoothGetTransition => _SmoothGetTransition();

class _SmoothGetTransition extends CustomTransition {
  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnim = CurvedAnimation(
      parent: animation,
      curve: curve ?? Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnim),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(curvedAnim),
        child: child,
      ),
    );
  }
}
