import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_select_provider.dart';
import 'package:photo_map/common_widgets/glass_card.dart';
import 'package:photo_map/core/theme/app_tokens.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  double _dragOffset = 0.0;
  bool _isDragging = false;
  bool _canDrag = false;

  void _onTabSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Future<void> _deleteSelectedPhotos(
      BuildContext context, WidgetRef ref, GallerySelectState select) async {
    final deleted = await ref
        .read(galleryStateProvider.notifier)
        .removePhotos(select.selectedPaths.toList());
    if (deleted.isNotEmpty) {
      ref.read(gallerySelectProvider.notifier).exit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final select = ref.watch(gallerySelectProvider);
    final showDeleteBar = select.isSelectMode && widget.navigationShell.currentIndex == 0;
    final botPad = MediaQuery.paddingOf(context).bottom;
    final safeBot = botPad > 0 ? botPad : 16.0;
    final t = context.tokens;
    final activeColor = t.textPrimary;
    final currentIndex = widget.navigationShell.currentIndex;

    const double tabWidth = 76.25;
    const double capWidth = 60.0;
    const double capHeight = 48.0;
    const double barHeight = 66.0;

    final baseLeft = 10 + currentIndex * tabWidth + (tabWidth - capWidth) / 2;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          widget.navigationShell,
          Positioned(
            left: 20,
            right: 20,
            bottom: safeBot,
            child: showDeleteBar
                ? GlassCard(
                    borderRadius: 24,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _DeleteActionBar(
                      selectedCount: select.selectedCount,
                      onDelete: select.selectedCount > 0
                          ? () => _deleteSelectedPhotos(context, ref, select)
                          : null,
                    ),
                  )
                : Center(
                    child: GestureDetector(
                  onTapDown: (details) {
                    final localX = details.localPosition.dx;
                    final tappedIndex = ((localX - 10) / tabWidth).floor().clamp(0, 3);
                    
                    if (tappedIndex == currentIndex) {
                      setState(() {
                        _isDragging = true;
                        _canDrag = true;
                        _dragOffset = 0.0;
                      });
                    } else {
                      HapticFeedback.selectionClick();
                      _onTabSelected(tappedIndex);
                    }
                  },
                  onTapUp: (_) {
                    setState(() {
                      _isDragging = false;
                      _canDrag = false;
                      _dragOffset = 0.0;
                    });
                  },
                  onTapCancel: () {
                    setState(() {
                      _isDragging = false;
                      _canDrag = false;
                      _dragOffset = 0.0;
                    });
                  },
                  onHorizontalDragStart: (details) {
                    final localX = details.localPosition.dx;
                    final dragIndex = ((localX - 10) / tabWidth).floor().clamp(0, 3);
                    if (dragIndex == currentIndex) {
                      setState(() {
                        _isDragging = true;
                        _canDrag = true;
                        _dragOffset = 0.0;
                      });
                    } else {
                      _canDrag = false;
                    }
                  },
                  onHorizontalDragUpdate: (details) {
                    if (!_canDrag) return;
                    setState(() {
                      _dragOffset += details.delta.dx;

                      // Clamp the capsule position within the bar boundaries
                      final currentPos = baseLeft + _dragOffset;
                      final minPos = 10 + (tabWidth - capWidth) / 2;
                      final maxPos = 10 + 3 * tabWidth + (tabWidth - capWidth) / 2;
                      if (currentPos < minPos) {
                        _dragOffset = minPos - baseLeft;
                      } else if (currentPos > maxPos) {
                        _dragOffset = maxPos - baseLeft;
                      }

                      // Calculate the nearest tab index based on the center of the capsule
                      final capsuleCenter = baseLeft + _dragOffset + capWidth / 2;
                      final nearestIndex = ((capsuleCenter - 10 - tabWidth / 2) / tabWidth)
                          .round()
                          .clamp(0, 3);

                      if (nearestIndex != currentIndex) {
                        HapticFeedback.selectionClick();
                        _onTabSelected(nearestIndex);
                        
                        // Adjust drag offset to maintain finger position smoothly
                        final shift = (nearestIndex - currentIndex) * tabWidth;
                        _dragOffset -= shift;
                      }
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    setState(() {
                      _isDragging = false;
                      _canDrag = false;
                      _dragOffset = 0.0;
                    });
                  },
                  onHorizontalDragCancel: () {
                    setState(() {
                      _isDragging = false;
                      _canDrag = false;
                      _dragOffset = 0.0;
                    });
                  },
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    scale: _isDragging ? 1.04 : 1.0,
                    child: SizedBox(
                      width: 325,
                      height: barHeight,
                      child: GlassCard(
                        borderRadius: 33,
                        padding: EdgeInsets.zero,
                        child: Stack(
                          children: [
                            // Sliding Capsule Highlight Background
                            AnimatedPositioned(
                              duration: _isDragging
                                  ? Duration.zero
                                  : const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              left: baseLeft + _dragOffset,
                              top: (barHeight - capHeight) / 2,
                              width: capWidth,
                              height: capHeight,
                              child: Center(
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutBack,
                                  scale: _isDragging ? 1.12 : 1.0,
                                  child: Container(
                                    width: capWidth,
                                    height: capHeight,
                                    decoration: BoxDecoration(
                                      color: activeColor.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Foreground Row of Icons
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _NavIcon(
                                  isSelected: currentIndex == 0,
                                  icon: Icons.photo_library_outlined,
                                  selectedIcon: Icons.photo_library,
                                ),
                                _NavIcon(
                                  isSelected: currentIndex == 1,
                                  icon: Icons.map_outlined,
                                  selectedIcon: Icons.map,
                                ),
                                _NavIcon(
                                  isSelected: currentIndex == 2,
                                  icon: Icons.emoji_events_outlined,
                                  selectedIcon: Icons.emoji_events,
                                ),
                                _NavIcon(
                                  isSelected: currentIndex == 3,
                                  icon: Icons.settings_outlined,
                                  selectedIcon: Icons.settings,
                                ),
                              ],
                            ),
                          ),
                        ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.isSelected,
    required this.icon,
    required this.selectedIcon,
  });

  final bool isSelected;
  final IconData icon;
  final IconData selectedIcon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final activeColor = t.textPrimary;
    final inactiveColor = t.textSecondary;

    return Expanded(
      child: Center(
        child: SizedBox(
          width: 60,
          height: 48,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: isSelected ? 1.08 : 1.0,
            child: Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteActionBar extends StatelessWidget {
  const _DeleteActionBar({
    required this.selectedCount,
    required this.onDelete,
  });

  final int selectedCount;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$selectedCount selected',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: onDelete != null
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurface.withAlpha(60),
            ),
            iconSize: 28,
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}
