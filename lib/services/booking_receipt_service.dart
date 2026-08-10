import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class BookingReceiptService {
  BookingReceiptService._();

  static final NumberFormat _money = NumberFormat('#,##0.00');

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
    final deliveryFee = _number(record['delivery_fee'] ?? record['deliveryFee']);
    final lateFee = _number(record['late_return_fee'] ?? record['late_fee'] ?? record['lateReturnFee']);
    final securityDeposit = _number(record['security_deposit'] ?? record['securityDeposit']);
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
          record['driverFee'] ??
          acceptedAssignment?['trip_fee'] ??
          booking['trip_fee'],
    );
    final explicitSubtotal = _number(
      record['rental_subtotal'] ?? record['rentalSubtotal'],
    );
    final otherFees = deliveryFee + driverFee;
    final rentalSubtotal = explicitSubtotal > 0
        ? explicitSubtotal
        : math.max(0, recordedTotal - otherFees - lateFee);
    final recordedReservation = _number(
      record['reservation_fee_amount'] ??
          record['reservation_fee'] ??
          record['reservationFeeAmount'],
    );
    final reservationFee = recordedReservation > 0
        ? recordedReservation
        : 1000.0;

    // Tax calculation
    final explicitTax = _number(record['tax'] ?? record['vat']);
    final taxAmount = explicitTax > 0
        ? explicitTax
        : ((rentalSubtotal + otherFees) * 0.12);

    final total = recordedTotal > 0
        ? recordedTotal
        : (rentalSubtotal + otherFees + lateFee + taxAmount);

    final bookingId = _firstText([
      record['id'],
      record['booking_id'],
    ], fallback: 'booking');
    final cleanId = bookingId.replaceAll('-', '').toUpperCase();
    final receiptNo = _firstText([
      record['receipt_no'],
      record['receipt_number'],
    ], fallback: 'MOB-${(startAt ?? DateTime.now()).year}-${cleanId.substring(0, math.min(4, cleanId.length))}');

    final receiptDateStr = DateFormat('MMMM dd, yyyy').format(startAt ?? DateTime.now());

    final vehicleName = _firstText([
      record['carName'],
      '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''} ${vehicle['year'] ?? ''}'.trim(),
      record['vehicle_name'],
    ], fallback: 'Toyota Camry 2024');

    final vehicleType = _firstText([
      record['category'],
      record['vehicle_type'],
      vehicle['category'],
      vehicle['vehicle_type'],
    ], fallback: 'Premium Sedan');

    final plateNumber = _firstText([
      vehicle['plate_number'],
      record['plate_number'],
      record['plateNumber'],
    ], fallback: 'ABC-1234');

    final pickupDateStr = startAt != null
        ? DateFormat('MMM dd').format(startAt)
        : (record['startDate']?.toString() ?? 'Aug 08');
    final pickupTimeStr = startAt != null
        ? DateFormat('h:mm a').format(startAt)
        : (record['startTime']?.toString() ?? '10:00 AM');

    final returnDateStr = endAt != null
        ? DateFormat('MMM dd').format(endAt)
        : (record['endDate']?.toString() ?? 'Aug 10');
    final returnTimeStr = endAt != null
        ? DateFormat('h:mm a').format(endAt)
        : (record['endTime']?.toString() ?? '10:00 AM');

    final serviceType = _firstText([
      record['service_type'],
      record['serviceType'],
      record['booking_type'],
      record['transmission'],
    ], fallback: 'Self-Drive (Delivery)');

    final destination = _firstText([
      record['dropoff_location'],
      record['dropoffLocation'],
      record['destination'],
      record['location'],
      record['pickup_location'],
      record['pickupLocation'],
    ], fallback: 'Metro Manila & Suburbs');

    final paymentStatus = _firstText([
      record['payment_status'],
      record['paymentStatus'],
      record['status'],
    ], fallback: 'PAID').toUpperCase();

    // Image processing
    String imageUrl = _firstText([
      record['imageUrl'],
      record['image_url'],
      vehicle['image_url'],
      vehicle['primary_image'],
    ]);
    if (imageUrl.isEmpty && vehicle['vehicle_images'] is List && (vehicle['vehicle_images'] as List).isNotEmpty) {
      final imgObj = (vehicle['vehicle_images'] as List).first;
      if (imgObj is Map) {
        imageUrl = imgObj['image_url']?.toString() ?? '';
      }
    }

    pw.MemoryImage? vehicleImageBytes;
    if (imageUrl.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          vehicleImageBytes = pw.MemoryImage(res.bodyBytes);
        }
      } catch (_) {}
    }

    pw.Widget summaryRow(String label, String value) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#64748B'),
              letterSpacing: 0.5,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#0F172A'),
            ),
          ),
        ],
      );
    }

    pw.Widget paymentRow(String label, String amount) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromHex('#334155'),
            ),
          ),
          pw.Text(
            amount,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#0F172A'),
            ),
          ),
        ],
      );
    }

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // 1. Title Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'Rental Receipt',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#0F172A'),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'RECEIPT NO: $receiptNo',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#64748B'),
                      letterSpacing: 0.8,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    receiptDateStr,
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColor.fromHex('#64748B'),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // 2. Vehicle Image Box
            pw.Container(
              width: double.infinity,
              height: 120,
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#EDE9FE'),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: vehicleImageBytes != null
                  ? pw.ClipRRect(
                      horizontalRadius: 12,
                      verticalRadius: 12,
                      child: pw.Image(vehicleImageBytes, fit: pw.BoxFit.cover),
                    )
                  : pw.Center(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(
                            vehicleName,
                            style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#6D28D9'),
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            vehicleType,
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColor.fromHex('#7C3AED'),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            pw.SizedBox(height: 10),

            // 3. Vehicle Info Card
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        vehicleName,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0F172A'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        vehicleType,
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColor.fromHex('#64748B'),
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'LICENSE PLATE',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#64748B'),
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        plateNumber,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0F172A'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // 4. Booking Summary
            pw.Text(
              'Booking Summary',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#0F172A'),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Container(height: 1, color: PdfColor.fromHex('#E2E8F0')),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F8FAFC'),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PICKUP',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#64748B'),
                            letterSpacing: 0.5,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          pickupDateStr,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#0F172A'),
                          ),
                        ),
                        pw.SizedBox(height: 1),
                        pw.Text(
                          pickupTimeStr,
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            color: PdfColor.fromHex('#475569'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F8FAFC'),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'RETURN',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#64748B'),
                            letterSpacing: 0.5,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          returnDateStr,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#0F172A'),
                          ),
                        ),
                        pw.SizedBox(height: 1),
                        pw.Text(
                          returnTimeStr,
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            color: PdfColor.fromHex('#475569'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  summaryRow('SERVICE TYPE', serviceType),
                  pw.SizedBox(height: 4),
                  summaryRow('DESTINATION', destination),
                  pw.SizedBox(height: 4),
                  summaryRow('DURATION', '$rentalDays Day${rentalDays == 1 ? '' : 's'}'),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // 5. Payment Breakdown
            pw.Text(
              'Payment Breakdown',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#0F172A'),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Container(height: 1, color: PdfColor.fromHex('#E2E8F0')),
            pw.SizedBox(height: 8),
            paymentRow('Rental Fee ($rentalDays Day${rentalDays == 1 ? '' : 's'})', 'PHP ${_money.format(rentalSubtotal)}'),
            pw.SizedBox(height: 4),
            if (otherFees > 0) ...[
              paymentRow('Insurance & Fees', 'PHP ${_money.format(otherFees)}'),
              pw.SizedBox(height: 4),
            ],
            paymentRow('Reservation Fee', 'PHP ${_money.format(reservationFee)}'),
            pw.SizedBox(height: 2),
            pw.Text(
              '* Refundable once the car is returned in good condition.',
              style: pw.TextStyle(
                fontSize: 7.5,
                color: PdfColor.fromHex('#64748B'),
              ),
            ),
            pw.SizedBox(height: 4),
            if (taxAmount > 0) ...[
              paymentRow('Tax (VAT 12%)', 'PHP ${_money.format(taxAmount)}'),
              pw.SizedBox(height: 6),
            ],
            pw.SizedBox(height: 2),

            // Total Gold Box
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#FDE68A'),
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColor.fromHex('#FCD34D')),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Total\nAmount',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1E293B'),
                          height: 1.1,
                        ),
                      ),
                      pw.Text(
                        'PHP ${_money.format(total)}',
                        style: pw.TextStyle(
                          fontSize: 17,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0F172A'),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'PAYMENT STATUS',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#78350F'),
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#78350F'),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text(
                          paymentStatus.isEmpty ? 'PAID' : paymentStatus,
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#FDE68A'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // 6. Policies
            pw.Text(
              'Policies',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#0F172A'),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Container(height: 1, color: PdfColor.fromHex('#E2E8F0')),
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Security Deposit',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#1E293B'),
                    ),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    securityDeposit > 0
                        ? 'PHP ${_money.format(securityDeposit)}'
                        : 'PHP 2,000.00 for 5-seater / PHP 3,000.00 for 7-seater',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColor.fromHex('#475569'),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Late Return Fees',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#1E293B'),
                    ),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    lateFee > 0
                        ? 'Late return fee: PHP ${_money.format(lateFee)}'
                        : 'Late return fee: PHP 200/hr (5-seater) or PHP 350/hr (7-seater)',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColor.fromHex('#475569'),
                    ),
                  ),
                ],
              ),
            ),

            pw.Spacer(),

            // 7. Footer
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'Thank you for riding with Mobilis!',
                    style: pw.TextStyle(
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#0F172A'),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Support   Privacy Policy   Terms of Service',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColor.fromHex('#64748B'),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    '© ${DateTime.now().year} Mobilis Car Rental. All rights reserved.',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      color: PdfColor.fromHex('#94A3B8'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'mobilis_receipt_${bookingId.replaceAll('-', '')}.pdf',
    );
  }
}
