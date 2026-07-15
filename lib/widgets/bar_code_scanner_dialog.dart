import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerDialog extends StatefulWidget {
  const BarcodeScannerDialog({super.key});

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  String? scannedValue;
  bool isDetected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (isDetected) return;

    final Barcode barcode = capture.barcodes.first;

    if (barcode.rawValue == null) return;

    setState(() {
      scannedValue = barcode.rawValue!;
      isDetected = true;
    });

    _controller.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            const Text(
              "Scan the bar code below",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 20),

            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.green,
                  width: 5,
                ),
              ),
              child: ClipRRect(
                child: MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
              ),
            ),

            const SizedBox(height: 15),

            Text(
              scannedValue ?? "Waiting for barcode...",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 25),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                SizedBox(
                  width: 120,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: scannedValue == null
                        ? null
                        : () {
                            Navigator.pop(context, scannedValue);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff3C73B9),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      "Save",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}