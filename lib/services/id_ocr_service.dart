import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Structured result holding extracted information from an ID document image.
class IdOcrResult {
  final String? idType;
  final String? idNumber;
  final String? fullName;
  final DateTime? expiryDate;
  final DateTime? birthDate;
  final String? rawText;
  final double confidenceScore;

  const IdOcrResult({
    this.idType,
    this.idNumber,
    this.fullName,
    this.expiryDate,
    this.birthDate,
    this.rawText,
    this.confidenceScore = 0.0,
  });

  bool get hasAnyData =>
      (idNumber != null && idNumber!.isNotEmpty) ||
      (fullName != null && fullName!.isNotEmpty) ||
      expiryDate != null;

  String get summary {
    final parts = <String>[];
    if (idType != null) parts.add('Type: $idType');
    if (fullName != null) parts.add('Name: $fullName');
    if (idNumber != null) parts.add('ID #: $idNumber');
    if (expiryDate != null) {
      parts.add(
        'Expires: ${expiryDate!.year}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}',
      );
    }
    return parts.join(' • ');
  }
}

/// Service that leverages Google ML Kit (on-device OCR) to automatically
/// parse and extract text from Philippine government IDs, Driver's Licenses,
/// and Passports.
class IdOcrService {
  static final IdOcrService _instance = IdOcrService._internal();
  factory IdOcrService() => _instance;
  IdOcrService._internal();

  /// Scans the given ID [imageFile] on-device and extracts text fields.
  /// Returns null if on web (where native ML Kit is unavailable) or if scan fails.
  Future<IdOcrResult?> scanIdImage(File imageFile) async {
    if (kIsWeb) {
      debugPrint('ℹ️ [IdOcrService] ML Kit on-device OCR is skipped on web');
      return null;
    }

    TextRecognizer? recognizer;
    try {
      final inputImage = InputImage.fromFile(imageFile);
      recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText =
          await recognizer.processImage(inputImage);

      final fullText = recognizedText.text;
      if (fullText.trim().isEmpty) {
        return null;
      }

      return _parsePhilippineId(recognizedText);
    } catch (e) {
      debugPrint('⚠️ [IdOcrService] OCR processing error: $e');
      return null;
    } finally {
      recognizer?.close();
    }
  }

