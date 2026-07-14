/// Entity for BoundingBox, used for DB/storage layer
class BoundingBoxEntity {
  double x;
  double y;
  double width;
  double height;

  BoundingBoxEntity({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Convert entity to document/map for DB storage (Supabase jsonb)
  Map<String, Object?> toDocument() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  /// Create entity from DB document/map
  static BoundingBoxEntity fromDocument(Map<String, dynamic> doc) {
    return BoundingBoxEntity(
      x: (doc['x'] as num).toDouble(),
      y: (doc['y'] as num).toDouble(),
      width: (doc['width'] as num).toDouble(),
      height: (doc['height'] as num).toDouble(),
    );
  }
}