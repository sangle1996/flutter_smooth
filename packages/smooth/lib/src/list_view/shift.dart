import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:smooth/src/binding.dart';
import 'package:smooth/src/list_view/controller.dart';

class SmoothShift extends StatefulWidget {
  final ScrollController scrollController;
  final Widget child;

  const SmoothShift({
    super.key,
    required this.scrollController,
    required this.child,
  });

  @override
  State<SmoothShift> createState() => _SmoothShiftState();
}

// try to use mixin to maximize performance
class _SmoothShiftState = _SmoothShiftBase
    with _SmoothShiftFromPointerEvent, _SmoothShiftFromBallistic;

abstract class _SmoothShiftBase extends State<SmoothShift>
    with TickerProviderStateMixin {
  double get offset => 0;

  @override
  @mustCallSuper
  Widget build(BuildContext context) {
    print('hi $runtimeType build offset=$offset');

    return Transform.translate(
      offset: Offset(0, offset),
      transformHitTests: false,
      child: widget.child,
    );
  }
}

// NOTE about this weird timing, see
// * https://github.com/fzyzcjy/yplusplus/issues/5961#issuecomment-1266944825
// * https://github.com/fzyzcjy/yplusplus/issues/5961#issuecomment-1266978644
// for detailed reasons
// (to do: copy it here)
mixin _SmoothShiftFromPointerEvent on _SmoothShiftBase {
  double? _pointerDownPosition;
  double? _positionWhenCurrStartDrawFrame;
  double? _positionWhenPrevStartDrawFrame;
  double? _currPosition;

  double get _offsetFromPointerEvent {
    if (_currPosition == null) return 0;

    final binding = SmoothRendererBindingMixin.instance;

    // https://github.com/fzyzcjy/yplusplus/issues/5961#issuecomment-1266978644
    final basePosition = binding.executingRunPipelineBecauseOfAfterFlushLayout
        ? _positionWhenCurrStartDrawFrame
        : _positionWhenPrevStartDrawFrame;

    print('hi $runtimeType get _offsetFromPointerEvent '
        '_currPosition=$_currPosition '
        'executingRunPipelineBecauseOfAfterFlushLayout=${binding.executingRunPipelineBecauseOfAfterFlushLayout} '
        '_positionWhenCurrStartDrawFrame=$_positionWhenCurrStartDrawFrame '
        '_positionWhenPrevStartDrawFrame=$_positionWhenPrevStartDrawFrame '
        '_pointerDownPosition=$_pointerDownPosition');
    return _currPosition! - (basePosition ?? _pointerDownPosition!);
  }

  @override
  double get offset => super.offset + _offsetFromPointerEvent;

  var _hasPendingStartDrawFrameCallback = false;
  var _hasPendingAfterFlushLayoutCallback = false;
  var _hasPendingPostFrameCallback = false;

  void _maybeAddCallbacks() {
    if (!_hasPendingStartDrawFrameCallback) {
      _hasPendingStartDrawFrameCallback = true;
      SmoothSchedulerBindingMixin.instance.addStartDrawFrameCallback(() {
        if (!mounted) return;
        _hasPendingStartDrawFrameCallback = false;
        setState(() {
          _positionWhenPrevStartDrawFrame = _positionWhenCurrStartDrawFrame;
          _positionWhenCurrStartDrawFrame = _currPosition;
        });

        print('hi $runtimeType addStartDrawFrameCallback.callback (after) '
            '_positionWhenPrevStartDrawFrame=$_positionWhenPrevStartDrawFrame _currPosition=$_currPosition');
      });
    }

    if (!_hasPendingAfterFlushLayoutCallback) {
      _hasPendingAfterFlushLayoutCallback = true;
      SmoothRendererBindingMixin.instance.addAfterFlushLayoutCallback(() {
        _hasPendingAfterFlushLayoutCallback = false;
        // TODO too hacky, optimize this
        // just to make widget rebuild, because
        // [_offsetFromPointerEvent] changes calculation method based
        // on whether it is in AfterFlushLayout
        if (mounted) setState(() {});
      });
    }

    if (!_hasPendingPostFrameCallback) {
      _hasPendingPostFrameCallback = true;
      SmoothRendererBindingMixin.instance.addPostFrameCallback((_) {
        _hasPendingPostFrameCallback = false;
        // TODO too hacky, optimize this
        // rebuild b/c same reason as [addAfterFlushLayoutCallback]
        if (mounted) setState(() {});
      });
    }
  }

  void _handlePointerDown(PointerDownEvent e) {
    setState(() {
      _pointerDownPosition = e.localPosition.dy;
    });
  }

  void _handlePointerMove(PointerMoveEvent e) {
    print(
        'hi $runtimeType _handlePointerMove e.localPosition=${e.localPosition.dy} e=$e');

    setState(() {
      _currPosition = e.localPosition.dy;
    });
  }

  void _handlePointerUpOrCancel(PointerEvent e) {
    setState(() {
      _pointerDownPosition = null;
      _positionWhenCurrStartDrawFrame = null;
      _positionWhenPrevStartDrawFrame = null;
      _currPosition = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    _maybeAddCallbacks();

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUpOrCancel,
      onPointerCancel: _handlePointerUpOrCancel,
      behavior: HitTestBehavior.translucent,
      child: super.build(context),
    );
  }
}

mixin _SmoothShiftFromBallistic on _SmoothShiftBase {
  double _offsetFromBallistic = 0;
  Ticker? _ticker;
  SmoothScrollPositionWithSingleContext? _position;

  @override
  double get offset => super.offset + _offsetFromBallistic;

  @override
  void initState() {
    super.initState();

    // https://github.com/fzyzcjy/yplusplus/issues/5918#issuecomment-1266553640
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _position =
          SmoothScrollPositionWithSingleContext.of(widget.scrollController);
      _position!.lastSimulationInfo.addListener(_handleLastSimulationChanged);
    });
  }

  @override
  void didUpdateWidget(covariant SmoothShift oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(oldWidget.scrollController == widget.scrollController,
        'for simplicity, not yet implemented change of `scrollController`');
    assert(
        SmoothScrollPositionWithSingleContext.of(widget.scrollController) ==
            _position,
        'for simplicity, SmoothScrollPositionWithSingleContext cannot yet be changed');
  }

  @override
  void dispose() {
    _position?.lastSimulationInfo.removeListener(_handleLastSimulationChanged);
    _ticker?.dispose();
    super.dispose();
  }

  void _handleLastSimulationChanged() {
    _ticker?.dispose();

    // re-create ticker, because the [Simulation] wants zero timestamp
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    if (!mounted) return;

    final lastSimulationInfo = _position!.lastSimulationInfo.value;
    if (lastSimulationInfo == null) return;

    final plainValue = lastSimulationInfo.realSimulation.lastX;
    if (plainValue == null) return;

    // ref: [AnimationController._tick]
    final elapsedInSeconds =
        elapsed.inMicroseconds.toDouble() / Duration.microsecondsPerSecond;
    final smoothValue = lastSimulationInfo.clonedSimulation.x(elapsedInSeconds);

    setState(() {
      _offsetFromBallistic = -(smoothValue - plainValue);
    });

    print('hi ${describeIdentity(this)}._tick '
        'set _offsetFromBallistic=$_offsetFromBallistic '
        'since smoothValue=$smoothValue plainValue=$plainValue elapsed=$elapsed');
  }
}
