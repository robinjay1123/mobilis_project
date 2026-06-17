import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'message_filter_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();

  factory ChatService() {
    return _instance;
  }

  ChatService._internal();

  final supabase = Supabase.instance.client;

  // Get all conversations for a user
  // Uses conversation_participants table for many-to-many relationship
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    try {
      debugPrint('Fetching conversations for user: $userId');

      // Get conversation IDs where user is a participant
      final participations = await supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', userId);

      if (participations.isEmpty) {
        return [];
      }

      final conversationIds = participations
          .map((p) => p['conversation_id'] as String)
          .toList();

      // Get conversations with latest message
      final response = await supabase
          .from('conversations')
          .select('''
            *,
            messages(*),
            bookings!conversations_booking_id_fkey (
              id,
              status,
              vehicles!bookings_vehicle_id_fkey (
                brand,
                model,
                vehicle_name
              )
            )
          ''')
          .inFilter('id', conversationIds)
          .order('updated_at', ascending: false);

      debugPrint('Fetched ${response.length} conversations');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching conversations: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching conversations: $e');
      rethrow;
    }
  }

  // Get or create a conversation between two users
  // Uses conversation_participants for normalized relationship
  Future<Map<String, dynamic>> getOrCreateConversation(
    String userId1,
    String userId2,
  ) async {
    try {
      debugPrint('Getting/creating conversation between $userId1 and $userId2');

      // Find conversations where both users are participants
      final user1Convs = await supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', userId1);

      final user2Convs = await supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', userId2);

      // Find intersection (conversation both users are in)
      final user1ConvIds = user1Convs
          .map((p) => p['conversation_id'] as String)
          .toSet();
      final user2ConvIds = user2Convs
          .map((p) => p['conversation_id'] as String)
          .toSet();
      final commonConvIds = user1ConvIds.intersection(user2ConvIds);

      if (commonConvIds.isNotEmpty) {
        // Return existing conversation
        final existing = await supabase
            .from('conversations')
            .select()
            .eq('id', commonConvIds.first)
            .single();
        debugPrint('Found existing conversation');
        return existing;
      }

      // Create new conversation
      final newConv = await supabase
          .from('conversations')
          .insert({
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      // Add both users as participants
      await supabase.from('conversation_participants').insert([
        {
          'conversation_id': newConv['id'],
          'user_id': userId1,
          'joined_at': DateTime.now().toIso8601String(),
        },
        {
          'conversation_id': newConv['id'],
          'user_id': userId2,
          'joined_at': DateTime.now().toIso8601String(),
        },
      ]);

      debugPrint('Created new conversation with participants');
      return newConv;
    } on PostgrestException catch (e) {
      debugPrint('Database error with conversation: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error with conversation: $e');
      rethrow;
    }
  }

  // Get messages for a conversation
  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    try {
      debugPrint('Fetching messages for conversation: $conversationId');

      final response = await supabase
          .from('messages')
          .select('*, sender:users!messages_sender_id_fkey(*)')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      debugPrint('Fetched ${response.length} messages');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching messages: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching messages: $e');
      rethrow;
    }
  }

  // Send a message
  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
  }) async {
    try {
      debugPrint('Sending message to conversation: $conversationId');

      final conversation = await supabase
          .from('conversations')
          .select('status')
          .eq('id', conversationId)
          .maybeSingle();

      if ((conversation?['status']?.toString().toLowerCase() ?? 'active') ==
          'closed') {
        throw Exception('This booking conversation is closed');
      }

      final response = await supabase
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': senderId,
            'message': content,
            'content': content,
            'created_at': DateTime.now().toIso8601String(),
            'is_read': false,
          })
          .select()
          .single();

      // Update conversation's updated_at
      await supabase
          .from('conversations')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', conversationId);

      // Auto-flag message if it contains filter words (async, don't await)
      final messageId = response['id'] as String?;
      if (messageId != null) {
        unawaited(
          MessageFilterService.autoFlagMessageIfNeeded(
            messageId: messageId,
            conversationId: conversationId,
            senderId: senderId,
            messageContent: content,
          ),
        );
      }

      debugPrint('Message sent successfully');
      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error sending message: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error sending message: $e');
      rethrow;
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(
    String conversationId,
    String readerId,
  ) async {
    try {
      debugPrint('Marking messages as read in: $conversationId');

      await supabase
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .neq('sender_id', readerId);

      debugPrint('Messages marked as read');
    } on PostgrestException catch (e) {
      debugPrint('Database error marking messages read: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error marking messages read: $e');
      rethrow;
    }
  }

  // Get unread message count for a user
  Future<int> getUnreadCount(String userId) async {
    try {
      debugPrint('Getting unread count for user: $userId');

      // Get user's conversations
      final conversations = await getConversations(userId);

      int totalUnread = 0;
      for (final conv in conversations) {
        final messages = conv['messages'] as List<dynamic>? ?? [];
        for (final msg in messages) {
          if (msg['sender_id'] != userId && msg['is_read'] == false) {
            totalUnread++;
          }
        }
      }

      debugPrint('Unread count: $totalUnread');
      return totalUnread;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  // Subscribe to messages in real-time (optional)
  Stream<List<Map<String, dynamic>>> subscribeToMessages(
    String conversationId,
  ) {
    debugPrint('Subscribing to messages for: $conversationId');

    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
  }

  // Get the other user in a conversation
  // Uses conversation_participants table
  Future<String?> getOtherUserId(
    String conversationId,
    String currentUserId,
  ) async {
    try {
      final participants = await supabase
          .from('conversation_participants')
          .select('user_id')
          .eq('conversation_id', conversationId)
          .neq('user_id', currentUserId)
          .limit(1);

      if (participants.isNotEmpty) {
        return participants.first['user_id'] as String;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting other user: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getOtherUser(
    String conversationId,
    String currentUserId,
  ) async {
    try {
      final participants = await supabase
          .from('conversation_participants')
          .select(
            'user_id, users:users!conversation_participants_new_user_id_fkey(*)',
          )
          .eq('conversation_id', conversationId)
          .neq('user_id', currentUserId)
          .limit(1);

      if (participants.isEmpty) return null;

      final participant = Map<String, dynamic>.from(participants.first);
      final user = participant['users'];
      if (user is Map<String, dynamic>) {
        return Map<String, dynamic>.from(user);
      }

      final userId = participant['user_id']?.toString();
      if (userId == null || userId.isEmpty) return null;

      return await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('Error getting other user profile: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getConversationParticipants(
    String conversationId,
  ) async {
    try {
      final participants = await supabase
          .from('conversation_participants')
          .select(
            'user_id, joined_at, users:users!conversation_participants_new_user_id_fkey(*)',
          )
          .eq('conversation_id', conversationId);

      final rows = List<Map<String, dynamic>>.from(participants);
      final hydrated = <Map<String, dynamic>>[];
      final missingUserIds = <String>[];

      for (final row in rows) {
        final user = row['users'];
        if (user is Map<String, dynamic>) {
          hydrated.add(_participantProfile(row, user));
        } else {
          final userId = row['user_id']?.toString();
          if (userId != null && userId.isNotEmpty) {
            missingUserIds.add(userId);
          }
        }
      }

      if (missingUserIds.isNotEmpty) {
        final users = await supabase
            .from('users')
            .select()
            .inFilter('id', missingUserIds);
        final userById = {
          for (final user in List<Map<String, dynamic>>.from(users))
            user['id']?.toString(): user,
        };

        for (final row in rows) {
          final userId = row['user_id']?.toString();
          final user = userById[userId];
          if (user != null) {
            hydrated.add(_participantProfile(row, user));
          }
        }
      }

      hydrated.sort((a, b) {
        final aRole = _roleSortValue(a['role']?.toString());
        final bRole = _roleSortValue(b['role']?.toString());
        if (aRole != bRole) return aRole.compareTo(bRole);
        return _displayName(a).compareTo(_displayName(b));
      });

      return hydrated;
    } on PostgrestException catch (e) {
      debugPrint(
        'Participant embed failed, retrying without relationship: ${e.message}',
      );
      return _getConversationParticipantsFallback(conversationId);
    } catch (e) {
      debugPrint('Error getting conversation participants: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getConversationParticipantsFallback(
    String conversationId,
  ) async {
    final participantRows = await supabase
        .from('conversation_participants')
        .select('user_id, joined_at')
        .eq('conversation_id', conversationId);

    final rows = List<Map<String, dynamic>>.from(participantRows);
    final userIds = rows
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (userIds.isEmpty) return [];

    final users = await supabase.from('users').select().inFilter('id', userIds);
    final userById = {
      for (final user in List<Map<String, dynamic>>.from(users))
        user['id']?.toString(): user,
    };

    final hydrated = rows
        .map((row) {
          final user = userById[row['user_id']?.toString()];
          if (user == null) return null;
          return _participantProfile(row, user);
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    hydrated.sort((a, b) {
      final aRole = _roleSortValue(a['role']?.toString());
      final bRole = _roleSortValue(b['role']?.toString());
      if (aRole != bRole) return aRole.compareTo(bRole);
      return _displayName(a).compareTo(_displayName(b));
    });

    return hydrated;
  }

  Map<String, dynamic> _participantProfile(
    Map<String, dynamic> participant,
    Map<String, dynamic> user,
  ) {
    final profile = Map<String, dynamic>.from(user);
    profile['user_id'] = participant['user_id'];
    profile['joined_at'] = participant['joined_at'];
    profile['display_name'] = _displayName(profile);
    profile['display_role'] = _displayRole(profile['role']?.toString());
    profile['display_phone'] =
        profile['phone']?.toString() ??
        profile['phone_number']?.toString() ??
        '';
    profile['display_avatar'] =
        profile['avatar_url']?.toString() ??
        profile['profile_picture_url']?.toString() ??
        profile['photo_url']?.toString() ??
        '';
    return profile;
  }

  String _displayName(Map<String, dynamic> user) {
    final name = user['full_name']?.toString().trim().isNotEmpty == true
        ? user['full_name'].toString().trim()
        : user['name']?.toString().trim().isNotEmpty == true
        ? user['name'].toString().trim()
        : user['email']?.toString().trim();
    return name == null || name.isEmpty ? 'Unknown User' : name;
  }

  String _displayRole(String? role) {
    final normalized = role?.trim().toLowerCase() ?? '';
    switch (normalized) {
      case 'operator':
        return 'Operator / Agent';
      case 'partner':
      case 'owner':
        return 'Partner';
      case 'driver':
        return 'Driver';
      case 'renter':
      case 'user':
        return 'Renter';
      case 'admin':
        return 'Admin';
      default:
        return normalized.isEmpty ? 'Participant' : normalized;
    }
  }

  int _roleSortValue(String? role) {
    switch (role?.trim().toLowerCase()) {
      case 'operator':
        return 0;
      case 'partner':
      case 'owner':
        return 1;
      case 'driver':
        return 2;
      case 'renter':
      case 'user':
        return 3;
      default:
        return 4;
    }
  }

  // Get error message from exception
  String getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return error.toString();
  }

  // Create a group conversation for a booking
  // Automatically creates conversation and adds participants
  Future<Map<String, dynamic>> createGroupConversation({
    required String bookingId,
    required List<String> participantIds,
  }) async {
    try {
      debugPrint(
        'Creating group conversation for booking: $bookingId with ${participantIds.length} participants',
      );

      final uniqueParticipantIds = participantIds
          .where((id) => id.trim().isNotEmpty)
          .toSet()
          .toList();

      final existing = await supabase
          .from('conversations')
          .select()
          .eq('booking_id', bookingId)
          .maybeSingle();

      final conversation =
          existing ??
          await supabase
              .from('conversations')
              .insert({
                'booking_id': bookingId,
                'status': 'active',
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .select()
              .single();

      await addParticipantsToBookingConversation(
        bookingId: bookingId,
        participantIds: uniqueParticipantIds,
      );

      debugPrint('Group conversation ready');
      return conversation;
    } on PostgrestException catch (e) {
      debugPrint('Database error creating group conversation: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error creating group conversation: $e');
      rethrow;
    }
  }

  Future<void> addParticipantsToBookingConversation({
    required String bookingId,
    required List<String> participantIds,
  }) async {
    try {
      final uniqueParticipantIds = participantIds
          .where((id) => id.trim().isNotEmpty)
          .toSet()
          .toList();

      if (uniqueParticipantIds.isEmpty) return;

      final conversation = await supabase
          .from('conversations')
          .select('id')
          .eq('booking_id', bookingId)
          .maybeSingle();

      if (conversation == null) return;

      final conversationId = conversation['id'] as String;
      final existingParticipants = await supabase
          .from('conversation_participants')
          .select('user_id')
          .eq('conversation_id', conversationId);

      final existingUserIds = List<Map<String, dynamic>>.from(
        existingParticipants,
      ).map((row) => row['user_id']?.toString()).whereType<String>().toSet();

      final participantRecords = uniqueParticipantIds
          .where((userId) => !existingUserIds.contains(userId))
          .map((userId) {
            return {
              'conversation_id': conversationId,
              'user_id': userId,
              'joined_at': DateTime.now().toIso8601String(),
            };
          })
          .toList();

      if (participantRecords.isEmpty) return;

      await supabase
          .from('conversation_participants')
          .insert(participantRecords);

      await supabase
          .from('conversations')
          .update({
            'status': 'active',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', conversationId);

      debugPrint('Participants added to booking conversation');
    } on PostgrestException catch (e) {
      debugPrint('Database error adding group participants: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error adding group participants: $e');
      rethrow;
    }
  }

  // Close a conversation (typically when booking is completed/cancelled)
  Future<void> closeConversation(String bookingId) async {
    try {
      debugPrint('Closing conversation for booking: $bookingId');

      await supabase
          .from('conversations')
          .update({
            'status': 'closed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('booking_id', bookingId);

      debugPrint('Conversation closed successfully');
    } on PostgrestException catch (e) {
      debugPrint('Database error closing conversation: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error closing conversation: $e');
      rethrow;
    }
  }
}
