import 'dart:io';
import 'dart:typed_data';

import 'package:wound_repository/src/models/inference_results.dart';

import 'models/models.dart';

abstract class WoundRepository {
  
  // Upload original wound image + results from Gradio 
  Future<void> saveWoundWithResults({
    required File originalImageFile,
    required String imageName,
    required List<BoundingBoxModel> boxes,
    required InferenceResult inference,
    double? pixelsPerCm,
  });

  // Stream of all wound images for a user
  Stream<List<WoundImageModel>> getWounds();

  // Update bounding boxes for an existing wound image
  Future<void> updateBoundingBoxes(
    {
      required String woundId,
      required List<BoundingBoxModel> boxes,
    }
  );

  // Delete a wound image
  Future<void> deleteWound(String woundId);

  // Get the segmentation mask and overlay images's byte from Gradio for displaying directly
  Future<InferenceResult> getSegmentationMask({
    required File imageFile,
    required String imageName,
    required List<BoundingBoxModel> boxes,
  });

  // Get the overlay image URL for a given image name
  Future<String?> getOverlayUrl(String imageName);

  // Get the segmentation mask URL for a given image name
  Future<String?> getMaskUrl(String imageName);

  // Get the tissue classification URL for a given image name
  Future<String?> getTissueUrl(String imageName);

  /// Save a comparison result between two wounds, optionally with a pre-generated
  /// overlay mask image.
  Future<WoundComparisonModel> saveComparison({
    required String previousImageName,
    required String currentImageName,
    required DateTime? previousDate,
    required DateTime? currentDate,
    required double sizeChangePct,
    Uint8List? overlayBytes,
  });

  /// Stream of comparison records for the current user, ordered by most recent.
  Stream<List<WoundComparisonModel>> getComparisons();

  /// Get wounds by their image names (for loading saved comparisons)
  Future<List<WoundImageModel>> getWoundsByImageNames(List<String> imageNames);

  /// Get signed URL for a saved overlay mask from storage path
  Future<String?> getOverlayMaskUrl(String overlayPath);
}