import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/country_provider.dart';

class CountryPickerSheet extends ConsumerWidget {
  const CountryPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(countryProvider);
    final notifier = ref.read(countryProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                'Select Country',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            if (state.error != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  state.error!,
                  style: const TextStyle(
                      color: Colors.redAccent, fontSize: 12),
                ),
              ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: state.available.length,
                itemBuilder: (context, i) {
                  final c = state.available[i];
                  final isCurrent = state.current.id == c.id;
                  final downloaded = state.downloadedIds.contains(c.id);
                  final progress = state.downloadProgress[c.id];

                  Widget? trailing;
                  if (progress != null) {
                    trailing = SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        value: progress > 0 ? progress : null,
                        strokeWidth: 2.5,
                      ),
                    );
                  } else if (downloaded) {
                    if (isCurrent) {
                      trailing = const Icon(Icons.radio_button_checked);
                    } else if (!c.isBundled) {
                      trailing = IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => notifier.deleteCountry(c),
                      );
                    }
                  } else {
                    trailing = IconButton(
                      icon: const Icon(Icons.download_rounded),
                      onPressed: () => notifier.downloadCountry(c),
                    );
                  }

                  return ListTile(
                    leading: Icon(
                      downloaded
                          ? Icons.check_circle_rounded
                          : Icons.public_rounded,
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(c.nameEn),
                    subtitle: Text(c.nameTh),
                    trailing: trailing,
                    onTap: downloaded
                        ? () async {
                            await notifier.selectCountry(c);
                            if (context.mounted) Navigator.pop(context);
                          }
                        : null,
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
