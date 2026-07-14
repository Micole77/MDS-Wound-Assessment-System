import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:wound_repository/wound_repository.dart';

part 'upload_event.dart';
part 'upload_state.dart';

/// Bloc driving the Upload module flow from selecting source to bounding box.
class UploadBloc extends Bloc<UploadEvent, UploadState> {

  final WoundRepository woundRepository;

  UploadBloc({required this.woundRepository}) : super(const UploadState.initial()) {
    on<UploadSourceSelected>(_onSourceSelected);
    on<UploadImageCaptured>(_onImageCaptured);
    on<UploadBoundingBoxRemoved>(_onBoundingBoxRemoved);
    on<UploadBoundingBoxesConfirmed>(_onBoundingBoxesConfirmed);
    on<UploadSaved>(_onSaved);
    on<UploadReset>(_onReset);
    on<UploadUiImageSizeUpdated>(_onUploadUiImageSizeUpdated);
    on<UploadReferenceScaleSet>(_onUploadReferenceScaleSet);
  }

  void _onUploadReferenceScaleSet(UploadReferenceScaleSet event, Emitter<UploadState> emit) {
    emit(state.copyWith(pixelsPerCm: event.pixelsPerCm));
  }

  // When user picks camera/gallery, the state updates its source
  void _onSourceSelected(UploadSourceSelected event, Emitter<UploadState> emit) {
    emit(state.copyWith(source: event.source));
  }

  // After user captures/selects an image, save it into state
  void _onImageCaptured(UploadImageCaptured event, Emitter<UploadState> emit) {
    emit(state.copyWith(imageFile: event.imageFile));
  }

  // Removes a bounding box at a given index (if valid)
  void _onBoundingBoxRemoved(UploadBoundingBoxRemoved event, Emitter<UploadState> emit) {
    final newBoxes = List<Rect>.from(state.boundingBoxes);
    if (event.index >= 0 && event.index < newBoxes.length) {
      newBoxes.removeAt(event.index);
      emit(state.copyWith(boundingBoxes: newBoxes));
    }
  }

  // 
  void _onBoundingBoxesConfirmed(UploadBoundingBoxesConfirmed event, Emitter<UploadState> emit) {
    // Keep the current state, just confirm the boxes are ready
    emit(state);
  }

  void _onUploadUiImageSizeUpdated(UploadUiImageSizeUpdated event, Emitter<UploadState> emit) {
    emit(state.copyWith(
      uiImageWidth: event.width,
      uiImageHeight: event.height,
    ));
  }

  // Helper function that convert UI bounding boxes drawn on a scaled image back to the original image's pixel coordinates
  List<Rect> convertUiBoxesToOriginal({
    required List<Rect> uiBoxes,
    required double uiWidth,
    required double uiHeight,
    required double imageWidth,
    required double imageHeight,
  }) {
    // Compute scale used by BoxFit.contain
    final scale = (uiWidth / imageWidth).clamp(0.0, uiHeight / imageHeight);

    final displayWidth = imageWidth * scale;
    final displayHeight = imageHeight * scale;

    // Compute the letterboxing offset (centered)
    final dx = (uiWidth - displayWidth) / 2;
    final dy = (uiHeight - displayHeight) / 2;

    // Convert each Rect
    return uiBoxes.map((rect) {
      final realLeft = (rect.left - dx) / scale;
      final realTop = (rect.top - dy) / scale;
      final realRight = (rect.right - dx) / scale;
      final realBottom = (rect.bottom - dy) / scale;

      return Rect.fromLTRB(realLeft, realTop, realRight, realBottom);
    }).toList();
  }

  Future<void> _onSaved(UploadSaved event, Emitter<UploadState> emit) async {
    if (state.imageFile == null || event.boxes.isEmpty) {
      emit(state.copyWith(
        status: UploadStatus.error,
        errorMessage: 'No image or bounding boxes to save',
      ));
      return;
    }

    emit(state.copyWith(status: UploadStatus.saving));

    try {
      // Read image bytes once
      final imageBytes = await state.imageFile!.readAsBytes();

      // Get original image resolution
      final decodedImage = await decodeImageFromList(imageBytes);
      final originalWidth = decodedImage.width.toDouble();
      final originalHeight = decodedImage.height.toDouble();

      // Get UI image display size
      final uiWidth = state.uiImageWidth;
      final uiHeight = state.uiImageHeight;

      // Convert UI -> original coordinates
      final converted_boxes = convertUiBoxesToOriginal(
        uiBoxes: event.boxes,
        uiWidth: uiWidth!,
        uiHeight: uiHeight!,
        imageWidth: originalWidth,
        imageHeight: originalHeight,
      );

      // Convert Rects to BoundingBoxModels for repository
      final boxes = converted_boxes
          .map((rect) => BoundingBoxModel(
                x: rect.left,
                y: rect.top,
                width: rect.width,
                height: rect.height,
              ))
          .toList();

      // Generate a consistent file name here
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$timestamp.jpg';

      // Run inference first
      // Will throw an Exception if confidence score less than threshold
      final inferenceResult = await woundRepository.getSegmentationMask(
        imageFile: state.imageFile!,
        imageName: fileName,
        boxes: boxes
      );

      // Only if inference succeeds, upload the original image and results
      await woundRepository.saveWoundWithResults(
        originalImageFile: state.imageFile!,
        imageName: fileName,
        boxes: boxes,
        inference: inferenceResult,
        pixelsPerCm: state.pixelsPerCm,
      );

      log('Upload and Save completed successfully');

      // Emit Success
      emit(state.copyWith(status: UploadStatus.success));

    } catch (e) {
      emit(state.copyWith(status: UploadStatus.error, errorMessage: e.toString()));
    }
  }

  // Clears everything
  void _onReset(UploadReset event, Emitter<UploadState> emit) {
    emit(const UploadState.initial());
  }
}


