import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class BookingReceiptService {
  BookingReceiptService._();

  static final NumberFormat _money = NumberFormat('#,##0.00');
  static final DateFormat _dateTime = DateFormat('MMM d, yyyy - h:mm a');

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static DateTime? _date(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  }

  static String _firstText(Iterable<dynamic> values, {String fallback = ''}) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }

  static Future<void> shareReceipt(Map<String, dynamic> booking) async {
    // Driver trip and assignment screens wrap the actual booking record.
    // Unwrap it once so every role produces the same complete receipt.
    final nestedBooking = _map(booking['bookings'] ?? booking['booking']);
    final record = nestedBooking.isEmpty ? booking : nestedBooking;
    final vehicle = _map(record['vehicles'] ?? record['vehicle']);
    final renter = _map(record['users'] ?? record['renter']);
    final payments = _maps(
      record['booking_payments'] ?? record['payments'] ?? booking['payments'],
    );
    final assignments = _maps(
      record['driver_job_assignments'] ??
          record['job_assignments'] ??
          booking['driver_job_assignments'] ??
          booking['job_assignments'],
    );

    final startAt = _date(
      record['start_at'] ?? record['start_date'] ?? record['startDate'],
    );
    final endAt = _date(
      record['end_at'] ?? record['end_date'] ?? record['endDate'],
    );
    final durationHours = startAt != null && endAt != null
        ? math.max(1, endAt.difference(startAt).inHours)
        : math.max(1, _number(record['duration_hours']).round());
    final rentalDays = math.max(1, (durationHours / 24).ceil());

    final recordedTotal = _number(
      record['total_cost'] ??
          record['total_price'] ??
          record['total_amount'] ??
          record['totalCost'],
    );
    final deliveryFee = _number(record['delivery_fee']);
    final lateFee = _number(record['late_return_fee'] ?? record['late_fee']);
    final securityDeposit = _number(record['security_deposit']);
    final acceptedAssignment = assignments
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (item) => const {
            'accepted',
            'ongoing',
            'awaiting_completion',
            'completed',
          }.contains(item?['status']?.toString().toLowerCase()),
          orElse: () => assignments.isEmpty ? null : assignments.first,
        );
    final driverFee = _number(
      record['driver_fee'] ??
          acceptedAssignment?['trip_fee'] ??
          booking['trip_fee'],
    );
    final explicitSubtotal = _number(
      record['rental_subtotal'] ?? record['rentalSubtotal'],
    );
    final rentalSubtotal = explicitSubtotal > 0
        ? explicitSubtotal
        : math.max(0, recordedTotal - deliveryFee - driverFee - lateFee);
    final total = recordedTotal > 0
        ? recordedTotal
        : rentalSubtotal + deliveryFee + driverFee + lateFee;

    final reservationPayment = payments
        .cast<Map<String, dynamic>?>()
        .firstWhere((payment) {
          final type = payment?['payment_type']?.toString().toLowerCase() ?? '';
          return type.contains('reservation');
        }, orElse: () => payments.isEmpty ? null : payments.first);
    final recordedReservation = _number(
      record['reservation_fee_amount'] ??
          record['reservation_fee'] ??
          reservationPayment?['amount'],
    );
    final reservationFee = recordedReservation > 0
        ? recordedReservation
        : 1000.0;
    final totalBalance = math.max(0, total - reservationFee);

    final bookingId = _firstText([
      record['id'],
      record['booking_id'],
    ], fallback: 'booking');
    final vehicleName = _firstText([
      record['carName'],
      '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim(),
      record['vehicle_name'],
    ], fallback: 'Vehicle');
    final plateNumber = _firstText([
      vehicle['plate_number'],
      record['plate_number'],
    ], fallback: 'N/A');
    final renterName = _firstText([
      renter['full_name'],
      record['renter_name'],
    ], fallback: 'Renter');
    final paymentReference = _firstText([
      record['reservation_payment_reference'],
      record['payment_reference'],
      reservationPayment?['reference_number'],
      reservationPayment?['payment_reference'],
    ], fallback: 'Not recorded');
    final paymentMethod = _firstText([
      record['reservation_payment_method'],
      record['payment_method'],
      reservationPayment?['payment_method'],
      reservationPayment?['method'],
    ], fallback: 'Not recorded');

    pw.Widget line(String label, String value, {bool bold = false}) {
      final style = pw.TextStyle(
        fontSize: bold ? 11 : 10,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      );
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: pw.Text(label, style: style)),
            pw.SizedBox(width: 16),
            pw.Text(value, style: style),
          ],
        ),
      );
    }

    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(18),
              color: PdfColor.fromHex('#08233D'),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'MOBILIS BY PSDC',
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#FFD600'),
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Official Booking Receipt',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            line('Booking ID', bookingId),
            line('Renter', renterName),
            line('Vehicle', '$vehicleName - $plateNumber'),
            line(
              'Rental period',
              startAt == null || endAt == null
                  ? 'Not recorded'
                  : '${_dateTime.format(startAt)} to ${_dateTime.format(endAt)}',
            ),
            line('Payment method', paymentMethod),
            line('Payment reference', paymentReference),
            pw.SizedBox(height: 12),
            pw.Divider(),
            pw.Text(
              'PAYMENT BREAKDOWN',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            line(
              '$rentalDays day${rentalDays == 1 ? '' : 's'} x rental rate',
              'PHP ${_money.format(rentalSubtotal)}',
            ),
            if (deliveryFee > 0)
              line(
                'Delivery / pickup charge',
                'PHP ${_money.format(deliveryFee)}',
              ),
            if (driverFee > 0)
              line(
                'Professional driver fee',
                'PHP ${_money.format(driverFee)}',
              ),
            if (lateFee > 0)
              line('Late-return fee', 'PHP ${_money.format(lateFee)}'),
            pw.Divider(),
            line('TOTAL', 'PHP ${_money.format(total)}', bold: true),
            line(
              'LESS RESERVATION FEE',
              '- PHP ${_money.format(reservationFee)}',
            ),
            line(
              'TOTAL BALANCE',
              'PHP ${_money.format(totalBalance)}',
              bold: true,
            ),
            line(
              'SECURITY DEPOSIT (REFUNDABLE)',
              'PHP ${_money.format(securityDeposit)}',
            ),
            pw.Spacer(),
            pw.Divider(),
            pw.Text(
              'Generated by Mobilis by PSDC. Amounts reflect the booking records available at the time of download.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'mobilis_receipt_${bookingId.replaceAll('-', '')}.pdf',
    );
  }
}
