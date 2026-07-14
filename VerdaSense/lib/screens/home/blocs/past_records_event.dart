part of 'past_records_bloc.dart';

abstract class PastRecordsEvent extends Equatable {
  const PastRecordsEvent();

  @override
  List<Object?> get props => [];
}

class PastRecordsStarted extends PastRecordsEvent {
  const PastRecordsStarted();
}

class _PastRecordsWoundsUpdated extends PastRecordsEvent {
  final List<WoundImageModel> wounds;

  const _PastRecordsWoundsUpdated(this.wounds);

  @override
  List<Object?> get props => [wounds];
}

