import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wound_repository/wound_repository.dart';

part 'analysis_event.dart';
part 'analysis_state.dart';

class AnalysisBloc extends Bloc<AnalysisEvent, AnalysisState> {
  final WoundRepository _woundRepository;
  StreamSubscription<List<WoundImageModel>>? _woundSubscription;

  AnalysisBloc({required WoundRepository woundRepository})
      : _woundRepository = woundRepository,
        super(const AnalysisState()) {
    on<AnalysisStarted>(_onStarted);
    on<AnalysisRefreshRequested>(_onRefresh);
    on<_AnalysisWoundsUpdated>(_onWoundsUpdated);
  }

  Future<void> _onStarted(AnalysisStarted event, Emitter<AnalysisState> emit) async {
    emit(state.copyWith(status: AnalysisStatus.loading));

    try {
      // Cancel old subscription if any
      await _woundSubscription?.cancel();

      // Listen to the wounds stream
      _woundSubscription = _woundRepository.getWounds().listen(
        (wounds) {
          add(_AnalysisWoundsUpdated(wounds));
        },
        onError: (error) {
          emit(state.copyWith(
            status: AnalysisStatus.failure,
            errorMessage: error.toString(),
          ));
        },
      );
    } catch (e) {
      emit(state.copyWith(
        status: AnalysisStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRefresh(AnalysisRefreshRequested event, Emitter<AnalysisState> emit) async {
    add(const AnalysisStarted());
  }

  Future<void> _onWoundsUpdated(
    _AnalysisWoundsUpdated event,
    Emitter<AnalysisState> emit,
  ) async {
    if (event.wounds.isEmpty) {
      emit(state.copyWith(
        status: AnalysisStatus.success,
        latestWound: null,
        latestOverlayUrl: null,
        latestTissueUrl: null,
        recentWounds: [],
        recentWoundsOverlayUrls: {},
        recentWoundsTissueUrls: {},
      ));
      return;
    }

    // 1. Identify the data we need
    final latestWound = event.wounds.first;
    // 'take(2)' safely handles lists with only 1 item too
    final recentWounds = event.wounds.take(2).toList(); 

    // 2. Prepare all Future tasks (but don't await them yet!)
    // We use a list to collect all the tasks we want to run in parallel.
    final overlayFutures = <Future<MapEntry<String, String?>>>[];
    final tissueFutures = <Future<MapEntry<String, String?>>>[];

    for (final wound in recentWounds) {
      // Add the task to fetch Overlay
      overlayFutures.add(_fetchUrlSafe(
        wound.originalImageName, 
        () => _woundRepository.getOverlayUrl(wound.originalImageName)
      ));

      // Add the task to fetch Tissue
      tissueFutures.add(_fetchUrlSafe(
        wound.originalImageName, 
        () => _woundRepository.getTissueUrl(wound.originalImageName)
      ));
    }

    // 3. Execute ALL tasks in parallel
    // This fires all 4 requests (max) simultaneously and waits for the slowest one.
    final results = await Future.wait([
      Future.wait(overlayFutures),
      Future.wait(tissueFutures),
    ]);

    // 4. Process Results
    final overlayEntries = results[0] as List<MapEntry<String, String?>>;
    final tissueEntries = results[1] as List<MapEntry<String, String?>>;

    // Build the Maps
    final recentWoundsOverlayUrls = <String, String>{};
    final recentWoundsTissueUrls = <String, String>{};

    for (final entry in overlayEntries) {
      if (entry.value != null) recentWoundsOverlayUrls[entry.key] = entry.value!;
    }
    for (final entry in tissueEntries) {
      if (entry.value != null) recentWoundsTissueUrls[entry.key] = entry.value!;
    }

    // 5. Extract 'Latest' URLs directly from our new maps
    // (Since latestWound is always the first item in recentWounds, we already fetched it!)
    final latestOverlayUrl = recentWoundsOverlayUrls[latestWound.originalImageName];
    final latestTissueUrl = recentWoundsTissueUrls[latestWound.originalImageName];

    emit(state.copyWith(
      status: AnalysisStatus.success,
      latestWound: latestWound,
      latestOverlayUrl: latestOverlayUrl,
      latestTissueUrl: latestTissueUrl,
      recentWounds: recentWounds,
      recentWoundsOverlayUrls: recentWoundsOverlayUrls,
      recentWoundsTissueUrls: recentWoundsTissueUrls,
    ));
  }

  /// Helper: Wraps the fetch in a try-catch so one failure doesn't crash the whole batch.
  /// Returns a MapEntry linking the Image Name -> URL (or null).
  Future<MapEntry<String, String?>> _fetchUrlSafe(
    String key,
    Future<String?> Function() fetcher,
  ) async {
    try {
      final url = await fetcher();
      return MapEntry(key, url);
    } catch (e) {
      // Log error if needed, but return null so the UI just shows a placeholder
      return MapEntry(key, null);
    }
  }

  @override
  Future<void> close() {
    _woundSubscription?.cancel();
    return super.close();
  }
}

class _AnalysisWoundsUpdated extends AnalysisEvent {
  final List<WoundImageModel> wounds;

  const _AnalysisWoundsUpdated(this.wounds);

  @override
  List<Object> get props => [wounds];
}

