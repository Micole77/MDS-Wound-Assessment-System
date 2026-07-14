import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:home_repository/home_repository.dart';
import 'package:verdasense/blocs/authentication_bloc/authentication_bloc.dart';
import 'package:verdasense/blocs/theme_bloc/theme_bloc.dart';
import 'package:verdasense/components/main_bottom_nav.dart';
import 'package:verdasense/components/my_app_bar.dart';
import 'package:verdasense/screens/home/views/home_screen.dart';
import 'package:verdasense/screens/home/blocs/home_bloc.dart';
import 'package:verdasense/screens/upload/views/upload_main_screen.dart';
import 'package:verdasense/screens/auth/blocs/sign_in_bloc/sign_in_bloc.dart';
import 'package:verdasense/screens/auth/views/sign_in_screen.dart';
import 'package:verdasense/screens/analysis/views/analysis_results_screen.dart';
import 'package:verdasense/screens/comparison/blocs/comparison_bloc.dart';
import 'package:verdasense/screens/comparison/blocs/comparison_event.dart';
import 'package:verdasense/screens/comparison/views/compare_progress_screen.dart';
import 'package:wound_repository/wound_repository.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();

  static _AppShellState? of(BuildContext context) => context.findAncestorStateOfType<_AppShellState>();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late final List<Widget> _tabs;

  void switchTab(int index) {
    setState(() {
      _index = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _tabs = [
      Builder(
        builder: (context) {
          return BlocProvider(
            create: (_) => HomeBloc(
              homeRepository: SupabaseHomeRepo(woundRepository: context.read<WoundRepository>()),
              // userId: userId,
            )..add(const HomeStarted()),
            child: const HomeScreen(),
          );
        },
      ),
      const UploadMainScreen(),
      const AnalysisResultsScreen(),
      Builder(
        builder: (context) {
          return BlocProvider(
            create: (_) => ComparisonBloc(
              woundRepository: context.read<WoundRepository>(),
            )..add(const ComparisonStarted()),
            child: const CompareProgressScreen(),
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Instead of BlocListener and manual navigation, rebuild based on auth state
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, state) {
        if (state.status == AuthenticationStatus.unauthenticated) {
          // Show SignInScreen directly
          return BlocProvider(
            create: (context) => SignInBloc(
              context.read<AuthenticationBloc>().userRepository,
            ),
            child: const SignInScreen(),
          );
        }

        // Otherwise show main app shell
        return Scaffold(
          appBar: MyAppBar(
            title: _titleForIndex(_index),
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.person),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
          drawer: Drawer(
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 16,
            child: const _DrawerContent(),
          ),
          body: IndexedStack(
            index: _index,
            children: _tabs,
          ),
          bottomNavigationBar: MainBottomNav(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
          ),
        );
      },
    );
  }

  String _titleForIndex(int i) {
    switch (i) {
      case 0:
        return 'Home';
      case 1:
        return 'Upload Image';
      case 2:
        return 'Analysis Results';
      case 3:
        return 'Compare Progress';
      default:
        return '';
    }
  }
}

class _DrawerContent extends StatelessWidget {
  const _DrawerContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BlocBuilder<AuthenticationBloc, AuthenticationState>(
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(state.user?.name ?? ''),
                subtitle: Text(state.user?.email ?? ''),
              ),
              const Divider(),
              // BlocBuilder<ThemeBloc, ThemeState>(
              //   builder: (context, themeState) {
              //     return ListTile(
              //       leading: Icon(
              //         themeState.themeMode == ThemeMode.dark
              //             ? Icons.light_mode
              //             : Icons.dark_mode,
              //       ),
              //       title: Text(
              //         themeState.themeMode == ThemeMode.dark
              //             ? 'Light Mode'
              //             : 'Dark Mode',
              //       ),
              //       onTap: () {
              //         context.read<ThemeBloc>().add(const ThemeToggled());
              //       },
              //     );
              //   },
              // ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log out'),
                onTap: () async {
                  // Log out user and let BlocBuilder rebuild automatically
                  await context.read<AuthenticationBloc>().userRepository.logOut();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

