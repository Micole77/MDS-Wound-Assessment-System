part of 'upload_bloc.dart';

// Events representing user's actions in the wound image upload flow.
abstract class UploadEvent extends Equatable {
  const UploadEvent();

  @override
  List<Object?> get props => [];
}

// Source type (camera or gallery)
enum UploadSource { camera, gallery }

// User pick camera or gallery
// Stores where the image comes from
class UploadSourceSelected extends UploadEvent {
  final UploadSource source;
  const UploadSourceSelected(this.source);

  @override
  List<Object?> get props => [source];
}

// User takes/selects a photo
// Store the image file in state
class UploadImageCaptured extends UploadEvent {
  final File imageFile;
  const UploadImageCaptured(this.imageFile);

  @override
  List<Object?> get props => [imageFile.path];
}

// User deletes a drawn region
// Remove a specific bounding box by index
class UploadBoundingBoxRemoved extends UploadEvent {
  final int index;
  const UploadBoundingBoxRemoved(this.index);

  @override
  List<Object?> get props => [index];
}

// User confirms the bounding boxes are ready
class UploadBoundingBoxesConfirmed extends UploadEvent {
  const UploadBoundingBoxesConfirmed();
}

// User hits "Save" triggering saving/uploading to Supabase
class UploadSaved extends UploadEvent {
  final List<Rect> boxes;
  const UploadSaved(this.boxes);

  @override
  List<Object?> get props => [boxes];
}

// User restarts flow
class UploadReset extends UploadEvent {
  const UploadReset();
}


class UploadUiImageSizeUpdated extends UploadEvent {
  final double width;
  final double height;
  const UploadUiImageSizeUpdated(this.width, this.height);

  @override
  List<Object?> get props => [width, height];
}

class UploadReferenceScaleSet extends UploadEvent {
  final double pixelsPerCm;
  UploadReferenceScaleSet(this.pixelsPerCm);
}