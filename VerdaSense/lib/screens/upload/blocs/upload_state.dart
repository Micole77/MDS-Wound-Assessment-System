part of 'upload_bloc.dart';

// Stashow PixelFormat, Recthe upload flow
enum UploadStatus { initial, loading, saving, success, error }

// Immutable state for the Upload flow.
// Every time it changes, a new instance is created
class UploadState extends Equatable {
  final UploadSource? source;           // camera or gallery
  final File? imageFile;                // actual wound image
  final List<Rect> boundingBoxes;       // all UI bounding boxes draw by user
  final UploadStatus status;            // tell UI what's going on (initial, loading, saving, etc)
  final String? errorMessage;           // used to show upload or logic errors
  final String? savedRecordId;          // Record ID returned from backend
  final double? uiImageWidth;           // width of image in UI
  final double? uiImageHeight;          // Height of image in UI
  final double? pixelsPerCm;

  // final String? overlayUrl; 
  // final String? maskUrl;

  const UploadState({
    this.source,
    this.imageFile,
    this.boundingBoxes = const [],
    this.status = UploadStatus.initial,
    this.errorMessage,
    this.savedRecordId,
    this.uiImageWidth,
    this.uiImageHeight,
    this.pixelsPerCm,
    // this.overlayUrl,
    // this.maskUrl,
  });

  const UploadState.initial() : this();

  // create a copy of the state with only the changed fields
  UploadState copyWith({
    UploadSource? source,
    File? imageFile,
    List<Rect>? boundingBoxes,
    UploadStatus? status,
    String? errorMessage,
    String? savedRecordId,
    double? uiImageWidth,
    double? uiImageHeight,
    double? pixelsPerCm,
    // String? overlayUrl,
    // String? maskUrl,
  }) {
    return UploadState(
      source: source ?? this.source,
      imageFile: imageFile ?? this.imageFile,
      boundingBoxes: boundingBoxes ?? this.boundingBoxes,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      savedRecordId: savedRecordId ?? this.savedRecordId,
      uiImageWidth: uiImageWidth ?? this.uiImageWidth,
      uiImageHeight: uiImageHeight ?? this.uiImageHeight, 
      pixelsPerCm: pixelsPerCm ?? this.pixelsPerCm,
      // overlayUrl: overlayUrl ?? this.overlayUrl, 
      // maskUrl: maskUrl ?? this.maskUrl,
    );
  }

  @override
  List<Object?> get props => [source, imageFile?.path, boundingBoxes, status, errorMessage, savedRecordId, uiImageWidth, uiImageWidth, pixelsPerCm];
}


