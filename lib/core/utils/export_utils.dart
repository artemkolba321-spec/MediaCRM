import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Result of an export attempt, so the caller can show an honest message.
class ExportResult {
  const ExportResult({
    required this.ok,
    required this.message,
    this.savedToFile = false,
  });

  final bool ok;
  final String message;
  final bool savedToFile;
}

/// Saves [content] as a file where the platform supports it, otherwise copies
/// the text to the clipboard. No fake "downloaded" feedback is shown.
Future<ExportResult> exportTextFile({
  required String fileName,
  required String content,
}) async {
  if (!kIsWeb) {
    try {
      final bytes = Uint8List.fromList(utf8.encode(content));
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить файл',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [fileName.split('.').last],
        bytes: bytes,
      );
      if (path != null) {
        return ExportResult(
          ok: true,
          savedToFile: true,
          message: 'Файл сохранён: $path',
        );
      }
      return const ExportResult(
        ok: false,
        message: 'Сохранение отменено',
      );
    } catch (error) {
      // Fall through to the clipboard fallback.
    }
  }
  try {
    await Clipboard.setData(ClipboardData(text: content));
    return ExportResult(
      ok: true,
      message: kIsWeb
          ? 'Браузер не сохраняет файлы напрямую: данные скопированы в буфер '
              'обмена. Вставьте их в текстовый редактор и сохраните как $fileName.'
          : 'Файл сохранить не удалось, данные скопированы в буфер обмена. '
              'Вставьте их в файл $fileName.',
    );
  } catch (error) {
    return ExportResult(
      ok: false,
      message: 'Не удалось экспортировать данные: $error',
    );
  }
}

/// Picks a UTF-8 text file. Returns null when the dialog is cancelled.
Future<String?> pickTextFile({List<String> extensions = const ['json']}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
    withData: true,
  );
  final file = result?.files.single;
  final bytes = file?.bytes;
  if (bytes == null) return null;
  return utf8.decode(bytes);
}
