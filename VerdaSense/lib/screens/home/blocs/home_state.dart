part of 'home_bloc.dart';

enum HomeStatus { initial, loading, success, failure }

class HomeState extends Equatable {
  final HomeStatus status;
  final List<WoundImageModel> wounds;
  final String? errorMessage;

  const HomeState({
    required this.status,
    required this.wounds,
    this.errorMessage,
  });

  const HomeState.initial()
      : status = HomeStatus.initial,
        wounds = const [],
        errorMessage = null;

  HomeState copyWith({
    HomeStatus? status,
    List<WoundImageModel>? wounds,
    String? errorMessage,
  }) {
    return HomeState(
      status: status ?? this.status,
      wounds: wounds ?? this.wounds,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, wounds, errorMessage];
}


