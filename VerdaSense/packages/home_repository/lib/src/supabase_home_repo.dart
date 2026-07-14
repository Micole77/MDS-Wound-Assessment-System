import 'package:home_repository/home_repository.dart';
import 'package:home_repository/models/home.dart';
import 'package:wound_repository/wound_repository.dart';

class SupabaseHomeRepo implements HomeRepository{
  final WoundRepository woundRepository;

  SupabaseHomeRepo({
    required this.woundRepository,
  });

  @override
  Future<HomeModel> fetchHomeData() async {
    // `getWounds` already returns a `Stream<List<WoundImageModel>>`,
    // so we just pass the stream through without awaiting.
    final woundsStream = woundRepository.getWounds();
    return HomeModel(recentWounds: woundsStream);
  }
}