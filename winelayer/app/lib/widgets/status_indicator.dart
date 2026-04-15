import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animated status indicator dot with pulsing effect.
class StatusIndicator extends StatefulWidget {
  final String status;
  final double size;
  final bool showLabel;

  const StatusIndicator({
    super.key,
    required this.status,
    this.size = 10,
    this.showLabel = false,
  });

  @override
  State<StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<StatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Pulse animation for active states
    if (_shouldPulse) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(StatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldPulse) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  bool get _shouldPulse =>
      widget.status == 'running' || widget.status == 'installing';

  Color get _color {
    switch (widget.status) {
      case 'installed':
        return AppColors.success;
      case 'running':
        return AppColors.info;
      case 'installing':
        return AppColors.warning;
      case 'error':
        return AppColors.error;
      case 'pending':
        return AppColors.textTertiary;
      default:
        return AppColors.textTertiary;
    }
  }

  String get _label {
    switch (widget.status) {
      case 'installed':
        return 'Ready';
      case 'running':
        return 'Running';
      case 'installing':
        return 'Installing';
      case 'error':
        return 'Error';
      case 'pending':
        return 'Pending';
      default:
        return widget.status;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget dot = AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _color.withValues(alpha: _shouldPulse ? _animation.value : 1.0),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _color.withValues(alpha: 0.4),
                blurRadius: widget.size,
                spreadRadius: widget.size * 0.2,
              ),
            ],
          ),
        );
      },
    );

    if (widget.showLabel) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          const SizedBox(width: 8),
          Text(
            _label,
            style: TextStyle(
              color: _color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return dot;
  }
}
