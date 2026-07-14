import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:wound_repository/wound_repository.dart';

import 'comparison_event.dart';
import 'comparison_state.dart';

class ComparisonBloc extends Bloc<ComparisonEvent, ComparisonState> {
  final WoundRepository _woundRepository;
  StreamSubscription<List<WoundImageModel>>? _woundSubscription;

  ComparisonBloc({required WoundRepository woundRepository})
      : _woundRepository = woundRepository,
        super(const ComparisonState()) {
    on<ComparisonStarted>(_onStarted);
    on<ComparisonWoundASelected>(_onWoundASelected);
    on<ComparisonWoundBSelected>(_onWoundBSelected);
    on<ComparisonWoundADeselected>(_onWoundADeselected);
    on<ComparisonWoundBDeselected>(_onWoundBDeselected);
    on<ComparisonCompareRequested>(_onCompareRequested);
    on<ComparisonLoadFromHistory>(_onLoadFromHistory);
    on<ComparisonWoundsRefreshed>(_onWoundsRefreshed);
  }

  // Fetch the available wounds
  Future<void> _onStarted(
    ComparisonStarted event,
    Emitter<ComparisonState> emit,
  ) async {
    emit(state.copyWith(status: ComparisonStatus.loading));

    try {
      await _woundSubscription?.cancel();
      _woundSubscription = _woundRepository.getWounds().listen(null);

      await for (final wounds in _woundRepository.getWounds()) {
        final List<WoundImageModel> availableWounds = [];
        for (final wound in wounds) {
          try {
            final overlayUrl =
                await _woundRepository.getOverlayUrl(wound.originalImageName);
            if (overlayUrl != null) availableWounds.add(wound);
          } catch (_) {}
        }
        emit(state.copyWith(
          status: ComparisonStatus.success,
          availableWounds: availableWounds,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: ComparisonStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  // Set user selection for wound A (for compare progress screen)
  void _onWoundASelected(
    ComparisonWoundASelected event,
    Emitter<ComparisonState> emit,
  ) {
    emit(state.copyWith(woundA: event.wound));
  }

  // Set user selection for wound B (for compare progress screen)
  void _onWoundBSelected(
    ComparisonWoundBSelected event,
    Emitter<ComparisonState> emit,
  ) {
    emit(state.copyWith(woundB: event.wound));
  }

  // Remove user selection for wound A
  void _onWoundADeselected(
    ComparisonWoundADeselected event,
    Emitter<ComparisonState> emit,
  ) {
    // Manually construct the state to force woundA to be null
    emit(ComparisonState(
      status: state.status,
      // Force woundA to null
      woundA: null, 
      // Keep everything else from current state
      woundB: state.woundB,
      previousWound: state.previousWound,
      currentWound: state.currentWound,
      previousWoundOverlayUrl: state.previousWoundOverlayUrl,
      currentWoundOverlayUrl: state.currentWoundOverlayUrl,
      previousWoundMaskUrl: state.previousWoundMaskUrl,
      currentWoundMaskUrl: state.currentWoundMaskUrl,
      previousWoundTissueUrl: state.previousWoundTissueUrl,
      currentWoundTissueUrl: state.currentWoundTissueUrl,
      woundSizeChange: state.woundSizeChange,
      errorMessage: state.errorMessage,
      availableWounds: state.availableWounds,
      comparisonDate: state.comparisonDate,
    ));
  }

  // Remove user selection for wound B
  void _onWoundBDeselected(
    ComparisonWoundBDeselected event,
    Emitter<ComparisonState> emit,
  ) {
    emit(ComparisonState(
      status: state.status,
      woundA: state.woundA,
      // Force woundB to null
      woundB: null, 
      // Keep everything else from current state
      previousWound: state.previousWound,
      currentWound: state.currentWound,
      previousWoundOverlayUrl: state.previousWoundOverlayUrl,
      currentWoundOverlayUrl: state.currentWoundOverlayUrl,
      previousWoundMaskUrl: state.previousWoundMaskUrl,
      currentWoundMaskUrl: state.currentWoundMaskUrl,
      previousWoundTissueUrl: state.previousWoundTissueUrl,
      currentWoundTissueUrl: state.currentWoundTissueUrl,
      woundSizeChange: state.woundSizeChange,
      errorMessage: state.errorMessage,
      availableWounds: state.availableWounds,
      comparisonDate: state.comparisonDate,
    ));
  }

  // --------------------------------------------------------------------------
  // OPTIMIZED COMPARE LOGIC
  // --------------------------------------------------------------------------
  Future<void> _onCompareRequested(
    ComparisonCompareRequested event,
    Emitter<ComparisonState> emit,
  ) async {
    if (state.woundA == null || state.woundB == null) {
      emit(state.copyWith(errorMessage: 'Please select both wounds to compare'));
      return;
    }

    emit(state.copyWith(status: ComparisonStatus.loading));

    try {
      final selectionA = state.woundA!;
      final selectionB = state.woundB!;

      // 1. Identify Chronological Order (Oldest = A, Newest = B)
      final bool isAOlder = selectionA.createdAt != null && 
                            selectionB.createdAt != null &&
                            selectionA.createdAt!.isBefore(selectionB.createdAt!);

      final WoundImageModel baselineWound = isAOlder ? selectionA : selectionB;
      final WoundImageModel targetWound = isAOlder ? selectionB : selectionA;

      // 2. Fetch fresh URLs for the chronologically ordered wounds
      // This ensures we always have the correct URLs matching the wounds, 
      // regardless of previous state
      final urls = await Future.wait([
        _woundRepository.getOverlayUrl(baselineWound.originalImageName),
        _woundRepository.getOverlayUrl(targetWound.originalImageName),
        _woundRepository.getMaskUrl(baselineWound.originalImageName),
        _woundRepository.getMaskUrl(targetWound.originalImageName),
        _woundRepository.getTissueUrl(baselineWound.originalImageName),
        _woundRepository.getTissueUrl(targetWound.originalImageName),
      ]);

      final baselineOverlayUrl = urls[0];
      final targetOverlayUrl = urls[1];
      final baselineMask = urls[2];
      final targetMask = urls[3];
      final baselineTissueUrl = urls[4];
      final targetTissueUrl = urls[5];

      if (baselineMask == null || targetMask == null) {
        throw Exception('Missing segmentation masks for comparison');
      }

      // 3. Process Comparison 
      // baselineMask (Old) becomes 'pixelsA', targetMask (New) becomes 'pixelsB'
      // This makes the sizeChange = ((New - Old) / Old) * 100
      final processingResult = await _processComparison(baselineMask, targetMask);

      // 4. Save to Backend
      final savedComparison = await _woundRepository.saveComparison(
        previousImageName: baselineWound.originalImageName,
        currentImageName: targetWound.originalImageName,
        previousDate: baselineWound.createdAt,
        currentDate: targetWound.createdAt,
        sizeChangePct: processingResult.sizeChange,
        overlayBytes: processingResult.pngBytes,
      );

      // 5. Emit Success with fresh URLs aligned to chronological order
      emit(state.copyWith(
        status: ComparisonStatus.success,
        // Keep user selections for the "Back" screen
        woundA: selectionA,
        woundB: selectionB,
        
        // Set chronological comparison results
        previousWound: baselineWound,
        currentWound: targetWound,
        previousWoundOverlayUrl: baselineOverlayUrl,
        currentWoundOverlayUrl: targetOverlayUrl,
        previousWoundMaskUrl: baselineMask,
        currentWoundMaskUrl: targetMask,
        previousWoundTissueUrl: baselineTissueUrl,
        currentWoundTissueUrl: targetTissueUrl,
        
        woundSizeChange: processingResult.sizeChange,
        comparisonDate: savedComparison.createdAt,
      ));
    } catch (e) {
      log("Comparison Error: $e");
      emit(state.copyWith(status: ComparisonStatus.failure, errorMessage: e.toString()));
    }
  }

  // The "All-in-One" Optimized Function
  Future<ComparisonProcessingResult> _processComparison(String urlA, String urlB) async {
    final responses = await Future.wait([
      http.get(Uri.parse(urlA)),
      http.get(Uri.parse(urlB)),
    ]);

    if (responses[0].statusCode != 200 || responses[1].statusCode != 200) {
      throw Exception('Failed to download mask images');
    }

    const int kSize = 1024;

    // Decode full masks
    final codecA = await ui.instantiateImageCodec(responses[0].bodyBytes);
    final codecB = await ui.instantiateImageCodec(responses[1].bodyBytes);

    final frameA = await codecA.getNextFrame();
    final frameB = await codecB.getNextFrame();
    
    // --- NEW: Align both wounds to the center of the 1024x1024 canvas ---
    final imageA = await _alignAndCenterWound(frameA.image, kSize);
    final imageB = await _alignAndCenterWound(frameB.image, kSize);

    final bytesA = await imageA.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytesB = await imageB.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (bytesA == null || bytesB == null) throw Exception("Failed to decode image bytes");

    final isolateResult = await compute(
      processComparisonTask,
      OverlayTaskData(bytesA, bytesB, kSize, kSize),
    );

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      isolateResult.rawOverlayBytes,
      kSize,
      kSize,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final finalImage = await completer.future;
    final pngByteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = pngByteData!.buffer.asUint8List();

    return ComparisonProcessingResult(isolateResult.sizeChange, pngBytes);
  }

  // --- NEW HELPER 1: Find the Bounding Box of the white pixels ---
  ui.Rect _getWoundBounds(Uint8List pixels, int width, int height) {
    int minX = width, maxX = 0, minY = height, maxY = 0;
    bool found = false;

    for (int i = 0; i < pixels.length; i += 4) {
      // Check if pixel is "White" (Wound)
      if (pixels[i] > 200) { 
        int pixelIndex = i ~/ 4;
        int x = pixelIndex % width;
        int y = pixelIndex ~/ width;

        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        found = true;
      }
    }
    
    if (!found) return ui.Rect.zero;
    
    // Return the rectangle encompassing the wound
    return ui.Rect.fromLTRB(
      minX.toDouble(), 
      minY.toDouble(), 
      maxX.toDouble(), 
      maxY.toDouble()
    );
  }

  // --- NEW HELPER 2: Crop the wound and center it on a fixed square canvas ---
  Future<ui.Image> _alignAndCenterWound(ui.Image mask, int canvasSize) async {
    final byteData = await mask.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return mask;

    final bounds = _getWoundBounds(
      byteData.buffer.asUint8List(), 
      mask.width, 
      mask.height
    );

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    
    // Draw black background
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, canvasSize.toDouble(), canvasSize.toDouble()), 
      ui.Paint()..color = const ui.Color(0xFF000000)
    );

    if (bounds != ui.Rect.zero) {
      // Calculate coordinates to place the wound in the center of the canvas
      double dx = (canvasSize - bounds.width) / 2;
      double dy = (canvasSize - bounds.height) / 2;

      canvas.drawImageRect(
        mask,
        bounds, // Source rectangle (just the wound)
        ui.Rect.fromLTWH(dx, dy, bounds.width, bounds.height), // Destination (centered)
        ui.Paint(),
      );
    }

    return await recorder.endRecording().toImage(canvasSize, canvasSize);
  }
  
  Future<void> _onLoadFromHistory(
    ComparisonLoadFromHistory event,
    Emitter<ComparisonState> emit,
  ) async {
    emit(state.copyWith(status: ComparisonStatus.loading));
    try {
      final comparison = event.comparison;
      final wounds = await _woundRepository.getWoundsByImageNames([
        comparison.woundAImageName,
        comparison.woundBImageName,
      ]);

      // 1. Identify which is which based on the saved comparison record
      // The saved comparison uses previousImageName (woundAImageName) and currentImageName (woundBImageName)
      final previousWound = wounds.firstWhere((w) => w.originalImageName == comparison.woundAImageName);
      final currentWound = wounds.firstWhere((w) => w.originalImageName == comparison.woundBImageName);

      // 2. Resolve all URLs for chronological comparison results
      final urls = await Future.wait([
        _woundRepository.getOverlayUrl(previousWound.originalImageName),
        _woundRepository.getOverlayUrl(currentWound.originalImageName),
        _woundRepository.getMaskUrl(previousWound.originalImageName),
        _woundRepository.getMaskUrl(currentWound.originalImageName),
        _woundRepository.getTissueUrl(previousWound.originalImageName),
        _woundRepository.getTissueUrl(currentWound.originalImageName),
      ]);

      emit(state.copyWith(
        status: ComparisonStatus.success,
        // Set user selections (for navigation back to compare progress screen)
        woundA: previousWound,
        woundB: currentWound,
        // Set chronological comparison results
        previousWound: previousWound,
        currentWound: currentWound,
        previousWoundOverlayUrl: urls[0],
        currentWoundOverlayUrl: urls[1],
        previousWoundMaskUrl: urls[2],
        currentWoundMaskUrl: urls[3],
        previousWoundTissueUrl: urls[4],
        currentWoundTissueUrl: urls[5],
        woundSizeChange: comparison.sizeChangePct,
        comparisonDate: comparison.createdAt,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ComparisonStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onWoundsRefreshed(ComparisonEvent event, Emitter<ComparisonState> emit) async {
    try {
      final wounds = await _woundRepository.getWounds().first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => [],
      );
      final List<WoundImageModel> availableWounds = [];
      for (final wound in wounds) {
        try {
          final overlayUrl = await _woundRepository.getOverlayUrl(wound.originalImageName);
          if (overlayUrl != null) availableWounds.add(wound);
        } catch (_) {}
      }
      emit(state.copyWith(
          status: ComparisonStatus.success,
          availableWounds: availableWounds,
      ));
    } catch (e) {
      log("Failed to refresh: $e");
    }
  }
}

// --------------------------------------------------------------------------
// ISOLATE DATA STRUCTURES & TASKS
// --------------------------------------------------------------------------

class ComparisonProcessingResult {
  final double sizeChange;
  final Uint8List pngBytes;
  ComparisonProcessingResult(this.sizeChange, this.pngBytes);
}

class IsolateResult {
  final double sizeChange;
  final Uint8List rawOverlayBytes;
  IsolateResult(this.sizeChange, this.rawOverlayBytes);
}

class OverlayTaskData {
  final ByteData bytesA;
  final ByteData bytesB;
  final int width;
  final int height;
  OverlayTaskData(this.bytesA, this.bytesB, this.width, this.height);
}

// Combined Task: Counts pixels AND generates overlay raw bytes
Future<IsolateResult> processComparisonTask(OverlayTaskData data) async {
  final pixelsA = data.bytesA.buffer.asUint8List();
  final pixelsB = data.bytesB.buffer.asUint8List();
  final width = data.width;
  final height = data.height;
  final length = pixelsA.length;
  
  final output = Uint8List(length);
  
  int countA = 0;
  int countB = 0;

  for (int i = 0; i < length; i += 4) {
    // Current Pixel position
    int pixelIndex = i ~/ 4;
    int x = pixelIndex % width;
    int y = pixelIndex ~/ width;

    bool isWhiteA = pixelsA[i] > 200; 
    bool isWhiteB = pixelsB[i] > 200;

    if (isWhiteA) countA++;
    if (isWhiteB) countB++;

    // --- BORDER DETECTION LOGIC ---
    bool isBorderA = false;
    bool isBorderB = false;

    // Only check for borders if the pixel is actually a wound pixel
    if (isWhiteA || isWhiteB) {
      // Check 4-connectivity (Up, Down, Left, Right)
      // We check if we are within bounds and if the neighbor is background
      if (x > 0 && x < width - 1 && y > 0 && y < height - 1) {
        if (isWhiteA) {
          // Check if any neighbor in Mask A is background
          if (pixelsA[i - 4] <= 200 ||          // Left
              pixelsA[i + 4] <= 200 ||          // Right
              pixelsA[i - (width * 4)] <= 200 || // Up
              pixelsA[i + (width * 4)] <= 200) { // Down
            isBorderA = true;
          }
        }
        if (isWhiteB) {
          if (pixelsB[i - 4] <= 200 || 
              pixelsB[i + 4] <= 200 || 
              pixelsB[i - (width * 4)] <= 200 || 
              pixelsB[i + (width * 4)] <= 200) {
            isBorderB = true;
          }
        }
      }
    }

    // --- COLORING LOGIC ---
    // Green = Healed (was in previous wound, not in current)
    // Red = Remaining wound (in current wound, including overlap)
    if (isWhiteA && !isWhiteB) {
      // Healed area (only in previous, not in current)
      if (isBorderA) {
        // Strong Green border for healed area
        _assignColor(output, i, 0, 255, 0, 255);
      } else {
        // Faint Green fill for healed area
        _assignColor(output, i, 0, 255, 0, 50);
      }
    } else if (isWhiteB) {
      // Remaining wound (in current, including overlap with previous)
      if (isBorderB) {
        // Strong Red border for remaining wound
        _assignColor(output, i, 255, 0, 0, 255);
      } else {
        // Faint Red fill for remaining wound
        _assignColor(output, i, 255, 0, 0, 50);
      }
    } else {
      // Background
      _assignColor(output, i, 0, 0, 0, 0);
    }
  }

  // 5. Finalize Calculation
  double sizeChange = 0.0;
  if (countA == 0) {
    sizeChange = countB > 0 ? 100.0 : 0.0;
  } else {
    sizeChange = ((countB - countA) / countA) * 100;
  }

  return IsolateResult(sizeChange, output); 
}

// Helper to keep the loop clean
void _assignColor(Uint8List list, int i, int r, int g, int b, int a) {
  list[i] = r;
  list[i + 1] = g;
  list[i + 2] = b;
  list[i + 3] = a;
}