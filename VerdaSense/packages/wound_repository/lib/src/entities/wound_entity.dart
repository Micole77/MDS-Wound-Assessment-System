import 'bbox_entity.dart';

/// Entity for WoundImage, used for DB/storage
class WoundImageEntity {
  String userId;
  String imageUrl;
  List<BoundingBoxEntity> boxes;
  final DateTime? createdAt;
  double? pixelsPerCm; // pixelsPerCm
  Map<String, dynamic>? imeResults; // IME classification results

  WoundImageEntity({
    required this.userId,
    required this.imageUrl,
    required this.boxes,
    this.createdAt,
    this.pixelsPerCm,
    this.imeResults,
  });

  /// Convert entity to document/map for DB storage
  Map<String, Object?> toDocument() {
    final doc = {
      'user_id': userId,
      'image_url': imageUrl,
      'bounding_boxes': boxes.map((b) => b.toDocument()).toList(),
    };
    if (pixelsPerCm != null) {
      doc['pixelsPerCm'] = pixelsPerCm as Object;
    }
    if (imeResults != null) {
      doc['ime_results'] = imeResults as Object;
    }
    return doc;
  }

  /// Create entity from DB document/map
  static WoundImageEntity fromDocument(Map<String, dynamic> doc) {
    final bboxList = (doc['bounding_boxes'] as List<dynamic>? ?? [])
        .map((b) => BoundingBoxEntity.fromDocument(b as Map<String, dynamic>))
        .toList();

    DateTime? parsedCreatedAt;
    final rawCreatedAt = doc['created_at'];

    if (rawCreatedAt is String) {
      // typical Supabase timestamptz is returned as an ISO string
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt);
    } else if (rawCreatedAt is DateTime) {
      // sometimes supabase-dart SDK already parses it for you
      parsedCreatedAt = rawCreatedAt;
    } else {
      parsedCreatedAt = null; // safely handle null
    }

    return WoundImageEntity(
      userId: doc['user_id'] as String,
      imageUrl: doc['image_url'] as String,
      boxes: bboxList,
      createdAt: parsedCreatedAt,
      pixelsPerCm: doc['pixelsPerCm'] != null 
          ? (doc['pixelsPerCm'] as num).toDouble() 
          : null,
      imeResults: doc['ime_results'] != null
          ? Map<String, dynamic>.from(doc['ime_results'] as Map)
          : null,
    );
  }
}
