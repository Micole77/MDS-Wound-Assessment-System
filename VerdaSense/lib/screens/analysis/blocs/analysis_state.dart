part of 'analysis_bloc.dart';

enum AnalysisStatus { initial, loading, success, failure }

class AnalysisState extends Equatable {
  const AnalysisState({
    this.status = AnalysisStatus.initial,
    this.latestWound,
    this.latestOverlayUrl,
    this.latestTissueUrl,
    this.recentWounds = const [],
    this.recentWoundsOverlayUrls = const {},
    this.recentWoundsTissueUrls = const {},
    this.errorMessage,
  });

  final AnalysisStatus status;
  final WoundImageModel? latestWound;
  final String? latestOverlayUrl;
  final String? latestTissueUrl;
  final List<WoundImageModel> recentWounds;
  final Map<String, String> recentWoundsOverlayUrls; // Map of imageName -> overlayUrl
  final Map<String, String> recentWoundsTissueUrls; // Map of imageName -> tissueUrl
  final String? errorMessage;

  /// Convenience getter for latest wound's IME results
  Map<String, dynamic>? get latestImeResults => latestWound?.imeResults;

  AnalysisState copyWith({
    AnalysisStatus? status,
    WoundImageModel? latestWound,
    String? latestOverlayUrl,
    String? latestTissueUrl,
    List<WoundImageModel>? recentWounds,
    Map<String, String>? recentWoundsOverlayUrls,
    Map<String, String>? recentWoundsTissueUrls,
    String? errorMessage,
  }) {
    return AnalysisState(
      status: status ?? this.status,
      latestWound: latestWound ?? this.latestWound,
      latestOverlayUrl: latestOverlayUrl ?? this.latestOverlayUrl,
      latestTissueUrl: latestTissueUrl ?? this.latestTissueUrl,
      recentWounds: recentWounds ?? this.recentWounds,
      recentWoundsOverlayUrls: recentWoundsOverlayUrls ?? this.recentWoundsOverlayUrls,
      recentWoundsTissueUrls: recentWoundsTissueUrls ?? this.recentWoundsTissueUrls,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        latestWound,
        latestOverlayUrl,
        latestTissueUrl,
        recentWounds,
        recentWoundsOverlayUrls,
        recentWoundsTissueUrls,
        errorMessage,
      ];
}
