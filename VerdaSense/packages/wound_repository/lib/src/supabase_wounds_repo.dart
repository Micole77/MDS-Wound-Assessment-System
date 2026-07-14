import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wound_repository/src/models/bbox.dart';
import 'package:wound_repository/src/models/inference_results.dart';
import 'package:wound_repository/src/models/wound.dart';
import 'package:wound_repository/src/wound_repo.dart';
import 'package:wound_repository/wound_repository.dart';
import 'package:http_parser/http_parser.dart';

class SupabaseWoundsRepo implements WoundRepository {
  final SupabaseClient _supabase;
  final String bucketName = 'wound-images';

  /// Base URL for the external wound segmentation service (e.g. Hugging Face Space).
  /// This is injected from the app layer so it can be configured via `.env`.
  final String _baseUrl;

  // Derived URLs
  String get _uploadUrl => "$_baseUrl/gradio_api/upload";
  String get _segmentationApiUrl => "$_baseUrl/gradio_api/call/gradio_segmentation_api";

  SupabaseWoundsRepo(
    this._supabase, {
    required String baseUrl,
  }) : _baseUrl = baseUrl;

  @override
  Future<void> saveWoundWithResults({
    required File originalImageFile,
    required String imageName,
    required List<BoundingBoxModel> boxes,
    required InferenceResult inference,
    double? pixelsPerCm,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final folder = userId;

      // Define paths
      final originalPath = '$folder/original_wound/$imageName';
      final overlayPath = '$folder/overlay_wound/${imageName}_overlay.webp';
      final maskPath = '$folder/segmentation_mask/${imageName}_mask.webp';
      final tissuePath = '$folder/tissue_classification/${imageName}_tissue.webp';

      // Define paths
      final paths = {
        'original_wound': originalPath,
        'overlay_wound': overlayPath,
        'segmentation_mask': maskPath,
        'tissue_classification': tissuePath,
      };

      // Upload all 4 files in parallel to Storage
      await Future.wait([
        _supabase.storage.from(bucketName).upload(
              paths['original_wound']!,
              originalImageFile,
              fileOptions: const FileOptions(upsert: true),
            ),
        _supabase.storage.from(bucketName).uploadBinary(
              paths['overlay_wound']!,
              inference.overlayBytes,
              fileOptions: const FileOptions(contentType: 'image/webp', upsert: true),
            ),
        _supabase.storage.from(bucketName).uploadBinary(
              paths['segmentation_mask']!,
              inference.maskBytes,
              fileOptions: const FileOptions(contentType: 'image/webp', upsert: true),
            ),
        _supabase.storage.from(bucketName).uploadBinary(
              paths['tissue_classification']!,
              inference.tissueBytes,
              fileOptions: const FileOptions(contentType: 'image/webp', upsert: true),
            ),
      ]);

      // Save Metadata to DB
      final woundEntity = WoundImageEntity(
        userId: userId,
        imageUrl: imageName, // We use the base name as the reference
        boxes: boxes.map((b) => b.toEntity()).toList(),
        pixelsPerCm: pixelsPerCm,
        imeResults: inference.imeResults,
      );
      await _supabase.from('wounds').insert(woundEntity.toDocument());
      
      log('Successfully saved wound and inference results to backend');
    } catch (e, st) {
      log('Error saving complete wound data: $e\n$st');
      rethrow;
    }
  }
  
  @override
  Stream<List<WoundImageModel>> getWounds() {
    final userId = _supabase.auth.currentUser!.id;
    
    // Subscribe to realtime changes on the wounds table filtered by userId
    final realtime = _supabase
      .from('wounds')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false);

