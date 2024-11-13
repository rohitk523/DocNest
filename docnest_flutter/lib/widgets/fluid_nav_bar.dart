// lib/widgets/fluid_nav_bar.dart
import 'package:flutter/material.dart';

class FluidNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FluidNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<FluidNavBar> createState() => _FluidNavBarState();
}

class _FluidNavBarState extends State<FluidNavBar>
    with TickerProviderStateMixin {
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _animations;

  final List<NavigationItem> _items = [
    NavigationItem(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'Profile'),
    NavigationItem(
        icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
    NavigationItem(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationControllers = List.generate(
      _items.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      ),
    );

    _animations = _animationControllers.map((controller) {
      return Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInBack,
        ),
      );
    }).toList();

    // Initialize current item as selected
    _animationControllers[widget.currentIndex].forward();
  }

  @override
  void didUpdateWidget(FluidNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _animationControllers[oldWidget.currentIndex].reverse();
      _animationControllers[widget.currentIndex].forward();
    }
  }

  @override
  void dispose() {
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2D2D) : Colors.black87,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_items.length, (index) {
              return AnimatedBuilder(
                animation: _animations[index],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _animations[index].value,
                    child: GestureDetector(
                      onTap: () => widget.onTap(index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.currentIndex == index
                              ? (isDark ? Colors.grey[800] : Colors.grey[800])
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.currentIndex == index
                                  ? _items[index].selectedIcon
                                  : _items[index].icon,
                              color: widget.currentIndex == index
                                  ? (isDark
                                      ? theme.colorScheme.primary
                                      : Colors.white)
                                  : Colors.grey[400],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _items[index].label,
                              style: TextStyle(
                                color: widget.currentIndex == index
                                    ? (isDark
                                        ? theme.colorScheme.primary
                                        : Colors.white)
                                    : Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  NavigationItem(
      {required this.icon, required this.selectedIcon, required this.label});
}
