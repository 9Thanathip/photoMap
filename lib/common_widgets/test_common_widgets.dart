import 'package:flutter/material.dart';

class TestCommonWidgets extends StatelessWidget {
  const TestCommonWidgets({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text);
  }
}
