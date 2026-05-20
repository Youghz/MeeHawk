import 'package:app/core/theme.dart';
import 'package:flutter/material.dart';

class NavCard extends StatelessWidget {
  const NavCard({required this.children, super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: MH.sand,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MH.rule),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, thickness: 1, color: MH.rule),
                children[i],
              ],
            ],
          ),
        ),
      );
}

class NavMenuItem extends StatelessWidget {
  const NavMenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconColor,
    this.onTap,
    this.enabled = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        splashColor: MH.ink.withValues(alpha: 0.14),
        highlightColor: MH.ink.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: MH.sans(size: 15, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: MH.sans(size: 13, color: MH.pencil),
                    ),
                  ],
                ),
              ),
              if (enabled)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: MH.pencil,
                ),
            ],
          ),
        ),
      ),
    );
    if (!enabled) return Opacity(opacity: 0.38, child: tile);
    return tile;
  }
}
