part of 'past_records_bloc.dart';

enum PastRecordsStatus { initial, loading, success, failure }

class PastRecordsState extends Equatable {
  final PastRecordsStatus status;
  final List<WoundImageModel> wounds;
  final Map<String, String> tissueUrls; // Map of imageName -> tissueUrl
  final String? errorMessage;

  const PastRecordsState({
    required this.status,
    required this.wounds,
    this.tissueUrls = const {},
    this.errorMessage,
  });

  const PastRecordsState.initial()
      : status = PastRecordsStatus.initial,
        wounds = const [],
        tissueUrls = const {},
        errorMessage = null;

  PastRecordsState copyWith({
    PastRecordsStatus? status,
    List<WoundImageModel>? wounds,
    Map<String, String>? tissueUrls,
    String? errorMessage,
  }) {
    return PastRecordsState(
      status: status ?? this.status,
      wounds: wounds ?? this.wounds,
      tissueUrls: tissueUrls ?? this.tissueUrls,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, wounds, tissueUrls, errorMessage];
}

