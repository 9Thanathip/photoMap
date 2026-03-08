import 'package:flutter/material.dart';
import 'package:photo_map/common_widgets/test_common_widgets.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return TestCommonWidgets(text: 'this is test message');
  }
}
