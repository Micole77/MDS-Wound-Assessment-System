import 'dart:async';

import 'package:home_repository/models/home.dart';

abstract class HomeRepository {
  Future<HomeModel> fetchHomeData();
}