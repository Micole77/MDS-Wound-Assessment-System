import '../entities/bbox_entity.dart';

/// App-level model for BoundingBox
class BoundingBoxModel {
  double x;
  double y;
  double width;
  double height;

  BoundingBoxModel({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Convert this model to entity for DB/storage
  BoundingBoxEntity toEntity() {
    return BoundingBoxEntity(
      x: x,
      y: y,
      width: width,
      height: height,
    );
  }

  /// Create model from entity
  static BoundingBoxModel fromEntity(BoundingBoxEntity entity) {
    return BoundingBoxModel(
      x: entity.x,
      y: entity.y,
      width: entity.width,
      height: entity.height,
    );
  }

  @override
  String toString() {
    return 'BoundingBoxModel(x: $x, y: $y, width: $width, height: $height)';
  }
}
