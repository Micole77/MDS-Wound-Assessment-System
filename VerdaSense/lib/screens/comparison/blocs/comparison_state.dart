import 'package:equatable/equatable.dart';
import 'package:wound_repository/wound_repository.dart';

enum ComparisonStatus {
  initial,
  loading,
  success,
  failure,
}

class ComparisonState extends Equatable {
  const ComparisonState({
    this.status = ComparisonStatus.initial,
    // User selections (for compare progress screen)
    this.woundA,
    this.woundB,
    // Chronological comparison results (previous = older, current = newer)
    this.previousWound,
    this.currentWound,
    this.previousWoundOverlayUrl,
    this.currentWoundOverlayUrl,
    this.previousWoundMaskUrl,
    this.currentWoundMaskUrl,
    this.previousWoundTissueUrl,
    this.currentWoundTissueUrl,
    this.woundSizeChange,
    this.errorMessage,
    this.availableWounds = const [],
    this.comparisonDate,
  });

  final ComparisonStatus status;
  // User selections (for compare progress screen)
  final WoundImageModel? woundA;
  final WoundImageModel? woundB;
  // Chronological comparison results (previous = older, current = newer)
  final WoundImageModel? previousWound;
  final WoundImageModel? currentWound;
  final String? previousWoundOverlayUrl;
  final String? currentWoundOverlayUrl;
  final String? previousWoundMaskUrl;
  final String? currentWoundMaskUrl;
  final String? previousWoundTissueUrl;
  final String? currentWoundTissueUrl;
  final double? woundSizeChange; // Percentage change
  final String? errorMessage;
  final List<WoundImageModel> availableWounds;
  final DateTime? comparisonDate;

  ComparisonState copyWith({
    ComparisonStatus? status,
    WoundImageModel? woundA,
    WoundImageModel? woundB,
    WoundImageModel? previousWound,
    WoundImageModel? currentWound,
    String? previousWoundOverlayUrl,
    String? currentWoundOverlayUrl,
    String? previousWoundMaskUrl,
    String? currentWoundMaskUrl,
    String? previousWoundTissueUrl,
    String? currentWoundTissueUrl,
    double? woundSizeChange,
    String? errorMessage,
    List<WoundImageModel>? availableWounds,
    DateTime? comparisonDate,
  }) {
    return ComparisonState(
      status: status ?? this.status,
      woundA: woundA ?? this.woundA,
      woundB: woundB ?? this.woundB,
      previousWound: previousWound ?? this.previousWound,
      currentWound: currentWound ?? this.currentWound,
      previousWoundOverlayUrl: previousWoundOverlayUrl ?? this.previousWoundOverlayUrl,
      currentWoundOverlayUrl: currentWoundOverlayUrl ?? this.currentWoundOverlayUrl,
      previousWoundMaskUrl: previousWoundMaskUrl ?? this.previousWoundMaskUrl,
      currentWoundMaskUrl: currentWoundMaskUrl ?? this.currentWoundMaskUrl,
      previousWoundTissueUrl: previousWoundTissueUrl ?? this.previousWoundTissueUrl,
      currentWoundTissueUrl: currentWoundTissueUrl ?? this.currentWoundTissueUrl,
      woundSizeChange: woundSizeChange ?? this.woundSizeChange,
      errorMessage: errorMessage ?? this.errorMessage,
      availableWounds: availableWounds ?? this.availableWounds,
      comparisonDate: comparisonDate ?? this.comparisonDate,
    );
  }

  @override
  List<Object?> get props => [
        status,
        woundA,
        woundB,
        previousWound,
        currentWound,
        previousWoundOverlayUrl,
        currentWoundOverlayUrl,
        previousWoundMaskUrl,
        currentWoundMaskUrl,
        previousWoundTissueUrl,
        currentWoundTissueUrl,
        woundSizeChange,
        errorMessage,
        availableWounds,
        comparisonDate,
      ];
}

