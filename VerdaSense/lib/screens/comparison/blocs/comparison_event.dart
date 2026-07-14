import 'package:equatable/equatable.dart';
import 'package:wound_repository/wound_repository.dart';

abstract class ComparisonEvent extends Equatable {
  const ComparisonEvent();

  @override
  List<Object?> get props => [];
}

class ComparisonStarted extends ComparisonEvent {
  const ComparisonStarted();
}

// Select wound A
class ComparisonWoundASelected extends ComparisonEvent {
  final WoundImageModel wound;

  const ComparisonWoundASelected(this.wound);

  @override
  List<Object?> get props => [wound];
}

// Select wound B
class ComparisonWoundBSelected extends ComparisonEvent {
  final WoundImageModel wound;

  const ComparisonWoundBSelected(this.wound);

  @override
  List<Object?> get props => [wound];
}

// Deselect wound A
class ComparisonWoundADeselected extends ComparisonEvent {
  const ComparisonWoundADeselected();
}

// Deselect wound B
class ComparisonWoundBDeselected extends ComparisonEvent {
  const ComparisonWoundBDeselected();
}

// Compare after selecting both wounds
class ComparisonCompareRequested extends ComparisonEvent {
  const ComparisonCompareRequested();
}

// Load past comparison result
class ComparisonLoadFromHistory extends ComparisonEvent {
  final WoundComparisonModel comparison;

  const ComparisonLoadFromHistory(this.comparison);

  @override
  List<Object?> get props => [comparison];
}

// Refresh the wounds selection
class ComparisonWoundsRefreshed extends ComparisonEvent {
  const ComparisonWoundsRefreshed();
}

