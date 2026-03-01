import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noise_meter/noise_meter.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/noise_filter.dart';
import '../data/report_repository.dart';
import '../../map/data/spots_repository.dart';
import '../../map/domain/spot_model.dart';

enum ReportPhase { idle, measuring, stabilizing, stickerSelection, submitting, done, error }

class ReportState {
  final double currentDb;
  final double stableDb;
  final ReportPhase phase;
  final StickerType? selectedSticker;
  final String? errorMessage;
  final int elapsedSeconds;

  const ReportState({
    this.currentDb = 30.0,
    this.stableDb = 0,
    this.phase = ReportPhase.idle,
    this.selectedSticker,
    this.errorMessage,
    this.elapsedSeconds = 0,
  });

  ReportState copyWith({
    double? currentDb,
    double? stableDb,
    ReportPhase? phase,
    StickerType? selectedSticker,
    String? errorMessage,
    bool clearError = false,
    int? elapsedSeconds,
  }) {
    return ReportState(
      currentDb: currentDb ?? this.currentDb,
      stableDb: stableDb ?? this.stableDb,
      phase: phase ?? this.phase,
      selectedSticker: selectedSticker ?? this.selectedSticker,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }
}

/// Riverpod 3.x Notifier for noise reporting.
/// Call [initialize] before [startMeasurement].
class ReportController extends Notifier<ReportState> {
  NoiseMeter? _meter;
  StreamSubscription<NoiseReading>? _sub;
  Timer? _stabilizeTimer;
  Timer? _elapsedTimer;
  int _elapsed = 0;
  final List<double> _recentReadings = [];

  // Empty string = new spot (will be created on submit)
  String _spotId = '';
  String _spotName = '';
  String? _googlePlaceId;
  double? _spotLat;
  double? _spotLng;

  /// Called by ReportScreen before startMeasurement().
  /// Pass empty [spotId] to create a new spot on submit.
  void initialize({
    required String spotId,
    String spotName = '',
    String? googlePlaceId,
    double? lat,
    double? lng,
  }) {
    _spotId = spotId;
    _spotName = spotName;
    _googlePlaceId = googlePlaceId;
    _spotLat = lat;
    _spotLng = lng;
  }

  /// Update the spot name (used when user types a name for a new spot).
  void updateSpotName(String name) {
    _spotName = name;
  }

  @override
  ReportState build() {
    ref.onDispose(_stopMeasurement);
    return const ReportState();
  }

  /// Begin dB measurement.
  /// Audio is processed in-memory only — never stored or transmitted.
  void startMeasurement() {
    if (state.phase == ReportPhase.measuring || state.phase == ReportPhase.stabilizing) return;
    _elapsed = 0;
    state = state.copyWith(phase: ReportPhase.measuring, elapsedSeconds: 0, clearError: true);
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed++;
      state = state.copyWith(elapsedSeconds: _elapsed);
    });
    _meter = NoiseMeter();

    _sub = _meter!.noise.listen(
      (NoiseReading reading) {
        final db = reading.meanDecibel;
        if (!NoiseFilter.isValid(db)) return;

        _recentReadings.add(db);
        if (_recentReadings.length > 30) _recentReadings.removeAt(0);

        state = state.copyWith(currentDb: db);

        if (_recentReadings.length >= 5 &&
            state.phase == ReportPhase.measuring) {
          state = state.copyWith(phase: ReportPhase.stabilizing);
          _startStabilizationCountdown();
        }
      },
      onError: (e) {
        state = state.copyWith(
          phase: ReportPhase.error,
          errorMessage: '마이크 접근 오류: $e',
        );
        _stopMeasurement();
      },
    );
  }

  void _startStabilizationCountdown() {
    _stabilizeTimer?.cancel();
    _stabilizeTimer = Timer(const Duration(seconds: 3), () {
      final filtered = NoiseFilter.filterOutliers(List.from(_recentReadings));
      if (filtered.isEmpty) return;

      final stable = filtered.reduce((a, b) => a + b) / filtered.length;

      // Audio stream torn down — all voice data volatilised
      _stopMeasurement();

      state = state.copyWith(
        stableDb: stable,
        phase: ReportPhase.stickerSelection,
      );
    });
  }

  /// Public stop — cancels measurement and returns to idle.
  void stopMeasurement() {
    _stopMeasurement();
    state = state.copyWith(phase: ReportPhase.idle, elapsedSeconds: 0);
  }

  void _stopMeasurement() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _sub?.cancel();
    _sub = null;
    _meter = null; // NoiseMeter released — no audio file ever created
    _recentReadings.clear();
    _stabilizeTimer?.cancel();
  }

  Future<bool> verifyProximity() async {
    if (_spotLat == null || _spotLng == null) return true;
    try {
      final pos = await LocationService.getCurrentPosition();
      return LocationService.isWithinReportRadius(
        userLat: pos.latitude,
        userLng: pos.longitude,
        targetLat: _spotLat!,
        targetLng: _spotLng!,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> submitWithSticker(StickerType sticker) async {
    state = state.copyWith(
      selectedSticker: sticker,
      phase: ReportPhase.submitting,
    );

    try {
      var spotId = _spotId;

      // New spot: use stored coordinates (from search) or fall back to GPS
      if (spotId.isEmpty) {
        final double lat, lng;
        if (_spotLat != null && _spotLng != null) {
          lat = _spotLat!;
          lng = _spotLng!;
        } else {
          final pos = await LocationService.getCurrentPosition();
          lat = pos.latitude;
          lng = pos.longitude;
        }
        final name = _spotName.trim().isEmpty ? '내 스팟' : _spotName.trim();
        spotId = await ref.read(spotsRepositoryProvider).createSpot(
          name: name,
          googlePlaceId: _googlePlaceId,
          lat: lat,
          lng: lng,
        );
      }

      await ref.read(reportRepositoryProvider).submitReport(
            spotId: spotId,
            measuredDb: state.stableDb,
            sticker: sticker,
          );
      state = state.copyWith(phase: ReportPhase.done);
    } catch (e) {
      state = state.copyWith(
        phase: ReportPhase.error,
        errorMessage: e.toString(),
      );
    }
  }
}

final reportControllerProvider =
    NotifierProvider<ReportController, ReportState>(
  ReportController.new,
);
