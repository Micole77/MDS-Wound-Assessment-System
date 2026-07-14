import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:user_repository/user_repository.dart';
import 'package:verdasense/app_view.dart';
import 'package:verdasense/blocs/authentication_bloc/authentication_bloc.dart';
import 'package:verdasense/blocs/theme_bloc/theme_bloc.dart';
import 'package:verdasense/screens/analysis/blocs/analysis_bloc.dart';
import 'package:wound_repository/wound_repository.dart';

class MyApp extends StatelessWidget {

  final SupabaseClient supabaseClient;
  final String inferenceBaseUrl;

  const MyApp({
    super.key,
    required this.supabaseClient,
    required this.inferenceBaseUrl,
  });

  @override
  Widget build(BuildContext context) {

    // Initialize repositories with same Supabase client
    final userRepository = SupabaseUsersRepo(supabaseClient);
    final woundsRepository = SupabaseWoundsRepo(
      supabaseClient,
      baseUrl: inferenceBaseUrl,
    );

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<UserRepository>.value(value: userRepository),
        RepositoryProvider<WoundRepository>.value(value: woundsRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthenticationBloc>(
            create: (context) => AuthenticationBloc(userRepository: userRepository),
          ),
          BlocProvider<ThemeBloc>(
            create: (context) => ThemeBloc(),
          ),
          BlocProvider<AnalysisBloc>(
            create: (context) => AnalysisBloc(
              woundRepository: context.read<WoundRepository>(),
            )..add(const AnalysisStarted()), // Start fetching data immediately
          ),
        ],
        child: const MyAppView(),
      ),
    );
  }
}