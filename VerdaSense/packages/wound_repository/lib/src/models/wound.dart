import '../entities/wound_entity.dart';
import 'bbox.dart';

/// App-level model for WoundImage
class WoundImageModel {
  String userId;
  String imageUrl; // Signed URL for the original image
  String originalImageName; // Original filename (e.g., "1234567890.jpg")
  List<BoundingBoxModel> boxes;
  DateTime? createdAt;
  Map<String, dynamic>? imeResults; // IME classification results

  WoundImageModel({
    required this.userId,
    required this.imageUrl,
    required this.originalImageName,
    required this.boxes,
    this.createdAt,
    this.imeResults,
  });

  /// Convert model to entity for DB/storage
  WoundImageEntity toEntity() {
    return WoundImageEntity(
      userId: userId,
      imageUrl: originalImageName, // Use original filename for entity
      boxes: boxes.map((b) => b.toEntity()).toList(),
      imeResults: imeResults,
    );
  }

  /// Create model from entity
  /// Note: imageUrl should be set to the signed URL, and originalImageName to the entity's imageUrl
  static WoundImageModel fromEntity(
    WoundImageEntity entity, {
    String? signedImageUrl,
  }) {
    return WoundImageModel(
      userId: entity.userId,
      imageUrl: signedImageUrl ?? entity.imageUrl,
      originalImageName: entity.imageUrl, // Preserve original filename
      boxes: entity.boxes.map((b) => BoundingBoxModel.fromEntity(b)).toList(),
      createdAt: entity.createdAt,
      imeResults: entity.imeResults,
    );
  }

  @override
  String toString() {
    return 'WoundImageModel(userId: $userId, imageUrl: $imageUrl, originalImageName: $originalImageName, boxes: $boxes, createdAt: $createdAt, imeResults: $imeResults)';
  }
}
