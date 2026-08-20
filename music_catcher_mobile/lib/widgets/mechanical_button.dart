import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 一个模拟真实物理按键的按钮组件
/// 包含：3D立体感、按下动画、触觉反馈、弹簧回弹
class MechanicalButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? color;
  final Color? shadowColor;
  final double borderRadius;
  final double depth; // 按钮凸起高度
  final Duration pressDuration;
  final Duration releaseDuration;
  final bool enableHaptic;
  final EdgeInsets padding;

  const MechanicalButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color,
    this.shadowColor,
    this.borderRadius = 16,
    this.depth = 6,
    this.pressDuration = const Duration(milliseconds: 60),
    this.releaseDuration = const Duration(milliseconds: 120),
    this.enableHaptic = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
  });

  @override
  State<MechanicalButton> createState() => _MechanicalButtonState();
}

class _MechanicalButtonState extends State<MechanicalButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pressAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pressDuration,
      reverseDuration: widget.releaseDuration,
      value: 0, // 0 = 释放状态, 1 = 按下状态
    );

    // 使用弹簧曲线模拟真实按键回弹
    _pressAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = true);
    _controller.forward();
    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
    _controller.reverse();
    widget.onPressed?.call();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final btnColor = widget.color ?? theme.colorScheme.primary;
    final shadow = widget.shadowColor ?? btnColor.withValues(alpha: 0.4);
    final isDisabled = widget.onPressed == null;

    return AnimatedBuilder(
      animation: _pressAnimation,
      builder: (context, child) {
        final pressOffset = _pressAnimation.value * widget.depth;
        final shadowBlur = isDisabled ? 0.0 : (widget.depth - pressOffset) * 2;
        final shadowOffset = isDisabled ? 0.0 : (widget.depth - pressOffset);

        return Transform.translate(
          offset: Offset(0, pressOffset),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: isDisabled
                  ? []
                  : [
                      // 底部深色阴影（模拟按钮底座）
                      BoxShadow(
                        color: shadow.withValues(alpha: 0.6),
                        offset: Offset(0, shadowOffset + 1),
                        blurRadius: shadowBlur,
                        spreadRadius: 0,
                      ),
                      // 环境光阴影
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        offset: Offset(0, shadowOffset + 2),
                        blurRadius: shadowBlur * 1.5,
                        spreadRadius: 1,
                      ),
                    ],
            ),
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: AnimatedContainer(
                duration: widget.pressDuration,
                padding: widget.padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDisabled
                        ? [Colors.grey.shade600, Colors.grey.shade700]
                        : _isPressed
                            ? [btnColor.withValues(alpha: 0.8), btnColor]
                            : [btnColor.withValues(alpha: 1.0), btnColor.withValues(alpha: 0.85)],
                  ),
                  // 顶部高光（模拟光源照射）
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: isDisabled ? 0.05 : (_isPressed ? 0.05 : 0.2)),
                      width: 1,
                    ),
                    left: BorderSide(
                      color: Colors.white.withValues(alpha: isDisabled ? 0.02 : (_isPressed ? 0.02 : 0.1)),
                      width: 0.5,
                    ),
                    right: BorderSide(
                      color: Colors.black.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                    bottom: BorderSide(
                      color: Colors.black.withValues(alpha: _isPressed ? 0.05 : 0.15),
                      width: 1,
                    ),
                  ),
                ),
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: isDisabled ? Colors.grey.shade400 : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  child: IconTheme(
                    data: IconThemeData(
                      color: isDisabled ? Colors.grey.shade400 : Colors.white,
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 圆形机械按钮（用于图标按钮）
class MechanicalIconButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final double size;
  final Color? color;
  final Color? iconColor;
  final bool enableHaptic;

  const MechanicalIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.size = 48,
    this.color,
    this.iconColor,
    this.enableHaptic = true,
  });

  @override
  State<MechanicalIconButton> createState() => _MechanicalIconButtonState();
}

class _MechanicalIconButtonState extends State<MechanicalIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
      reverseDuration: const Duration(milliseconds: 100),
      value: 0,
    );
    _pressAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final btnColor = widget.color ?? theme.colorScheme.primary;
    final isDisabled = widget.onPressed == null;
    final depth = 4.0;

    return AnimatedBuilder(
      animation: _pressAnimation,
      builder: (context, child) {
        final pressOffset = _pressAnimation.value * depth;
        final shadowBlur = (depth - pressOffset) * 2;

        return Transform.translate(
          offset: Offset(0, pressOffset),
          child: Listener(
            onPointerDown: (e) {
              if (isDisabled) return;
              _controller.forward();
              if (widget.enableHaptic) HapticFeedback.lightImpact();
            },
            onPointerUp: (e) {
              if (isDisabled) return;
              _controller.reverse();
              widget.onPressed?.call();
            },
            onPointerCancel: (e) => _controller.reverse(),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDisabled ? Colors.grey.shade600 : btnColor,
                boxShadow: isDisabled
                    ? []
                    : [
                        BoxShadow(
                          color: btnColor.withValues(alpha: 0.4),
                          offset: Offset(0, shadowBlur * 0.5),
                          blurRadius: shadowBlur,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          offset: Offset(0, shadowBlur * 0.5 + 1),
                          blurRadius: shadowBlur * 1.5,
                        ),
                      ],
              ),
              child: Icon(
                widget.icon,
                color: widget.iconColor ?? (isDisabled ? Colors.grey.shade400 : Colors.white),
                size: widget.size * 0.5,
              ),
            ),
          ),
        );
      },
    );
  }
}
