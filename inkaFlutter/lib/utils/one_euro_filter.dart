// lib/utils/one_euro_filter.dart
import 'dart:math';
import 'dart:ui';

class OneEuroFilter {
  final double _minCutoff;
  final double _beta;
  final double _dCutoff;
  
  Offset? _xPrev;
  Offset? _dxPrev;
  int? _lastTime;

  /// [minCutoff]: Filter strength at slow speeds. Lower = more stable, but more lag.
  /// [beta]: Filter adaptation speed. Higher = less lag during fast movements, but more jitter.
  OneEuroFilter({double minCutoff = 1.0, double beta = 0.007, double dCutoff = 1.0})
      : _minCutoff = minCutoff,
        _beta = beta,
        _dCutoff = dCutoff;

  double _alpha(double tE, double cutoff) {
    final r = 2 * pi * cutoff * tE;
    return r / (r + 1);
  }

  Offset filter(Offset x, int timestamp) {
    if (_lastTime == null || _xPrev == null || _dxPrev == null) {
      _lastTime = timestamp;
      _xPrev = x;
      _dxPrev = Offset.zero;
      return x;
    }

    // Time elapsed in seconds
    final tE = (timestamp - _lastTime!) / 1000.0;
    if (tE <= 0) return x;

    // Calculate derivative (velocity)
    final dx = Offset(
      (x.dx - _xPrev!.dx) / tE,
      (x.dy - _xPrev!.dy) / tE,
    );

    // Exponential smoothing of the derivative
    final alphaD = _alpha(tE, _dCutoff);
    final edx = Offset(
      alphaD * dx.dx + (1 - alphaD) * _dxPrev!.dx,
      alphaD * dx.dy + (1 - alphaD) * _dxPrev!.dy,
    );
    _dxPrev = edx;

    // Calculate dynamic cutoff frequency based on velocity
    final velocityMagnitude = sqrt(edx.dx * edx.dx + edx.dy * edx.dy);
    final dynamicCutoff = _minCutoff + _beta * velocityMagnitude;

    // Apply exponential smoothing with dynamic alpha
    final alpha = _alpha(tE, dynamicCutoff);
    final filteredX = alpha * x.dx + (1 - alpha) * _xPrev!.dx;
    final filteredY = alpha * x.dy + (1 - alpha) * _xPrev!.dy;

    final filteredOffset = Offset(filteredX, filteredY);
    
    // Store current state for next frame
    _xPrev = filteredOffset;
    _lastTime = timestamp;

    return filteredOffset;
  }

  void reset() {
    _xPrev = null;
    _dxPrev = null;
    _lastTime = null;
  }
}
