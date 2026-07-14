import 'dart:typed_data';

class InferenceResult {
  final Uint8List overlayBytes;
  final Uint8List maskBytes;
  final Uint8List tissueBytes;
  final List<double> scores;

  /// IME classification results parsed from the Gradio response.
  /// Keys: 'infection_label', 'infection_conf',
  ///        'moisture_label', 'moisture_conf',
  ///        'edge_label', 'edge_conf'
  final Map<String, dynamic>? imeResults;

  InferenceResult({
    required this.overlayBytes,
    required this.maskBytes,
    required this.tissueBytes,
    required this.scores,
    this.imeResults,
  });
}