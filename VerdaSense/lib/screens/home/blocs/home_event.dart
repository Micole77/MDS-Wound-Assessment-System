part of 'home_bloc.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => [];
}

class HomeStarted extends HomeEvent {
  const HomeStarted();
}

class HomeRefreshRequested extends HomeEvent {
  const HomeRefreshRequested();
}

class _HomeWoundsUpdated extends HomeEvent {
  final List<WoundImageModel> wounds;

  const _HomeWoundsUpdated(this.wounds);

  @override
  List<Object?> get props => [wounds];
}


