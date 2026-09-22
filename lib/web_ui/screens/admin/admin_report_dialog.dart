import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/admin_report_service.dart';

class AdminReportDialog extends StatefulWidget {
  final AdminReportData reportData;

  const AdminReportDialog({
    super.key,
    required this.reportData,
  });

  static Future<void> show(
    BuildContext context, {
    required AdminReportData reportData,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => AdminReportDialog(reportData: reportData),
    );
  }

  @override
  State<AdminReportDialog> createState() => _AdminReportDialogState();
}

class _AdminReportDialogState extends State<AdminReportDialog> {
  static final NumberFormat _currency = NumberFormat('#,##0.00');
  static final NumberFormat _integerMoney = NumberFormat('#,##0');

  bool _isExporting = false;
  bool _isPrinting = false;

  AdminReportData get d => widget.reportData;

  Future<void> _handleExport() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      await AdminReportPdfService.exportPdfFile(d);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verified PDF report generated and downloaded!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not export PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handlePrint() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      await AdminReportPdfService.printPdf(d);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not print report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMMM d, yyyy').format(d.generatedAt);
    final formattedTime = DateFormat('h:mm a').format(d.generatedAt);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        width: 1060,
        constraints: const BoxConstraints(maxHeight: 920),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9), // Soft slate background
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── TOP HEADER TOOLBAR ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
              ),
              child: Row(
                children: [
                  // PDF Document Icon
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 1),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Color(0xFFD97706),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title & Meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Executive Admin Audit Report.pdf',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF86EFAC), width: 1),
                              ),
                              child: const Text(
                                'OFFICIAL RECORD',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF15803D),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Generated on $formattedDate • $formattedTime PHT • Ref: ${d.referenceCode}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions: Print Sheet + Export Verified PDF
                  OutlinedButton.icon(
                    onPressed: _isPrinting ? null : _handlePrint,
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Print Sheet'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 10),

                  ElevatedButton.icon(
                    onPressed: _isExporting ? null : _handleExport,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.file_download_rounded, size: 18),
                    label: const Text('Export Verified PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Close button
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    splashRadius: 20,
                    tooltip: 'Close Preview',
                  ),
                ],
              ),
            ),

            // ── SCROLLABLE PREVIEW SHEET ─────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Center(
                  child: Container(
                    width: 980,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. BRAND HEADER & AUDIT REPORT METADATA
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Logo + Title
                            Container(
                              width: 48,
                              height: 48,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Image.asset(
                                'assets/icon/logo1.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.directions_car_filled_rounded,
                                  color: Color(0xFF0F172A),
                                  size: 26,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'MOBILIS',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFFDE68A)),
                                      ),
                                      child: const Text(
                                        'by PSDC Car Rental',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Global Mobility Management System & Fleet Operations Console',
                                  style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 1),
                                const Text(
                                  'PSDC Operations HQ, Clark Global City, Philippines',
                                  style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),

                            const Spacer(),

                            // Right side: Badge + Meta lines
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF9C3),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFFDE047), width: 0.9),
                                  ),
                                  child: const Text(
                                    'MONTHLY EXECUTIVE AUDIT & SYSTEM REPORT',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF854D0E),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                _buildMetaRow('Doc Serial: ', d.docSerial, isBold: true),
                                _buildMetaRow('Audit Cycle: ', d.auditCycle, isBold: true),
                                _buildMetaRow('Prepared By: ', d.preparedByName),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // 2. SECTION TITLE: SYSTEM OVERVIEW & KEY FINANCIAL INDICATORS
                        Row(
                          children: const [
                            Icon(Icons.trending_up_rounded, color: Color(0xFFD97706), size: 17),
                            SizedBox(width: 8),
                            Text(
                              'SYSTEM OVERVIEW & KEY FINANCIAL INDICATORS',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 3. 4 KEY KPI METRIC CARDS
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                title: 'GROSS BOOKING VOLUME',
                                value: '₱${_integerMoney.format(d.grossBookingVolume)}',
                                subtext: d.grossGrowthText,
                                subtextColor: const Color(0xFF16A34A),
                                valueColor: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildMetricCard(
                                title: 'PLATFORM COMMISSION',
                                value: '₱${_integerMoney.format(d.platformCommission)}',
                                subtext: 'Automated platform deductions',
                                subtextColor: const Color(0xFF64748B),
                                valueColor: const Color(0xFFD97706),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildMetricCard(
                                title: 'ACTIVE / COMPLETED TRIPS',
                                value: '${d.totalActiveTrips} Active',
                                subtext: d.onTimeReturnRate,
                                subtextColor: const Color(0xFF16A34A),
                                valueColor: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildMetricCard(
                                title: 'REGISTERED FLEET CAPACITY',
                                value: '${d.fleetCapacity} Vehicles',
                                subtext: '${d.partnerCars} Partner / ${d.psdcCars} PSDC Fleet',
                                subtextColor: const Color(0xFF64748B),
                                valueColor: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // 4. TWO-COLUMN SPLIT: TRANSACTIONS TABLE vs REVENUE DISTRIBUTION
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column (60%): Audited Transactions
                            Expanded(
                              flex: 60,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.receipt_long_rounded, size: 15, color: Color(0xFFD97706)),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'RECENT AUDITED TRIP SETTLEMENTS & TRANSACTIONS',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'Showing ${d.recentTrips.length} of ${d.totalReconciledRecords} records',
                                          style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Table Header
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: const [
                                          Expanded(flex: 18, child: Text('BOOKING REF', style: _thStyle)),
                                          Expanded(flex: 28, child: Text('VEHICLE & FLEET', style: _thStyle)),
                                          Expanded(flex: 24, child: Text('RENTER / MODE', style: _thStyle)),
                                          Expanded(flex: 14, child: Text('GROSS', style: _thStyle, textAlign: TextAlign.right)),
                                          Expanded(flex: 13, child: Text('FEE', style: _thStyle, textAlign: TextAlign.right)),
                                          Expanded(flex: 15, child: Text('STATUS', style: _thStyle, textAlign: TextAlign.center)),
                                        ],
                                      ),
                                    ),

                                    // Table Rows
                                    if (d.recentTrips.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 24),
                                        child: Center(
                                          child: Text(
                                            'No audited booking transactions recorded in database.',
                                            style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                          ),
                                        ),
                                      )
                                    else
                                      ...d.recentTrips.map((trip) {
                                        final isSettled = trip.status == 'SETTLED' || trip.status == 'COMPLETED';
                                        final isActive = trip.status == 'ACTIVE' || trip.status == 'ONGOING';
                                        final isCancelled = trip.status == 'CANCELLED';

                                        final badgeTextColor = isSettled
                                            ? const Color(0xFF15803D)
                                            : (isActive
                                                ? const Color(0xFF1D4ED8)
                                                : (isCancelled ? const Color(0xFFB91C1C) : const Color(0xFFB45309)));
                                        final badgeBgColor = isSettled
                                            ? const Color(0xFFDCFCE7)
                                            : (isActive
                                                ? const Color(0xFFDBEAFE)
                                                : (isCancelled ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)));
                                        final badgeBorderColor = isSettled
                                            ? const Color(0xFF86EFAC)
                                            : (isActive
                                                ? const Color(0xFF93C5FD)
                                                : (isCancelled ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A)));

                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          decoration: const BoxDecoration(
                                            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                                          ),
                                          child: Row(
                                            children: [
                                              // Booking Ref
                                              Expanded(
                                                flex: 18,
                                                child: Text(
                                                  trip.bookingRef,
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                              // Vehicle & Category
                                              Expanded(
                                                flex: 28,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      trip.vehicleName,
                                                      style: const TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      trip.category,
                                                      style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Renter / Driver
                                              Expanded(
                                                flex: 24,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      trip.renterName,
                                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF0F172A)),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      trip.driverMode,
                                                      style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Gross Total
                                              Expanded(
                                                flex: 14,
                                                child: Text(
                                                  '₱${_currency.format(trip.grossTotal)}',
                                                  style: const TextStyle(fontSize: 10, color: Color(0xFF0F172A)),
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                              // Admin Fee
                                              Expanded(
                                                flex: 13,
                                                child: Text(
                                                  '₱${_currency.format(trip.adminFee)}',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFFD97706),
                                                  ),
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                              // Status Badge
                                              Expanded(
                                                flex: 15,
                                                child: Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: badgeBgColor,
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: badgeBorderColor, width: 0.8),
                                                    ),
                                                    child: Text(
                                                      trip.status,
                                                      style: TextStyle(
                                                        fontSize: 8,
                                                        fontWeight: FontWeight.bold,
                                                        color: badgeTextColor,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(width: 14),

                            // Right Column (40%): Revenue Distribution
                            Expanded(
                              flex: 40,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.pie_chart_outline_rounded, size: 15, color: Color(0xFFD97706)),
                                        SizedBox(width: 6),
                                        Text(
                                          'REVENUE DISTRIBUTION',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    _buildDistributionRow(
                                      title: 'Fleet Rental Operations',
                                      amount: '₱${_integerMoney.format(d.tripCommissions)} (${d.tripCommissionsPct}%)',
                                      pct: d.tripCommissionsPct / 100,
                                      color: const Color(0xFF2563EB),
                                    ),
                                    const SizedBox(height: 10),

                                    _buildDistributionRow(
                                      title: 'Partner Fleet Share',
                                      amount: '₱${_integerMoney.format(d.partnerSubscriptions)} (${d.partnerSubscriptionsPct}%)',
                                      pct: d.partnerSubscriptionsPct / 100,
                                      color: const Color(0xFF0EA5E9),
                                    ),
                                    const SizedBox(height: 10),

                                    _buildDistributionRow(
                                      title: 'Overtime & Late Penalties',
                                      amount: '₱${_integerMoney.format(d.overtimePenalties)} (${d.overtimePenaltiesPct}%)',
                                      pct: d.overtimePenaltiesPct / 100,
                                      color: const Color(0xFFEF4444),
                                    ),
                                    const SizedBox(height: 10),

                                    _buildDistributionRow(
                                      title: 'Driver & Delivery Surcharges',
                                      amount: '₱${_integerMoney.format(d.driverSurcharge)} (${d.driverSurchargePct}%)',
                                      pct: d.driverSurchargePct / 100,
                                      color: const Color(0xFF22C55E),
                                    ),

                                    const SizedBox(height: 14),

                                    // Net Platform Earnings Card (Clean and tight)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF9C3),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFFDE68A)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'NET PLATFORM EARNINGS:',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF92400E),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '₱${_currency.format(d.netPlatformEarnings)}',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFFB45309),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const Text(
                                            'Directly disbursed to verified PSDC corporate accounts.',
                                            style: TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // 5. COMPLIANCE, FLEET INTAKE & SYSTEM SUMMARY
                        Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, color: Color(0xFFD97706), size: 15),
                            const SizedBox(width: 8),
                            const Text(
                              'COMPLIANCE, FLEET INTAKE & SYSTEM SUMMARY',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: Text(
                                d.auditStatusBadge,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 3 Summary Cards - TRUE DATA
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                title: 'USER VERIFICATION RATIO',
                                value: '${d.verifiedUsers} Verified / ${d.pendingUsers} Pending',
                                subtext: d.userVerificationSubtext,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildSummaryCard(
                                title: 'SAFETY & AUDIT INTEGRITY',
                                value: d.systemSafetyMetric,
                                subtext: d.systemSafetySubtext,
                                valueColor: const Color(0xFFD97706),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildSummaryCard(
                                title: 'GPS TELEMATICS & DISPATCH',
                                value: d.gpsTelematicsUptime,
                                subtext: d.gpsTelematicsSubtext,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // 6. SIGN-OFF & CRYPTOGRAPHIC VERIFICATION FOOTER - TRUE NAMES ONLY
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Prepared & Generated By Real Admin
                            Expanded(
                              flex: 32,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PREPARED & GENERATED BY:',
                                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(width: 160, height: 1.5, color: const Color(0xFFCBD5E1)),
                                  const SizedBox(height: 6),
                                  Text(
                                    d.preparedBySigner,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    d.preparedByTitle,
                                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                                  ),
                                  Text(
                                    d.preparedById,
                                    style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),

                            // System Reconciliation
                            Expanded(
                              flex: 33,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'SYSTEM RECONCILIATION:',
                                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(width: 160, height: 1.5, color: const Color(0xFFCBD5E1)),
                                  const SizedBox(height: 6),
                                  Text(
                                    d.auditedByName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    d.auditedByTitle,
                                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                                  ),
                                  Text(
                                    d.auditedByCreds,
                                    style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),

                            // Cryptographically Signed Seal Box
                            Expanded(
                              flex: 35,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.lock_rounded, size: 13, color: Color(0xFF0F172A)),
                                        SizedBox(width: 6),
                                        Text(
                                          'CRYPTOGRAPHICALLY SIGNED',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Hash: ${d.sha256Hash} • SHA-256 Validated',
                                      style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Internal audit documentation for PSDC Management & Fleet Operations.',
                                      style: TextStyle(fontSize: 8, color: Color(0xFF94A3B8)),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const TextStyle _thStyle = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.bold,
    color: Color(0xFF475569),
  );

  Widget _buildMetaRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
          Text(
            value,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtext,
    required Color subtextColor,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtext,
            style: TextStyle(fontSize: 9, color: subtextColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionRow({
    required String title,
    required String amount,
    required double pct,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 9.5, color: Color(0xFF334155))),
            Text(
              amount,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtext,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtext,
            style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
