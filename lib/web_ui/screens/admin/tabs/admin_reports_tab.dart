part of '../admin_web_screen.dart';

extension _AdminReportsTab on _AdminWebScreenState {
  Future<void> _loadUserReports({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _isLoadingReports = true);
    }
    try {
      final reports = await ReportService().getPendingReports();
      if (!mounted) return;
      setState(() {
        _userReports = reports;
        _pendingReportsCount = reports.where((r) => r['status'] == 'pending').length;
      });
    } catch (e) {
      debugPrint('Error loading user reports: $e');
    } finally {
      if (mounted && showLoading) {
        setState(() => _isLoadingReports = false);
      }
    }
  }

  Future<void> _banUserFromReportDialog(Map<String, dynamic> report, bool isDark) async {
    final reportedUser = report['reported_user'] as Map<String, dynamic>?;
    final reportedName = reportedUser?['full_name']?.toString() ?? 'User';
    final reportedEmail = reportedUser?['email']?.toString() ?? '';
    final reportedRole = reportedUser?['role']?.toString().toUpperCase() ?? 'PARTICIPANT';
    final reportedUserId = report['reported_user_id']?.toString() ?? '';
    final reportId = report['id']?.toString() ?? '';
    final category = report['category']?.toString() ?? 'General Incident';
    final description = report['description']?.toString() ?? '';

    final reasonController = TextEditingController(
      text: 'Incident violation ($category): $description',
    );

    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setModalState) {
          final bg = isDark ? _adminNavyDeep : Colors.white;
          final cardBg = isDark ? const Color(0xFF021F35) : const Color(0xFFF8FAFC);
          final textColor = isDark ? Colors.white : _adminInk;

          return Dialog(
            backgroundColor: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Colors.red.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.gavel_rounded,
                            color: Colors.red,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ban User Account',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Immediate suspension of app access & bookings',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                reportedName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  reportedRole,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (reportedEmail.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              reportedEmail,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Report Category: $category\n"$description"',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Reason for Ban (Logged in Audit Trail):',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      style: TextStyle(fontSize: 13, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Enter specific justification for banning this account...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.red, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final reason = reasonController.text.trim();
                                  if (reason.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please provide a reason for the ban.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final currentAdminId = _supabase.auth.currentUser?.id ?? '';
                                    await ReportService().banReportedUser(
                                      reportId: reportId,
                                      reportedUserId: reportedUserId,
                                      adminId: currentAdminId,
                                      banReason: reason,
                                    );
                                    if (mounted) {
                                      Navigator.pop(dialogContext);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Account for $reportedName has been permanently banned.'),
                                          backgroundColor: Colors.red.shade700,
                                        ),
                                      );
                                      await _loadUserReports(showLoading: false);
                                      await _loadAllUsers();
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (dialogContext.mounted) {
                                      setModalState(() => isSubmitting = false);
                                    }
                                  }
                                },
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.block_rounded, size: 16),
                          label: Text(isSubmitting ? 'Banning...' : 'Confirm Ban'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _resolveReportDialog(Map<String, dynamic> report, bool isDark) async {
    final reportId = report['id']?.toString() ?? '';
    final notesController = TextEditingController();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setModalState) {
          final bg = isDark ? _adminNavyDeep : Colors.white;
          final textColor = isDark ? Colors.white : _adminInk;

          return AlertDialog(
            backgroundColor: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.green,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Resolve Incident Report',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mark this report as resolved or settled with the involved parties.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    style: TextStyle(fontSize: 13, color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Resolution Notes / Settlement Details',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setModalState(() => isSubmitting = true);
                        try {
                          final currentAdminId = _supabase.auth.currentUser?.id ?? '';
                          await ReportService().resolveReport(
                            reportId: reportId,
                            adminId: currentAdminId,
                            resolutionNotes: notesController.text.trim().isNotEmpty
                                ? notesController.text.trim()
                                : 'Resolved by Admin after review',
                          );
                          if (mounted) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Report marked as resolved.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            await _loadUserReports(showLoading: false);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        } finally {
                          if (dialogContext.mounted) {
                            setModalState(() => isSubmitting = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(isSubmitting ? 'Saving...' : 'Mark Resolved'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showReportEvidenceDialog(Map<String, dynamic> report, bool isDark) {
    final evidenceUrls = report['evidence_urls'];
    final List<String> urls = [];
    if (evidenceUrls is List) {
      for (final u in evidenceUrls) {
        if (u != null && u.toString().isNotEmpty) {
          urls.add(u.toString());
        }
      }
    } else if (evidenceUrls is String && evidenceUrls.isNotEmpty) {
      urls.add(evidenceUrls);
    }

    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No evidence files attached to this report.')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: isDark ? _adminNavyDeep : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Report Attached Evidence',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: urls.length,
                    itemBuilder: (context, index) {
                      final url = urls[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: OptimizedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            color: Colors.grey.shade300,
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.broken_image, color: Colors.grey),
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
        ),
      ),
    );
  }

  Widget _buildReportsContent(bool isDark) {
    final search = _reportSearchQuery.trim().toLowerCase();
    final filter = _reportStatusFilter;

    final filteredReports = _userReports.where((report) {
      final category = report['category']?.toString().toLowerCase() ?? '';
      final description = report['description']?.toString().toLowerCase() ?? '';
      final status = report['status']?.toString().toLowerCase() ?? '';
      final bookingId = report['booking_id']?.toString().toLowerCase() ?? '';
      final reporter = report['reporter'] as Map<String, dynamic>?;
      final reportedUser = report['reported_user'] as Map<String, dynamic>?;
      final reporterName = reporter?['full_name']?.toString().toLowerCase() ?? '';
      final reportedName = reportedUser?['full_name']?.toString().toLowerCase() ?? '';

      final matchesSearch = search.isEmpty ||
          category.contains(search) ||
          description.contains(search) ||
          bookingId.contains(search) ||
          reporterName.contains(search) ||
          reportedName.contains(search);

      if (!matchesSearch) return false;

      if (filter == 'pending') return status == 'pending';
      if (filter == 'resolved') return status == 'resolved' || status == 'dismissed';
      if (filter == 'banned') return status == 'banned' || reportedUser?['is_blocked'] == true || reportedUser?['is_active'] == false;

      return true;
    }).toList();

    final pendingCount = _userReports.where((r) => r['status'] == 'pending').length;
    final resolvedCount = _userReports.where((r) => r['status'] == 'resolved' || r['status'] == 'dismissed').length;
    final bannedCount = _userReports.where((r) {
      final user = r['reported_user'] as Map<String, dynamic>?;
      return r['status'] == 'banned' || user?['is_blocked'] == true || user?['is_active'] == false;
    }).length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF021F35) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Colors.red,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Safety & Incident Reports',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (pendingCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.amber.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.amber,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$pendingCount PENDING ACTION',
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Review participant complaints regarding unreturned security deposits, fraudulent post-trip damage claims, and take immediate ban actions.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Reports',
                      onPressed: () => _loadUserReports(showLoading: true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
                const SizedBox(height: 16),

                // Search Bar
                TextField(
                  onChanged: (val) => setState(() => _reportSearchQuery = val),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by reporter, violator, booking ID, reason...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: isDark ? Colors.white54 : Colors.grey.shade500,
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.red,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildReportCategoryChip('all', 'All (${_userReports.length})', isDark),
                      const SizedBox(width: 8),
                      _buildReportCategoryChip('pending', 'Pending ($pendingCount)', isDark),
                      const SizedBox(width: 8),
                      _buildReportCategoryChip('resolved', 'Resolved ($resolvedCount)', isDark),
                      const SizedBox(width: 8),
                      _buildReportCategoryChip('banned', 'Banned Accounts ($bannedCount)', isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Reports List
          Expanded(
            child: _isLoadingReports
                ? const Center(child: CircularProgressIndicator())
                : filteredReports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: 56,
                              color: Colors.green.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No Safety Reports Found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              search.isNotEmpty || filter != 'all'
                                  ? 'Try clearing the filters or search keywords'
                                  : 'No disputes or violations reported yet.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredReports.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 14),
                        itemBuilder: (context, index) => _buildReportCard(
                          filteredReports[index],
                          isDark,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCategoryChip(String key, String label, bool isDark) {
    final isSelected = _reportStatusFilter == key;
    return InkWell(
      onTap: () => setState(() => _reportStatusFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.red.withValues(alpha: 0.18)
              : (isDark ? Colors.black26 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.red
                : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.red
                : (isDark ? Colors.white70 : Colors.black87),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, bool isDark) {
    final status = report['status']?.toString().toLowerCase() ?? 'pending';
    final category = report['category']?.toString() ?? 'General Incident';
    final description = report['description']?.toString() ?? '';
    final bookingId = report['booking_id']?.toString() ?? '';
    final createdAt = report['created_at']?.toString();
    final parsedTime = createdAt != null ? DateTime.tryParse(createdAt) : null;

    final reporter = report['reporter'] as Map<String, dynamic>?;
    final reporterName = reporter?['full_name']?.toString() ?? 'Reporter';
    final reporterRole = reporter?['role']?.toString().toUpperCase() ?? 'USER';

    final reportedUser = report['reported_user'] as Map<String, dynamic>?;
    final reportedName = reportedUser?['full_name']?.toString() ?? 'Reported User';
    final reportedRole = reportedUser?['role']?.toString().toUpperCase() ?? 'USER';
    final isUserBlocked = reportedUser?['is_blocked'] == true || reportedUser?['is_active'] == false;

    final evidenceUrls = report['evidence_urls'];
    final bool hasEvidence = evidenceUrls != null &&
        ((evidenceUrls is List && evidenceUrls.isNotEmpty) ||
            (evidenceUrls is String && evidenceUrls.isNotEmpty));

    Color statusBg = Colors.amber.withValues(alpha: 0.15);
    Color statusColor = Colors.amber;
    String statusLabel = 'PENDING REVIEW';

    if (status == 'resolved') {
      statusBg = Colors.green.withValues(alpha: 0.15);
      statusColor = Colors.green;
      statusLabel = 'RESOLVED';
    } else if (status == 'banned' || isUserBlocked) {
      statusBg = Colors.red.withValues(alpha: 0.15);
      statusColor = Colors.red;
      statusLabel = 'USER BANNED';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF021F35) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUserBlocked
              ? Colors.red.withValues(alpha: 0.4)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
          width: isUserBlocked ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: category badge, status, timestamp
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.report_problem_rounded, size: 13, color: Colors.red),
                    const SizedBox(width: 6),
                    Text(
                      category.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              if (parsedTime != null)
                RelativeTimeText(
                  value: parsedTime,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Parties Row
          Row(
            children: [
              // Reporter
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_pin_circle_outlined, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Reported By (Victim/Complainant):',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            reporterName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              reporterRole,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Reported Violator
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUserBlocked
                        ? Colors.red.withValues(alpha: 0.08)
                        : (isDark ? Colors.black26 : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isUserBlocked
                          ? Colors.red.withValues(alpha: 0.3)
                          : (isDark ? Colors.white10 : Colors.grey.shade200),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                          const SizedBox(width: 6),
                          Text(
                            'Reported Party (Alleged Violator):',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            reportedName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isUserBlocked ? Colors.red : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: isUserBlocked
                                  ? Colors.red.withValues(alpha: 0.2)
                                  : Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isUserBlocked ? 'BANNED' : reportedRole,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isUserBlocked ? Colors.red : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Incident details
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              description.isNotEmpty ? description : 'No description provided.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Booking reference & actions row
          Row(
            children: [
              if (bookingId.isNotEmpty) ...[
                Icon(
                  Icons.confirmation_number_outlined,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  'Booking: ${bookingId.length > 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
              ],
              if (hasEvidence) ...[
                OutlinedButton.icon(
                  onPressed: () => _showReportEvidenceDialog(report, isDark),
                  icon: const Icon(Icons.attach_file_rounded, size: 14),
                  label: const Text('View Evidence Photo'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const Spacer(),

              // Action buttons: Resolve and Ban
              if (status == 'pending') ...[
                OutlinedButton.icon(
                  onPressed: () => _resolveReportDialog(report, isDark),
                  icon: const Icon(Icons.check, size: 14, color: Colors.green),
                  label: const Text('Resolve', style: TextStyle(color: Colors.green)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              if (!isUserBlocked)
                ElevatedButton.icon(
                  onPressed: () => _banUserFromReportDialog(report, isDark),
                  icon: const Icon(Icons.gavel_rounded, size: 14),
                  label: const Text('Ban Violator'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.block, size: 14, color: Colors.red),
                      SizedBox(width: 6),
                      Text(
                        'Account Blocked',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
