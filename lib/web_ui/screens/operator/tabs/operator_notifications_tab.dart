part of '../operator_web_screen.dart';

extension _OperatorNotificationsTab on _OperatorWebScreenState {
  Widget _buildNotificationsContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Notifications (${_notifications.length})',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () async {
                  final currentUserId = _supabase.auth.currentUser?.id;
                  if (currentUserId == null) return;
                  await NotificationService().markAllAsRead(currentUserId);
                  await _loadNotifications();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.done_all, size: 16),
                label: const Text('Mark all read'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_notifications.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade200,
                ),
              ),
              child: Text(
                'No notifications yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey.shade600,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                final isRead = notification['is_read'] == true;
                final title = notification['title']?.toString() ?? 'Update';
                final message =
                    notification['message']?.toString() ??
                    notification['body']?.toString() ??
                    '';
                final visual = notificationVisualFor(notification);
                final vehicleImageUrl = _notificationVehicleImageUrl(
                  notification,
                );

                return InkWell(
                  onTap: () => _handleOperatorNotificationTap(notification),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isRead
                          ? (isDark ? AppColors.darkCard : Colors.white)
                          : AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isRead
                            ? (isDark
                                  ? AppColors.borderColor
                                  : Colors.grey.shade200)
                            : AppColors.primary.withOpacity(0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: visual.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isRead
                                      ? Colors.transparent
                                      : visual.color.withOpacity(0.45),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: vehicleImageUrl.isNotEmpty
                                  ? OptimizedNetworkImage(
                                      imageUrl: vehicleImageUrl,
                                      width: 58,
                                      height: 58,
                                      fit: BoxFit.cover,
                                      placeholder: Center(
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: visual.color,
                                          ),
                                        ),
                                      ),
                                      errorWidget: Icon(
                                        visual.icon,
                                        color: visual.color,
                                      ),
                                    )
                                  : Icon(
                                      visual.icon,
                                      color: isRead
                                          ? (isDark
                                                ? Colors.grey
                                                : Colors.grey.shade600)
                                          : visual.color,
                                    ),
                            ),
                            if (!isRead)
                              Positioned(
                                right: -3,
                                top: -3,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF101827)
                                          : Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isRead
                                      ? FontWeight.w700
                                      : FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              if (message.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              RelativeTimeText(
                                value: notification['created_at'],
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _handleOperatorNotificationTap(
    Map<String, dynamic> notification,
  ) async {
    final notificationId = notification['id']?.toString();
    if (notificationId != null &&
        notificationId.isNotEmpty &&
        notification['is_read'] != true) {
      await NotificationService().markAsRead(notificationId);
      notification['is_read'] = true;
      if (mounted) setState(() {});
    }
    if (!mounted) return;

    final target = resolveNotificationTarget(notification);
    switch (target.destination) {
      case NotificationDestination.messages:
        setState(() {
          _selectedIndex = 2;
          if (target.conversationId != null) {
            _selectedConversationId = target.conversationId!;
          }
        });
        if (target.conversationId != null) {
          await _loadConversationMessages(target.conversationId!);
        }
        return;
      case NotificationDestination.tracking:
        setState(() {
          _selectedIndex = 6;
          _focusedTrackingBookingId = target.bookingId;
        });
        return;
      case NotificationDestination.booking:
        setState(() {
          _selectedIndex = 1;
          _bookingFilter = 'all';
        });
        final bookingId = target.bookingId;
        if (bookingId != null) {
          final booking = _recentBookings.firstWhere(
            (item) => item['id']?.toString() == bookingId,
            orElse: () => <String, dynamic>{},
          );
          if (booking.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showOperatorBookingDetailsDialog(booking);
            });
          }
        }
        return;
      case NotificationDestination.payment:
        setState(() => _selectedIndex = 7);
        return;
      case NotificationDestination.application:
      case NotificationDestination.verification:
      case NotificationDestination.vehicles:
        setState(() => _selectedIndex = 4);
        return;
      case NotificationDestination.ratings:
        setState(() => _selectedIndex = 7);
        return;
      case NotificationDestination.announcement:
      case NotificationDestination.general:
        _showOperatorNotificationDetails(notification);
        return;
    }
  }

  void _showOperatorNotificationDetails(Map<String, dynamic> notification) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(notification['title']?.toString() ?? 'Notification'),
        content: Text(
          notification['message']?.toString().trim().isNotEmpty == true
              ? notification['message'].toString()
              : 'No additional details are available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    switch (role) {
      case 'partner':
        color = Colors.blue;
        break;
      case 'operator':
        color = Colors.purple;
        break;
      case 'admin':
        color = Colors.red;
        break;
      default:
        color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildImageWidget(
    XFile imageFile, {
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    return FutureBuilder<Uint8List>(
      future: _selectedImageBytes.putIfAbsent(
        imageFile.path,
        imageFile.readAsBytes,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final image = Image.memory(snapshot.data!, fit: fit);
          return borderRadius != null
              ? ClipRRect(borderRadius: borderRadius, child: image)
              : image;
        } else if (snapshot.hasError) {
          return const Center(child: Icon(Icons.error, color: Colors.red));
        } else {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
      },
    );
  }

  Future<void> _loadConversations() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      if (mounted) {
        setState(() {
          _isLoadingConversations = false;
          _conversationLoadError = 'Your operator session is not ready yet.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingConversations = true;
        _conversationLoadError = null;
      });
    }

    try {
      debugPrint(
        '[Messages] Loading conversations for operator: $currentUserId',
      );

      // 1. Fetch conversations from ChatService
      List<Map<String, dynamic>> chatServiceRows = [];
      try {
        chatServiceRows = await ChatService().getConversations(currentUserId);
      } catch (csErr) {
        debugPrint('[Messages] ChatService lookup note: $csErr');
      }

      // 2. Direct query on conversations table as fallback
      List<Map<String, dynamic>> directConversations = [];
      try {
        final response = await _supabase
            .from('conversations')
            .select('id, booking_id, user_id, other_user_id, status, created_at, updated_at')
            .order('updated_at', ascending: false)
            .limit(100);
        final rawRows = List<Map<String, dynamic>>.from(response);
        final bookingIds = rawRows
            .map((c) => c['booking_id']?.toString().trim())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();

        final bookingsMap = <String, Map<String, dynamic>>{};
        if (bookingIds.isNotEmpty) {
          try {
            final bRows = await _supabase
                .from('bookings')
                .select()
                .inFilter('id', bookingIds);
            for (final b in List<Map<String, dynamic>>.from(bRows)) {
              final id = b['id']?.toString() ?? '';
              if (id.isNotEmpty) bookingsMap[id] = b;
            }
          } catch (_) {}
        }

        for (final row in rawRows) {
          final bId = row['booking_id']?.toString() ?? '';
          if (bId.isNotEmpty && bookingsMap.containsKey(bId)) {
            row['bookings'] = bookingsMap[bId];
          }
          directConversations.add(row);
        }
      } catch (queryErr) {
        debugPrint('[Messages] Direct conversations query note: $queryErr');
      }

      // Merge both sources and deduplicate by conversation or booking ID
      final conversationsMap = <String, Map<String, dynamic>>{};
      for (final item in [...chatServiceRows, ...directConversations]) {
        final cId = item['id']?.toString().trim() ?? '';
        final bId = item['booking_id']?.toString().trim() ?? '';
        final key = cId.isNotEmpty ? cId : bId;
        if (key.isNotEmpty) {
          conversationsMap.putIfAbsent(key, () => item);
        }
      }

      _conversations = conversationsMap.values.toList();

      // Hydrate missing booking and vehicle data using _recentBookings and cached lists
      for (final item in _conversations) {
        final bId = (item['booking_id'] ?? (item['bookings'] is Map ? item['bookings']['id'] : null))?.toString().trim() ?? '';
        if (bId.isNotEmpty) {
          final cached = _recentBookings.firstWhere(
            (rb) => rb['id']?.toString().trim() == bId,
            orElse: () => {},
          );
          if (cached.isNotEmpty) {
            final currentB = item['bookings'] is Map
                ? Map<String, dynamic>.from(item['bookings'] as Map)
                : <String, dynamic>{};
            final merged = <String, dynamic>{...cached, ...currentB};
            if (currentB['vehicles'] == null ||
                (currentB['vehicles'] is Map && (currentB['vehicles'] as Map).isEmpty)) {
              merged['vehicles'] = cached['vehicles'];
            }
            if (currentB['renter'] == null && (cached['users'] != null || cached['renter'] != null)) {
              merged['renter'] = cached['users'] ?? cached['renter'];
            }
            item['bookings'] = merged;
          }
        }
      }

      // Batch-fetch any missing renter profiles to ensure renter name is always visible
      final missingRenterIds = <String>{};
      for (final item in _conversations) {
        final b = item['bookings'];
        if (b is Map) {
          final r = b['renter'];
          final rName = r is Map ? r['full_name']?.toString().trim() : null;
          if (rName == null || rName.isEmpty || rName.toLowerCase() == 'unknown renter') {
            final rid = b['renter_id']?.toString().trim() ?? '';
            if (rid.isNotEmpty) missingRenterIds.add(rid);
          }
        }
      }
      if (missingRenterIds.isNotEmpty) {
        try {
          final usersRows = await _supabase
              .from('users')
              .select('id, full_name, email, phone, avatar_url, is_blocked, restriction_level')
              .inFilter('id', missingRenterIds.toList());
          final usersMap = {
            for (final u in List<Map<String, dynamic>>.from(usersRows))
              u['id']?.toString() ?? '': u
          };
          for (final item in _conversations) {
            final b = item['bookings'];
            if (b is Map) {
              final rid = b['renter_id']?.toString().trim() ?? '';
              if (rid.isNotEmpty && usersMap.containsKey(rid)) {
                b['renter'] = usersMap[rid];
              }
            }
          }
        } catch (uErr) {
          debugPrint('[Messages] Batch-fetch missing renters skipped: $uErr');
        }
      }

      // Batch-fetch any missing vehicle or partner vehicle details and images
      final missingVehicleIds = <String>{};
      final missingPartnerVehicleIds = <String>{};
      final missingBookingIdsForVehicles = <String>{};

      for (final item in _conversations) {
        final b = item['bookings'];
        final bId = (item['booking_id'] ?? (b is Map ? b['id'] : null))?.toString().trim() ?? '';
        if (b is Map) {
          final v = (b['vehicles'] ?? b['partner_vehicles'] ?? b['partner_vehicle']) as Map<String, dynamic>?;
          final vid = (b['vehicle_id'] ?? b['partner_vehicle_id'])?.toString().trim() ?? '';
          final pvid = b['partner_vehicle_id']?.toString().trim() ?? '';
          final vImg = _operatorVehicleImageUrl(v ?? {}, item, b is Map<String, dynamic> ? b : null);
          if (v == null || vImg.isEmpty || (v['brand'] == null && v['vehicle_name'] == null)) {
            if (vid.isNotEmpty) missingVehicleIds.add(vid);
            if (pvid.isNotEmpty) missingPartnerVehicleIds.add(pvid);
            if (vid.isEmpty && pvid.isEmpty && bId.isNotEmpty) {
              missingBookingIdsForVehicles.add(bId);
            }
          }
        } else if (bId.isNotEmpty) {
          missingBookingIdsForVehicles.add(bId);
        }
      }

      if (missingBookingIdsForVehicles.isNotEmpty) {
        try {
          final bRows = await _supabase
              .from('bookings')
              .select('id, vehicle_id, partner_vehicle_id, renter_id, status')
              .inFilter('id', missingBookingIdsForVehicles.toList());
          for (final bRow in List<Map<String, dynamic>>.from(bRows)) {
            final id = bRow['id']?.toString() ?? '';
            final vid = (bRow['vehicle_id'] ?? bRow['partner_vehicle_id'])?.toString().trim() ?? '';
            final pvid = bRow['partner_vehicle_id']?.toString().trim() ?? '';
            if (vid.isNotEmpty) missingVehicleIds.add(vid);
            if (pvid.isNotEmpty) missingPartnerVehicleIds.add(pvid);
            for (final item in _conversations) {
              final itemBId = (item['booking_id'] ?? (item['bookings'] is Map ? item['bookings']['id'] : null))?.toString();
              if (itemBId == id) {
                if (item['bookings'] is Map) {
                  item['bookings']['vehicle_id'] ??= vid;
                  item['bookings']['partner_vehicle_id'] ??= pvid;
                } else {
                  item['bookings'] = Map<String, dynamic>.from(bRow);
                }
              }
            }
          }
        } catch (_) {}
      }

      // Seed vehicles map with in-memory vehicle caches first
      final vehiclesMap = <String, Map<String, dynamic>>{};
      for (final v in _vehicles) {
        final id = v['id']?.toString() ?? '';
        if (id.isNotEmpty) vehiclesMap[id] = v;
      }
      for (final pv in _partnerVehicles) {
        final id = pv['id']?.toString() ?? '';
        if (id.isNotEmpty) vehiclesMap[id] = pv;
      }

      final fetchVehicleIds = missingVehicleIds.where((id) => !vehiclesMap.containsKey(id)).toList();
      final fetchPartnerVehicleIds = missingPartnerVehicleIds.where((id) => !vehiclesMap.containsKey(id)).toList();

      if (fetchVehicleIds.isNotEmpty || fetchPartnerVehicleIds.isNotEmpty || vehiclesMap.isNotEmpty) {
        try {
          if (fetchVehicleIds.isNotEmpty) {
            try {
              final vRows = await _supabase
                  .from('vehicles')
                  .select('id, brand, model, vehicle_name, plate_number, vehicle_images(image_url, display_order)')
                  .inFilter('id', fetchVehicleIds);
              for (final v in List<Map<String, dynamic>>.from(vRows)) {
                final id = v['id']?.toString() ?? '';
                if (id.isNotEmpty) vehiclesMap[id] = v;
              }
            } catch (_) {
              try {
                final vRows = await _supabase
                    .from('vehicles')
                    .select('id, brand, model, vehicle_name, plate_number')
                    .inFilter('id', fetchVehicleIds);
                for (final v in List<Map<String, dynamic>>.from(vRows)) {
                  final id = v['id']?.toString() ?? '';
                  if (id.isNotEmpty) vehiclesMap[id] = v;
                }
              } catch (_) {}
            }
          }

          final partnerIdsToFetch = {
            ...fetchPartnerVehicleIds,
            ...fetchVehicleIds.where((id) => !vehiclesMap.containsKey(id)),
          }.toList();

          if (partnerIdsToFetch.isNotEmpty) {
            try {
              final pvRows = await _supabase
                  .from('partner_vehicles')
                  .select('id, brand, model, vehicle_name, plate_number')
                  .inFilter('id', partnerIdsToFetch);
              for (final pv in List<Map<String, dynamic>>.from(pvRows)) {
                final id = pv['id']?.toString() ?? '';
                if (id.isNotEmpty) vehiclesMap[id] = pv;
              }
            } catch (pvErr) {
              debugPrint('[Messages] Partner vehicle query note: $pvErr');
            }
          }

          final idsNeedingImages = vehiclesMap.entries
              .where((e) {
                final v = e.value;
                final img = (v['image_url'] ?? v['imageUrl'] ?? v['photo_url'])?.toString().trim() ?? '';
                final vImgs = v['vehicle_images'] as List?;
                return img.isEmpty && (vImgs == null || vImgs.isEmpty);
              })
              .map((e) => e.key)
              .toList();

          if (idsNeedingImages.isNotEmpty) {
            try {
              final imgRows = await _supabase
                  .from('vehicle_images')
                  .select('vehicle_id, partner_vehicle_id, image_url, display_order')
                  .or('vehicle_id.in.(${idsNeedingImages.join(",")}),partner_vehicle_id.in.(${idsNeedingImages.join(",")})')
                  .order('display_order', ascending: true);
              for (final img in List<Map<String, dynamic>>.from(imgRows)) {
                final vId = (img['vehicle_id'] ?? img['partner_vehicle_id'])?.toString() ?? '';
                if (vId.isNotEmpty && vehiclesMap.containsKey(vId)) {
                  final target = vehiclesMap[vId]!;
                  final currentImgs = (target['vehicle_images'] as List? ?? []).toList();
                  currentImgs.add(img);
                  target['vehicle_images'] = currentImgs;
                  if ((target['image_url']?.toString().trim() ?? '').isEmpty) {
                    target['image_url'] = img['image_url'];
                  }
                }
              }
            } catch (_) {}
          }

          for (final item in _conversations) {
            final b = item['bookings'];
            if (b is Map) {
              final vid = (b['vehicle_id'] ?? b['partner_vehicle_id'])?.toString().trim() ?? '';
              final pvid = b['partner_vehicle_id']?.toString().trim() ?? '';
              if (vid.isNotEmpty && vehiclesMap.containsKey(vid)) {
                b['vehicles'] = vehiclesMap[vid];
              } else if (pvid.isNotEmpty && vehiclesMap.containsKey(pvid)) {
                b['vehicles'] = vehiclesMap[pvid];
              }
              final resolvedVehicle = b['vehicles'];
              if (resolvedVehicle is Map<String, dynamic>) {
                final resolvedUrl = _operatorVehicleImageUrl(
                  resolvedVehicle,
                  item,
                  b is Map<String, dynamic> ? b : null,
                );
                if (resolvedUrl.isNotEmpty) {
                  b['vehicle_image_url'] = resolvedUrl;
                  item['vehicle_image_url'] = resolvedUrl;
                }
              }
            }
          }
        } catch (vErr) {
          debugPrint('[Messages] Batch-fetch missing vehicles skipped: $vErr');
        }
      }

      ChatService.sortConversationsByPriority(_conversations);

      debugPrint('[Messages] Loaded ${_conversations.length} conversations for operator');

      // Auto-select first conversation if none selected
      if (_selectedConversationId.isEmpty && _conversations.isNotEmpty) {
        final firstId = _conversations.first['id']?.toString() ?? '';
        if (firstId.isNotEmpty) {
          _selectedConversationId = firstId;
          unawaited(_loadConversationMessages(firstId));
        }
      } else if (_selectedConversationId.isNotEmpty) {
        unawaited(_loadConversationMessages(_selectedConversationId));
      }

      if (mounted) {
        setState(() {
          _isLoadingConversations = false;
          _conversationLoadError = _conversations.isEmpty
              ? 'No active booking conversations were found.'
              : null;
        });
      }
    } catch (e) {
      debugPrint('[Messages] Error loading conversations: $e');
      if (mounted) {
        setState(() {
          _isLoadingConversations = false;
          _conversationLoadError =
              'Unable to load booking conversations. Please retry.';
        });
      }
    }
  }

  Future<void> _loadConversationMessages(String conversationId) async {
    try {
      debugPrint(
        '[Messages] Loading messages for conversation: $conversationId',
      );

      await _loadConversationParticipants(conversationId);
      _watchConversationMessages(conversationId);

      List<Map<String, dynamic>> loadedMessages = [];
      try {
        loadedMessages = await ChatService().getMessages(conversationId);
      } catch (queryErr) {
        debugPrint(
          '[Messages] ChatService getMessages note: $queryErr, falling back to select()',
        );
        final response = await _supabase
            .from('messages')
            .select()
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: true);
        loadedMessages = List<Map<String, dynamic>>.from(response);
      }

      // Enrich missing sender details from participants
      final participants =
          _conversationParticipants[conversationId] ?? const [];
      for (final msg in loadedMessages) {
        if (msg['sender'] == null) {
          final sId = msg['sender_id']?.toString();
          final p = participants.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['user_id']?.toString() == sId,
            orElse: () => null,
          );
          final pName = p?['display_name']?.toString() ?? p?['full_name']?.toString();
          if (pName != null && pName.trim().isNotEmpty) {
            msg['sender'] = {'id': sId, 'full_name': pName.trim()};
          }
        }
      }

      // Fetch flagged messages for this conversation and participants
      try {
        final flagRows = await _supabase
            .from('message_flags')
            .select()
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: true);
        final flags = List<Map<String, dynamic>>.from(flagRows);

        final conv = _conversations.firstWhere(
          (c) => c['id']?.toString() == conversationId,
          orElse: () => <String, dynamic>{},
        );
        final booking = conv['bookings'] as Map<String, dynamic>? ?? {};
        final renterId = (booking['renter_id'] ??
                (booking['renter'] as Map?)?['id'])
            ?.toString() ??
            '';

        if (renterId.isNotEmpty) {
          try {
            final renterFlags = await _supabase
                .from('message_flags')
                .select()
                .eq('sender_id', renterId)
                .order('created_at', ascending: false)
                .limit(10);
            for (final rf in List<Map<String, dynamic>>.from(renterFlags)) {
              if (!flags.any((f) =>
                  f['id'] == rf['id'] ||
                  f['message_content'] == rf['message_content'])) {
                flags.add({...rf, 'is_account_history_flag': true});
              }
            }
          } catch (_) {}
        }

        _conversationFlags[conversationId] = flags;

        // Merge flagged messages that were blocked before reaching messages table into the message list
        for (final flag in flags) {
          final content = flag['message_content']?.toString().trim() ?? '';
          if (content.isEmpty) continue;
          final alreadyPresent = loadedMessages.any(
            (m) =>
                m['id']?.toString() == flag['message_id']?.toString() ||
                (m['content'] ?? m['message'])?.toString().trim() == content,
          );
          if (!alreadyPresent) {
            loadedMessages.add({
              'id': flag['message_id']?.toString() ??
                  flag['id']?.toString() ??
                  'flag_${DateTime.now().millisecondsSinceEpoch}',
              'conversation_id': conversationId,
              'sender_id': flag['sender_id'],
              'content': content,
              'message': content,
              'created_at':
                  flag['created_at'] ?? DateTime.now().toIso8601String(),
              'is_flagged': true,
              'is_blocked_flag': true,
              'flag_reason':
                  flag['flag_reason'] ?? 'Off-platform contact attempt',
              'risk_level': flag['risk_level'] ?? 'high',
              'sender': {
                'full_name': (booking['renter'] as Map?)?['full_name'] ??
                    'Renter (Flagged Content)',
              },
            });
          }
        }
      } catch (flagErr) {
        debugPrint('[Messages] Error fetching flags: $flagErr');
      }

      // Deduplicate loaded messages by ID and collapse redundant auto-generated booking messages
      final seenIds = <String>{};
      final uniqueMessages = <Map<String, dynamic>>[];
      var hasSeenAutoSummary = false;

      for (final msg in loadedMessages) {
        final id = msg['id']?.toString() ?? '';
        if (id.isNotEmpty && seenIds.contains(id)) continue;
        if (id.isNotEmpty) seenIds.add(id);

        final contentStr =
            (msg['content'] ?? msg['message'])?.toString().toLowerCase().trim() ??
                '';
        final isBookingSummary = contentStr.startsWith('booking details') ||
            contentStr.startsWith('booking confirmed') ||
            contentStr.startsWith('booking request created') ||
            contentStr.startsWith('📋');

        if (isBookingSummary) {
          if (hasSeenAutoSummary) {
            continue; // Skip redundant duplicate automated booking summary
          }
          hasSeenAutoSummary = true;
        }

        uniqueMessages.add(msg);
      }
      loadedMessages = uniqueMessages;

      loadedMessages.sort((first, second) {
        final firstTime =
            parseMessageTimestamp(first['created_at']) ?? DateTime(1970);
        final secondTime =
            parseMessageTimestamp(second['created_at']) ?? DateTime(1970);
        return firstTime.compareTo(secondTime);
      });
      _messages[conversationId] = loadedMessages;
      debugPrint(
        '[Messages] Loaded ${_messages[conversationId]?.length ?? 0} messages',
      );

      if (mounted) {
        setState(() {});
      }
      _scrollMessagesToBottom();

      // Mark unread messages in this conversation as read
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        try {
          await _supabase
              .from('messages')
              .update({'is_read': true})
              .eq('conversation_id', conversationId)
              .neq('sender_id', currentUserId)
              .eq('is_read', false);
          _loadUnreadMessagesCount();
        } catch (markErr) {
          debugPrint('Could not mark conversation as read: $markErr');
        }
      }
    } catch (e) {
      debugPrint('[Messages] Error loading messages: $e');
    }
  }

  void _watchConversationMessages(String conversationId) {
    _conversationMessagesChannel?.unsubscribe();
    _conversationMessagesChannel = _supabase
        .channel('operator-conversation-$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final raw = payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord;
            if (raw.isEmpty || !mounted) return;
            final message = Map<String, dynamic>.from(raw);
            setState(() => _mergeOperatorMessage(conversationId, message));
            if (_selectedConversationId == conversationId) {
              _scrollMessagesToBottom();
            }
          },
        )
        .subscribe();
  }

  void _mergeOperatorMessage(
    String conversationId,
    Map<String, dynamic> message,
  ) {
    final messages = _messages.putIfAbsent(conversationId, () => []);
    final messageId = message['id']?.toString();
    if (messageId == null || messageId.isEmpty) return;

    final contentStr =
        (message['content'] ?? message['message'])?.toString().toLowerCase().trim() ??
            '';
    final isBookingSummary = contentStr.startsWith('booking details') ||
        contentStr.startsWith('booking confirmed') ||
        contentStr.startsWith('booking request created') ||
        contentStr.startsWith('📋');

    if (isBookingSummary &&
        messages.any((m) {
          if (m['id']?.toString() == messageId) return false;
          final mContent =
              (m['content'] ?? m['message'])?.toString().toLowerCase().trim() ??
                  '';
          return mContent.startsWith('booking details') ||
              mContent.startsWith('booking confirmed') ||
              mContent.startsWith('booking request created') ||
              mContent.startsWith('📋');
        })) {
      return; // Prevent adding duplicate realtime automated booking summary
    }

    var enrichedMessage = message;
    if (message['sender'] == null) {
      final senderId = message['sender_id']?.toString();
      final participants =
          _conversationParticipants[conversationId] ?? const [];
      final participant = participants.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['user_id']?.toString() == senderId,
        orElse: () => null,
      );
      final senderName = participant?['display_name']?.toString();
      if (senderName != null && senderName.trim().isNotEmpty) {
        enrichedMessage = {
          ...message,
          'sender': {'id': senderId, 'full_name': senderName.trim()},
        };
      }
    }
    final existingIndex = messages.indexWhere(
      (item) => item['id']?.toString() == messageId,
    );
    if (existingIndex >= 0) {
      final existing = messages[existingIndex];
      messages[existingIndex] = {...existing, ...enrichedMessage};
    } else {
      messages.add(enrichedMessage);
    }
    messages.sort((first, second) {
      final firstTime =
          parseMessageTimestamp(first['created_at']) ?? DateTime(1970);
      final secondTime =
          parseMessageTimestamp(second['created_at']) ?? DateTime(1970);
      return firstTime.compareTo(secondTime);
    });
  }

  void _scrollMessagesToBottom({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messageScrollController.hasClients) return;
      final target = _messageScrollController.position.maxScrollExtent;
      if (animate) {
        _messageScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _messageScrollController.jumpTo(target);
      }
    });
  }

  Future<void> _loadConversationParticipants(String conversationId) async {
    try {
      _conversationParticipants[conversationId] = await ChatService()
          .getConversationParticipants(conversationId);
    } catch (e) {
      debugPrint('[Messages] Error loading participants: $e');
      _conversationParticipants[conversationId] = [];
    }
  }

  Map<String, dynamic> _checkConversationViolation(
    Map<String, dynamic>? conversation,
    List<Map<String, dynamic>> messages,
  ) {
    if (conversation == null) {
      return {
        'has_violation': false,
        'is_pending_review': false,
        'is_frozen': false,
        'violated_reasons': <String>[],
        'flagged_messages': <Map<String, dynamic>>[],
      };
    }

    final convId = conversation['id']?.toString() ?? '';
    final booking = conversation['bookings'] as Map<String, dynamic>? ?? {};
    final renter = booking['renter'] as Map<String, dynamic>? ?? {};
    final renterName = renter['full_name']?.toString() ?? 'Renter';
    final renterId =
        renter['id']?.toString() ?? booking['renter_id']?.toString() ?? '';
    final flagCount = (renter['off_platform_flag_count'] as num?)?.toInt() ?? 0;
    final isBlocked = renter['is_blocked'] == true;
    final isSafetyFreeze = booking['safety_freeze'] == true ||
        (booking['status']?.toString().toLowerCase() == 'frozen');

    final violatedReasons = <String>[];
    final flaggedMessages = <Map<String, dynamic>>[];
    final currentUserId = _supabase.auth.currentUser?.id;

    // 1. Scan flags recorded in database (message_flags)
    final dbFlags = _conversationFlags[convId] ?? const [];
    for (final flag in dbFlags) {
      final flagStatus = flag['status']?.toString().toLowerCase() ?? 'pending_review';
      if (flagStatus == 'dismissed') continue;

      final content = flag['message_content']?.toString().trim() ?? '';
      final reason = flag['flag_reason']?.toString().trim() ??
          'Report / Off-platform contact attempt';
      final risk = flag['risk_level']?.toString().toUpperCase() ?? 'HIGH';
      final isHistory = flag['is_account_history_flag'] == true;

      flaggedMessages.add({
        'content': content,
        'reason': reason,
        'risk_level': risk,
        'created_at': flag['created_at'],
        'is_account_history': isHistory,
        'sender_name': renterName,
        'status': flagStatus,
      });

      final excerpt =
          content.length > 70 ? '${content.substring(0, 67)}...' : content;
      final sourceTag =
          isHistory ? '[Renter Profile History]' : '[Reported / Flagged]';
      final detail = content.isNotEmpty
          ? '$sourceTag "$excerpt" — $reason'
          : '$sourceTag Policy Notice: $reason';
      if (!violatedReasons.contains(detail)) {
        violatedReasons.add(detail);
      }
    }

    // 2. Scan loaded messages in memory for suspicious keywords
    for (final msg in messages) {
      final isAutoGenerated = msg['is_auto_generated'] == true ||
          msg['is_system'] == true ||
          msg['sender_id'] == null;
      if (isAutoGenerated) continue;

      final senderId = msg['sender_id']?.toString();
      if (senderId == null || senderId == currentUserId) continue;

      final content = (msg['content'] ?? msg['message'])?.toString() ?? '';
      final cleanContent = content.trim();
      if (cleanContent.isEmpty) continue;

      if (MessageFilterService.isSystemOrAuditMessage(cleanContent) ||
          cleanContent.startsWith('[System]') ||
          cleanContent.startsWith('Booking Details') ||
          cleanContent.startsWith('Booking Confirmed') ||
          cleanContent.contains('Checklist Submitted')) {
        continue;
      }

      final analysis = MessageFilterService.analyzeMessage(cleanContent);
      if (analysis['is_suspicious'] == true ||
          msg['is_flagged'] == true ||
          msg['is_blocked_flag'] == true) {
        final keywords = List<String>.from(
          analysis['found_keywords'] as List? ?? [],
        );
        final label = keywords.isNotEmpty
            ? keywords.join(', ')
            : (msg['flag_reason']?.toString() ??
                'Off-platform contact attempt');
        final excerpt = cleanContent.length > 70
            ? '${cleanContent.substring(0, 67)}...'
            : cleanContent;

        final alreadyInFlagged =
            flaggedMessages.any((f) => f['content'] == cleanContent);
        if (!alreadyInFlagged) {
          flaggedMessages.add({
            'content': cleanContent,
            'reason': label,
            'risk_level':
                analysis['risk_level']?.toString().toUpperCase() ?? 'HIGH',
            'created_at': msg['created_at'],
            'is_account_history': false,
            'sender_name': (msg['sender'] as Map?)?['full_name']?.toString() ??
                renterName,
            'status': 'pending_review',
          });
        }

        final detail =
            'Flagged for Admin review: "$excerpt" ($label)';
        if (!violatedReasons.contains(detail) &&
            !violatedReasons.any((r) => r.contains(excerpt))) {
          violatedReasons.add(detail);
        }
      }
    }

    // 3. User account restriction annotations
    if (flagCount > 0 && isBlocked && !violatedReasons.any((r) => r.contains('policy violation'))) {
      violatedReasons.add(
        'Renter has $flagCount confirmed policy violation flag${flagCount == 1 ? '' : 's'} on account profile',
      );
    }

    final restrReason = renter['restriction_reason']?.toString().trim();
    if (isBlocked && restrReason != null && restrReason.isNotEmpty) {
      violatedReasons.add('Restriction Reason: $restrReason');
    }

    if (isBlocked) {
      violatedReasons.add('Renter account is currently blocked/suspended by Admin');
    }
    if (isSafetyFreeze) {
      violatedReasons.add(
        'Booking is currently frozen under Safety Freeze policy',
      );
    }

    // Only lock/ban the conversation if explicitly confirmed/banned by Admin or safety freeze
    final hasConfirmedViolation = isSafetyFreeze ||
        isBlocked ||
        dbFlags.any((f) => f['status'] == 'confirmed' || f['status'] == 'violation');

    final hasPendingReview = dbFlags.any((f) => f['status'] == 'pending_review' || f['status'] == 'pending') ||
        (!hasConfirmedViolation && flaggedMessages.isNotEmpty);

    return {
      'has_violation': hasConfirmedViolation,
      'is_pending_review': hasPendingReview && !hasConfirmedViolation,
      'is_frozen': isSafetyFreeze,
      'renter_name': renterName,
      'renter_id': renterId,
      'flag_count': flagCount,
      'is_blocked': isBlocked,
      'violated_reasons': violatedReasons,
      'flagged_messages': flaggedMessages,
    };
  }

  Widget _buildOperatorViolationBanner(
    Map<String, dynamic> violation,
    bool isDark,
  ) {
    final renterName = violation['renter_name']?.toString() ?? 'Renter';
    final isFrozen = violation['is_frozen'] == true;
    final isPendingReview = violation['is_pending_review'] == true;
    final reasons = List<String>.from(
      violation['violated_reasons'] as List? ?? [],
    );
    final flaggedMessages = List<Map<String, dynamic>>.from(
      violation['flagged_messages'] as List? ?? [],
    );

    final bannerColor = isPendingReview
        ? Colors.amber.shade900.withValues(alpha: isDark ? 0.28 : 0.14)
        : Colors.red.shade900.withValues(alpha: isDark ? 0.28 : 0.14);
    final borderColor = isPendingReview
        ? Colors.amber.shade600
        : Colors.red.shade600;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isPendingReview ? Colors.amber.shade700 : Colors.red.shade700,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  isPendingReview ? Icons.pending_actions_rounded : Icons.gavel_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isPendingReview
                              ? 'REPORT / MESSAGE FLAGGED — PENDING ADMIN REVIEW'
                              : 'CONVERSATION CLOSED — MESSAGE RULE VIOLATION',
                          style: TextStyle(
                            color: isPendingReview ? Colors.amber.shade400 : Colors.red.shade400,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (isFrozen) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF00E5FF).withOpacity(0.5),
                              ),
                            ),
                            child: const Text(
                              '❄️ BOOKING FROZEN',
                              style: TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isPendingReview
                          ? 'A message in this conversation was flagged by filter and submitted to Admin for verification. Conversation remains active.'
                          : '$renterName violated PSDC messaging guidelines (Confirmed off-platform contact/payment attempt).',
                      style: TextStyle(
                        color: isDark ? Colors.white : _operatorInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (flaggedMessages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.4)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade400.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.report_problem_rounded,
                        size: 14,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'OFFENDING MESSAGE AUDIT EVIDENCE:',
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final fm in flaggedMessages)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.shade300.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((fm['content']?.toString() ?? '').isNotEmpty)
                            Text(
                              '"${fm['content']}"',
                              style: TextStyle(
                                color: isDark ? Colors.yellow.shade100 : Colors.red.shade900,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  fm['risk_level']?.toString() ?? 'FLAGGED',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Reason: ${fm['reason'] ?? 'Off-platform contact attempt'} ${fm['is_account_history'] == true ? '• From user profile history' : ''}',
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[300] : Colors.black87,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ] else if (reasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black38 : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Violation Detail(s):',
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final r in reasons)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: TextStyle(
                                color: Colors.red.shade400,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                r,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.black87,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendMessage(String conversationId, String content) async {
    if (content.trim().isEmpty) return;
    if (_isSendingMessage) return; // prevent double-send

    final selectedConv = _conversations.firstWhere(
      (c) => c['id']?.toString() == conversationId,
      orElse: () => <String, dynamic>{},
    );
    final currentMsgs = _messages[conversationId] ?? const [];
    final check = _checkConversationViolation(selectedConv, currentMsgs);
    if (check['has_violation'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ This conversation is closed due to message policy violations.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isSendingMessage = true);
    _messageController.clear(); // clear immediately to prevent re-submit

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      debugPrint('[Messages] Sending message to conversation: $conversationId');

      final sentMessage = await ChatService().sendMessage(
        conversationId: conversationId,
        senderId: currentUserId,
        content: content,
      );

      // Optimistically merge the sent message immediately so it appears
      // without waiting for the realtime channel event.
      if (mounted) {
        setState(() => _mergeOperatorMessage(conversationId, sentMessage));
      }
      _scrollMessagesToBottom(animate: true);
      debugPrint('[Messages] Message sent successfully');
    } catch (e) {
      debugPrint('[Messages] Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  Widget _buildOperatorParticipantReference(
    List<Map<String, dynamic>> participants,
    bool isDark,
  ) {
    if (participants.isEmpty) return const SizedBox.shrink();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        backgroundColor: isDark
            ? AppColors.darkBgSecondary
            : Colors.grey.shade50,
        collapsedBackgroundColor: isDark
            ? AppColors.darkBgSecondary
            : Colors.grey.shade50,
        iconColor: AppColors.primary,
        collapsedIconColor: isDark
            ? Colors.grey.shade400
            : Colors.grey.shade600,
        title: Text(
          'Conversation profiles',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : _operatorInk,
          ),
        ),
        subtitle: Text(
          '${participants.length} participant${participants.length == 1 ? '' : 's'} - tap to view contact details',
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey[400] : Colors.grey.shade600,
          ),
        ),
        children: [
          SizedBox(
            height: 86,
            child: ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                dragDevices: {
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.touch,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                },
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                itemCount: participants.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) =>
                    _buildParticipantProfileCard(participants[index], isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantProfileCard(
    Map<String, dynamic> participant,
    bool isDark,
  ) {
    final name =
        participant['display_name']?.toString().trim().isNotEmpty == true
        ? participant['display_name'].toString().trim()
        : 'Unknown User';
    final role =
        participant['display_role']?.toString().trim().isNotEmpty == true
        ? participant['display_role'].toString().trim()
        : 'Participant';
    final phone =
        participant['display_phone']?.toString().trim().isNotEmpty == true
        ? participant['display_phone'].toString().trim()
        : '';
    final email = participant['email']?.toString().trim() ?? '';
    final avatar = participant['display_avatar']?.toString().trim() ?? '';
    final detail = phone.isNotEmpty
        ? phone
        : email.isNotEmpty
        ? email
        : 'No contact saved';

    return Container(
      width: 250,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              color: AppColors.primary.withOpacity(0.18),
              child: avatar.isNotEmpty
                  ? OptimizedNetworkImage(imageUrl: avatar, fit: BoxFit.cover)
                  : Text(
                      _initials(name),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[500] : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

