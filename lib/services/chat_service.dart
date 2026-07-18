import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'notification_service.dart';
import 'user_restriction_service.dart';
import 'image_optimization_service.dart';

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

      final conversationIds = await _conversationIdsForUser(userId);
      if (conversationIds.isEmpty) return [];

      // Get conversations with latest message
      final response = await supabase
          .from('conversations')
          .select('''
            *,
            messages!messages_conversation_id_fkey(*),
            bookings!conversations_booking_id_fkey (
              id,
              status,
              vehicles!bookings_vehicle_id_fkey (
                id,
                brand,
                model,
                vehicle_name,
                image_url,
                vehicle_images(image_url, display_order)
              )
            )
          ''')
          .inFilter('id', conversationIds)
          .order('updated_at', ascending: false);

      debugPrint('Fetched ${response.length} conversations');
      return _normalizeConversationRows(
        List<Map<String, dynamic>>.from(response),
      );
    } on PostgrestException catch (e) {
      debugPrint(
        'Conversation embed failed; loading related rows separately: ${e.message}',
      );
      return _getConversationsWithoutEmbed(userId);
    } catch (e) {
      debugPrint('Unexpected error fetching conversations: $e');
      rethrow;
    }
  }

  Future<List<String>> _conversationIdsForUser(String userId) async {
    final conversationIds = <String>{};

    try {
      final participantRows = await supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', userId);
      for (final row in List<Map<String, dynamic>>.from(participantRows)) {
        final id = row['conversation_id']?.toString().trim() ?? '';
        if (id.isNotEmpty) conversationIds.add(id);
      }
    } on PostgrestException catch (error) {
      debugPrint(
        'Normalized participant conversation lookup skipped: ${error.message}',
      );
    }

    // Older direct/support conversations retain these columns even when their
    // normalized participant row was not created.
    try {
      final directRows = await supabase
          .from('conversations')
          .select('id')
          .or('user_id.eq.$userId,other_user_id.eq.$userId');
      for (final row in List<Map<String, dynamic>>.from(directRows)) {
        final id = row['id']?.toString().trim() ?? '';
        if (id.isNotEmpty) conversationIds.add(id);
      }
    } on PostgrestException catch (error) {
      debugPrint('Legacy direct conversation lookup skipped: ${error.message}');
    }

    // Older booking chats can be missing their normalized participant rows.
    // Resolve them through every booking relationship used by the app so the
    // Messages tab and direct booking chat always discover the same threads.
    try {
      final bookingIds = await _bookingIdsForConversationUser(userId);
      if (bookingIds.isNotEmpty) {
        final bookingConversationRows = await supabase
            .from('conversations')
            .select('id')
            .inFilter('booking_id', bookingIds);
        for (final row in List<Map<String, dynamic>>.from(
          bookingConversationRows,
        )) {
          final id = row['id']?.toString().trim() ?? '';
          if (id.isNotEmpty) conversationIds.add(id);
        }
      }
    } on PostgrestException catch (error) {
      debugPrint(
        'Related booking conversation lookup skipped: ${error.message}',
      );
    }

    debugPrint('Resolved ${conversationIds.length} conversations for $userId');
    return conversationIds.toList();
  }

  Future<List<String>> _bookingIdsForConversationUser(String userId) async {
    final bookingIds = <String>{};

    final directBookingRows = await supabase
        .from('bookings')
        .select('id')
        .or('renter_id.eq.$userId,driver_id.eq.$userId,operator_id.eq.$userId');
    for (final row in List<Map<String, dynamic>>.from(directBookingRows)) {
      final id = row['id']?.toString().trim() ?? '';
      if (id.isNotEmpty) bookingIds.add(id);
    }

    // Partner chats are linked through vehicles.owner_id. Some PSDC records
    // also carry vehicles.operator_id instead of bookings.operator_id.
    final vehicleRows = await supabase
        .from('vehicles')
        .select('id')
        .or('owner_id.eq.$userId,operator_id.eq.$userId');
    final vehicleIds = List<Map<String, dynamic>>.from(vehicleRows)
        .map((row) => row['id']?.toString().trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (vehicleIds.isNotEmpty) {
      final vehicleBookingRows = await supabase
          .from('bookings')
          .select('id')
          .inFilter('vehicle_id', vehicleIds);
      for (final row in List<Map<String, dynamic>>.from(vehicleBookingRows)) {
        final id = row['id']?.toString().trim() ?? '';
        if (id.isNotEmpty) bookingIds.add(id);
      }
    }

    return bookingIds.toList();
  }

  Future<List<Map<String, dynamic>>> _getConversationsWithoutEmbed(
    String userId,
  ) async {
    final conversationIds = await _conversationIdsForUser(userId);
    if (conversationIds.isEmpty) return [];

    final conversationRows = await supabase
        .from('conversations')
        .select()
        .inFilter('id', conversationIds)
        .order('updated_at', ascending: false);
    final conversations = List<Map<String, dynamic>>.from(conversationRows);

    final bookingIds = conversations
        .map((conversation) => conversation['booking_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final bookingsById = <String, Map<String, dynamic>>{};
    if (bookingIds.isNotEmpty) {
      final bookingRows = await supabase
          .from('bookings')
          .select('''
            id,
            status,
            vehicles!bookings_vehicle_id_fkey (
              id,
              brand,
              model,
              vehicle_name,
              image_url,
              vehicle_images(image_url, display_order)
            )
          ''')
          .inFilter('id', bookingIds);
      for (final booking in List<Map<String, dynamic>>.from(bookingRows)) {
        final id = booking['id']?.toString();
        if (id != null && id.isNotEmpty) bookingsById[id] = booking;
      }
    }

    final messageRows = await supabase
        .from('messages')
        .select()
        .inFilter('conversation_id', conversationIds)
        .order('created_at', ascending: true);
    final messagesByConversation = <String, List<Map<String, dynamic>>>{};
    for (final message in List<Map<String, dynamic>>.from(messageRows)) {
      final conversationId = message['conversation_id']?.toString();
      if (conversationId == null || conversationId.isEmpty) continue;
      messagesByConversation.putIfAbsent(conversationId, () => []).add(message);
    }

    for (final conversation in conversations) {
      final id = conversation['id']?.toString();
      conversation['messages'] = messagesByConversation[id] ?? const [];
      final bookingId = conversation['booking_id']?.toString();
      if (bookingId != null && bookingsById.containsKey(bookingId)) {
        conversation['bookings'] = bookingsById[bookingId];
      }
    }
    return _normalizeConversationRows(conversations);
  }

  List<Map<String, dynamic>> _normalizeConversationRows(
    List<Map<String, dynamic>> conversations,
  ) {
    for (final conversation in conversations) {
      final rawMessages = conversation['messages'];
      if (rawMessages is! List) {
        conversation['messages'] = <Map<String, dynamic>>[];
        conversation['vehicle_image_url'] = _conversationVehicleImageUrl(
          conversation,
        );
        continue;
      }
      final messages = rawMessages
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList();
      messages.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
        return (aDate ?? DateTime(1970)).compareTo(bDate ?? DateTime(1970));
      });
      conversation['messages'] = messages;
      conversation['vehicle_image_url'] = _conversationVehicleImageUrl(
        conversation,
      );
    }
    return conversations.where(_isVisibleConversation).toList();
  }

  bool _isVisibleConversation(Map<String, dynamic> conversation) {
    final booking = conversation['bookings'];
    if (booking is! Map) return true;

    final conversationStatus =
        conversation['status']?.toString().trim().toLowerCase() ?? 'active';
    if (conversationStatus == 'closed' || conversationStatus == 'archived') {
      return false;
    }

    final bookingStatus =
        booking['status']?.toString().trim().toLowerCase() ?? '';
    const visibleBookingStatuses = {
      'approved',
      'confirmed',
      'active',
      'ongoing',
    };
    return visibleBookingStatuses.contains(bookingStatus);
  }

  String _conversationVehicleImageUrl(Map<String, dynamic> conversation) {
    final booking = conversation['bookings'];
    if (booking is! Map) return '';
    final vehicle = booking['vehicles'];
    if (vehicle is! Map) return '';

    final direct = _normalizeVehicleImageUrl(vehicle['image_url']);
    if (direct.isNotEmpty) return direct;

    final images =
        List<Map<String, dynamic>>.from(
          vehicle['vehicle_images'] as List? ?? const [],
        )..sort((a, b) {
          final aOrder = (a['display_order'] as num?)?.toInt() ?? 999;
          final bOrder = (b['display_order'] as num?)?.toInt() ?? 999;
          return aOrder.compareTo(bOrder);
        });
    for (final image in images) {
      final url = _normalizeVehicleImageUrl(image['image_url']);
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  String _normalizeVehicleImageUrl(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final path = raw.startsWith('/') ? raw.substring(1) : raw;
    return path.isEmpty
        ? ''
        : supabase.storage.from('vehicle_images').getPublicUrl(path);
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
        final candidates = await supabase
            .from('conversations')
            .select()
            .inFilter('id', commonConvIds.toList())
            .isFilter('booking_id', null)
            .eq('is_group', false)
            .order('updated_at', ascending: false);
        for (final candidate in List<Map<String, dynamic>>.from(candidates)) {
          final participantRows = await supabase
              .from('conversation_participants')
              .select('user_id')
              .eq('conversation_id', candidate['id']);
          if (participantRows.length == 2) {
            debugPrint('Found existing direct conversation');
            return candidate;
          }
        }
      }

      // Create new conversation
      final newConv = await supabase
          .from('conversations')
          .insert({
            'is_group': false,
            'user_id': userId1,
            'other_user_id': userId2,
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();

      // Add both users as participants
      await supabase.from('conversation_participants').upsert([
        {
          'conversation_id': newConv['id'],
          'user_id': userId1,
          'joined_at': DateTime.now().toUtc().toIso8601String(),
        },
        {
          'conversation_id': newConv['id'],
          'user_id': userId2,
          'joined_at': DateTime.now().toUtc().toIso8601String(),
        },
      ], onConflict: 'conversation_id,user_id');

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

  Future<String> getPrimaryAdminUserId() async {
    Map<String, dynamic>? response;
    for (final role in ['customer_service', 'support', 'admin']) {
      response = await supabase
          .from('users')
          .select('id')
          .eq('role', role)
          .limit(1)
          .maybeSingle();
      if (response != null) break;
    }

    final adminId = response?['id']?.toString().trim() ?? '';
    if (adminId.isEmpty) {
      throw Exception(
        'No support or admin account is available for customer service',
      );
    }
    return adminId;
  }

  Future<Map<String, dynamic>> getOrCreateCustomerServiceConversation({
    required String userId,
    String? userName,
    String? userRole,
  }) async {
    final adminId = await getPrimaryAdminUserId();

    final existing = await getOrCreateConversation(userId, adminId);
    final conversationId = existing['id']?.toString().trim() ?? '';
    if (conversationId.isEmpty) {
      throw Exception('Could not open customer service conversation');
    }

    final existingMessages = await supabase
        .from('messages')
        .select('id')
        .eq('conversation_id', conversationId)
        .limit(1);

    if (existingMessages.isEmpty) {
      await NotificationService().createNotification(
        userId: adminId,
        title: 'Customer Service Request',
        message:
            '${userName?.trim().isNotEmpty == true ? userName!.trim() : 'A user'} opened a customer service conversation.',
        type: 'customer_service',
        data: {
          'conversation_id': conversationId,
          'requester_id': userId,
          if (userRole != null && userRole.trim().isNotEmpty)
            'requester_role': userRole.trim(),
        },
      );
    }

    return existing;
  }

  Future<Map<String, dynamic>?> getConversationByBookingId(
    String bookingId,
  ) async {
    try {
      if (bookingId.trim().isEmpty) return null;

      final response = await supabase
          .from('conversations')
          .select()
          .eq('booking_id', bookingId)
          .maybeSingle();

      if (response == null) return null;
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching booking conversation: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching booking conversation: $e');
      rethrow;
    }
  }

  // Get messages for a conversation
  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    try {
      debugPrint('Fetching messages for conversation: $conversationId');

      final response = await supabase
          .from('messages')
          .select('*, sender:users!messages_new_sender_id_fkey(*)')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      debugPrint('Fetched ${response.length} messages');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint(
        'Message sender relationship failed; loading profiles separately: ${e.message}',
      );
      return _getMessagesWithoutEmbed(conversationId);
    } catch (e) {
      debugPrint('Unexpected error fetching messages: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _getMessagesWithoutEmbed(
    String conversationId,
  ) async {
    final response = await supabase
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
    final messages = List<Map<String, dynamic>>.from(response);
    final senderIds = messages
        .map((message) => message['sender_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (senderIds.isEmpty) return messages;

    final users = await supabase
        .from('users')
        .select()
        .inFilter('id', senderIds);
    final usersById = {
      for (final user in List<Map<String, dynamic>>.from(users))
        user['id']?.toString(): user,
    };
    return messages
        .map(
          (message) => {
            ...message,
            'sender': usersById[message['sender_id']?.toString()],
          },
        )
        .toList();
  }

  // Send a message
  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentName,
    int? attachmentSize,
  }) async {
    try {
      debugPrint('Sending message to conversation: $conversationId');

      final restriction = await UserRestrictionService().getUserRestriction(
        senderId,
      );
      if (restriction.isBlocked || restriction.isAccountRestricted) {
        throw Exception(
          'This account is temporarily restricted from messaging',
        );
      }

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
            if (attachmentUrl != null) 'attachment_url': attachmentUrl,
            if (attachmentType != null) 'attachment_type': attachmentType,
            if (attachmentName != null) 'attachment_name': attachmentName,
            if (attachmentSize != null) 'attachment_size': attachmentSize,
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'is_read': false,
          })
          .select()
          .single();

      // Update conversation's updated_at
      await supabase
          .from('conversations')
          .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', conversationId);

      await _notifyMessageRecipients(
        conversationId: conversationId,
        senderId: senderId,
        content: content,
      );

      // Flagging and enforcement are handled by the chat screen flow.

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

  Future<Map<String, dynamic>> softDeleteMessage({
    required String messageId,
    required String userId,
  }) async {
    final message = await supabase
        .from('messages')
        .select('id, sender_id, is_auto_generated, content, message')
        .eq('id', messageId)
        .maybeSingle();
    if (message == null) throw Exception('Message no longer exists');
    if (message['sender_id']?.toString() != userId) {
      throw Exception('You can only delete your own messages');
    }
    if (message['is_auto_generated'] == true) {
      throw Exception('System messages cannot be deleted');
    }
    if ((message['content'] ?? message['message'])?.toString() ==
        'Message deleted') {
      return Map<String, dynamic>.from(message);
    }

    final commonUpdates = <String, dynamic>{
      'message': 'Message deleted',
      'content': 'Message deleted',
      'attachment_url': null,
      'attachment_type': null,
      'attachment_name': null,
      'attachment_size': null,
    };
    try {
      final response = await supabase
          .from('messages')
          .update({
            ...commonUpdates,
            'is_deleted': true,
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'deleted_by': userId,
          })
          .eq('id', messageId)
          .eq('sender_id', userId)
          .select()
          .single();
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (error) {
      final missingDeleteColumns =
          error.code == 'PGRST204' ||
          error.code == '42703' ||
          error.message.contains('is_deleted');
      if (!missingDeleteColumns) rethrow;
      final response = await supabase
          .from('messages')
          .update(commonUpdates)
          .eq('id', messageId)
          .eq('sender_id', userId)
          .select()
          .single();
      return Map<String, dynamic>.from(response);
    }
  }

  String typingChannelName(String conversationId) =>
      'chat-typing-${conversationId.trim()}';

  Future<void> _notifyMessageRecipients({
    required String conversationId,
    required String senderId,
    required String content,
  }) async {
    try {
      final participantRows = await supabase
          .from('conversation_participants')
          .select('user_id')
          .eq('conversation_id', conversationId)
          .neq('user_id', senderId);
      final preview = content.trim().isEmpty
          ? 'You received a new attachment.'
          : content.trim().length > 120
          ? '${content.trim().substring(0, 117)}...'
          : content.trim();
      for (final participant in participantRows) {
        final recipientId = participant['user_id']?.toString();
        if (recipientId == null || recipientId.isEmpty) continue;
        await NotificationService().createNotification(
          userId: recipientId,
          title: 'New Message',
          message: preview,
          type: 'message',
          data: {'conversation_id': conversationId, 'sender_id': senderId},
        );
      }
    } catch (e) {
      // A delivered chat message must not be reported as failed only because
      // its secondary notification could not be queued.
      debugPrint('Message notification skipped: $e');
    }
  }

  Future<String> uploadChatAttachment({
    required String senderId,
    required File file,
    required String fileName,
  }) async {
    final safeFileName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final objectPath =
        '$senderId/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

    final originalBytes = await file.readAsBytes();
    final bytes = await ImageOptimizationService.optimizeForUpload(
      originalBytes,
      fileName: safeFileName,
    );
    await supabase.storage
        .from('chat_attachments')
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            cacheControl: '31536000',
          ),
        );

    return supabase.storage.from('chat_attachments').getPublicUrl(objectPath);
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

      final existing = await _firstBookingConversation(bookingId);

      final conversation =
          existing ??
          await supabase
              .from('conversations')
              .insert({
                'booking_id': bookingId,
                'status': 'active',
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
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

      final conversation = await _firstBookingConversation(bookingId);

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
              'joined_at': DateTime.now().toUtc().toIso8601String(),
            };
          })
          .toList();

      if (participantRecords.isNotEmpty) {
        await supabase
            .from('conversation_participants')
            .upsert(participantRecords, onConflict: 'conversation_id,user_id');
      }

      // Reactivate the same booking GC even when all participants already
      // exist. Previously the early return left repaired chats closed.
      await supabase
          .from('conversations')
          .update({
            'status': 'active',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
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

  Future<Map<String, dynamic>?> _firstBookingConversation(
    String bookingId,
  ) async {
    final rows = await supabase
        .from('conversations')
        .select()
        .eq('booking_id', bookingId)
        .order('created_at', ascending: true)
        .limit(1);
    final conversations = List<Map<String, dynamic>>.from(rows);
    return conversations.isEmpty ? null : conversations.first;
  }

  // Close a conversation (typically when booking is completed/cancelled)
  Future<void> closeConversation(String bookingId) async {
    try {
      debugPrint('Closing conversation for booking: $bookingId');

      await supabase
          .from('conversations')
          .update({
            'status': 'closed',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
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
