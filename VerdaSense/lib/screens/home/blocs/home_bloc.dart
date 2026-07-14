import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:home_repository/home_repository.dart';
import 'package:wound_repository/wound_repository.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {

  final HomeRepository _homeRepository;
  StreamSubscription<List<WoundImageModel>>? _woundSubscription;

  HomeBloc({required HomeRepository homeRepository}) : _homeRepository = homeRepository, super(const HomeState.initial()) {
    on<HomeStarted>(_onStarted);
    on<HomeRefreshRequested>(_onRefresh);

    on<_HomeWoundsUpdated>((event, emit) {
      emit(state.copyWith(status: HomeStatus.success, wounds: event.wounds));
    });
  }

  Future<void> _onStarted(HomeStarted event, Emitter<HomeState> emit) async {
    emit(state.copyWith(status: HomeStatus.loading));
    
    try{
      final homeData = await _homeRepository.fetchHomeData();

      // cancel old subscription if any
      await _woundSubscription?.cancel();

      // Listen to the wounds stream
      _woundSubscription = homeData.recentWounds.listen(
        (wounds) {
          add(_HomeWoundsUpdated(wounds)); 
        },
        onError: (error) {
          emit(state.copyWith(status: HomeStatus.failure, errorMessage: error.toString()));
        }
      );

    } catch (e) {
      emit(state.copyWith(status: HomeStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onRefresh(HomeRefreshRequested event, Emitter<HomeState> emit) async {
    add(HomeStarted());
  }

  // cancel the stream subscription after the HomeBloc is disposed
  @override
  Future<void> close() {
    _woundSubscription?.cancel();
    return super.close();
  }
}


