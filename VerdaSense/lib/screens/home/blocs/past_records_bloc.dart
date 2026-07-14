import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wound_repository/wound_repository.dart';

part 'past_records_event.dart';
part 'past_records_state.dart';

class PastRecordsBloc extends Bloc<PastRecordsEvent, PastRecordsState> {
  final WoundRepository _woundRepository;
  StreamSubscription<List<WoundImageModel>>? _woundSubscription;

  PastRecordsBloc({required WoundRepository woundRepository})
      : _woundRepository = woundRepository,
        super(const PastRecordsState.initial()) {
    on<PastRecordsStarted>(_onStarted);
    on<_PastRecordsWoundsUpdated>(_onWoundsUpdated);
  }

  Future<void> _onStarted(PastRecordsStarted event, Emitter<PastRecordsState> emit) async {
    emit(state.copyWith(status: PastRecordsStatus.loading));

    try {
      // Cancel old subscription if any
      await _woundSubscription?.cancel();

      // Listen to the wounds stream
      _woundSubscription = _woundRepository.getWounds().listen(
        (wounds) {
          add(_PastRecordsWoundsUpdated(wounds));
        },
        onError: (error) {
          emit(state.copyWith(
            status: PastRecordsStatus.failure,
            errorMessage: error.toString(),
          ));
        },
      );
    } catch (e) {
      emit(state.copyWith(
        status: PastRecordsStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onWoundsUpdated(
    _PastRecordsWoundsUpdated event,
    Emitter<PastRecordsState> emit,
  ) async {
    // Sort wounds by createdAt in descending order
    final sortedWounds = List<WoundImageModel>.from(event.wounds)
      ..sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

    // Fetch tissue URLs for all wounds
    final Map<String, String> tissueUrls = {};
    for (final wound in sortedWounds) {
      try {
        final url = await _woundRepository.getTissueUrl(wound.originalImageName);
        if (url != null) {
          tissueUrls[wound.originalImageName] = url;
        }
      } catch (e) {
        // If tissue doesn't exist, skip it
      }
    }

    emit(state.copyWith(
      status: PastRecordsStatus.success,
      wounds: sortedWounds,
      tissueUrls: tissueUrls,
    ));
  }

  @override
  Future<void> close() {
    _woundSubscription?.cancel();
    return super.close();
  }
}

