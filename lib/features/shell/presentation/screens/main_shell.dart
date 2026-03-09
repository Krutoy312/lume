import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shell_tab_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/floating_nav_bar.dart';
import '../../../ai_assistant/presentation/screens/ai_chat_screen.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../progress/presentation/screens/progress_screen.dart';
import '../../../settings/presentation/screens/account_screen.dart';
import '../../../shelf/presentation/screens/shelf_screen.dart';

/// Root shell that hosts all 5 tabs with the floating bottom navigation bar.
///
/// Uses [IndexedStack] to keep every tab alive (preserves scroll positions,
/// provider state, etc.) while showing only the selected one.
///
/// The MediaQuery bottom padding is overridden for the [IndexedStack] only,
/// so inner [SafeArea] widgets automatically clear the floating nav bar.
/// The [FloatingNavBar] itself stays outside the override and reads the true
/// system safe area inset for its own positioning.
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const List<Widget> _screens = [
    ShelfScreen(),
    ProgressScreen(),
    HomeScreen(),
    AiChatScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(shellTabProvider);
    final w = MediaQuery.sizeOf(context).width;
    final mq = MediaQuery.of(context);

    // Total vertical space consumed by the floating nav bar from the
    // bottom of the screen:  bar height + visual margin + system safe area.
    final barHeight = w * 0.171;       // 67 / 393
    final bottomMargin = w * 0.041;    // 16 px visual gap above safe area
    final navBarTotalHeight =
        barHeight + bottomMargin + mq.padding.bottom;

    // When the keyboard is open, hide the floating nav bar so it cannot
    // bleed into modal bottom sheets. resizeToAvoidBottomInset: false
    // prevents the Scaffold body from shrinking upward when the keyboard
    // appears — without it, the bar (positioned at bottom: 0 of the Stack)
    // would rise above the keyboard and show through transparent modals.
    final keyboardOpen = mq.viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      // Must be false: if the body shrinks, the FloatingNavBar moves up
      // and becomes visible through the transparent barrier of any modal
      // bottom sheet that uses useRootNavigator: true.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Override bottom padding so child SafeArea widgets clear the bar.
          MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(bottom: navBarTotalHeight),
            ),
            child: IndexedStack(
              index: selectedIndex,
              children: _screens,
            ),
          ),

          // Floating nav bar overlaid at the bottom of the screen.
          // Hidden while the keyboard is open so it never interferes with
          // bottom sheets or keyboard-adjacent UI.
          // Placed OUTSIDE the MediaQuery override to read the real system
          // bottom padding for its own internal layout.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Visibility(
              visible: !keyboardOpen,
              child: FloatingNavBar(
                selectedIndex: selectedIndex,
                onTap: (i) =>
                    ref.read(shellTabProvider.notifier).state = i,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
