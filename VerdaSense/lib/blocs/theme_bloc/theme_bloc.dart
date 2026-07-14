import 'package:flutter/material.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_event.dart';
part 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  static const String _themeKey = 'theme_mode';

  ThemeBloc() : super(const ThemeState(themeMode: ThemeMode.light)) {
    on<ThemeToggled>(_onThemeToggled);
    on<ThemeLoaded>(_onThemeLoaded);
    add(const ThemeLoaded());
  }

  Future<void> _onThemeLoaded(
    ThemeLoaded event,
    Emitter<ThemeState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_themeKey) ?? false;
      emit(ThemeState(
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      ));
    } catch (e) {
      // Default to light mode on error
      emit(const ThemeState(themeMode: ThemeMode.light));
    }
  }

  Future<void> _onThemeToggled(
    ThemeToggled event,
    Emitter<ThemeState> emit,
  ) async {
    final newMode = state.themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    
    emit(ThemeState(themeMode: newMode));
    
    // Persist preference
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, newMode == ThemeMode.dark);
    } catch (e) {
      // Ignore persistence errors
    }
  }
}

