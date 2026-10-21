import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../theme.dart';

/// IMIC's staggered-dots loader.
class AppLoader extends StatelessWidget {
  final Color color;
  final double size;
  const AppLoader({super.key, this.color = AppColors.rose, this.size = 32});

  @override
  Widget build(BuildContext context) =>
      LoadingAnimationWidget.staggeredDotsWave(color: color, size: size);
}

/// Full-width rounded button with an inline loader, like IMIC's AuthButton.
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? icon;
  final Color background;
  final Color foreground;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.background = AppColors.rose,
    this.foreground = AppColors.white,
  });

  /// White button with black text, used for the main action on auth screens.
  const AppButton.light({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
    this.icon,
  }) : background = AppColors.white,
       foreground = AppColors.black;

  @override
  Widget build(BuildContext context) {
    final enabled = !loading && onPressed != null;
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled || loading ? 1 : 0.5,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: loading
              ? AppLoader(color: foreground, size: 22)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[icon!, const SizedBox(width: 8)],
                    Text(
                      text,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Round translucent back button.
class CircleBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const CircleBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Material(
      color: Colors.white.withValues(alpha: 0.10),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed ?? () => Navigator.maybePop(context),
        child: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 18,
        ),
      ),
    ),
  );
}

class NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;
  const NavItem(this.icon, this.selectedIcon, this.label, {this.badge = 0});
}

/// Small rose pill with a count, e.g. unread messages.
class UnreadBadge extends StatelessWidget {
  final int count;
  const UnreadBadge(this.count, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 20),
    height: 20,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.rose,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.black, width: 1.5),
    ),
    child: Text(
      count > 99 ? '99+' : '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// IMIC's floating frosted pill nav: icons only, selected tab in a rose circle.
class FloatingNavBar extends StatelessWidget {
  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const FloatingNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF5EEEE).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(45),
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  label: items[i].label,
                  selected: i == selectedIndex,
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: SizedBox(
                      height: 52,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == selectedIndex
                                ? AppColors.rose
                                : Colors.transparent,
                          ),
                          child: Badge(
                            isLabelVisible:
                                items[i].badge > 0 && i != selectedIndex,
                            backgroundColor: AppColors.rose,
                            label: Text(
                              items[i].badge > 99 ? '99+' : '${items[i].badge}',
                            ),
                            child: Icon(
                              i == selectedIndex
                                  ? items[i].selectedIcon
                                  : items[i].icon,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
