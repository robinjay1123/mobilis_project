import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmergencyContactService {
  EmergencyContactService._();

  static final EmergencyContactService _instance =
      EmergencyContactService._();

  factory EmergencyContactService() => _instance;

  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getMyContacts() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response = await supabase
        .from('emergency_contacts')
        .select()
        .eq('user_id', user.id)
        .order('is_default', ascending: false)
        .order('updated_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getDefaultContact() async {
    final contacts = await getMyContacts();
    if (contacts.isEmpty) return null;

    for (final contact in contacts) {
      if (contact['is_default'] == true) {
        return contact;
      }
    }
    return contacts.first;
  }

  Future<Map<String, dynamic>> saveContact({
    String? contactId,
    required String fullName,
    required String phoneNumber,
    required String relationship,
    bool isDefault = true,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('You need to log in first.');
    }

    if (isDefault) {
      await supabase
          .from('emergency_contacts')
          .update({'is_default': false})
          .eq('user_id', user.id)
          .eq('is_default', true);
    }

    final payload = <String, dynamic>{
      'user_id': user.id,
      'full_name': fullName.trim(),
      'phone_number': phoneNumber.trim(),
      'relationship': relationship.trim(),
      'is_default': isDefault,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (contactId != null && contactId.trim().isNotEmpty) {
      final response = await supabase
          .from('emergency_contacts')
          .update(payload)
          .eq('id', contactId)
          .eq('user_id', user.id)
          .select()
          .single();
      debugPrint('Emergency contact updated for ${user.id}');
      return Map<String, dynamic>.from(response);
    }

    payload['created_at'] = DateTime.now().toIso8601String();
    final response = await supabase
        .from('emergency_contacts')
        .insert(payload)
        .select()
        .single();
    debugPrint('Emergency contact created for ${user.id}');
    return Map<String, dynamic>.from(response);
  }

  Future<void> deleteContact(String contactId) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('You need to log in first.');
    }

    await supabase
        .from('emergency_contacts')
        .delete()
        .eq('id', contactId)
        .eq('user_id', user.id);
  }
}
