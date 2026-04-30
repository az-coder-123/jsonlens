import 'package:flutter/material.dart';

class LazyNodeChildren extends StatelessWidget {
  static const int _virtualizationThreshold = 32;

  final dynamic value;
  final List<MapEntry<String, dynamic>> Function(Map<String, dynamic> map)
  sortEntries;
  final String Function(String childKey, {required bool isIndex}) buildPath;
  final Widget Function(
    String keyName,
    dynamic value,
    String path,
    bool isArrayIndex,
  )
  buildChild;

  const LazyNodeChildren({
    super.key,
    required this.value,
    required this.sortEntries,
    required this.buildPath,
    required this.buildChild,
  });

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v is Map<String, dynamic>) {
      final entries = sortEntries(v);
      if (entries.isEmpty) return const SizedBox.shrink();
      if (entries.length <= _virtualizationThreshold) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries
              .map(
                (e) => buildChild(
                  e.key,
                  e.value,
                  buildPath(e.key, isIndex: false),
                  false,
                ),
              )
              .toList(),
        );
      }
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final e = entries[index];
          return buildChild(
            e.key,
            e.value,
            buildPath(e.key, isIndex: false),
            false,
          );
        },
      );
    }

    if (v is List) {
      if (v.isEmpty) return const SizedBox.shrink();
      if (v.length <= _virtualizationThreshold) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            v.length,
            (i) => buildChild(
              '[$i]',
              v[i],
              buildPath('[$i]', isIndex: true),
              true,
            ),
          ),
        );
      }
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: v.length,
        itemBuilder: (context, index) => buildChild(
          '[$index]',
          v[index],
          buildPath('[$index]', isIndex: true),
          true,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
