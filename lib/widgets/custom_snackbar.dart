import 'package:flutter/material.dart';

class AnimatedSnackBar extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback? onDismiss;
  final Duration duration;

  const AnimatedSnackBar({
    super.key,
    required this.message,
    required this.isError,
    this.onDismiss,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<AnimatedSnackBar> createState() => _AnimatedSnackBarState();
}

class _AnimatedSnackBarState extends State<AnimatedSnackBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  // Swipe gesture variables
  double _dragOffset = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();

    // Auto dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      if (mounted && widget.onDismiss != null) {
        widget.onDismiss!();
      }
    });
  }

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    
    setState(() {
      // Only allow upward swipes (negative delta)
      _dragOffset = (_dragOffset + details.delta.dy).clamp(-200.0, 0.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    
    _isDragging = false;
    
    // If dragged up more than 50 pixels, dismiss the snackbar
    if (_dragOffset < -50) {
      _dismiss();
    } else {
      // Snap back to original position
      setState(() {
        _dragOffset = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        return GestureDetector(
          onPanStart: _handleDragStart,
          onPanUpdate: _handleDragUpdate,
          onPanEnd: _handleDragEnd,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value * 100 + _dragOffset), // Add drag offset
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 50), // Restored margin for overlay positioning
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isError
                        ? [
                            const Color(0xFFFF6B6B),
                            const Color(0xFFFF5252),
                            const Color(0xFFFF1744),
                          ]
                        : [
                            const Color(0xFF4CAF50),
                            const Color(0xFF66BB6A),
                            const Color(0xFF81C784),
                          ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isError ? Colors.red : Colors.green).withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      // Animated Icon
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          widget.isError ? Icons.error_outline : Icons.check_circle_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Message
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.isError ? 'Error' : 'Success',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      
                      // Close Button
                      GestureDetector(
                        onTap: _dismiss,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          )
        );
      },
    );
  }
}

void showAnimatedSnackBar({
  required BuildContext context,
  required String message,
  required bool isError,
  Duration duration = const Duration(seconds: 4),
}) {
  // Remove any existing snackbars
  ScaffoldMessenger.of(context).clearSnackBars();
  
  // Use Overlay to position at the very top of the screen
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;
  
  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: AnimatedSnackBar(
          message: message,
          isError: isError,
          duration: duration,
          onDismiss: () {
            overlayEntry.remove();
          },
        ),
      ),
    ),
  );
  
  overlay.insert(overlayEntry);
  
  // Auto remove after duration
  Future.delayed(duration + const Duration(milliseconds: 600), () {
    if (overlayEntry.mounted) {
      overlayEntry.remove();
    }
  });
}

// Legacy function for backward compatibility
void showCustomSnackBar({
  required BuildContext context,
  required String message,
  required bool isError,
  Duration duration = const Duration(seconds: 3),
}) {
  showAnimatedSnackBar(
    context: context,
    message: message,
    isError: isError,
    duration: duration,
  );
} 