import 'package:flutter/material.dart';
import 'package:photo_map/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_map/common_widgets/app_sheet_handle.dart';
import 'package:photo_map/common_widgets/glass_sheet.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import '../../../domain/models/country.dart';
import '../../providers/country_provider.dart';

class CountryPickerSheet extends ConsumerStatefulWidget {
  const CountryPickerSheet({super.key});

  @override
  ConsumerState<CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends ConsumerState<CountryPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Country> _filter(List<Country> list) {
    if (_query.isEmpty) return list;
    final q = _query.toLowerCase().trim();
    return list.where((c) {
      return c.nameEn.toLowerCase().contains(q) ||
          c.nameTh.toLowerCase().contains(q) ||
          c.id.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(countryProvider);
    final notifier = ref.read(countryProvider.notifier);
    final filtered = _filter(state.available);

    final botPad = MediaQuery.paddingOf(context).bottom;

    return GlassSheet(
      child: Container(
        padding: EdgeInsets.only(bottom: botPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSheetHandle(title: l10n.countryTitle),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.searchCountries,
                  prefixIcon: const Icon(AppIcons.search_rounded, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(AppIcons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.error_outline_rounded,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          _query.isEmpty
                              ? l10n.noCountriesAvailable
                              : l10n.noResultsFor(_query),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.fromLTRB(
                        8,
                        0,
                        8,
                        MediaQuery.paddingOf(context).bottom + 8,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        return _CountryRow(
                          country: c,
                          isCurrent: state.current.id == c.id,
                          downloaded: state.downloadedIds.contains(c.id),
                          progress: state.downloadProgress[c.id],
                          onTap: state.downloadedIds.contains(c.id)
                              ? () async {
                                  await notifier.selectCountry(c);
                                  if (context.mounted) Navigator.pop(context);
                                }
                              : null,
                          onDownload: () => notifier.downloadCountry(c),
                          onDelete: () => notifier.deleteCountry(c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryRow extends StatelessWidget {
  const _CountryRow({
    required this.country,
    required this.isCurrent,
    required this.downloaded,
    required this.progress,
    required this.onTap,
    required this.onDownload,
    required this.onDelete,
  });

  final Country country;
  final bool isCurrent;
  final bool downloaded;
  final double? progress;
  final VoidCallback? onTap;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget trailingChild;
    if (progress != null) {
      final pct = (progress! * 100).clamp(0, 100).toInt();
      trailingChild = Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              value: progress! > 0 ? progress : null,
              strokeWidth: 2.5,
              color: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.15,
              ),
            ),
          ),
          Text(
            '$pct',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 9,
            ),
          ),
        ],
      );
    } else if (!downloaded) {
      trailingChild = IconButton(
        icon: const Icon(AppIcons.download_rounded, size: 22),
        color: theme.colorScheme.primary,
        onPressed: onDownload,
        tooltip: AppLocalizations.of(context).tooltipDownload,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
      );
    } else if (isCurrent) {
      trailingChild = Icon(
        AppIcons.check_circle_rounded,
        color: theme.colorScheme.primary,
        size: 22,
      );
    } else if (!country.isBundled) {
      trailingChild = IconButton(
        icon: Icon(
          AppIcons.delete_outline_rounded,
          size: 22,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onPressed: onDelete,
        tooltip: AppLocalizations.of(context).tooltipDelete,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
      );
    } else {
      trailingChild = const SizedBox.shrink();
    }

    final trailing = SizedBox(
      width: 40,
      height: 40,
      child: Center(child: trailingChild),
    );

    return Material(
      color: isCurrent
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.6,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  country.isBundled
                      ? AppIcons.flag_rounded
                      : (downloaded
                            ? AppIcons.public_rounded
                            : AppIcons.cloud_outlined),
                  size: 18,
                  color: isCurrent
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      country.nameEn,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (country.nameTh.isNotEmpty &&
                        country.nameTh != country.nameEn)
                      Text(
                        country.nameTh,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
