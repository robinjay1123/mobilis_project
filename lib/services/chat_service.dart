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
          .select('*, messages(*)')
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
          .select('*, users(*)')
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

      final response = await supabase
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': senderId,
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

  // Get error message from exception
  String getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return error.toString();
  }
}
