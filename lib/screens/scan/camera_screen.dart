import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/providers.dart';
import '../../services/food_scan_service.dart';
import '../../utils/theme.dart';
import 'scan_result_screen.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  late AnimationController _pulseController;
  late Animation<double> _pulse;
  late AnimationController _cornerController;
  late Animation<double> _cornerAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse =
        Tween<double>(begin: 1.0, end: 1.04).animate(_pulseController);

    _cornerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _cornerAnim =
        Tween<double>(begin: 0.6, end: 1.0).animate(_cornerController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cornerController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (photo != null && mounted) {
        await _processImage(File(photo.path));
      }
    } catch (e) {
      _showError('Camera unavailable: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        await _processImage(File(image.path));
      }
    } catch (e) {
      _showError('Gallery unavailable: $e');
    }
  }

  Future<void> _simulateCapture() async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(foodScanServiceProvider);
      // Pass a dummy path — service recognises 'simulated_food.jpg' and uses mock
      final dummyFile = File('simulated_food.jpg');
      final result = await service.scanFoodImage(dummyFile);
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ScanResultScreen(
              nutritionResult: result,
              scanMode: ScanMode.photo,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Demo failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _processImage(File file) async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(foodScanServiceProvider);
      final result = await service.scanFoodImage(file);
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ScanResultScreen(
              nutritionResult: result,
              scanMode: ScanMode.photo,
              localImageFile: file,
            ),
          ),
        );
      }
    } on ScanLimitReachedException catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showLimitDialog(e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Scan failed: $e');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _showLimitDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: FuelixTheme.accentOrange),
            SizedBox(width: 8),
            Text('Scan Limit Reached'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boxSize = size.width * 0.78;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background dark gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [Color(0xFF1A1A2E), Color(0xFF0D0D0D)],
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'AI Food Scanner',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 48), // balance
                  ],
                ),
              ),
            ),
          ),

          // Framing guide
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (ctx, _) => Transform.scale(
                    scale: _isProcessing ? 1.0 : _pulse.value,
                    child: AnimatedBuilder(
                      animation: _cornerAnim,
                      builder: (ctx2, __) => _FramingGuide(
                        size: boxSize,
                        cornerOpacity: _cornerAnim.value,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Center your food or plate',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Gemini AI will identify the dish & portion',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                ),
              ],
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 44),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.92),
                    Colors.transparent
                  ],
                ),
              ),
              child: _isProcessing
                  ? const _ProcessingIndicator()
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ActionButton(
                          icon: Icons.photo_library_rounded,
                          label: 'Gallery',
                          onTap: _pickFromGallery,
                        ),
                        // Main capture button
                        GestureDetector(
                          onTap: _capturePhoto,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 3.5),
                              boxShadow: [
                                BoxShadow(
                                  color: FuelixTheme.accentOrange
                                      .withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    FuelixTheme.accentOrange,
                                    Color(0xFFFF3D00)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  color: Colors.white, size: 32),
                            ),
                          ),
                        ),
                        _ActionButton(
                          icon: Icons.psychology_alt_rounded,
                          label: 'Demo',
                          onTap: _simulateCapture,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// Animated corner framing guide
class _FramingGuide extends StatelessWidget {
  final double size;
  final double cornerOpacity;

  const _FramingGuide({required this.size, required this.cornerOpacity});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FramingGuidePainter(cornerOpacity: cornerOpacity),
      ),
    );
  }
}

class _FramingGuidePainter extends CustomPainter {
  final double cornerOpacity;

  _FramingGuidePainter({required this.cornerOpacity});

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(20)),
      borderPaint,
    );

    final cornerPaint = Paint()
      ..color = FuelixTheme.accentOrange.withValues(alpha: cornerOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const cl = 32.0;
    final pts = [
      [Offset(0, cl), Offset(0, 0), Offset(cl, 0)],
      [Offset(size.width - cl, 0), Offset(size.width, 0), Offset(size.width, cl)],
      [Offset(size.width, size.height - cl), Offset(size.width, size.height), Offset(size.width - cl, size.height)],
      [Offset(cl, size.height), Offset(0, size.height), Offset(0, size.height - cl)],
    ];
    for (final p in pts) {
      final path = Path()
        ..moveTo(p[0].dx, p[0].dy)
        ..lineTo(p[1].dx, p[1].dy)
        ..lineTo(p[2].dx, p[2].dy);
      canvas.drawPath(path, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FramingGuidePainter old) =>
      old.cornerOpacity != cornerOpacity;
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ProcessingIndicator extends StatelessWidget {
  const _ProcessingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(
            color: FuelixTheme.accentOrange,
            strokeWidth: 3,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Uploading & analyzing…',
          style: TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 4),
        Text(
          'Gemini AI is identifying your meal',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}