    // Convert each realtime emission
    return realtime.asyncMap((records) async{
      final List<WoundImageModel> results = [];

      // if records is not a list, return empty
      if (records.isEmpty) return results;

      for (final rec in records) {
        try {

          final doc = Map<String, dynamic>.from(rec as Map);
          final entity = WoundImageEntity.fromDocument(doc);

          final imageName = entity.imageUrl;
          final storagePath = '${entity.userId}/original_wound/$imageName';

          // try to create a signed URL (7 days)
          String finalImageUrl;

          try{
            final signed = await _supabase.storage
              .from(bucketName)
              .createSignedUrl(storagePath, 60 * 60 * 24 +7);

            finalImageUrl = signed;

          } catch(e) {
            log('createSignedUrl failed for $storagePath: $e');
            finalImageUrl = '';
          }
        
        // if the image url is empty, log for debugging
        if (finalImageUrl.isEmpty) log('Warning: image url is empty for path: $storagePath');

        final boxes = entity.boxes
          .map((be) => BoundingBoxModel.fromEntity(be))
          .toList();

        // Build model with signed URL and preserve original filename
        final model = WoundImageModel(
          userId: userId,
          imageUrl: finalImageUrl,
          originalImageName: imageName, // Preserve original filename
          boxes: boxes,
          createdAt: entity.createdAt,
          imeResults: entity.imeResults,
        );

        results.add(model);

        } catch(e, st) {
          log('Error parsing wound record: $e\n$st');
        }
      }
      return results;
    });
  }
  
  @override
  Future<void> updateBoundingBoxes({required String woundId, required List<BoundingBoxModel> boxes}) {
    // TODO: implement updateBoundingBoxes
    throw UnimplementedError();
  }

  @override
  Future<void> deleteWound(String woundId) {
    // TODO: implement deleteWound
    throw UnimplementedError();
  }

  @override
  Future<InferenceResult> getSegmentationMask({
    required File imageFile,
    required String imageName,
    required List<BoundingBoxModel> boxes,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      // Upload the file to inference server and get the internal path
      final gradioFilePath = await _uploadToGradio(imageFile);

      // Prepare bounding box input (COCO --> Pascal VOC)
      final bboxesPascal = _convertToPascalVoc(boxes);
      final bboxesJsonString = jsonEncode(bboxesPascal);

      final imagePayload = {
        "path": gradioFilePath,
        "meta": {"_type": "gradio.FileData"}
      };

      final payload = jsonEncode({
        "data": [
          imagePayload,          // Input 1: Base64 string directly
          bboxesJsonString       // Input 2: Bounding boxes (as a JSON string literal)
        ]
      });
      log("Final payload: $payload");

      // Step 1: Call the segmentation API to get the event ID (first time)
      final initialResponse = await http.post(
        Uri.parse(_segmentationApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );

      final initialResult = jsonDecode(initialResponse.body);
      final eventID = initialResult['event_id'];

      if (eventID == null) {
        log('Initial API call returned 200 but no event_id. Body: ${initialResponse.body}');
        throw Exception('Failed to retrieve event ID for segmentation.');
      }
      
      log('Initial Segmentation API response status: ${initialResponse.body}');
      log('Event ID: $eventID');

      // Step 2: Get the result
      String resultUrl = '$_segmentationApiUrl/$eventID';
      final response = await http.get(Uri.parse(resultUrl));

      if (response.statusCode == 200) {
        log('Segmentation API response body: ${response.body}');

        // response in Server-Sent Event (SSE) format
        // event: <event_name>
        // data: <JSON_STRING>
        final body = response.body;

        // Find the line starting with 'data:'
        final dataLine = body
            .split('\n')
            .firstWhere((line) => line.trim().startsWith('data:'), orElse: () => '');

        if (dataLine.isEmpty) {
          throw Exception('No data found in response');
        }

        // Remove 'data:' prefix and trim
        final jsonString = dataLine.replaceFirst('data:', '').trim();

        // Now decode JSON
        final result = jsonDecode(jsonString) as List<dynamic>;

        final result_0 = result[0];     // confidence scores
        final result_1 = result[1];     // wound overlay
        final result_2 = result[2];     // segmentation mask
        final result_3 = result[3];     // kmeans overlay

        // Separate box scores from IME entries
        bool hasValidWound = false;
        List<double> allScores = [];
        Map<String, dynamic> imeResults = {};

        try {
          if (result_0 is Map && result_0.containsKey('confidences')) {

            final confidencesList = result_0['confidences'] as List<dynamic>;

            // Iterate through all items to separate box scores from IME results
            for (var item in confidencesList) {
              final label = item['label'] as String;
              final score = (item['confidence'] as num).toDouble();

              if (label.startsWith('IME -')) {
                // Parse IME entries: "IME - Infection: Non-Infected" -> extract task and label
                final parts = label.replaceFirst('IME - ', '').split(': ');
                if (parts.length == 2) {
                  final task = parts[0].toLowerCase(); // "infection", "moisture", "edge"
                  final taskLabel = parts[1];           // "Non-Infected", "Moderate", etc.
                  imeResults['${task}_label'] = taskLabel;
                  imeResults['${task}_conf'] = score;
                }
              } else {
                // Regular bounding box score
                allScores.add(score);
                if (score > 0.80) {
                  hasValidWound = true;
                }
              }
            }
          }
        } catch (e) {
          log('Error parsing confidence score: $e');
        }

        // If no valid wound was found in any of the boxes
        if (!hasValidWound) {
          throw Exception(
            'No wound detected. Confidence too low.'
            '\nPlease check the uploaded image or try redrawing the bounding box.'
          );
        }

        // Fetch Result Bytes in Parallel
        final futures = [
          http.get(Uri.parse(result_1['url'])), // Overlay
          http.get(Uri.parse(result_2['url'])), // Mask
          http.get(Uri.parse(result_3['url'])), // Tissue
        ];
        
        final resps = await Future.wait(futures);

        stopwatch.stop();
        log('====================================================');
        log('END-TO-END INFERENCE TIME: ${stopwatch.elapsedMilliseconds} ms (${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)} seconds)');
        log('====================================================');

        return InferenceResult(
          overlayBytes: resps[0].bodyBytes,
          maskBytes: resps[1].bodyBytes,
          tissueBytes: resps[2].bodyBytes,
          scores: allScores,
          imeResults: imeResults.isNotEmpty ? imeResults : null,
        );       
      } else {
        final errorBody = response.body;
        log('Segmentation API Error ${response.statusCode}: $errorBody');
        throw Exception('Segmentation API failed: $errorBody');
      }
    } catch (e, st) {
      log('Error fetching segmentation mask: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<String?> getOverlayUrl(String imageName) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final overlayFileName = '${imageName}_overlay.webp';
      final overlayPath = '$userId/overlay_wound/$overlayFileName';

      final signedUrl = await _supabase.storage
        .from(bucketName)
        .createSignedUrl(overlayPath, 60 * 60 * 24 * 7);

      return signedUrl;
    } catch (e) {
      log('Error getting overlay URL for $imageName: $e');
      return null;
    }
  }

  @override
  Future<String?> getMaskUrl(String imageName) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final maskFileName = '${imageName}_mask.webp';
      final maskPath = '$userId/segmentation_mask/$maskFileName';

      final signedUrl = await _supabase.storage
        .from(bucketName)
        .createSignedUrl(maskPath, 60 * 60 * 24 * 7);

      return signedUrl;
    } catch (e) {
      log('Error getting mask URL for $imageName: $e');
      return null;
    }
  }

  @override
  Future<String?> getTissueUrl(String imageName) async {
    try{
      final userId = _supabase.auth.currentUser!.id;
      final tissueFileName = '${imageName}_tissue.webp';
      final tissuePath = '$userId/tissue_classification/$tissueFileName';

      final signedUrl = await _supabase.storage
        .from(bucketName)
        .createSignedUrl(tissuePath, 60 * 60 * 24 * 7);

      return signedUrl;
    } catch (e) {
      log('Error getting tissue URL for $imageName: $e');
      return null;
    }
  }

  @override
  Future<WoundComparisonModel> saveComparison({
    required String previousImageName,
    required String currentImageName,
    required DateTime? previousDate,
    required DateTime? currentDate,
    required double sizeChangePct,
    Uint8List? overlayBytes,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      String? overlayPath;

      if (overlayBytes != null && overlayBytes.isNotEmpty) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName =
            '${previousImageName}_${currentImageName}_${timestamp}_overlay_mask.png';
        overlayPath = '$userId/overlay_mask/$fileName';

        await _supabase.storage.from(bucketName).uploadBinary(
              overlayPath,
              overlayBytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );
      }

      final response = await _supabase.from('wound_comparisons').insert({
        'user_id': userId,
        'wound_a_image_name': previousImageName,
        'wound_b_image_name': currentImageName,
        'previous_date': previousDate?.toIso8601String(),
        'current_date': currentDate?.toIso8601String(),
        'size_change_pct': sizeChangePct,
        'overlay_path': overlayPath,
      })
      .select()   // Tells Supabase to return the inserted row
      .single();  // Returns a Map instead of List

      return WoundComparisonModel.fromDocument(response);   // Return the saved model
    } catch (e, st) {
      log('Error saving comparison: $e\n$st');
      rethrow;
    }
  }

  @override
  Stream<List<WoundComparisonModel>> getComparisons() {
    final userId = _supabase.auth.currentUser!.id;

    final realtime = _supabase
        .from('wound_comparisons')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return realtime.map((records) {
      final List<WoundComparisonModel> results = [];

      for (final rec in records) {
        try {
          final doc = Map<String, dynamic>.from(rec as Map);
          results.add(WoundComparisonModel.fromDocument(doc));
        } catch (e, st) {
          log('Error parsing comparison record: $e\n$st');
        }
      }

      return results;
    });
  }

  @override
  Future<List<WoundImageModel>> getWoundsByImageNames(
      List<String> imageNames) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // Query wounds by image names - query each separately and combine
      final List<Map<String, dynamic>> allRecords = [];
      for (final imageName in imageNames) {
        try {
          final response = await _supabase
              .from('wounds')
              .select()
              .eq('user_id', userId)
              .eq('image_url', imageName)
              .maybeSingle();
          if (response != null) {
            allRecords.add(response);
          }
        } catch (e) {
          log('Error querying wound $imageName: $e');
        }
      }

      final List<WoundImageModel> results = [];

      for (final rec in allRecords) {
        try {
          final doc = Map<String, dynamic>.from(rec as Map);
          final entity = WoundImageEntity.fromDocument(doc);

          final imageName = entity.imageUrl;
          final storagePath = '${entity.userId}/original_wound/$imageName';

          String finalImageUrl;
          try {
            final signed = await _supabase.storage
                .from(bucketName)
                .createSignedUrl(storagePath, 60 * 60 * 24 * 7);
            finalImageUrl = signed;
          } catch (e) {
            log('createSignedUrl failed for $storagePath: $e');
            finalImageUrl = '';
          }

          final boxes = entity.boxes
              .map((be) => BoundingBoxModel.fromEntity(be))
              .toList();

          final model = WoundImageModel(
            userId: userId,
            imageUrl: finalImageUrl,
            originalImageName: imageName,
            boxes: boxes,
            createdAt: entity.createdAt,
            imeResults: entity.imeResults,
          );

          results.add(model);
        } catch (e, st) {
          log('Error parsing wound record: $e\n$st');
        }
      }

      return results;
    } catch (e, st) {
      log('Error getting wounds by image names: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<String?> getOverlayMaskUrl(String overlayPath) async {
    try {
      final signedUrl = await _supabase.storage
          .from(bucketName)
          .createSignedUrl(overlayPath, 60 * 60 * 24 * 7);
      return signedUrl;
    } catch (e) {
      log('Error getting overlay mask URL for $overlayPath: $e');
      return null;
    }
  }

  // Helper function to convert COCO (x,y,w,h) to Pascal VOC (x1, y1, x2, y2)
  List<List<double>> _convertToPascalVoc(List<BoundingBoxModel> boxes) {
    return boxes.map((box) {
      return [
        box.x,
        box.y,
        box.x + box.width,
        box.y + box.height,
      ]; // [x1, y1, x2, y2]
    }).toList();
  }

  // Helper function that uploads file to Gradio /upload endpoint
  Future<String> _uploadToGradio(File file) async {
    final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
    request.files.add(await http.MultipartFile.fromPath(
      'files',
      file.path,
      contentType: MediaType('image', 'jpeg'),
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Failed to upload to Gradio: ${response.body}');
    }

    final List<dynamic> jsonResponse = jsonDecode(response.body);
    return jsonResponse[0] as String;
  }
}
