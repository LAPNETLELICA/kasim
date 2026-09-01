import 'dart:async';

import 'package:camera/camera.dart';

import 'api_service.dart';


class CameraCaptureService {
  final String sessionId;
  final void Function(String status)? onStatusChanged;

  CameraController? _controller;
  Timer? _captureTimer;
  bool _capturing = false;
  String status = 'pending';

  CameraCaptureService({
    required this.sessionId,
    this.onStatusChanged,
  });

  Future<void> start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        await _setStatus('unavailable');
        return;
      }
      final preferred = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        preferred,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _controller!.initialize();
      await _setStatus('active');
      await _captureFrame();
      _captureTimer = Timer.periodic(
        const Duration(seconds: 6),
        (_) => _captureFrame(),
      );
    } on CameraException catch (error) {
      await _setStatus(
        error.code == 'CameraAccessDenied' ? 'denied' : 'unavailable',
      );
    } catch (_) {
      await _setStatus('unavailable');
    }
  }

  Future<void> _captureFrame() async {
    final controller = _controller;
    if (_capturing || controller == null || !controller.value.isInitialized) return;
    _capturing = true;
    try {
      final image = await controller.takePicture();
      final bytes = await image.readAsBytes();
      await StudentApiService.uploadCameraFrame(sessionId, bytes);
      if (status != 'active') await _setStatus('active');
    } catch (_) {
      // Keep the camera initialized and retry on the next capture interval.
    } finally {
      _capturing = false;
    }
  }

  Future<void> _setStatus(String value) async {
    status = value;
    onStatusChanged?.call(value);
    try {
      await StudentApiService.updateCameraStatus(sessionId, value);
    } catch (_) {}
  }

  Future<void> stop() async {
    _captureTimer?.cancel();
    _captureTimer = null;
    final controller = _controller;
    _controller = null;
    if (controller != null) await controller.dispose();
  }
}