  /// Parses text blocks and lines into recognized Philippine ID fields.
  IdOcrResult _parsePhilippineId(RecognizedText recognizedText) {
    final rawText = recognizedText.text;
    final lines = <String>[];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) {
          lines.add(text);
        }
      }
    }

    final upperFullText = rawText.toUpperCase();

    // 1. Detect ID Type
    String? detectedIdType;
    if (_isDriverLicense(upperFullText)) {
      detectedIdType = "Driver's License";
    } else if (_isNationalId(upperFullText)) {
      detectedIdType = 'National ID';
    } else if (_isPassport(upperFullText)) {
      detectedIdType = 'Passport';
    } else if (_isTinId(upperFullText)) {
      detectedIdType = 'TIN ID';
    } else if (_isUmidOrSss(upperFullText)) {
      detectedIdType = 'National ID'; // Maps to official government ID
    }

    // 2. Extract ID Number
    String? detectedIdNumber;
    if (detectedIdType == "Driver's License" || _isDriverLicense(upperFullText)) {
      detectedIdNumber = _extractDriverLicenseNumber(lines, upperFullText);
    }

    if (detectedIdNumber == null &&
        (detectedIdType == 'National ID' || _isNationalId(upperFullText))) {
      detectedIdNumber = _extractNationalIdNumber(lines, upperFullText);
    }

    if (detectedIdNumber == null &&
        (detectedIdType == 'Passport' || _isPassport(upperFullText))) {
      detectedIdNumber = _extractPassportNumber(lines, upperFullText);
    }

    if (detectedIdNumber == null) {
      detectedIdNumber = _extractGenericIdNumber(lines, upperFullText);
    }

    // 3. Extract Expiry Date
    final detectedExpiryDate = _extractExpiryDate(lines, upperFullText);

    // 4. Extract Full Name
    final detectedFullName = _extractFullName(lines, detectedIdType);

    double score = 0.0;
    if (detectedIdType != null) score += 0.25;
    if (detectedIdNumber != null) score += 0.35;
    if (detectedFullName != null) score += 0.25;
    if (detectedExpiryDate != null) score += 0.15;

    return IdOcrResult(
      idType: detectedIdType,
      idNumber: detectedIdNumber,
      fullName: detectedFullName,
      expiryDate: detectedExpiryDate,
      rawText: rawText,
      confidenceScore: score,
    );
  }

  // --- ID Type Detectors ---

  bool _isDriverLicense(String text) {
    return text.contains('DRIVER') ||
        text.contains('LICENSE') ||
        text.contains('LTO') ||
        text.contains('LAND TRANSPORTATION OFFICE') ||
        text.contains('RESTRICTIONS') ||
        text.contains('CONDITIONS') ||
        RegExp(r'\b[A-Z]\d{2}-\d{2}-\d{6}\b').hasMatch(text);
  }

  bool _isNationalId(String text) {
    return text.contains('PAMBANSANG PAGKAKAKILANLAN') ||
        text.contains('PHILIPPINE IDENTIFICATION') ||
        text.contains('PHILSYS') ||
        text.contains('PHILID') ||
        text.contains('REPUBLIKA NG PILIPINAS') ||
        RegExp(r'\b\d{4}-\d{4}-\d{4}-\d{4}\b').hasMatch(text);
  }

  bool _isPassport(String text) {
    return text.contains('PASSPORT') ||
        text.contains('PASAPORTE') ||
        text.contains('REPUBLICA DE FILIPINAS') ||
        (text.contains('PILIPINAS') && text.contains('TYPE/URI'));
  }

  bool _isTinId(String text) {
    return text.contains('BUREAU OF INTERNAL REVENUE') ||
        text.contains('TAX IDENTIFICATION') ||
        text.contains('TIN');
  }

  bool _isUmidOrSss(String text) {
    return text.contains('UNIFIED MULTI-PURPOSE') ||
        text.contains('UMID') ||
        text.contains('SOCIAL SECURITY SYSTEM') ||
        text.contains('SSS');
  }

  // --- Extraction Helpers ---

  String? _extractDriverLicenseNumber(List<String> lines, String fullText) {
    // 1. Standard LTO pattern: N01-19-123456 or A12-34-567890
    final ltoRegex = RegExp(r'\b([A-Z]\d{2}[-\s]?\d{2}[-\s]?\d{6})\b');
    final match = ltoRegex.firstMatch(fullText);
    if (match != null) {
      final raw = match.group(1)!.replaceAll(' ', '-');
      // Format with standard dashes if missing
      final clean = raw.replaceAll('-', '');
      if (clean.length == 11) {
        return '${clean.substring(0, 3)}-${clean.substring(3, 5)}-${clean.substring(5)}';
      }
      return raw;
    }

    // 2. Scan lines following "License No." or "DL No."
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toUpperCase();
      if (line.contains('LICENSE') || line.contains('DL NO') || line.contains('NO.')) {
        final lineMatch = ltoRegex.firstMatch(line);
        if (lineMatch != null) return lineMatch.group(1);
        if (i + 1 < lines.length) {
          final nextMatch = ltoRegex.firstMatch(lines[i + 1].toUpperCase());
          if (nextMatch != null) return nextMatch.group(1);
        }
      }
    }
    return null;
  }

  String? _extractNationalIdNumber(List<String> lines, String fullText) {
    // 16-digit PhilSys Card Number: 1234-5678-9012-3456
    final philSysRegex = RegExp(r'\b(\d{4}[-\s]\d{4}[-\s]\d{4}[-\s]\d{4})\b');
    final match = philSysRegex.firstMatch(fullText);
    if (match != null) {
      return match.group(1)!.replaceAll(' ', '-');
    }

    // Continuous 16 digits
    final digits16 = RegExp(r'\b(\d{16})\b').firstMatch(fullText);
    if (digits16 != null) {
      final s = digits16.group(1)!;
      return '${s.substring(0, 4)}-${s.substring(4, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}';
    }

    return null;
  }

  String? _extractPassportNumber(List<String> lines, String fullText) {
    // Philippine Passport: P followed by 7-8 chars/digits, or 1 letter + 7 digits + 1 letter
    final passportRegex = RegExp(r'\b([P][A-Z0-9]{7,8}|[A-Z]\d{7}[A-Z]?)\b');
    final match = passportRegex.firstMatch(fullText);
    if (match != null) {
      return match.group(1);
    }
    return null;
  }

  String? _extractGenericIdNumber(List<String> lines, String fullText) {
    // Check for TIN: 123-456-789-000
    final tinMatch = RegExp(r'\b(\d{3}[-\s]\d{3}[-\s]\d{3}(?:[-\s]\d{3})?)\b')
        .firstMatch(fullText);
    if (tinMatch != null) return tinMatch.group(1)!.replaceAll(' ', '-');

    // Check for UMID / CRN: 1234-5678901-2
    final umidMatch =
        RegExp(r'\b(\d{4}[-\s]\d{7}[-\s]\d)\b').firstMatch(fullText);
    if (umidMatch != null) return umidMatch.group(1)!.replaceAll(' ', '-');

    return null;
  }

  static const Map<String, int> _monthNames = {
    'JAN': 1,
    'FEB': 2,
    'MAR': 3,
    'APR': 4,
    'MAY': 5,
    'JUN': 6,
    'JUL': 7,
    'AUG': 8,
    'SEP': 9,
    'OCT': 10,
    'NOV': 11,
    'DEC': 12,
  };

  DateTime? _extractExpiryDate(List<String> lines, String fullText) {
    // Look for lines containing "EXPIRATION", "EXPIRY", "EXP", "VALID UNTIL", "4A"
    final dateRegex = RegExp(
      r'\b(20\d{2}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}[-/.]\d{1,2}[-/.]20\d{2}|\d{1,2}[-\s](?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[a-z]*[-\s]20\d{2}|(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[a-z]*\s+\d{1,2},?\s+20\d{2})\b',
      caseSensitive: false,
    );

    // Prioritize lines with expiration keywords
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toUpperCase();
      if (line.contains('EXPIR') ||
          line.contains('EXP.') ||
          line.contains('EXP DATE') ||
          line.contains('4A.') ||
          line.contains('4A ') ||
          line.contains('VALID UNTIL')) {
        final match = dateRegex.firstMatch(line);
        if (match != null) {
          final dt = _parseFlexibleDate(match.group(1)!);
          if (dt != null) return dt;
        }
        // Check immediate next line
        if (i + 1 < lines.length) {
          final nextMatch = dateRegex.firstMatch(lines[i + 1]);
          if (nextMatch != null) {
            final dt = _parseFlexibleDate(nextMatch.group(1)!);
            if (dt != null) return dt;
          }
        }
      }
    }

    // Fallback: look for future dates in the document
    final now = DateTime.now();
    for (final line in lines) {
      final matches = dateRegex.allMatches(line);
      for (final match in matches) {
        final dt = _parseFlexibleDate(match.group(1)!);
        // Expiry dates are typically in the future or recent past
        if (dt != null && dt.isAfter(DateTime(now.year - 2))) {
          return dt;
        }
      }
    }

    return null;
  }

  DateTime? _parseFlexibleDate(String dateStr) {
    try {
      final clean = dateStr
          .replaceAll('.', ' ')
          .replaceAll('/', ' ')
          .replaceAll('-', ' ')
          .replaceAll(',', ' ')
          .trim();
      final tokens =
          clean.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      if (tokens.length != 3) return null;

      // Check for word month (e.g. "18 MAY 2029" or "MAY 18 2029")
      int? month;
      int? day;
      int? year;

      for (int i = 0; i < tokens.length; i++) {
        final upper = tokens[i].toUpperCase();
        for (final entry in _monthNames.entries) {
          if (upper.startsWith(entry.key)) {
            month = entry.value;
            final remaining = tokens.where((t) => t != tokens[i]).toList();
            if (remaining.length == 2) {
              final val1 = int.tryParse(remaining[0]);
              final val2 = int.tryParse(remaining[1]);
              if (val1 != null && val2 != null) {
                if (val1 > 1000) {
                  year = val1;
                  day = val2;
                } else if (val2 > 1000) {
                  year = val2;
                  day = val1;
                }
              }
            }
            break;
          }
        }
        if (month != null) break;
      }

      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }

      // Numeric cases (YYYY-MM-DD, MM-DD-YYYY, DD-MM-YYYY)
      if (tokens[0].length == 4) {
        final y = int.parse(tokens[0]);
        final m = int.parse(tokens[1]);
        final d = int.parse(tokens[2]);
        return DateTime(y, m, d);
      } else if (tokens[2].length == 4) {
        final val1 = int.parse(tokens[0]);
        final val2 = int.parse(tokens[1]);
        final y = int.parse(tokens[2]);
        if (val1 > 12) {
          return DateTime(y, val2, val1);
        } else {
          return DateTime(y, val1, val2);
        }
      }
    } catch (_) {}
    return null;
  }

  String? _extractFullName(List<String> lines, String? detectedIdType) {
    // 1. If Driver's License:
    // LTO cards usually have:
    // "1. Last Name, First Name Middle Name" or
    // "1. Last Name"
    // "2. First Name"
    // "3. Middle Name"
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final upper = line.toUpperCase();

      // Check for LTO "1. Last Name" or "1. Last Name, First Name"
      if (RegExp(r'^\s*1\.\s*[A-Z]').hasMatch(line)) {
        final textAfter1 =
            line.replaceFirst(RegExp(r'^\s*1\.\s*'), '').trim();
        if (textAfter1.contains(',')) {
          final parts = textAfter1.split(',');
          if (parts.length >= 2) {
            return _formatCleanName('${parts[1].trim()} ${parts[0].trim()}');
          }
          return _formatCleanName(textAfter1);
        }

        // Multi-line numbered LTO format (1. Surname, 2. Given Name, 3. Middle Name)
        String firstName = '';
        String middleName = '';
        for (int j = i + 1; j < lines.length && j <= i + 3; j++) {
          final nextLine = lines[j].trim();
          if (RegExp(r'^\s*2\.\s*[A-Z]').hasMatch(nextLine)) {
            firstName =
                nextLine.replaceFirst(RegExp(r'^\s*2\.\s*'), '').trim();
          } else if (RegExp(r'^\s*3\.\s*[A-Z]').hasMatch(nextLine)) {
            middleName =
                nextLine.replaceFirst(RegExp(r'^\s*3\.\s*'), '').trim();
          }
        }
        if (firstName.isNotEmpty) {
          final combined = middleName.isNotEmpty
              ? '$firstName $middleName $textAfter1'
              : '$firstName $textAfter1';
          return _formatCleanName(combined);
        }

        return _formatCleanName(textAfter1);
      }

      // Check for "NAME: " prefix
      if (upper.startsWith('NAME:') || upper.startsWith('NAME :')) {
        final cleaned = line.substring(line.indexOf(':') + 1).trim();
        if (cleaned.length >= 3) {
          return _formatCleanName(cleaned);
        }
        if (i + 1 < lines.length && _isLikelyPersonName(lines[i + 1])) {
          return _formatCleanName(lines[i + 1]);
        }
      }

      // Check for comma-separated surname pattern: "SANTOS, JUAN DELA CRUZ"
      if (line.contains(',') && !line.contains('@') && !line.contains('http')) {
        final parts = line.split(',');
        if (parts.length == 2 &&
            _isLikelyPersonName(parts[0].trim()) &&
            _isLikelyPersonName(parts[1].trim())) {
          // Flip "LastName, FirstName MiddleName" -> "FirstName MiddleName LastName"
          final last = parts[0].trim();
          final first = parts[1].trim();
          return _formatCleanName('$first $last');
        }
      }
    }

    // 2. National ID / PhilSys Given name + Surname detection
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toUpperCase();
      if (line.contains('APELYIDO') || line.contains('LAST NAME')) {
        if (i + 1 < lines.length && _isLikelyPersonName(lines[i + 1])) {
          final lastName = lines[i + 1].trim();
          // Look for Given Names next
          String givenName = '';
          for (int j = i + 2; j < lines.length && j < i + 6; j++) {
            if (lines[j].toUpperCase().contains('MGA PANGALAN') ||
                lines[j].toUpperCase().contains('GIVEN')) {
              if (j + 1 < lines.length && _isLikelyPersonName(lines[j + 1])) {
                givenName = lines[j + 1].trim();
                break;
              }
            }
          }
          if (givenName.isNotEmpty) {
            return _formatCleanName('$givenName $lastName');
          }
        }
      }
    }

    return null;
  }

  bool _isLikelyPersonName(String text) {
    if (text.length < 2 || text.length > 50) return false;
    // Names should not contain numbers or suspicious keywords
    if (RegExp(r'\d').hasMatch(text)) return false;
    final upper = text.toUpperCase();
    final excludedWords = [
      'REPUBLIC',
      'PHILIPPINES',
      'PILIPINAS',
      'LICENSE',
      'DRIVER',
      'OFFICE',
      'EXPIRE',
      'EXPIRATION',
      'SIGNATURE',
      'SEX',
      'BLOOD',
      'HEIGHT',
      'WEIGHT',
      'NATIONALITY',
      'CIVIL',
      'DATE',
      'BIRTH',
      'ADDRESS',
      'AGENCY',
      'LAND',
      'TRANSPORTATION',
    ];
    for (final word in excludedWords) {
      if (upper.contains(word)) return false;
    }
    // Must contain letters
    return RegExp(r'[a-zA-Z]').hasMatch(text);
  }

  String _formatCleanName(String raw) {
    // Remove unwanted leading/trailing symbols
    var clean = raw.replaceAll(RegExp(r'[^a-zA-Z\s,.-]'), '').trim();
    // Normalize multiple spaces
    clean = clean.replaceAll(RegExp(r'\s+'), ' ');

    // Convert ALL CAPS to Title Case if needed: "JUAN DELA CRUZ" -> "Juan Dela Cruz"
    if (clean.length > 2 && clean == clean.toUpperCase()) {
      clean = clean
          .split(' ')
          .map((word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : '')
          .join(' ');
    }
    return clean;
  }
}
