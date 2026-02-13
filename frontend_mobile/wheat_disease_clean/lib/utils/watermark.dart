import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

Future<File> addWatermark({
  required File originalFile,
  required double lat,
  required double lon,
}) async {
  final Uint8List bytes = await originalFile.readAsBytes();
  img.Image? original = img.decodeImage(bytes);

  if (original == null) return originalFile;

  final timestamp = DateTime.now().toString().substring(0, 19);

  final text1 = "WheatGuard AI";
  final text2 = "Lat: $lat";
  final text3 = "Lon: $lon";
  final text4 = "Time: $timestamp";

  final font = img.arial24;

  img.drawString(original, text1,
      font: font, x: 20, y: 20,
      color: img.ColorRgb8(255, 255, 255));

  img.drawString(original, text2,
      font: font, x: 20, y: 60,
      color: img.ColorRgb8(255, 255, 0));

  img.drawString(original, text3,
      font: font, x: 20, y: 100,
      color: img.ColorRgb8(255, 255, 0));

  img.drawString(original, text4,
      font: font, x: 20, y: 140,
      color: img.ColorRgb8(0, 255, 255));

  final newPath = originalFile.path.replaceAll(".jpg", "_wm.jpg");
  final File newFile = File(newPath);
  await newFile.writeAsBytes(img.encodeJpg(original, quality: 95));

  return newFile;
}
