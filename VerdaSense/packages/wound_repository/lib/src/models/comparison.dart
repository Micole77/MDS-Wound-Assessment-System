class WoundComparisonModel {
  final String id;
  final String userId;
  final String woundAImageName;
  final String woundBImageName;
  final DateTime? previousDate;
  final DateTime? currentDate;
  final double sizeChangePct;
  final String? overlayPath;
  final DateTime? createdAt;

  WoundComparisonModel({
    required this.id,
    required this.userId,
    required this.woundAImageName,
    required this.woundBImageName,
    required this.previousDate,
    required this.currentDate,
    required this.sizeChangePct,
    required this.overlayPath,
    required this.createdAt,
  });

  factory WoundComparisonModel.fromDocument(Map<String, dynamic> doc) {
    DateTime? _parseDate(dynamic value) {
      if (value is String) {
        return DateTime.tryParse(value);
      }
      if (value is DateTime) {
        return value;
      }
      return null;
    }

    return WoundComparisonModel(
      id: doc['id']?.toString() ?? '',
      userId: doc['user_id']?.toString() ?? '',
      woundAImageName: doc['wound_a_image_name']?.toString() ?? '',
      woundBImageName: doc['wound_b_image_name']?.toString() ?? '',
      previousDate: _parseDate(doc['previous_date']),
      currentDate: _parseDate(doc['current_date']),
      sizeChangePct: (doc['size_change_pct'] is num)
          ? (doc['size_change_pct'] as num).toDouble()
          : 0.0,
      overlayPath: doc['overlay_path']?.toString(),
      createdAt: _parseDate(doc['created_at']),
    );
  }
}


