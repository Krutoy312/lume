import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controls which tab is currently selected in [MainShell].
///
/// Tab indices: 0=Shelf, 1=Progress, 2=Home, 3=Chat, 4=Account
///
/// Any widget inside the app can switch tabs by writing to this provider:
/// ```dart
/// ref.read(shellTabProvider.notifier).state = 3; // go to Chat
/// ```
final shellTabProvider = StateProvider<int>((_) => 2);
