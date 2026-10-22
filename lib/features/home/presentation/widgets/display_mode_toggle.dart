import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/data/models/setting.dart';
import 'package:money_manager/data/repositories/settings_repository.dart';

class DisplayModeToggle extends ConsumerWidget {
  const DisplayModeToggle({
    super.key,
    required this.uid,
    required this.setting,
  });

  final String uid;
  final Setting setting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 'cdf', label: Text('CDF')),
          ButtonSegment(value: 'usd', label: Text('USD')),
          ButtonSegment(value: 'combined', label: Text('Both')),
        ],
        selected: {setting.displayMode},
        onSelectionChanged: (values) {
          final mode = values.first;
          if (mode == setting.displayMode) return;
          unawaited(
            ref
                .read(settingsRepositoryProvider)
                .saveSettings(uid, setting.copyWith(displayMode: mode)),
          );
        },
      ),
    );
  }
}
