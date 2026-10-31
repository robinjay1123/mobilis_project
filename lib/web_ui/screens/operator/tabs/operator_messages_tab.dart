part of '../operator_web_screen.dart';

extension _OperatorMessagesTab on _OperatorWebScreenState {
  Widget _buildMessagesContent(bool isDark) {
    if (_isLoadingConversations && _conversations.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(42),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.borderColor : Colors.grey.shade200,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: _operatorGold.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: _operatorNavy,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _conversationLoadError ?? 'No booking conversations yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white : _operatorInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _conversationLoadError == null
                    ? 'A group conversation appears after a booking is finalized.'
                    : 'The conversations already in the database were not removed. Try loading them again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _isLoadingConversations ? null : _loadConversations,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Map<String, dynamic>? selectedConversation;
    for (final conversation in _conversations) {
      if (conversation['id']?.toString() == _selectedConversationId) {
        selectedConversation = conversation;
        break;
      }
    }
    var selectedBooking =
        selectedConversation?['bookings'] as Map<String, dynamic>?;
    final selectedBookingId = (selectedConversation?['booking_id'] ?? selectedBooking?['id'])?.toString().trim() ?? '';
    if ((selectedBooking == null || selectedBooking['vehicles'] == null) && selectedBookingId.isNotEmpty) {
      final cached = _recentBookings.firstWhere(
        (b) => b['id']?.toString().trim() == selectedBookingId,
        orElse: () => {},
      );
      if (cached.isNotEmpty) {
        selectedBooking = <String, dynamic>{...cached, ...?selectedBooking};
        if (selectedBooking['vehicles'] == null && cached['vehicles'] != null) {
          selectedBooking['vehicles'] = cached['vehicles'];
        }
      }
    }
    final selectedRenter =
        selectedBooking?['renter'] as Map<String, dynamic>? ?? (selectedBooking?['users'] as Map<String, dynamic>?) ?? {};
    var selectedVehicle = (selectedBooking?['vehicles'] ??
            selectedBooking?['partner_vehicles'] ??
            selectedBooking?['partner_vehicle'] ??
            selectedBooking?['vehicle']) as Map<String, dynamic>? ??
        {};
    if (selectedVehicle.isEmpty ||
        ((selectedVehicle['brand'] == null || selectedVehicle['brand'].toString().trim().isEmpty) &&
            (selectedVehicle['vehicle_name'] == null || selectedVehicle['vehicle_name'].toString().trim().isEmpty))) {
      final vid = (selectedBooking?['vehicle_id'] ?? selectedBooking?['partner_vehicle_id'])?.toString().trim() ?? '';
      if (vid.isNotEmpty) {
        final found = _vehicles.firstWhere(
          (v) => v['id']?.toString() == vid,
          orElse: () => _partnerVehicles.firstWhere(
            (pv) => pv['id']?.toString() == vid,
            orElse: () => {},
          ),
        );
        if (found.isNotEmpty) {
          selectedVehicle = found;
        }
      }
    }
    final selectedStatus =
        selectedBooking?['status']?.toString().toLowerCase() ?? 'active';
    final conversationStatus =
        selectedConversation?['status']?.toString().toLowerCase() ?? 'active';
    final isClosed =
        conversationStatus == 'closed' || selectedStatus == 'completed';
    final messages = _messages[_selectedConversationId] ?? [];
    final violation = _checkConversationViolation(
      selectedConversation,
      messages,
    );
    final hasViolation = violation['has_violation'] == true;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.borderColor : Colors.grey.shade200,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 820;
            final showThreads = !compact || _selectedConversationId.isEmpty;
            final showConversation =
                !compact || _selectedConversationId.isNotEmpty;
            return Row(
              children: [
                if (showThreads)
                  SizedBox(
                    width: compact ? constraints.maxWidth : 360,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(22, 22, 18, 18),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withOpacity(0.12)
                                : const Color(0xFFFAFBFC),
                            border: Border(
                              bottom: BorderSide(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey.shade200,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Active Threads',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : _operatorInk,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${_conversations.length} booking conversations',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey.shade600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Refresh conversations',
                                onPressed: _loadConversations,
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: _conversations.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 9),
                            itemBuilder: (context, index) =>
                                _buildOperatorConversationTile(
                                  _conversations[index],
                                  isDark,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!compact)
                  VerticalDivider(
                    width: 1,
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                if (showConversation)
                  Expanded(
                    child: _selectedConversationId.isEmpty
                        ? _buildOperatorEmptyConversation(isDark)
                        : Column(
                            children: [
                              _buildOperatorConversationHeader(
                                selectedConversation,
                                selectedRenter,
                                selectedVehicle,
                                selectedStatus,
                                compact,
                                isDark,
                                hasViolation: hasViolation,
                              ),
                              if (hasViolation || violation['is_pending_review'] == true)
                                _buildOperatorViolationBanner(
                                  violation,
                                  isDark,
                                ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                child: _showOperatorBookingActivity
                                    ? _buildOperatorOngoingConversationBanner(
                                        selectedBooking,
                                        selectedVehicle,
                                        isDark,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              Expanded(
                                child: messages.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No messages yet',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      )
                                    : NotificationListener<
                                        UserScrollNotification
                                      >(
                                        onNotification: (notification) {
                                          if (notification.direction !=
                                                  ScrollDirection.idle &&
                                              _showOperatorBookingActivity) {
                                            setState(
                                              () =>
                                                  _showOperatorBookingActivity =
                                                      false,
                                            );
                                          }
                                          return false;
                                        },
                                        child: ListView.builder(
                                          controller: _messageScrollController,
                                          padding: const EdgeInsets.fromLTRB(
                                            28,
                                            22,
                                            28,
                                            12,
                                          ),
                                          itemCount: messages.length,
                                          itemBuilder: (context, index) =>
                                              _buildOperatorMessageBubble(
                                                messages[index],
                                                isDark,
                                              ),
                                        ),
                                      ),
                              ),
                              _buildOperatorMessageComposer(
                                isClosed || hasViolation,
                                isDark,
                                hasViolation: hasViolation,
                              ),
                            ],
                          ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOperatorConversationTile(
    Map<String, dynamic> conversation,
    bool isDark,
  ) {
    final conversationId = conversation['id']?.toString() ?? '';
    var booking = conversation['bookings'] as Map<String, dynamic>? ?? {};
    final bookingId = (conversation['booking_id'] ?? booking['id'])?.toString().trim() ?? '';
    if ((booking.isEmpty || booking['vehicles'] == null) && bookingId.isNotEmpty) {
      final cached = _recentBookings.firstWhere(
        (b) => b['id']?.toString().trim() == bookingId,
        orElse: () => {},
      );
      if (cached.isNotEmpty) {
        booking = <String, dynamic>{...cached, ...booking};
        if (booking['vehicles'] == null && cached['vehicles'] != null) {
          booking['vehicles'] = cached['vehicles'];
        }
      }
    }
    final renter = booking['renter'] as Map<String, dynamic>? ?? (booking['users'] as Map<String, dynamic>?) ?? {};
    var vehicle = (booking['vehicles'] ??
            booking['partner_vehicles'] ??
            booking['partner_vehicle'] ??
            booking['vehicle']) as Map<String, dynamic>? ??
        {};
    if (vehicle.isEmpty ||
        ((vehicle['brand'] == null || vehicle['brand'].toString().trim().isEmpty) &&
            (vehicle['vehicle_name'] == null || vehicle['vehicle_name'].toString().trim().isEmpty))) {
      final vid = (booking['vehicle_id'] ?? booking['partner_vehicle_id'])?.toString().trim() ?? '';
      if (vid.isNotEmpty) {
        final found = _vehicles.firstWhere(
          (v) => v['id']?.toString() == vid,
          orElse: () => _partnerVehicles.firstWhere(
            (pv) => pv['id']?.toString() == vid,
            orElse: () => {},
          ),
        );
        if (found.isNotEmpty) {
          vehicle = found;
        }
      }
    }
    
    var renterName = renter['full_name']?.toString()?.trim() ?? '';
    if (renterName.isEmpty || renterName.toLowerCase() == 'unknown renter') {
      final userObj = conversation['users'] as Map<String, dynamic>?;
      final otherUserObj = conversation['other_users'] as Map<String, dynamic>?;
      if (userObj != null && userObj['full_name']?.toString().trim().isNotEmpty == true) {
        renterName = userObj['full_name'].toString().trim();
      } else if (otherUserObj != null && otherUserObj['full_name']?.toString().trim().isNotEmpty == true) {
        renterName = otherUserObj['full_name'].toString().trim();
      }
    }
    if (renterName.isEmpty || renterName.toLowerCase() == 'unknown renter') {
      final participants = _conversationParticipants[conversationId];
      if (participants != null && participants.isNotEmpty) {
        for (final p in participants) {
          final pRole = p['role']?.toString().toLowerCase() ?? '';
          if (pRole == 'renter' || pRole == 'customer' || pRole == 'user') {
            final pName = (p['full_name'] ?? p['display_name'])?.toString().trim() ?? '';
            if (pName.isNotEmpty) {
              renterName = pName;
              break;
            }
          }
        }
      }
    }
    if (renterName.isEmpty || renterName.toLowerCase() == 'unknown renter') {
      renterName = 'Renter';
    }

    final vehicleName = [
      vehicle['brand'],
      vehicle['model'],
    ].where((value) => value?.toString().trim().isNotEmpty == true).join(' ');
    final vehicleDisplay = vehicleName.isNotEmpty
        ? vehicleName
        : (vehicle['vehicle_name']?.toString().trim().isNotEmpty == true
            ? vehicle['vehicle_name'].toString().trim()
            : (vehicle['plate_number']?.toString().trim().isNotEmpty == true
                ? 'Vehicle (${vehicle['plate_number'].toString().trim()})'
                : ''));
    final status = booking['status']?.toString() ?? 'pending';
    var imageUrl = _operatorVehicleImageUrl(vehicle, conversation, booking);
    if (imageUrl.isEmpty) {
      final vid = (vehicle['id'] ?? booking['vehicle_id'] ?? booking['partner_vehicle_id'])?.toString() ?? '';
      if (vid.isNotEmpty) {
        final found = _vehicles.firstWhere(
          (v) => v['id']?.toString() == vid,
          orElse: () => _partnerVehicles.firstWhere(
            (pv) => pv['id']?.toString() == vid,
            orElse: () => {},
          ),
        );
        if (found.isNotEmpty) {
          imageUrl = _operatorVehicleImageUrl(found, conversation, booking);
        }
      }
    }
    final selected = conversationId == _selectedConversationId;
    final shortId = conversation['booking_id']?.toString() ?? conversationId;
    final displayId = shortId.length > 8
        ? shortId.substring(0, 8).toUpperCase()
        : shortId.toUpperCase();

    final unreadCount = _conversationUnreadCounts[conversationId] ?? 0;
    final messages = _messages[conversationId] ?? const [];
    final violation = _checkConversationViolation(conversation, messages);
    final hasViolation = violation['has_violation'] == true;
    final isFrozen = violation['is_frozen'] == true ||
        booking['safety_freeze'] == true ||
        status.trim().toLowerCase() == 'frozen';

    return InkWell(
      onTap: () {
        if (_selectedConversationId == conversationId) {
          setState(() => _selectedConversationId = '');
          return;
        }
        setState(() {
          _selectedConversationId = conversationId;
          _showOperatorBookingActivity = true;
        });
        _loadConversationMessages(conversationId);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? (isDark
                    ? _operatorGold.withOpacity(0.16)
                    : const Color(0xFFFFF8DC))
              : (hasViolation || isFrozen)
              ? (isDark
                    ? Colors.red.shade900.withValues(alpha: 0.14)
                    : Colors.red.shade50.withValues(alpha: 0.6))
              : (isDark
                    ? Colors.white.withOpacity(0.035)
                    : const Color(0xFFF6F7F8)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? _operatorGold
                : (hasViolation || isFrozen)
                ? Colors.red.shade500
                : (isDark ? Colors.white10 : Colors.transparent),
            width: (selected || hasViolation || isFrozen) ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  margin: const EdgeInsets.only(right: 10),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: imageUrl.isNotEmpty
                      ? OptimizedNetworkImage(
                          imageUrl: imageUrl,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(12),
                          errorWidget: const Icon(
                            Icons.directions_car_outlined,
                          ),
                        )
                      : const Icon(Icons.directions_car_outlined),
                ),
                Text(
                  '#$displayId',
                  style: TextStyle(
                    color: isDark ? Colors.white : _operatorInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                if (unreadCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _operatorGold,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$unreadCount new',
                      style: TextStyle(
                        color: _operatorNavy,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (hasViolation) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '⚠️ BANNED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ] else if (violation['is_pending_review'] == true) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '⏳ REVIEW PENDING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                _buildStatusBadge(isFrozen ? 'frozen' : status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              renterName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white : _operatorInk,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Builder(
              builder: (context) {
                final plate = vehicle['plate_number']?.toString().trim() ?? '';
                final displayWithPlate = vehicleDisplay.isNotEmpty && plate.isNotEmpty && !vehicleDisplay.contains(plate)
                    ? '$vehicleDisplay • $plate'
                    : vehicleDisplay;
                return Text(
                  displayWithPlate.isEmpty ? 'Booking conversation' : displayWithPlate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    fontSize: 11,
                  ),
                );
              },
            ),
            if (hasViolation || isFrozen) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 13,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      isFrozen
                          ? 'Safety Freeze active • Rule violation'
                          : 'Message rule violation detected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _operatorVehicleImageUrl(
    Map<String, dynamic> vehicle, [
    Map<String, dynamic>? conversation,
    Map<String, dynamic>? booking,
  ]) {
    final direct = (vehicle['image_url'] ??
            vehicle['imageUrl'] ??
            vehicle['photo_url'] ??
            vehicle['vehicle_image_url'] ??
            vehicle['thumbnail_url'])
        ?.toString()
        .trim() ?? '';
    if (direct.isNotEmpty) return _normalizeVehicleImageUrl(direct);

    final rawImages = (vehicle['vehicle_images'] ??
            vehicle['images'] ??
            vehicle['photos']) as List? ??
        const [];
    final images = List<Map<String, dynamic>>.from(
      rawImages.whereType<Map<String, dynamic>>(),
    )..sort((a, b) {
        final aOrder = (a['display_order'] as num?)?.toInt() ?? 999;
        final bOrder = (b['display_order'] as num?)?.toInt() ?? 999;
        return aOrder.compareTo(bOrder);
      });
    for (final image in images) {
      final url = (image['image_url'] ?? image['url'] ?? image['image'])
          ?.toString()
          .trim() ?? '';
      if (url.isNotEmpty) return _normalizeVehicleImageUrl(url);
    }

    if (booking != null) {
      final bDirect = (booking['vehicle_image_url'] ??
              booking['image_url'] ??
              booking['photo_url'])
          ?.toString()
          .trim() ?? '';
      if (bDirect.isNotEmpty) return _normalizeVehicleImageUrl(bDirect);

      final pv = (booking['partner_vehicles'] ?? booking['partner_vehicle']);
      if (pv is Map<String, dynamic>) {
        final pvUrl = _operatorVehicleImageUrl(pv);
        if (pvUrl.isNotEmpty) return pvUrl;
      }
    }

    if (conversation != null) {
      final cDirect = (conversation['vehicle_image_url'] ??
              conversation['image_url'])
          ?.toString()
          .trim() ?? '';
      if (cDirect.isNotEmpty) return _normalizeVehicleImageUrl(cDirect);
    }

    return '';
  }

  Widget _buildOperatorEmptyConversation(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 58,
            color: isDark ? Colors.grey[600] : Colors.grey.shade300,
          ),
          const SizedBox(height: 14),
          Text(
            'Select a booking conversation',
            style: TextStyle(
              color: isDark ? Colors.white : _operatorInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Messages from the renter, driver, and vehicle owner appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey.shade600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorConversationHeader(
    Map<String, dynamic>? conversation,
    Map<String, dynamic> renter,
    Map<String, dynamic> vehicle,
    String status,
    bool compact,
    bool isDark, {
    bool hasViolation = false,
  }) {
    final bookingId = conversation?['booking_id']?.toString() ?? '';
    final shortId = bookingId.length > 8
        ? bookingId.substring(0, 8).toUpperCase()
        : bookingId.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.12) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          if (compact) ...[
            IconButton(
              onPressed: () => setState(() => _selectedConversationId = ''),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
          ],
          Builder(
            builder: (context) {
              final headerImg = _operatorVehicleImageUrl(vehicle, conversation);
              if (headerImg.isNotEmpty && !hasViolation) {
                return Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 12),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: OptimizedNetworkImage(
                    imageUrl: headerImg,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(11),
                    errorWidget: const Icon(
                      Icons.directions_car_outlined,
                      size: 20,
                    ),
                  ),
                );
              }
              return Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(right: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hasViolation ? Colors.red.shade900 : _operatorNavy,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  hasViolation ? Icons.gavel_rounded : Icons.directions_car_rounded,
                  color: hasViolation ? Colors.white : _operatorGold,
                  size: 19,
                ),
              );
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shortId.isEmpty
                      ? 'Booking Conversation'
                      : 'Booking #$shortId',
                  style: TextStyle(
                    color: isDark ? Colors.white : _operatorInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Builder(
                  builder: (context) {
                    final brandModel = [
                      vehicle['brand'],
                      vehicle['model'],
                    ].where((value) => value?.toString().trim().isNotEmpty == true).join(' ');
                    final carName = brandModel.isNotEmpty
                        ? brandModel
                        : (vehicle['vehicle_name']?.toString().trim().isNotEmpty == true
                            ? vehicle['vehicle_name'].toString().trim()
                            : '');
                    final plate = vehicle['plate_number']?.toString().trim() ?? '';
                    final carWithPlate = carName.isNotEmpty && plate.isNotEmpty
                        ? '$carName ($plate)'
                        : (carName.isNotEmpty ? carName : plate);
                    final rName = (renter['full_name'] ?? renter['name'] ?? 'Renter').toString().trim();
                    final subtitle = carWithPlate.isNotEmpty
                        ? '$rName • $carWithPlate'
                        : rName;
                    return Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (hasViolation) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Rule Violated',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          _buildStatusBadge(status),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Conversation options',
            onPressed: () => _showOperatorConversationOptions(isDark),
            icon: const Icon(Icons.more_vert_rounded),
          ),
          IconButton(
            tooltip: 'Unselect conversation',
            onPressed: () => setState(() => _selectedConversationId = ''),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Future<void> _showOperatorConversationOptions(bool isDark) async {
    final participants =
        _conversationParticipants[_selectedConversationId] ??
        const <Map<String, dynamic>>[];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _operatorGold.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        Icons.groups_2_outlined,
                        color: _operatorGold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Conversation details',
                            style: TextStyle(
                              color: isDark ? Colors.white : _operatorInk,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${participants.length} booking participant${participants.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (participants.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBgSecondary
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Participant details are not available yet.',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 92,
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
                            _buildParticipantProfileCard(
                              participants[index],
                              isDark,
                            ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: BorderSide(
                        color: _operatorGold.withValues(alpha: 0.55),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) showPolicyDetailsSheet(context);
                      });
                    },
                    icon: Icon(Icons.policy_outlined, color: _operatorGold),
                    label: Text(
                      'View conversation policy',
                      style: TextStyle(
                        color: isDark ? Colors.white : _operatorInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorOngoingConversationBanner(
    Map<String, dynamic>? booking,
    Map<String, dynamic> vehicle,
    bool isDark,
  ) {
    final status = booking?['status']?.toString().trim().toLowerCase();
    if (status != 'ongoing' && status != 'active') {
      return const SizedBox.shrink();
    }

    final vehicleName = [
      vehicle['brand']?.toString().trim(),
      vehicle['model']?.toString().trim(),
    ].whereType<String>().where((value) => value.isNotEmpty).join(' ');
    final returnAt = DateTime.tryParse(
      (booking?['end_at'] ?? booking?['end_date'])?.toString() ?? '',
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: isDark ? 0.13 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.38)),
      ),
      child: Row(
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.route_rounded,
              size: 17,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'ONGOING BOOKING  ',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  TextSpan(
                    text: vehicleName.isEmpty ? 'Active rental' : vehicleName,
                    style: TextStyle(
                      color: isDark ? Colors.white : _operatorInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (returnAt != null) ...[
            const SizedBox(width: 12),
            Text(
              'Return ${_formatBookingDateTime(returnAt)}',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOperatorMessageBubble(
    Map<String, dynamic> message,
    bool isDark,
  ) {
    final currentUserId = _supabase.auth.currentUser?.id;
    final isOwn = message['sender_id']?.toString() == currentUserId;
    final sender = message['sender'] as Map<String, dynamic>? ?? {};
    final senderName = sender['full_name']?.toString() ?? 'System';
    final content =
        message['content']?.toString() ?? message['message']?.toString() ?? '';
    final isDeleted = message['is_deleted'] == true;

    String attachmentUrl = '';
    if (!isDeleted) {
      attachmentUrl =
          (message['attachment_url'] ??
                  message['image_url'] ??
                  message['file_url'] ??
                  message['media_url'] ??
                  message['url'] ??
                  message['attachment'])
              ?.toString()
              .trim() ??
          '';

      if (attachmentUrl.isEmpty &&
          content.trim().startsWith(
            RegExp(r'https?://', caseSensitive: false),
          )) {
        final trimmed = content.trim();
        final lower = trimmed.toLowerCase();
        if (RegExp(
              r'\.(png|jpe?g|webp|gif|heic|bmp|tiff)(\?|$)',
              caseSensitive: false,
            ).hasMatch(trimmed) ||
            lower.contains('/chat-attachments/') ||
            lower.contains('/chat/') ||
            lower.contains('/storage/v1/object/')) {
          attachmentUrl = trimmed;
        }
      }
    }

  String _formatOperatorMessageTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp.toString()).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

    final attachmentType =
        (message['attachment_type'] ?? message['type'])?.toString().trim() ??
        '';
    final attachmentName =
        (message['attachment_name'] ?? message['name'])?.toString().trim() ??
        'Attachment';

    final isAutoGenerated = message['is_auto_generated'] == true ||
        (message['is_system'] == true) ||
        MessageFilterService.isSystemOrAuditMessage(content) ||
        content.trim().startsWith('[System]') ||
        content.trim().startsWith('Booking Details') ||
        content.trim().startsWith('Booking Confirmed') ||
        content.contains('Checklist Submitted');

    Map<String, dynamic>? violationAnalysis;
    if (!isAutoGenerated && !isOwn && content.trim().isNotEmpty && !isDeleted) {
      final analysis = MessageFilterService.analyzeMessage(content);
      if (analysis['is_suspicious'] == true ||
          message['is_flagged'] == true ||
          message['is_blocked_flag'] == true) {
        violationAnalysis = analysis;
      }
    }
    final isViolatingMessage = violationAnalysis != null ||
        message['is_flagged'] == true ||
        message['is_blocked_flag'] == true;
    final violationKeywords = isViolatingMessage
        ? ((violationAnalysis != null &&
                (violationAnalysis['found_keywords'] as List?)
                        ?.isNotEmpty ==
                    true)
            ? List<String>.from(violationAnalysis['found_keywords'] as List)
            : [
                message['flag_reason']?.toString() ??
                    'Off-platform contact attempt'
              ])
        : <String>[];

    final showContentText =
        isDeleted ||
        (content.trim().isNotEmpty && content.trim() != attachmentUrl);

    if (isAutoGenerated) {
      final isInspectionNote = content.contains('Checklist Submitted') ||
          content.contains('Inspection');
      final isPaymentNote = content.contains('FULL PAYMENT') ||
          content.contains('Full Payment') ||
          content.contains('💳');
      final cardBorderColor = isPaymentNote
          ? const Color(0xFF10B981)
          : (isDark ? _operatorNavy : const Color(0xFFD97706));
      final cardBg = isPaymentNote
          ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFECFDF5))
          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB));
      return Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border(
                  left: BorderSide(
                    color: cardBorderColor,
                    width: 4,
                  ),
                  top: BorderSide(
                    color: isDark ? Colors.white10 : const Color(0xFFFCD34D),
                    width: 0.5,
                  ),
                  right: BorderSide(
                    color: isDark ? Colors.white10 : const Color(0xFFFCD34D),
                    width: 0.5,
                  ),
                  bottom: BorderSide(
                    color: isDark ? Colors.white10 : const Color(0xFFFCD34D),
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isInspectionNote
                            ? (isPaymentNote ? Icons.verified_rounded : Icons.assignment_turned_in_rounded)
                            : (isPaymentNote ? Icons.verified_rounded : Icons.description_outlined),
                        size: 16,
                        color: isDark ? Colors.amber : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isInspectionNote
                              ? (isPaymentNote ? 'SYSTEM NOTE • FULL PAYMENT VERIFIED' : 'SYSTEM NOTE • VEHICLE INSPECTION RECORD')
                              : (isPaymentNote ? 'SYSTEM NOTE • FULL PAYMENT VERIFIED' : 'SYSTEM NOTE • BOOKING DETAILS'),
                          style: TextStyle(
                            color: isDark ? Colors.amber : const Color(0xFFD97706),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.amber : const Color(0xFFD97706))
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isPaymentNote ? 'PAID IN FULL' : 'NOTE',
                          style: TextStyle(
                            color: isDark ? Colors.amber : const Color(0xFFD97706),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (attachmentUrl.isNotEmpty) ...[
                    _buildOperatorAttachmentPreview(
                      url: attachmentUrl,
                      type: attachmentType,
                      name: attachmentName,
                      isOwn: false,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    content.replaceFirst(RegExp(r'\n\n\[Audit: [^\]]+\]\s*$'), '').trim(),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _formatOperatorMessageTime(message['created_at']),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[400] : const Color(0xFF78350F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: Column(
            crossAxisAlignment: isOwn
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  isOwn ? 'You (Operator)' : senderName,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: isOwn
                      ? _operatorNavy
                      : isViolatingMessage
                      ? (isDark
                            ? Colors.red.shade900.withValues(alpha: 0.35)
                            : Colors.red.shade50)
                      : (isDark
                            ? Colors.white.withOpacity(0.07)
                            : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isOwn ? 16 : 4),
                    bottomRight: Radius.circular(isOwn ? 4 : 16),
                  ),
                  border: isOwn
                      ? null
                      : Border.all(
                          color: isViolatingMessage
                              ? Colors.red.shade600
                              : (isDark ? Colors.white10 : Colors.grey.shade200),
                          width: isViolatingMessage ? 1.5 : 1.0,
                        ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isViolatingMessage) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                message['is_blocked_flag'] == true
                                    ? '🚨 BLOCKED VIOLATION: ${violationKeywords.isNotEmpty ? violationKeywords.join(', ') : 'Off-platform contact'}'
                                    : '🚨 FLAGGED VIOLATION: ${violationKeywords.isNotEmpty ? violationKeywords.join(', ') : 'Off-platform contact'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (attachmentUrl.isNotEmpty)
                      _buildOperatorAttachmentPreview(
                        url: attachmentUrl,
                        type: attachmentType,
                        name: attachmentName,
                        isOwn: isOwn,
                        isDark: isDark,
                      ),
                    if (attachmentUrl.isNotEmpty && showContentText)
                      const SizedBox(height: 9),
                    if (showContentText)
                      Text(
                        isDeleted ? 'Message deleted' : content,
                        style: TextStyle(
                          color: isOwn
                              ? Colors.white
                              : (isDark ? Colors.white : _operatorInk),
                          fontSize: 13,
                          height: 1.35,
                          fontStyle: isDeleted
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              RelativeTimeText(
                value: message['created_at'],
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey.shade500,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorAttachmentPreview({
    required String url,
    required String type,
    required String name,
    required bool isOwn,
    required bool isDark,
  }) {
    final normalizedType = type.toLowerCase();
    final normalizedUrl = url.toLowerCase();
    final normalizedName = name.toLowerCase();

    final isImage =
        normalizedType.contains('image') ||
        normalizedType.contains('photo') ||
        normalizedType.contains('picture') ||
        normalizedType.contains('img') ||
        normalizedName.contains('image') ||
        normalizedName.contains('photo') ||
        RegExp(
          r'\.(png|jpe?g|webp|gif|heic|bmp|tiff|svg)(\?|$)',
          caseSensitive: false,
        ).hasMatch(url) ||
        normalizedUrl.contains('/chat-attachments/') ||
        normalizedUrl.contains('/chat_attachments/') ||
        normalizedUrl.contains('/images/') ||
        normalizedUrl.contains('/photos/') ||
        normalizedUrl.contains('/uploads/');

    final isVideo =
        normalizedType.contains('video') ||
        RegExp(
          r'\.(mp4|mov|m4v|webm)(\?|$)',
          caseSensitive: false,
        ).hasMatch(url);

    if (isImage) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showOperatorImageAttachment(url, name),
        child: Stack(
          children: [
            OptimizedNetworkImage(
              imageUrl: url,
              width: 360,
              height: 210,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(12),
              errorWidget: const SizedBox(
                width: 300,
                height: 150,
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.fullscreen_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final foreground = isOwn
        ? Colors.white
        : (isDark ? Colors.white : _operatorInk);
    return Material(
      color: Colors.black.withOpacity(0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isVideo) {
            showDialog<void>(
              context: context,
              builder: (_) =>
                  _OperatorVideoAttachmentViewer(url: url, title: name),
            );
            return;
          }
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _operatorGold.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isVideo
                      ? Icons.play_arrow_rounded
                      : Icons.insert_drive_file_outlined,
                  color: isVideo ? _operatorGold : foreground,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isVideo ? 'Tap to play video' : 'Tap to open file',
                      style: TextStyle(
                        color: foreground.withOpacity(0.68),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                isVideo ? Icons.play_circle_outline : Icons.open_in_new,
                color: foreground,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOperatorImageAttachment(String url, String name) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(28),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Center(
                child: OptimizedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  errorWidget: const Center(
                    child: Text(
                      'This image could not be loaded.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton.filled(
                tooltip: 'Close $name',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorMessageComposer(
    bool isClosed,
    bool isDark, {
    bool hasViolation = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: hasViolation
            ? (isDark
                  ? const Color(0xFF2C0A0A).withOpacity(0.35)
                  : Colors.red.shade50)
            : isDark
            ? Colors.black.withOpacity(0.12)
            : const Color(0xFFFAFBFC),
        border: Border(
          top: BorderSide(
            color: hasViolation
                ? Colors.red.shade600
                : (isDark ? Colors.white10 : Colors.grey.shade200),
          ),
        ),
      ),
      child: hasViolation
          ? Row(
              children: [
                Icon(Icons.lock_rounded, color: Colors.red.shade400, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '🔒 Conversation Closed: Locked due to renter message policy violation (off-platform contact attempt).',
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            )
          : isClosed
          ? Text(
              'This completed booking conversation is read-only.',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey.shade600,
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => _sendMessage(
                      _selectedConversationId,
                      _messageController.text,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type a message to the booking team...',
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _isSendingMessage
                      ? null
                      : () => _sendMessage(
                          _selectedConversationId,
                          _messageController.text,
                        ),
                  style: IconButton.styleFrom(
                    backgroundColor: _isSendingMessage
                        ? Colors.grey
                        : _operatorGold,
                    foregroundColor: _operatorNavyDeep,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: _isSendingMessage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
    );
  }

  Widget _buildLegacyMessagesContent(bool isDark) {
    // Show empty state if no conversations
    if (_conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.message_outlined,
                size: 64,
                color: isDark ? Colors.grey[600] : Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No conversations yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Conversations will appear when you confirm bookings',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[500] : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedConversationId.isEmpty) {
      // Show conversation list only
      return Row(
        children: [
          // Conversations list (left sidebar)
          Container(
            width: 320,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade200,
                ),
              ),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _conversations.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final conversation = _conversations[index];
                final conversationId = conversation['id'] as String? ?? '';

                // Safely extract booking info
                var renterName = 'Unknown Renter';
                var vehicleInfo = 'No vehicle info';
                var status = 'PENDING';

                try {
                  final bookings = conversation['bookings'];
                  if (bookings is Map<String, dynamic>) {
                    final renter = bookings['renter'];
                    if (renter is Map<String, dynamic>) {
                      renterName =
                          renter['full_name'] as String? ?? 'Unknown Renter';
                    }

                    final vehicles = bookings['vehicles'];
                    if (vehicles is Map<String, dynamic>) {
                      final brand = vehicles['brand'] as String? ?? '';
                      final model = vehicles['model'] as String? ?? '';
                      vehicleInfo = '$brand $model'.trim();
                    }

                    status = (bookings['status'] as String? ?? 'PENDING')
                        .toUpperCase();
                  }
                } catch (e) {
                  debugPrint('[Messages] Error extracting booking info: $e');
                }

                return InkWell(
                  onTap: () {
                    setState(() => _selectedConversationId = conversationId);
                    _loadConversationMessages(conversationId);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          renterName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          vehicleInfo.isEmpty ? 'No vehicle info' : vehicleInfo,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey[400]
                                : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: status == 'CONFIRMED'
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Empty chat area
          Expanded(
            child: Center(
              child: Text(
                'Select a conversation to start messaging',
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Show conversation detail with chat
    var renterName = 'Conversation';
    var vehicleInfo = 'Vehicle';
    var status = 'pending';
    var conversationStatus = 'active';

    try {
      final conversation = _conversations.firstWhere(
        (c) => c['id'] == _selectedConversationId,
        orElse: () => {},
      );

      if (conversation.isNotEmpty) {
        conversationStatus =
            conversation['status']?.toString().toLowerCase() ?? 'active';
        final bookings = conversation['bookings'];
        if (bookings is Map<String, dynamic>) {
          final renter = bookings['renter'];
          if (renter is Map<String, dynamic>) {
            renterName = renter['full_name'] as String? ?? 'Unknown';
          }

          final vehicles = bookings['vehicles'];
          if (vehicles is Map<String, dynamic>) {
            final brand = vehicles['brand'] as String? ?? '';
            final model = vehicles['model'] as String? ?? '';
            vehicleInfo = '$brand $model'.trim();
          }

          status = bookings['status'] as String? ?? 'pending';
        }
      }
    } catch (e) {
      debugPrint('[Messages] Error extracting conversation data: $e');
    }

    final conversationMessages = _messages[_selectedConversationId] ?? [];
    final isConversationClosed =
        conversationStatus == 'closed' || status.toLowerCase() == 'completed';

    return Row(
      children: [
        // Conversations list (left sidebar)
        Container(
          width: 320,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: isDark ? AppColors.borderColor : Colors.grey.shade200,
              ),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () =>
                          setState(() => _selectedConversationId = ''),
                    ),
                    Expanded(
                      child: Text(
                        renterName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _conversations.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final conv = _conversations[index];
                    final isSelected = conv['id'] == _selectedConversationId;

                    var rnt = 'Unknown';
                    try {
                      final bookings = conv['bookings'];
                      if (bookings is Map<String, dynamic>) {
                        final renter = bookings['renter'];
                        if (renter is Map<String, dynamic>) {
                          rnt = renter['full_name'] as String? ?? 'Unknown';
                        }
                      }
                    } catch (e) {
                      debugPrint('[Messages] Error extracting renter name: $e');
                    }

                    return InkWell(
                      onTap: () {
                        setState(() => _selectedConversationId = conv['id']);
                        _loadConversationMessages(conv['id']);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.2)
                              : (isDark ? Colors.black26 : Colors.grey.shade50),
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: AppColors.primary)
                              : null,
                        ),
                        child: Text(
                          rnt,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Chat area (right side)
        Expanded(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? AppColors.borderColor
                          : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isDark ? Colors.black26 : Colors.grey.shade200,
                      ),
                      child: Icon(
                        Icons.directions_car,
                        color: isDark ? Colors.grey[600] : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$renterName - Booking',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            '$vehicleInfo (${status.toUpperCase()})',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildOperatorParticipantReference(
                _conversationParticipants[_selectedConversationId] ?? [],
                isDark,
              ),
              // Messages
              Expanded(
                child: conversationMessages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey[500]
                                : Colors.grey.shade600,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: conversationMessages.length,
                        itemBuilder: (context, index) {
                          final message = conversationMessages[index];
                          final currentUserId = _supabase.auth.currentUser?.id;
                          final isOwn = message['sender_id'] == currentUserId;

                          var senderName = 'System';
                          try {
                            final sender = message['sender'];
                            if (sender is Map<String, dynamic>) {
                              senderName =
                                  sender['full_name'] as String? ?? 'System';
                            }
                          } catch (e) {
                            debugPrint(
                              '[Messages] Error extracting sender name: $e',
                            );
                          }

                          return Align(
                            alignment: isOwn
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isOwn
                                    ? AppColors.primary
                                    : (isDark
                                          ? Colors.black26
                                          : Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isOwn)
                                    Text(
                                      senderName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  if (!isOwn) const SizedBox(height: 4),
                                  Text(
                                    (message['content'] as String?) ??
                                        (message['message'] as String?) ??
                                        '',
                                    style: TextStyle(
                                      color: isOwn
                                          ? const Color(0xFF101820)
                                          : (isDark
                                                ? Colors.white
                                                : Colors.black),
                                      fontWeight: isOwn
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  RelativeTimeText(
                                    value: message['created_at'],
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isOwn
                                          ? const Color(0xA6101820)
                                          : (isDark
                                                ? Colors.grey[500]
                                                : Colors.grey.shade600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              // Input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? AppColors.borderColor
                          : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: isConversationClosed
                    ? Text(
                        'This booking is completed. The group chat is closed.',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              maxLines: 1,
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.grey[600]
                                      : Colors.grey.shade400,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? AppColors.borderColor
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => _sendMessage(
                              _selectedConversationId,
                              _messageController.text,
                            ),
                            icon: const Icon(Icons.send, size: 18),
                            label: const Text('Send'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

