import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:smooth/smooth.dart';

// NOTE This is used to reproduce [list_text_layout.dart] in Flutter's official
// benchmark, as is requested by @dnfield in #173
class ExampleListTextLayoutSubPage extends StatefulWidget {
  final bool enableSmooth;

  const ExampleListTextLayoutSubPage({super.key, required this.enableSmooth});

  @override
  State<ExampleListTextLayoutSubPage> createState() =>
      ExampleListTextLayoutSubPageState();
}

class ExampleListTextLayoutSubPageState
    extends State<ExampleListTextLayoutSubPage>
    with SingleTickerProviderStateMixin {
  bool _showText = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _showText = !_showText;
          });
          _controller
            ..reset()
            ..forward();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('hi ${describeIdentity(this)}.build _showText=$_showText');

    return widget.enableSmooth
        ? SmoothBuilder(
            // usually put animations etc in [builder], but this page does not have
            // that...
            builder: (context, child) {
              print(
                  'hi ${describeIdentity(this)}.SmoothBuilder.build _showText=$_showText');
              // hack: have not dealt with subtle setState etc, so brute-force
              // let everything refresh in every frame
              return AlwaysBuildBuilder(
                builder: (_) {
                  print(
                      'hi ${describeIdentity(this)}.SmoothBuilder.AlwaysBuildBuilder.build _showText=$_showText');
                  return KeyedSubtree(
                    key: ValueKey(_showText),
                    child: child,
                  );
                },
              );
            },
            child: _buildCore(),
          )
        : _buildCore();
  }

  Widget _buildCore() {
    return CircularProgressIndicator();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: double.infinity,
          child: !_showText
              ? Container()
              : Column(
                  children: List<Widget>.generate(9, (int index) {
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text('G$index'),
                      ),
                      title: SmoothLayoutPreemptPointWidget(
                        child: Text(
                          'Foo contact from $index-th local contact',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      subtitle: SmoothLayoutPreemptPointWidget(
                        child: Text('+91 88888 8800$index'),
                      ),
                    );
                  }),
                ),
        ),
      ),
    );
  }
}

class AlwaysBuildBuilder extends StatefulWidget {
  final WidgetBuilder builder;

  const AlwaysBuildBuilder({super.key, required this.builder});

  @override
  State<AlwaysBuildBuilder> createState() => _AlwaysBuildBuilderState();
}

class _AlwaysBuildBuilderState extends State<AlwaysBuildBuilder> {
  var count = 0;

  @override
  Widget build(BuildContext context) {
    print('hi ${describeIdentity(this)}.build');
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    count++;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.builder(context),
          Center(
              child: Text(
            'count=$count',
            style: const TextStyle(color: Colors.blue),
          )),
        ],
      ),
    );
  }
}