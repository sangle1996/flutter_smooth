import 'package:flutter/material.dart';
import 'package:smooth/src/adapter_in_auxiliary_tree.dart';
import 'package:smooth/src/adapter_in_main_tree.dart';
import 'package:smooth/src/auxiliary_tree_pack.dart';

// TODO merge with classical [SmoothBuilder]
class SmoothMultiChildBuilder extends StatefulWidget {
  final Widget Function(BuildContext context) smoothBuilder;
  final Widget Function(BuildContext context, Object slot) childBuilder;

  const SmoothMultiChildBuilder({
    super.key,
    required this.smoothBuilder,
    required this.childBuilder,
  });

  @override
  State<SmoothMultiChildBuilder> createState() =>
      _SmoothMultiChildBuilderState();
}

class _SmoothMultiChildBuilderState extends State<SmoothMultiChildBuilder> {
  late final AuxiliaryTreePack pack;

  @override
  void initState() {
    super.initState();
    // print('${describeIdentity(this)} initState');

    pack = AuxiliaryTreePack(
      (pack) => Builder(
        builder: (context) => widget.smoothBuilder(context),
      ),
    );
  }

  @override
  void dispose() {
    // print('${describeIdentity(this)} dispose');
    pack.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // hack: [AdapterInMainTreeWidget] does not respect "offset" in paint
    // now, so we add a RepaintBoundary to let offset==0
    return RepaintBoundary(
      child: AdapterInMainTreeWidget(
        pack: pack,
        children: TODO,
      ),
    );
  }
}

class SmoothChildPlaceholder extends StatelessWidget {
  final Object slot;

  const SmoothChildPlaceholder({super.key, required this.slot});

  @override
  Widget build(BuildContext context) {
    return TODO;
  }
}