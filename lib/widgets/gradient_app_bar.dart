import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';

class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final double toolbarHeight;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const GradientAppBar({
    super.key,
    required this.title,
    this.actions,
    this.toolbarHeight = 40,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [

            Color(0xFFa0bee4), // 시작 색상
            Color(0xFF418ded), // 끝 색상 (약간 밝게)


          ],
        ),
      ),
      child: AppBar(
        title: Consumer<SubscriptionProvider>(
          builder: (context, subscriptionProvider, child) {
            final hasActiveSubscription = subscriptionProvider.hasActiveSubscription;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color.fromARGB(255, 34, 36, 39),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (hasActiveSubscription) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Premium',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        backgroundColor: const Color.fromARGB(0, 224, 92, 92),
        elevation: 0,
        toolbarHeight: toolbarHeight,
        actions: actions,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        iconTheme: const IconThemeData(color: Color.fromARGB(255, 50, 51, 56)),
        actionsIconTheme: const IconThemeData(color:Color.fromARGB(255, 23, 24, 29)),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);
}
