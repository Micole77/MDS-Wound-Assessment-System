import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdasense/blocs/authentication_bloc/authentication_bloc.dart';
import 'package:verdasense/blocs/theme_bloc/theme_bloc.dart';
import 'package:verdasense/main.dart';
import 'package:verdasense/screens/auth/blocs/sign_in_bloc/sign_in_bloc.dart';
import 'package:verdasense/screens/auth/views/sign_in_screen.dart';
import 'package:verdasense/screens/home/views/app_shell.dart';

class MyAppView extends StatelessWidget {
  const MyAppView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        return MaterialApp(
          title: 'VerdaSense',
          debugShowCheckedModeBanner: false,
          themeMode: themeState.themeMode,
          theme: ThemeData(
            fontFamily: 'Poppins',
            colorScheme: ColorScheme.light(
              surface: Colors.grey.shade100,
              onSurface: Colors.black,
              primary: const Color(0xFF636AE8),
              onPrimary: Colors.white, 
            ),
          ),
          darkTheme: ThemeData(
            fontFamily: 'Poppins',
            colorScheme: ColorScheme.dark(
              surface: Colors.grey.shade900,
              onSurface: Colors.white,
              primary: const Color(0xFF636AE8),
              onPrimary: Colors.white,
            ),
          ),
      home: BlocBuilder <AuthenticationBloc, AuthenticationState>(
        builder: (context, state) {
          if (state.status == AuthenticationStatus.authenticated) {
            return const AppShell();
          } else {
            return BlocProvider(
              create: (context) => SignInBloc(
                context.read<AuthenticationBloc>().userRepository,
              ),
              child: SignInScreen()
            );
          }
        }
      ),
          navigatorObservers: [routeObserver],
        );
      },
    );
  }
}