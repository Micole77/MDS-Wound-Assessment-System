import 'package:wound_repository/wound_repository.dart';

class HomeModel {
  final Stream<List<WoundImageModel>> recentWounds;

  HomeModel({required this.recentWounds});
}