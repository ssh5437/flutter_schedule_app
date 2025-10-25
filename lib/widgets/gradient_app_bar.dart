import 'package:flutter/material.dart';

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
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            color: Color.fromARGB(255, 34, 36, 39),
            fontWeight: FontWeight.w500,
          ),
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
