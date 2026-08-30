import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'notification_service.dart';
import 'user_restriction_service.dart';
import 'image_optimization_service.dart';
import 'booking_service.dart';
import '../utils/booking_status.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();

  factory ChatService() {
    return _instance;
  }

  ChatService._internal();

  final supabase = Supabase.instance.client;

  /// Loads the booking state separately from the conversation query to avoid
  /// PostgREST relationship ambiguity in projects with legacy foreign keys.
  Future<Map<String, dynamic>?> getConversationBookingContext(
    String conversationId,
  ) async {
    try {
      final conversation = await supabase
          .from('conversations')
          .select('booking_id')
          .eq('id', conversationId)
          .maybeSingle();
      final bookingId = conversation?['booking_id']?.toString().trim() ?? '';
      if (bookingId.isEmpty) return null;

      Map<String, dynamic>? bookingMap;

      try {
        final booking = await supabase
            .from('bookings')
            .select(
              'id, status, start_at, end_at, start_date, end_date, vehicle_id, '
              'vehicles!bookings_vehicle_id_fkey(id, brand, model, vehicle_name, plate_number, image_url, vehicle_images(image_url, display_order))',
            )
            .eq('id', bookingId)
            .maybeSingle();
        if (booking != null) {
          bookingMap = Map<String, dynamic>.from(booking);
        }
      } catch (_) {}

      if (bookingMap == null) {
        // Fallback without embed
        final booking = await supabase
            .from('bookings')
            .select()
            .eq('id', bookingId)
            .maybeSingle();
        if (booking == null) return null;
        bookingMap = Map<String, dynamic>.from(booking);
        final vehicleId = bookingMap['vehicle_id']?.toString().trim() ?? '';
        if (vehicleId.isNotEmpty) {
          try {
            final vehicle = await supabase
                .from('vehicles')
                .select(
                  'id, brand, model, vehicle_name, plate_number, image_url, vehicle_images(image_url, display_order)',
                )
                .eq('id', vehicleId)
                .maybeSingle();
            if (vehicle != null) {
              bookingMap['vehicles'] = Map<String, dynamic>.from(vehicle);
            } else {
              final pv = await supabase
                  .from('partner_vehicles')
                  .select(
                    'id, brand, model, vehicle_name, plate_number, image_url',
                  )
                  .eq('id', vehicleId)
                  .maybeSingle();
              if (pv != null) {
                bookingMap['vehicles'] = Map<String, dynamic>.from(pv);
              }
            }
          } catch (_) {}
        }
      }

      final vehicle = bookingMap['vehicles'] as Map<String, dynamic>?;
      if (vehicle != null) {
        final imgUrl = _normalizeVehicleImageUrl(vehicle['image_url']);
        if (imgUrl.isNotEmpty) {
          bookingMap['vehicle_image_url'] = imgUrl;
        } else {
          final images =
              List<Map<String, dynamic>>.from(
                vehicle['vehicle_images'] as List? ?? const [],
              )..sort((a, b) {
                final aOrder = (a['display_order'] as num?)?.toInt() ?? 999;
                final bOrder = (b['display_order'] as num?)?.toInt() ?? 999;
                return aOrder.compareTo(bOrder);
              });
          if (images.isNotEmpty) {
            bookingMap['vehicle_image_url'] = _normalizeVehicleImageUrl(
              images.first['image_url'],
            );
          }
        }
      }

      return bookingMap;
    } catch (error) {
      debugPrint('Could not load conversation booking context: $error');
      return null;
    }
  }

  // Get all conversations for a user
  // Uses conversation_participants table for many-to-many relationship
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    try {
      debugPrint('Fetching conversations for user: $userId');

      try {
        await BookingService().syncUpcomingBookingConversations(userId: userId);
      } catch (e) {
        debugPrint('Could not sync upcoming conversations: $e');
      }

      final conversationIds = await _conversationIdsForUser(userId);
      if (conversationIds.isEmpty) return [];

      // Get conversations with latest messages
      try {
        final response = await supabase
            .from('conversations')
            .select('''
              *,
              messages!messages_conversation_id_fkey(
                id,
                content,
                message,
                sender_id,
                created_at,
                is_read,
                is_auto_generated,
                attachment_url,
                attachment_type,
                attachment_name
              ),
              bookings!conversations_booking_id_fkey (
                id,
                status,
                renter_id,
                renter:users!bookings_renter_id_fkey (
                  id,
                  full_name,
                  email,
                  phone,
                  avatar_url
                ),
                vehicles!bookings_vehicle_id_fkey (
                  id,
                  brand,
                  model,
                  vehicle_name,
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
      } catch (e) {
        debugPrint(
          'Conversation embed failed; loading related rows separately: $e',
        );
        return await _getConversationsWithoutEmbed(userId);
      }
    } catch (e) {
      debugPrint('Unexpected error fetching conversations: $e');
      try {
        return await _getConversationsWithoutEmbed(userId);
      } catch (fallbackErr) {
        debugPrint('Conversations fallback also failed: $fallbackErr');
        return [];
      }
    }
  }

  Future<List<String>> _conversationIdsForUser(String userId) async {
    final conversationIds = <String>{};

    // Check if user is an Operator/Admin/Staff who manages platform operations
    bool isOperatorOrAdmin = false;
    try {
      final currentAuthUser = supabase.auth.currentUser;
      final metaRole =
          (currentAuthUser?.userMetadata?['role'] ??
                  currentAuthUser?.appMetadata['role'])
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';
      final userRow = await supabase
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      final role = (userRow?['role']?.toString().trim().toLowerCase() ?? '')
          .isNotEmpty
          ? userRow!['role'].toString().trim().toLowerCase()
          : metaRole;
      isOperatorOrAdmin =
          role == 'operator' ||
          role == 'admin' ||
          role == 'superadmin' ||
          role == 'staff' ||
          role == 'operations';
    } catch (_) {}

    // If operator/admin, fetch all active conversations in the system directly
    if (isOperatorOrAdmin) {
      try {
        final allConversations = await supabase
            .from('conversations')
            .select('id')
            .order('updated_at', ascending: false)
            .limit(300);
        for (final row in List<Map<String, dynamic>>.from(allConversations)) {
          final id = row['id']?.toString().trim() ?? '';
          if (id.isNotEmpty) conversationIds.add(id);
        }
      } catch (e) {
        debugPrint('Operator all-conversation lookup note: $e');
      }
    }

    try {
      final participantRows = await supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', userId);
      for (final row in List<Map<String, dynamic>>.from(participantRows)) {
        final id = row['conversation_id']?.toString().trim() ?? '';
        if (id.isNotEmpty) conversationIds.add(id);
      }
    } catch (error) {
      debugPrint('Participant conversation lookup note: $error');
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
    } catch (error) {
      debugPrint('Legacy direct conversation lookup note: $error');
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
    } catch (error) {
      debugPrint('Related booking conversation lookup note: $error');
    }

    debugPrint('Resolved ${conversationIds.length} conversations for $userId');
    return conversationIds.toList();
  }

  Future<List<String>> _bookingIdsForConversationUser(String userId) async {
    final bookingIds = <String>{};

    try {
      final renterBookings = await supabase
          .from('bookings')
          .select('id')
          .eq('renter_id', userId);
      for (final row in List<Map<String, dynamic>>.from(renterBookings)) {
        final id = row['id']?.toString().trim() ?? '';
        if (id.isNotEmpty) bookingIds.add(id);
      }
    } catch (_) {}

    try {
      final driverBookings = await supabase
          .from('bookings')
          .select('id')
          .eq('driver_id', userId);
      for (final row in List<Map<String, dynamic>>.from(driverBookings)) {
        final id = row['id']?.toString().trim() ?? '';
        if (id.isNotEmpty) bookingIds.add(id);
      }
    } catch (_) {}

    try {
      final operatorBookings = await supabase
          .from('bookings')
          .select('id')
          .eq('operator_id', userId);
      for (final row in List<Map<String, dynamic>>.from(operatorBookings)) {
        final id = row['id']?.toString().trim() ?? '';
        if (id.isNotEmpty) bookingIds.add(id);
      }
    } catch (_) {}

    try {
      final ownedVehicles = await supabase
          .from('vehicles')
          .select('id')
          .or('owner_id.eq.$userId,operator_id.eq.$userId');
      final vehicleIds = ownedVehicles
          .map((row) => row['id']?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      if (vehicleIds.isNotEmpty) {
        final partnerBookings = await supabase
            .from('bookings')
            .select('id')
            .inFilter('vehicle_id', vehicleIds);
        for (final row in List<Map<String, dynamic>>.from(partnerBookings)) {
          final id = row['id']?.toString().trim() ?? '';
          if (id.isNotEmpty) bookingIds.add(id);
        }
      }
    } catch (_) {}

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
        .map((conversation) => conversation['booking_id']?.toString().trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final bookingsById = <String, Map<String, dynamic>>{};
    if (bookingIds.isNotEmpty) {
      try {
        final bookingRows = await supabase
            .from('bookings')
            .select()
            .inFilter('id', bookingIds);

        final bookingsList = List<Map<String, dynamic>>.from(bookingRows);
        final renterIds = bookingsList
            .map((b) => b['renter_id']?.toString().trim())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
        final vehicleIds = bookingsList
            .map((b) => b['vehicle_id']?.toString().trim())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();

        final usersById = <String, Map<String, dynamic>>{};
        if (renterIds.isNotEmpty) {
          try {
            final userRows = await supabase
                .from('users')
                .select('id, full_name, email, phone, avatar_url')
                .inFilter('id', renterIds);
            for (final u in List<Map<String, dynamic>>.from(userRows)) {
              final uid = u['id']?.toString() ?? '';
              if (uid.isNotEmpty) usersById[uid] = u;
            }
          } catch (uErr) {
            debugPrint('Renter lookup note: $uErr');
          }
        }

        final vehiclesById = <String, Map<String, dynamic>>{};
        if (vehicleIds.isNotEmpty) {
          try {
            final vehicleRows = await supabase
                .from('vehicles')
                .select(
                  'id, brand, model, vehicle_name, image_url, vehicle_images(image_url, display_order)',
                )
                .inFilter('id', vehicleIds);
            for (final v in List<Map<String, dynamic>>.from(vehicleRows)) {
              final vid = v['id']?.toString() ?? '';
              if (vid.isNotEmpty) vehiclesById[vid] = v;
            }
          } catch (_) {
            try {
              final vehicleRows = await supabase
                  .from('vehicles')
                  .select('id, brand, model, vehicle_name, image_url')
                  .inFilter('id', vehicleIds);
              for (final v in List<Map<String, dynamic>>.from(vehicleRows)) {
                final vid = v['id']?.toString() ?? '';
                if (vid.isNotEmpty) vehiclesById[vid] = v;
              }
            } catch (vErr) {
              debugPrint('Vehicle lookup note: $vErr');
            }
          }

          final missingVehicleIds = vehicleIds
              .where((id) => !vehiclesById.containsKey(id))
              .toList();
          if (missingVehicleIds.isNotEmpty) {
            try {
              final pvRows = await supabase
                  .from('partner_vehicles')
                  .select('id, brand, model, vehicle_name, image_url')
                  .inFilter('id', missingVehicleIds);
              for (final pv in List<Map<String, dynamic>>.from(pvRows)) {
                final vid = pv['id']?.toString() ?? '';
                if (vid.isNotEmpty) vehiclesById[vid] = pv;
              }
            } catch (_) {}
          }
        }

        for (final booking in bookingsList) {
          final id = booking['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          final renterId = booking['renter_id']?.toString() ?? '';
          final vehicleId = (booking['vehicle_id'] ?? booking['partner_vehicle_id'])?.toString() ?? '';
          if (renterId.isNotEmpty && usersById.containsKey(renterId)) {
            booking['renter'] = usersById[renterId];
          }
          if (vehicleId.isNotEmpty && vehiclesById.containsKey(vehicleId)) {
            booking['vehicles'] = vehiclesById[vehicleId];
          }
          bookingsById[id] = booking;
        }
      } catch (bErr) {
        debugPrint('Bookings lookup note: $bErr');
      }
    }

    List<Map<String, dynamic>> messageRowsList = [];
    try {
      final messageRows = await supabase
          .from('messages')
          .select(
            'id, conversation_id, sender_id, content, message, created_at, is_read, is_auto_generated, attachment_url, attachment_type, attachment_name',
          )
          .inFilter('conversation_id', conversationIds)
          .order('created_at', ascending: true);
      messageRowsList = List<Map<String, dynamic>>.from(messageRows);
    } catch (msgSelectErr) {
      debugPrint('Specific column messages query note: $msgSelectErr');
      try {
        final fallbackRows = await supabase
            .from('messages')
            .select()
            .inFilter('conversation_id', conversationIds)
            .order('created_at', ascending: true);
        messageRowsList = List<Map<String, dynamic>>.from(fallbackRows);
      } catch (fallbackMsgErr) {
        debugPrint('Fallback messages query note: $fallbackMsgErr');
      }
    }

    final messagesByConversation = <String, List<Map<String, dynamic>>>{};
    for (final message in messageRowsList) {
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
    final visible = conversations.where(_isVisibleConversation).toList();
    sortConversationsByPriority(visible);
    return visible;
  }

  /// Priority ranking for conversation ordering:
  /// 0: Ongoing / Active rental trips (top operational priority)
  /// 1: Approved / Confirmed / Upcoming rental trips (high priority)
  /// 2: Direct Support / Customer Service conversations
  /// 3: Pending / Requested booking conversations
  /// 4: Frozen / Safety locked conversations
  /// 5: Completed / Returned past trips (read-only history)
  /// 6: Cancelled / Rejected bookings
  static int getConversationPriority(Map<String, dynamic> conversation) {
    final booking = conversation['bookings'];
    if (booking is! Map) {
      // Direct Support / Customer Service conversation
      return 2;
    }
    final rawStatus = (booking['status'] ?? '').toString().trim().toLowerCase();
    final group = bookingStatusGroup(rawStatus);
    switch (group) {
      case BookingStatusGroup.ongoing:
        return 0; // Top priority: Ongoing / Active trip
      case BookingStatusGroup.approved:
        return 1; // High priority: Approved / Confirmed / Upcoming trip
      case BookingStatusGroup.pending:
        return 3;
      case BookingStatusGroup.frozen:
        return 4;
      case BookingStatusGroup.completed:
        return 5;
      case BookingStatusGroup.cancelled:
        return 6;
    }
  }

  /// Extracts the most recent timestamp for sorting conversations within the same priority tier.
  static DateTime getConversationTimestamp(Map<String, dynamic> conversation) {
    final lastMessage = conversation['last_message'];
    if (lastMessage is Map) {
      final d = DateTime.tryParse(lastMessage['created_at']?.toString() ?? '');
      if (d != null) return d;
    }
    final messages = conversation['messages'];
    if (messages is List && messages.isNotEmpty) {
      final last = messages.last;
      if (last is Map) {
        final d = DateTime.tryParse(last['created_at']?.toString() ?? '');
        if (d != null) return d;
      }
      final first = messages.first;
      if (first is Map) {
        final d = DateTime.tryParse(first['created_at']?.toString() ?? '');
        if (d != null) return d;
      }
    }
    final updated = DateTime.tryParse(conversation['updated_at']?.toString() ?? '');
    if (updated != null) return updated;
    final created = DateTime.tryParse(conversation['created_at']?.toString() ?? '');
    if (created != null) return created;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Compares two conversations prioritizing Ongoing (0) and Approved (1), then latest message timestamp descending.
  static int compareConversationsByPriority(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final aPriority = getConversationPriority(a);
    final bPriority = getConversationPriority(b);
    if (aPriority != bPriority) {
      return aPriority.compareTo(bPriority);
    }
    final aDate = getConversationTimestamp(a);
    final bDate = getConversationTimestamp(b);
    return bDate.compareTo(aDate);
  }

  /// Sorts a conversation list in-place so Ongoing and Approved bookings appear at the top.
  static void sortConversationsByPriority(List<Map<String, dynamic>> conversations) {
    conversations.sort(compareConversationsByPriority);
  }

  bool _isVisibleConversation(Map<String, dynamic> conversation) {
    // Archived conversations are hidden by manual operator/admin action.
    // Completed or closed booking conversations stay visible in the messages list ("stay as is")
    // and operate in View Mode (read-only) inside ChatDetailScreen.
    final conversationStatus =
        conversation['status']?.toString().trim().toLowerCase() ?? 'active';
    if (conversationStatus == 'archived') {
      return false;
    }

    // If there is no linked booking the conversation is always visible
    // (e.g. customer-service / direct chats).
    final booking = conversation['bookings'];
    if (booking is! Map) return true;

    // Only hide conversations whose booking has been hard-cancelled or rejected.
    // Every other status (pending, requested, reserved, approved, active,
    // confirmed, ongoing, completed, paid, returned, etc.) remains visible
    // so that participants can view past chat history in view-only mode.
    const hiddenBookingStatuses = {
      'cancelled',
      'canceled',
      'rejected',
      'declined',
    };
    final bookingStatus =
        booking['status']?.toString().trim().toLowerCase() ?? '';
    return !hiddenBookingStatuses.contains(bookingStatus);
  }

  String _conversationVehicleImageUrl(Map<String, dynamic> conversation) {
    final booking = conversation['bookings'];
    if (booking is Map) {
      final bDirect = _normalizeVehicleImageUrl(booking['vehicle_image_url']);
      if (bDirect.isNotEmpty) return bDirect;

      final vehicle = booking['vehicles'];
      if (vehicle is Map) {
        final direct = _normalizeVehicleImageUrl(
          vehicle['image_url'] ??
              vehicle['imageUrl'] ??
              vehicle['image'] ??
              vehicle['thumbnail_url'],
        );
        if (direct.isNotEmpty) return direct;

        final images =
            List<Map<String, dynamic>>.from(
              (vehicle['vehicle_images'] ?? vehicle['images'] ?? vehicle['photos']) as List? ??
                  const [],
            )..sort((a, b) {
              final aOrder = (a['display_order'] as num?)?.toInt() ?? 999;
              final bOrder = (b['display_order'] as num?)?.toInt() ?? 999;
              return aOrder.compareTo(bOrder);
            });
        for (final image in images) {
          final url = _normalizeVehicleImageUrl(
            image['image_url'] ?? image['url'] ?? image['image'],
          );
          if (url.isNotEmpty) return url;
        }
      }
    }

    final convDirect = _normalizeVehicleImageUrl(conversation['vehicle_image_url']);
    if (convDirect.isNotEmpty) return convDirect;

    return '';
  }

  String _normalizeVehicleImageUrl(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return _normalizeVehicleImageUrl(value.first);
    }
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty || raw == 'null') return '';
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
          .order('updated_at', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;
      return Map<String, dynamic>.from(response.first);
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

      try {
        final response = await supabase
            .from('messages')
            .select('*, sender:users!messages_new_sender_id_fkey(*)')
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: true);

        debugPrint('Fetched ${response.length} messages with embed');
        return List<Map<String, dynamic>>.from(response);
      } catch (embedErr) {
        debugPrint(
          'Message sender relationship embed failed; loading profiles separately: $embedErr',
        );
        return await _getMessagesWithoutEmbed(conversationId);
      }
    } catch (e) {
      debugPrint('Unexpected error fetching messages: $e');
      try {
        return await _getMessagesWithoutEmbed(conversationId);
      } catch (fallbackErr) {
        debugPrint('Fallback message fetching also failed: $fallbackErr');
        return [];
      }
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

    Map<String, Map<String, dynamic>> usersById = {};
    try {
      final users = await supabase
          .from('users')
          .select('id, full_name, email, phone, avatar_url, role')
          .inFilter('id', senderIds);
      usersById = {
        for (final user in List<Map<String, dynamic>>.from(users))
          user['id']?.toString() ?? '': user,
      };
    } catch (userErr) {
      debugPrint('Could not fetch message senders: $userErr');
    }

    return messages
        .map(
          (message) => {
            ...message,
            if (usersById.containsKey(message['sender_id']?.toString()))
              'sender': usersById[message['sender_id']?.toString()],
          },
        )
        .toList();
  }

  // Send a message
  Future<bool> _isCustomerServiceConversation(
    String conversationId,
    Map<String, dynamic> conversation,
  ) async {
    if (conversation['booking_id'] != null ||
        conversation['is_group'] == true) {
      return false;
    }

    try {
      final participantRows = await supabase
          .from('conversation_participants')
          .select('user_id')
          .eq('conversation_id', conversationId);
      final participantIds = <String>{
        if (conversation['user_id'] != null) conversation['user_id'].toString(),
        if (conversation['other_user_id'] != null)
          conversation['other_user_id'].toString(),
        ...List<Map<String, dynamic>>.from(
          participantRows,
        ).map((row) => row['user_id']?.toString() ?? ''),
      }..removeWhere((id) => id.trim().isEmpty);

      if (participantIds.isEmpty) return false;
      final users = await supabase
          .from('users')
          .select('id, role')
          .inFilter('id', participantIds.toList());
      const supportRoles = {
        'customer_service',
        'support',
        'admin',
        'super_admin',
      };
      return List<Map<String, dynamic>>.from(users).any(
        (user) => supportRoles.contains(
          user['role']?.toString().trim().toLowerCase(),
        ),
      );
    } catch (error) {
      debugPrint('Could not classify support conversation: $error');
      return false;
    }
  }

  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentName,
    int? attachmentSize,
    bool isAutoGenerated = false,
  }) async {
    try {
      debugPrint('Sending message to conversation: $conversationId');

      final conversation = await supabase
          .from('conversations')
          .select('status, booking_id, is_group, user_id, other_user_id')
          .eq('id', conversationId)
          .maybeSingle();
      final isCustomerService =
          conversation != null &&
          await _isCustomerServiceConversation(
            conversationId,
            Map<String, dynamic>.from(conversation),
          );

      final restriction = await UserRestrictionService().getUserRestriction(
        senderId,
      );
      if (!isCustomerService &&
          (restriction.isBlocked || restriction.isAccountRestricted)) {
        throw Exception(
          'This account is temporarily restricted from messaging',
        );
      }

      if ((conversation?['status']?.toString().toLowerCase() ?? 'active') ==
          'closed') {
        throw Exception('This booking conversation is closed');
      }

      final bookingId = conversation?['booking_id']?.toString();
      if (bookingId != null && bookingId.isNotEmpty) {
        final bookingRow = await supabase
            .from('bookings')
            .select('status')
            .eq('id', bookingId)
            .maybeSingle();
        final bStatus = bookingRow?['status']?.toString().toLowerCase().trim();
        const readOnlyStatuses = {
          'completed',
          'returned',
          'cancelled',
          'canceled',
          'rejected',
          'declined',
          'expired',
        };
        if (bStatus != null && readOnlyStatuses.contains(bStatus)) {
          throw Exception(
            'This conversation is read-only because the booking is $bStatus.',
          );
        }
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
            if (isAutoGenerated) 'is_auto_generated': true,
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

  /// Adds an immutable lifecycle record to a booking group conversation.
  /// The audit key prevents duplicate checklist records when a transition is
  /// retried after a network interruption.
  Future<Map<String, dynamic>> sendBookingAuditMessage({
    required String conversationId,
    required String senderId,
    required String content,
    required String auditKey,
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentName,
  }) async {
    final marker = '[Audit: $auditKey]';
    final existing = await supabase
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(100);
    for (final raw in List<Map<String, dynamic>>.from(existing)) {
      final message = (raw['content'] ?? raw['message'])?.toString() ?? '';
      if (message.contains(marker)) return raw;
    }

    final messageContent = '$content\n\n$marker';
    final response = await supabase
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': senderId,
          'message': messageContent,
          'content': messageContent,
          'is_auto_generated': true,
          if (attachmentUrl != null) 'attachment_url': attachmentUrl,
          if (attachmentType != null) 'attachment_type': attachmentType,
          if (attachmentName != null) 'attachment_name': attachmentName,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'is_read': false,
        })
        .select()
        .single();

    await supabase
        .from('conversations')
        .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', conversationId);
    await _notifyMessageRecipients(
      conversationId: conversationId,
      senderId: senderId,
      content: content,
    );
    return Map<String, dynamic>.from(response);
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
          .select('user_id')
          .eq('conversation_id', conversationId)
          .neq('user_id', currentUserId)
          .limit(1);

      if (participants.isNotEmpty) {
        final userId = participants.first['user_id']?.toString().trim();
        if (userId != null && userId.isNotEmpty) {
          final user = await supabase
              .from('users')
              .select()
              .eq('id', userId)
              .maybeSingle();
          if (user != null) return Map<String, dynamic>.from(user);
        }
      }

      // Fallback: Check conversations table direct user columns
      final conv = await supabase
          .from('conversations')
          .select('user_id, other_user_id')
          .eq('id', conversationId)
          .maybeSingle();
      if (conv != null) {
        final u1 = conv['user_id']?.toString().trim() ?? '';
        final u2 = conv['other_user_id']?.toString().trim() ?? '';
        final targetId = u1 == currentUserId ? u2 : (u2 == currentUserId ? u1 : (u1.isNotEmpty ? u1 : u2));
        if (targetId.isNotEmpty) {
          final user = await supabase
              .from('users')
              .select()
              .eq('id', targetId)
              .maybeSingle();
          if (user != null) return Map<String, dynamic>.from(user);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting other user profile: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getConversationParticipants(
    String conversationId,
  ) async {
    try {
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
      } catch (e) {
        debugPrint(
          'Participant embed failed, retrying without relationship: $e',
        );
        return await _getConversationParticipantsFallback(conversationId);
      }
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

  Future<Map<String, dynamic>> getOrCreateBookingConversation(
    String bookingId, {
    List<String>? initialParticipantIds,
  }) async {
    final existing = await _firstBookingConversation(bookingId);
    if (existing != null) {
      if (initialParticipantIds != null && initialParticipantIds.isNotEmpty) {
        await addParticipantsToBookingConversation(
          bookingId: bookingId,
          participantIds: initialParticipantIds,
        );
      }
      return existing;
    }

    return await createGroupConversation(
      bookingId: bookingId,
      participantIds: initialParticipantIds ?? const [],
    );
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
