import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class VehicleDocumentService {
  static final VehicleDocumentService _instance =
      VehicleDocumentService._internal();

  factory VehicleDocumentService() {
    return _instance;
  }

  VehicleDocumentService._internal();

  final supabase = Supabase.instance.client;
  static const String _vehicleDocumentsBucket = 'vehicle_documents';

  // ==================== VEHICLE DOCUMENTS ====================

  /// Upload vehicle document file to storage
  Future<String> uploadVehicleDocumentFile({
    required String partnerId,
    required File file,
    required String documentType, // 'or', 'cr', 'insurance', etc
  }) async {
    try {
      debugPrint('Uploading $documentType to storage for partner: $partnerId');

      final bytes = await file.readAsBytes();
      final extension = file.path.contains('.')
          ? file.path.split('.').last.toLowerCase()
          : 'jpg';
      final objectPath =
          '$partnerId/${documentType}_${DateTime.now().millisecondsSinceEpoch}.$extension';

      await supabase.storage
          .from(_vehicleDocumentsBucket)
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = supabase.storage
          .from(_vehicleDocumentsBucket)
          .getPublicUrl(objectPath);

      debugPrint('Vehicle document uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading vehicle document: $e');
      rethrow;
    }
  }

  /// Create vehicle document record in database
  Future<Map<String, dynamic>> createVehicleDocument({
    required String applicationId,
    required String documentType, // 'or', 'cr', 'insurance', 'registration'
    required String fileUrl,
    required DateTime expiryDate,
  }) async {
    try {
      debugPrint(
        'Creating vehicle document record: $documentType for application: $applicationId',
      );

      final response = await supabase
          .from('vehicle_documents')
          .insert({
            'application_id': applicationId,
            'document_type': documentType,
            'file_url': fileUrl,
            'expiry_date': expiryDate.toIso8601String().split('T')[0],
            'status': 'pending', // Will be verified by admin
            'uploaded_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      debugPrint('Vehicle document record created successfully');
      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error creating document: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error creating document: $e');
      rethrow;
    }
  }

  /// Upload vehicle document (file + record) - all in one call
  Future<Map<String, dynamic>> uploadVehicleDocument({
    required String applicationId,
    required String partnerId,
    required File file,
    required String documentType, // 'or', 'cr', 'insurance', 'registration'
    required DateTime expiryDate,
  }) async {
    try {
      debugPrint('Uploading vehicle document: $documentType');

      // Upload to storage
      final fileUrl = await uploadVehicleDocumentFile(
        partnerId: partnerId,
        file: file,
        documentType: documentType,
      );

      // Create database record
      final docRecord = await createVehicleDocument(
        applicationId: applicationId,
        documentType: documentType,
        fileUrl: fileUrl,
        expiryDate: expiryDate,
      );

      return {
        'success': true,
        'document_id': docRecord['id'],
        'file_url': fileUrl,
        'message': 'Document uploaded successfully',
      };
    } catch (e) {
      debugPrint('Error uploading vehicle document: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get all documents for a vehicle application
  Future<List<Map<String, dynamic>>> getApplicationDocuments(
    String applicationId,
  ) async {
    try {
      debugPrint('Fetching documents for application: $applicationId');

      final response = await supabase
          .from('vehicle_documents')
          .select()
          .eq('application_id', applicationId)
          .order('uploaded_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching documents: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching documents: $e');
      return [];
    }
  }

  /// Get document by type for application
  Future<Map<String, dynamic>?> getApplicationDocumentByType(
    String applicationId,
    String documentType,
  ) async {
    try {
      debugPrint('Fetching $documentType for application: $applicationId');

      final response = await supabase
          .from('vehicle_documents')
          .select()
          .eq('application_id', applicationId)
          .eq('document_type', documentType)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error fetching document: $e');
      return null;
    }
  }

  /// Check if all required documents are uploaded for application
  Future<bool> hasAllRequiredDocuments(String applicationId) async {
    try {
      final docs = await getApplicationDocuments(applicationId);

      // Required documents for vehicle: OR and CR
      final hasOR = docs.any(
        (d) => (d['document_type'] as String).toLowerCase() == 'or',
      );
      final hasCR = docs.any(
        (d) => (d['document_type'] as String).toLowerCase() == 'cr',
      );

      return hasOR && hasCR;
    } catch (e) {
      debugPrint('Error checking required documents: $e');
      return false;
    }
  }

  /// Get error message from exception
  String getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return error.toString();
  }
}
