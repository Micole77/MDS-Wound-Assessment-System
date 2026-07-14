import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:verdasense/app.dart';
import 'package:verdasense/simple_bloc_observer.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Read inference backend base URL (for wound segmentation server)
  // Fallback to the current default if not provided.
  final inferenceBaseUrl =
      dotenv.env["WOUND_SEGMENTATION_BASE_URL"] ?? "https://bp17-woundsegmenter.hf.space";
  
  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env["SUPABASE_URL"]!,
    anonKey: dotenv.env["SUPABASE_KEY"]!,
  ); 

  // Initialize Supabase client
  final supabaseClient = Supabase.instance.client;

  Bloc.observer = SimpleBlocObserver();
  runApp(
    MyApp(
      supabaseClient: supabaseClient,
      inferenceBaseUrl: inferenceBaseUrl,
    ),
  );
}
