import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdasense/components/my_app_bar.dart';
import 'package:verdasense/screens/upload/blocs/upload_bloc.dart';
import 'package:verdasense/screens/upload/views/bounding_box_screen.dart';

class ReferenceObjectScreen extends StatefulWidget {
  final VoidCallback onAnalysisRequested;
  
  const ReferenceObjectScreen({super.key, required this.onAnalysisRequested});

  @override
  State<ReferenceObjectScreen> createState() => _ReferenceObjectScreenState();
}

class _ReferenceObjectScreenState extends State<ReferenceObjectScreen> {
  Offset? _startPoint; 
  Offset? _endPoint; 
  double? _realWorldCm;
  double? _pixelsPerCm;

  int? _originalWidth;
  int? _originalHeight;
  
  bool _isLocked = false;
  final TransformationController _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _loadOriginalImageSize();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadOriginalImageSize() async {
    final file = context.read<UploadBloc>().state.imageFile;
    if (file == null) return;

    final bytes = await File(file.path).readAsBytes();
    final decoded = await decodeImageFromList(bytes);

    if (mounted) {
      setState(() {
        _originalWidth = decoded.width;
        _originalHeight = decoded.height;
      });
    }
  }

  // --- Button Label Logic ---
  String get _bottomButtonLabel {
    if (_pixelsPerCm != null) return "Confirm Scale";
    if (_startPoint != null && _endPoint != null) return "Enter real-world length (cm)";
    return _isLocked ? "Draw a line" : "Switch to Draw Mode";
  }

  // --- Button Action Logic ---
  VoidCallback? _getButtonAction() {
    if (_pixelsPerCm != null) return _navigateToNext;
    if (_startPoint != null && _endPoint != null) return _showWidthDialog;
    return null; 
  }

  // --- Animation to reset zoom ---
  void _resetZoom() {
    // This smoothly returns the image to its original scale and position
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final bool isFinalized = _pixelsPerCm != null;

    return Scaffold(
      appBar: const MyAppBar(title: "Mark Reference Object"),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<UploadBloc, UploadState>(
              builder: (context, state) {
                final file = state.imageFile;
                if (file == null) return const Center(child: Text("No image selected"));
                if (_originalWidth == null) return const Center(child: CircularProgressIndicator());

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final imgW = _originalWidth!.toDouble();
                    final imgH = _originalHeight!.toDouble();
                    final imageAspectRatio = imgW / imgH;
                    final screenAspectRatio = constraints.maxWidth / constraints.maxHeight;

                    double fittedWidth, fittedHeight;
                    if (screenAspectRatio > imageAspectRatio) {
                      fittedHeight = constraints.maxHeight;
                      fittedWidth = fittedHeight * imageAspectRatio;
                    } else {
                      fittedWidth = constraints.maxWidth;
                      fittedHeight = fittedWidth / imageAspectRatio;
                    }

                    final baseScale = fittedWidth / imgW;

                    return Container(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      color: Theme.of(context).colorScheme.surface,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          InteractiveViewer(
                            transformationController: _transformController,
                            minScale: 1.0,
                            maxScale: 5.0,
                            panEnabled: !_isLocked && !isFinalized,
                            scaleEnabled: !_isLocked && !isFinalized,
                            boundaryMargin: EdgeInsets.zero, 
                            clipBehavior: Clip.hardEdge,
                            child: Center( 
                              child: SizedBox(
                                width: fittedWidth,
                                height: fittedHeight,
                                child: Stack(
                                  children: [
                                    Image.file(File(file.path), fit: BoxFit.fill),
                                    IgnorePointer(
                                      ignoring: !_isLocked || isFinalized,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onPanStart: (details) {
                                          final local = details.localPosition;
                                          final pt = Offset(local.dx / baseScale, local.dy / baseScale);
                                          setState(() {
                                            _startPoint = pt;
                                            _endPoint = null;
                                            _pixelsPerCm = null;
                                            _realWorldCm = null;
                                          });
                                        },
                                        onPanUpdate: (details) {
                                          if (_startPoint == null) return;
                                          final local = details.localPosition;
                                          final pt = Offset(local.dx / baseScale, local.dy / baseScale);
                                          setState(() => _endPoint = pt);
                                        },
                                        child: CustomPaint(
                                          painter: _ReferencePainter(
                                            startPoint: _startPoint,
                                            endPoint: _endPoint,
                                            scale: baseScale,
                                          ),
                                          size: Size(fittedWidth, fittedHeight),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          if (!isFinalized)
                            Positioned(
                              top: 20,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildModeButton(
                                      icon: Icons.zoom_in,
                                      label: "Zoom",
                                      isActive: !_isLocked,
                                      onTap: () => setState(() => _isLocked = false),
                                    ),
                                    _buildModeButton(
                                      icon: Icons.edit,
                                      label: "Draw",
                                      isActive: _isLocked,
                                      onTap: () => setState(() => _isLocked = true),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          if (isFinalized)
                            Positioned(
                              top: 20,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Text(
                                  "Scale: 1px = ${(1 / _pixelsPerCm! * 10).toStringAsFixed(2)} mm",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),

                          if (_startPoint != null)
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Material(
                                color: Theme.of(context).colorScheme.surface,
                                shape: const CircleBorder(),
                                child: IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: _resetAll,
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.grey.shade300,
                                    foregroundColor: Colors.black,
                                    elevation: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _getButtonAction(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_bottomButtonLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({required IconData icon, required String label, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.white : Colors.white70),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white70, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showWidthDialog() {
    final controller = TextEditingController(text: _realWorldCm?.toString() ?? "");
    showDialog(
      context: context,
      barrierDismissible: false, // Force the user to interact with the dialog
      builder: (_) => AlertDialog(
        title: const Text("Enter real-world length"),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Length (cm)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.replaceAll(',', '.'));
              if (val != null && val > 0) {
                setState(() {
                  _realWorldCm = val;
                });
                _calculatePixelsPerCm();
                _resetZoom(); // Reset the image zoom here
                Navigator.pop(context);
              }
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _resetAll() {
    setState(() {
      _startPoint = null;
      _endPoint = null;
      _realWorldCm = null;
      _pixelsPerCm = null;
    });
  }

  void _calculatePixelsPerCm() {
    if (_startPoint == null || _endPoint == null || _realWorldCm == null) return;
    final lineLength = (_endPoint! - _startPoint!).distance;
    setState(() => _pixelsPerCm = lineLength / _realWorldCm!);
  }

  void _navigateToNext() {
    context.read<UploadBloc>().add(UploadReferenceScaleSet(_pixelsPerCm!));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<UploadBloc>(),
          child: BoundingBoxScreen(onAnalysisRequested: widget.onAnalysisRequested),
        ),
      ),
    );
  }
}

class _ReferencePainter extends CustomPainter {
  final Offset? startPoint;
  final Offset? endPoint;
  final double scale;

  _ReferencePainter({required this.startPoint, required this.endPoint, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    if (startPoint == null || endPoint == null) return;
    final start = Offset(startPoint!.dx * scale, startPoint!.dy * scale);
    final end = Offset(endPoint!.dx * scale, endPoint!.dy * scale);
    final dot = Paint()..color = Colors.redAccent..style = PaintingStyle.fill;
    final line = Paint()..color = Colors.yellowAccent..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawCircle(start, 5, dot);
    canvas.drawCircle(end, 5, dot);
    canvas.drawLine(start, end, line);
  }

  @override
  bool shouldRepaint(covariant _ReferencePainter oldDelegate) => true;
}