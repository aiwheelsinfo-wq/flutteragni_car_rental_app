import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:agni_car_rental/config/api_config.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';

class InvoicePage extends StatefulWidget {
  final String bookingId;

  InvoicePage({required this.bookingId});

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  final FlutterSecureStorage secureStorage = FlutterSecureStorage();
  String? userType;
  final Map<String, String> invoiceData = {
    'invoieceDate': 'Not Generated',
    'invoiceNumber': 'Not Generated',
    'business_name': 'Not Generated',
    'business_address': 'Not Generated',
    'gst_number': 'Not Generated',
    'business_pincode': 'Not Generated',
    'trip_type': 'Not Generated',
    'cus_name': 'Not Generated',
    'car_type': 'Not Generated',
    'from': 'Not Generated',
    'to': 'Not Generated',
    'trip_date': 'Not Generated',
    'starting_km': '00',
    'closing_km': '00',
    'starting_date': '0000-00-00',
    'closing_date': '0000-00-00',
    'starting_time': '00:00:00',
    'closing_time': '00:00:00',
    'packageKm': '00',
    'packageHours': '00',
    'packageBaseFare': '00',
    'extra_km_price': '00',
    'extra_hours_price': '00',
    'package_price': 'Not Generated',
    'extra_hours': 'Not Generated',
    'parking_charge': '00',
    'toll_charge': '00',
    'gstPercent': '00',
    'driver_allowance': '00',
    'trip_total_fair': 'Not Generated',
    'user_id': 'Not Generated',
    'id': 'Not Generated',
    'next_invoice_no': 'Not Generated',
    'daily_limit': '0',
    'kmRate': '0',
    'distance': '0',
    'total_amount': '0',
    'agent_commission': '0',
    'permit_charge': '0',
    'base_charge': '0',
    'paid_amount': '0',
    'driver_name': '',
    'driver_phone': '',
    'vehicle_number': '',
  };

  bool get _isAgentInvoice {
    if (userType == 'agent') return true;
    if (invoiceData['agent_accountType'] == 'agent') return true;
    final bName = invoiceData['business_name'];
    if (bName != null && bName != 'Not Generated' && bName.trim().isNotEmpty) {
      return true;
    }
    return false;
  }

  String get _agentHeaderName {
    final bName = invoiceData['business_name'];
    if (bName != null && bName != 'Not Generated' && bName.trim().isNotEmpty) {
      return bName;
    }
    final aName = invoiceData['agent_agency_name'];
    if (aName != null && aName != 'Not Filled' && aName.trim().isNotEmpty) {
      return aName;
    }
    final agName = invoiceData['agent_name'];
    if (agName != null && agName != 'Not Filled' && agName.trim().isNotEmpty) {
      return agName;
    }
    return 'AGENT CAR RENTAL';
  }

  String get _agentHeaderAddress {
    final bAddr = invoiceData['business_address'];
    if (bAddr != null && bAddr != 'Not Generated' && bAddr.trim().isNotEmpty) {
      return bAddr;
    }
    final aCity = invoiceData['agent_city'];
    if (aCity != null && aCity != 'Not Filled' && aCity.trim().isNotEmpty) {
      return aCity;
    }
    return '';
  }

  String get _agentHeaderContact {
    String contact = '';
    final phone = invoiceData['agent_phone'];
    if (phone != null && phone.isNotEmpty && phone != 'Not Filled') {
      contact += "Tel: $phone";
    }
    final email = invoiceData['agent_email'];
    if (email != null && email.isNotEmpty && email != 'Not Filled') {
      if (contact.isNotEmpty) contact += " | ";
      contact += "Email: $email";
    }
    return contact;
  }

  String get _agentHeaderGst {
    final gst = invoiceData['gst_number'];
    if (gst != null && gst != 'Not Generated' && gst.trim().isNotEmpty) {
      return gst;
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    fetchInvoiceData("123");
  }

  Future<void> fetchInvoiceData(String invoiceId) async {
    userType = await secureStorage.read(key: "userType");
    final url = Uri.parse(
        "${ApiConfig.baseUrl}/get_invoice_data.php?bookingId=${widget.bookingId}");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['error'] == null) {
          setState(() {
            invoiceData['invoiceNumber'] =
                data['invoice_no'] ?? 'Not Generated';
            invoiceData['invoieceDate'] =
                data['invoice_date'] ?? 'Not Generated';
            invoiceData['gst_number'] = data['gst_number'] ?? 'Not Generated';
            invoiceData['business_name'] =
                data['business_name'] ?? 'Not Generated';
            invoiceData['business_address'] =
                data['business_address'] ?? 'Not Generated';
            invoiceData['business_pincode'] =
                data['business_pincode'] ?? 'Not Generated';
            invoiceData['cus_name'] = data['name'] ?? 'Not Generated';
            invoiceData['car_type'] =
                '${data['car_type'] ?? 'Not Generated'} - ${data['vehicle_id'] ?? ''}';
            invoiceData['from'] = data['from_address'] ?? 'Not Generated';
            invoiceData['to'] = data['to_address'] ?? 'Not Generated';
            invoiceData['starting_date'] =
                data['starting_date'] ?? '0000-00-00';
            invoiceData['closing_date'] = data['closing_date'] ?? '0000-00-00';
            invoiceData['starting_km'] =
                (data['starting_km'] ?? '0').toString();
            invoiceData['closing_km'] = (data['closing_km'] ?? '0').toString();
            invoiceData['packageKm'] = (data['packageKm'] ?? '0').toString();
            invoiceData['packageHours'] =
                (data['packageHours'] ?? '0').toString();
            invoiceData['packageBaseFare'] =
                (data['baseAmount'] ?? '0').toString();
            invoiceData['extra_km_price'] =
                (data['extraKMAmount'] ?? '0').toString();
            invoiceData['extra_hours_price'] =
                (data['extraHoursAmount'] ?? '0').toString();
            invoiceData['starting_time'] =
                (data['starting_time'] ?? '00:00:00').toString();
            invoiceData['closing_time'] =
                (data['closing_time'] ?? '00:00:00').toString();
            invoiceData['parking_charge'] =
                (data['parking_charge'] ?? '0').toString();
            invoiceData['toll_charge'] =
                (data['toll_charge'] ?? '0').toString();
            invoiceData['gstPercent'] = (data['gstPercent'] ?? '0').toString();
            invoiceData['driver_allowance'] =
                (data['driver_allowance'] ?? '0').toString();
            invoiceData['trip_type'] =
                (data['trip_type'] ?? 'Not Generated').toString();
            invoiceData['daily_limit'] =
                (data['daily_limit'] ?? '0').toString();
            invoiceData['kmRate'] = (data['kmRate'] ?? '0').toString();
            invoiceData['distance'] = (data['distance'] ?? '0').toString();
            invoiceData['total_amount'] =
                (data['total_amount'] ?? '0').toString();
            invoiceData['agent_commission'] =
                (data['agent_commission'] ?? '0').toString();
            invoiceData['permit_charge'] =
                (data['permit_charge'] ?? '0').toString();
            invoiceData['base_charge'] =
                (data['base_charge'] ?? '0').toString();
            invoiceData['paid_amount'] =
                (data['paid_amount'] ?? '0').toString();
            invoiceData['driver_name'] = (data['driver_name'] ?? '').toString();
            invoiceData['driver_phone'] = (data['driver_phone'] ?? '').toString();
            invoiceData['vehicle_number'] =
                (data['vehicle_number'] ?? data['vehicle_id'] ?? '').toString();
            invoiceData['agent_agency_name'] =
                data['agent_agency_name'] ?? data['agency_name'] ?? '';
            invoiceData['agent_name'] = data['agent_name'] ?? '';
            invoiceData['agent_email'] = data['agent_email'] ?? '';
            invoiceData['agent_city'] = data['agent_city'] ?? '';
            invoiceData['agent_phone'] = data['agent_phone'] ?? '';
            invoiceData['agent_accountType'] =
                data['agent_accountType'] ?? data['accountType'] ?? '';
            invoiceData['booked_start_date'] =
                (data['date'] ?? '0000-00-00').toString();
            invoiceData['booked_return_date'] =
                (data['return_date'] ?? '0000-00-00').toString();
          });
        } else {
          print(data['error']);
        }
      } else {
        print('Failed to load data');
      }
    } catch (e) {
      print('Exception: $e');
    }
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '₹0';
    double? numVal;
    if (value is num) {
      numVal = value.toDouble();
    } else if (value is String) {
      String cleanStr = value
          .replaceAll('₹', '')
          .replaceAll('Rs', '')
          .replaceAll(',', '')
          .trim();
      numVal = double.tryParse(cleanStr);
    }
    if (numVal == null) return value.toString();

    if (numVal % 1 == 0) {
      final f = NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 0,
      );
      return f.format(numVal.toInt());
    } else {
      final f = NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 2,
      );
      String res = f.format(numVal);
      if (res.endsWith('.00')) {
        return res.substring(0, res.length - 3);
      }
      return res;
    }
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    double? numVal;
    if (value is num) {
      numVal = value.toDouble();
    } else if (value is String) {
      String cleanStr = value.replaceAll(',', '').trim();
      numVal = double.tryParse(cleanStr);
    }
    if (numVal == null) return value.toString();

    if (numVal % 1 == 0) {
      final f = NumberFormat.decimalPattern('en_IN');
      return f.format(numVal.toInt());
    } else {
      final f = NumberFormat.currency(
        locale: 'en_IN',
        symbol: '',
        decimalDigits: 2,
      );
      String res = f.format(numVal).trim();
      if (res.endsWith('.00')) {
        return res.substring(0, res.length - 3);
      }
      return res;
    }
  }

  pw.TableRow _buildModernPdfTableRow(
    String col1,
    String col2,
    String col3, {
    bool isHeader = false,
    bool isAlt = false,
    bool isTotal = false,
  }) {
    final bgColor = isHeader
        ? PdfColor.fromHex('#1E3A8A')
        : isTotal
            ? PdfColor.fromHex('#F1F5F9')
            : isAlt
                ? PdfColor.fromHex('#F8FAFC')
                : PdfColors.white;

    final textColor = isHeader
        ? PdfColors.white
        : isTotal
            ? PdfColor.fromHex('#0F172A')
            : PdfColor.fromHex('#1E293B');

    final textWeight =
        (isHeader || isTotal) ? pw.FontWeight.bold : pw.FontWeight.normal;
    final fontSize = isHeader ? 9.5 : (isTotal ? 10.5 : 9.0);

    String displayCol3 = '';
    if (col3.isNotEmpty) {
      if (isHeader || col3 == 'TOTAL' || col3 == 'AMOUNT') {
        displayCol3 = col3;
      } else {
        displayCol3 = _formatCurrency(col3);
      }
    }

    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: bgColor,
        border: pw.Border(
          bottom: pw.BorderSide(
            color: isHeader
                ? PdfColor.fromHex('#1E3A8A')
                : PdfColor.fromHex('#E2E8F0'),
            width: isTotal ? 1.2 : 0.5,
          ),
        ),
      ),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5.5),
          child: pw.Text(
            col1,
            style: pw.TextStyle(
              fontWeight: (col1 == 'TOTAL' || isHeader)
                  ? pw.FontWeight.bold
                  : textWeight,
              fontSize: fontSize,
              color: textColor,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5.5),
          child: pw.Text(
            col2,
            style: pw.TextStyle(
              fontWeight: textWeight,
              fontSize: fontSize,
              color: isHeader ? PdfColors.white : PdfColor.fromHex('#475569'),
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5.5),
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              displayCol3,
              style: pw.TextStyle(
                fontWeight: (col1 == 'TOTAL' || isHeader || isTotal)
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                fontSize: fontSize,
                color: isHeader
                    ? PdfColors.white
                    : (col1 == 'TOTAL'
                        ? PdfColor.fromHex('#1E3A8A')
                        : textColor),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<pw.Document> _generateDocument() async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('yyyy-MM-dd hh:mm a');

    final totalKm = double.parse(invoiceData['closing_km']!) -
        double.parse(invoiceData['starting_km']!);
    final startingDate = invoiceData['starting_date'];
    final startingTime = invoiceData['starting_time'];
    final closingDate = invoiceData['closing_date'];
    final closingTime = invoiceData['closing_time'];
    final startDateTime =
        DateTime.tryParse('$startingDate $startingTime') ?? DateTime.now();
    var endDateTime =
        DateTime.tryParse('$closingDate $closingTime') ?? DateTime.now();
    if (endDateTime.isBefore(startDateTime)) {
      endDateTime = endDateTime.add(const Duration(days: 1));
    }
    final duration = endDateTime.difference(startDateTime);
    var hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    String? commission;
    double? packageBaseWithCommission;
    String commissionFormulaText = '';
    int? totalDays = 0;
    double? extraKm;
    double? extrakmAmount;
    num? extraHours;
    double? extraHoursAmount;
    double? gst;
    double? netTotal;
    String? driver_allowance;
    double? baceAmount;
    double baseKmCharge = 0.0;
    double agentCommissionAmount = 0.0;
    double commissionRate = 0.0;

    var maxKm;
    double kmRate =
        double.tryParse(invoiceData['kmRate']?.toString() ?? '') ?? 0.0;
    double gstPercent = double.parse(invoiceData['gstPercent'].toString());
    bool isIntraState = true;
    String custGst = (invoiceData['gst_number'] ?? '').trim();
    if (custGst.isNotEmpty && custGst != 'Not Generated' && custGst != 'None') {
      String stateCode = custGst.length >= 2 ? custGst.substring(0, 2) : '';
      if (stateCode.isNotEmpty && stateCode != '27') {
        isIntraState = false;
      }
    }
    double? agent_commission =
        double.tryParse(invoiceData['agent_commission'].toString()) ?? 0.0;
    double? permit_charge =
        double.tryParse(invoiceData['permit_charge'].toString()) ?? 0.0;
    double? parking_charge =
        double.tryParse(invoiceData['parking_charge'].toString()) ?? 0.0;
    double? toll_charge =
        double.tryParse(invoiceData['toll_charge'].toString()) ?? 0.0;
    if (invoiceData['trip_type'] == 'Local-Duty') {
      final packageKm = double.tryParse(invoiceData['packageKm'] ?? '0') ?? 0;
      final packageHours =
          double.tryParse(invoiceData['packageHours'] ?? '0') ?? 0;
      final extraKmPrice =
          double.tryParse(invoiceData['extra_km_price'] ?? '0') ?? 0;
      final extraHoursPrice =
          double.tryParse(invoiceData['extra_hours_price'] ?? '0') ?? 0;
      final packageBaseFare =
          double.tryParse(invoiceData['packageBaseFare'] ?? '0') ?? 0;
      double driverAllowance = 0.0;

      extraKm = totalKm > packageKm ? totalKm - packageKm : 0;
      extrakmAmount = extraKm * extraKmPrice;

      if (minutes > 30) hours += 1;
      extraHours = hours > packageHours ? hours - packageHours : 0;
      extraHoursAmount = extraHours * extraHoursPrice;

      bool isStartBefore5AM = startDateTime.hour < 5;
      bool isEndAfter1130PM = endDateTime.hour > 23 ||
          (endDateTime.hour == 23 && endDateTime.minute > 30);
      if (isStartBefore5AM || isEndAfter1130PM) {
        driverAllowance =
            double.tryParse(invoiceData['driver_allowance'] ?? '0') ?? 0;
      }

      double totalBeforeGst =
          packageBaseFare + extrakmAmount + extraHoursAmount + agent_commission;

      gst = totalBeforeGst * gstPercent / 100;
      netTotal = totalBeforeGst +
          gst +
          parking_charge +
          toll_charge +
          permit_charge +
          driverAllowance;

      baceAmount = double.parse(packageBaseFare.toStringAsFixed(2));
      packageBaseWithCommission =
          double.parse((packageBaseFare + agent_commission).toStringAsFixed(2));
      extrakmAmount = double.parse(extrakmAmount.toStringAsFixed(2));
      extraHoursAmount = double.parse(extraHoursAmount.toStringAsFixed(2));
      driverAllowance = double.parse(driverAllowance.toStringAsFixed(2));
      totalBeforeGst = double.parse(totalBeforeGst.toStringAsFixed(2));
      gst = double.parse(gst.toStringAsFixed(2));
      netTotal = double.parse(netTotal.toStringAsFixed(2));
      driver_allowance = driverAllowance.toString();
    }

    if (invoiceData['trip_type'] == 'Round-Trip') {
      double? driver_allowanceXdays;
      driver_allowance = invoiceData['driver_allowance'].toString();
      double runningKm = double.parse(invoiceData['closing_km'] ?? '0') -
          double.parse(invoiceData['starting_km'] ?? '0');
      double daily_limit = double.parse(invoiceData['daily_limit'] ?? '0');
      commission = userType == 'agent' ? '+${agent_commission.toString()}' : '';

      int days = 1;
      try {
        final bStartStr = invoiceData['booked_start_date'] ?? '';
        final bReturnStr = invoiceData['booked_return_date'] ?? '';
        if (bStartStr.isNotEmpty &&
            bReturnStr.isNotEmpty &&
            bStartStr != '0000-00-00' &&
            bReturnStr != '0000-00-00') {
          try {
            final bStart = DateFormat('dd MMM yyyy').parse(bStartStr);
            final bReturn = DateFormat('dd MMM yyyy').parse(bReturnStr);
            days = bReturn.difference(bStart).inDays + 1;
          } catch (_) {
            final bStart = DateTime.parse(bStartStr);
            final bReturn = DateTime.parse(bReturnStr);
            days = bReturn.difference(bStart).inDays + 1;
          }
        }
      } catch (e) {
        debugPrint("Error parsing booked dates: $e");
      }
      if (days <= 0) days = 1;
      maxKm = max(runningKm, (daily_limit * days));
      double dailyAllowance = double.tryParse(driver_allowance) ?? 400.0;
      bool isEarlyMorning = _isEarlyMorningTime(startingTime ?? '') ||
          ((startDateTime.hour >= 1 && startDateTime.hour < 6) ||
              (startDateTime.hour == 6 && startDateTime.minute == 0));
      double earlyMorningAllowance = isEarlyMorning ? 300.0 : 0.0;
      driver_allowanceXdays = (dailyAllowance * days) + earlyMorningAllowance;
      driver_allowance = driver_allowanceXdays.toStringAsFixed(2);
      totalDays = days;

      double commissionRateVal = 0.0;
      if (agent_commission > 0 && days > 0 && daily_limit > 0) {
        commissionRateVal =
            (agent_commission / (daily_limit * days)).roundToDouble();
      }
      commissionRate = commissionRateVal;
      baseKmCharge = (maxKm ?? 0) * kmRate;
      agentCommissionAmount = (maxKm ?? 0) * commissionRateVal;
      double effectiveKmRate = kmRate + commissionRateVal;
      baceAmount = baseKmCharge + agentCommissionAmount;

      commissionFormulaText = effectiveKmRate % 1 == 0
          ? effectiveKmRate.toInt().toString()
          : (effectiveKmRate.toStringAsFixed(2).endsWith('.00')
              ? effectiveKmRate.toInt().toString()
              : effectiveKmRate.toStringAsFixed(1));

      gst = baceAmount! * gstPercent / 100;

      netTotal = baceAmount +
          gst +
          parking_charge +
          toll_charge +
          permit_charge +
          driver_allowanceXdays;
    }

    double base_charge = 0.0;
    if (invoiceData['trip_type'] == 'One-way') {
      double distance = double.parse(invoiceData['distance'].toString());
      double driver_allowanceVal;

      driver_allowanceVal = (distance < 200) ? 300 : 400;

      baceAmount = invoiceData['total_amount'] != '0'
          ? double.parse(invoiceData['total_amount'].toString())
          : (distance * kmRate) + driver_allowanceVal + agent_commission;

      double totalbeforeGst = baceAmount;

      gst = baceAmount * gstPercent / 100;
      netTotal =
          baceAmount + gst + parking_charge + toll_charge + permit_charge;

      base_charge = baceAmount;

      baceAmount = double.parse(baceAmount.toStringAsFixed(2));
      totalbeforeGst = double.parse(totalbeforeGst.toStringAsFixed(2));
      gst = double.parse(gst.toStringAsFixed(2));
      netTotal = double.parse(netTotal.toStringAsFixed(2));
      driver_allowance = driver_allowanceVal.toString();
    }

    if (invoiceData['trip_type'] == 'Local-taxi') {
      netTotal = double.parse(invoiceData['total_amount'].toString());
    }

    final double advancedAmount =
        double.tryParse(invoiceData['paid_amount']?.toString() ?? '') ?? 0.0;
    final double balanceAmount = (netTotal ?? 0.0) - advancedAmount;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Top Brand Header & Invoice Summary Box
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    flex: 6,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#EFF6FF'),
                            borderRadius:
                                const pw.BorderRadius.all(pw.Radius.circular(4)),
                            border: pw.Border.all(
                                color: PdfColor.fromHex('#BFDBFE'), width: 0.8),
                          ),
                          child: pw.Text(
                            "CAR RENTAL INVOICE",
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('#1E3A8A'),
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        if (_isAgentInvoice) ...[
                          pw.Text(
                            _agentHeaderName,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 16,
                              color: PdfColor.fromHex('#0F172A'),
                            ),
                          ),
                          if (_agentHeaderAddress.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              _agentHeaderAddress,
                              style: pw.TextStyle(
                                  fontSize: 9.5,
                                  color: PdfColor.fromHex('#475569')),
                            ),
                          ],
                          if (_agentHeaderContact.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              _agentHeaderContact,
                              style: pw.TextStyle(
                                  fontSize: 9.5,
                                  color: PdfColor.fromHex('#475569')),
                            ),
                          ],
                          if (_agentHeaderGst.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              "GSTIN: $_agentHeaderGst",
                              style: pw.TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#1E3A8A')),
                            ),
                          ],
                        ] else ...[
                          pw.Text(
                            "RENTOX CAR",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 16,
                              color: PdfColor.fromHex('#0F172A'),
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            "7, Jalaram Niwas, Ganesh Gawde Road, Mulund (W), Mumbai - 400080",
                            style: pw.TextStyle(
                                fontSize: 9.5,
                                color: PdfColor.fromHex('#475569')),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            "Tel: 9619936999 | Email: agnicarrental@gmail.com | Web: www.agnicarrental.com",
                            style: pw.TextStyle(
                                fontSize: 9.5,
                                color: PdfColor.fromHex('#475569')),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            "GSTIN: 27AABPG5706A3ZB",
                            style: pw.TextStyle(
                                fontSize: 9.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#1E3A8A')),
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    flex: 4,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F8FAFC'),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(
                            color: PdfColor.fromHex('#E2E8F0'), width: 1),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text("BILL NO:",
                                  style: pw.TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColor.fromHex('#64748B'))),
                              pw.Text("#${invoiceData['invoiceNumber']}",
                                  style: pw.TextStyle(
                                      fontSize: 11,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColor.fromHex('#0F172A'))),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Divider(
                              color: PdfColor.fromHex('#E2E8F0'),
                              thickness: 0.6),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text("DATE:",
                                  style: pw.TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColor.fromHex('#64748B'))),
                              pw.Text("${invoiceData['invoieceDate']}",
                                  style: pw.TextStyle(
                                      fontSize: 9.5,
                                      color: PdfColor.fromHex('#0F172A'))),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text("TRIP TYPE:",
                                  style: pw.TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColor.fromHex('#64748B'))),
                              pw.Text("${invoiceData['trip_type']}",
                                  style: pw.TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColor.fromHex('#1E3A8A'))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // Customer & Route Cards Row
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Customer Card
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F8FAFC'),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(
                            color: PdfColor.fromHex('#E2E8F0'), width: 1),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "CUSTOMER INFORMATION",
                            style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#1E3A8A'),
                                letterSpacing: 0.5),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            "Passenger: ${invoiceData['cus_name']}",
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#0F172A')),
                          ),
                          if (!_isAgentInvoice &&
                              invoiceData['gst_number'] != 'Not Generated' &&
                              invoiceData['gst_number'] != '') ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                                "Business: ${invoiceData['business_name']}",
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    color: PdfColor.fromHex('#475569'))),
                            pw.Text(
                                "Address: ${invoiceData['business_address']}",
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    color: PdfColor.fromHex('#475569'))),
                            pw.Text("GSTIN: ${invoiceData['gst_number']}",
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColor.fromHex('#1E3A8A'))),
                          ],
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  // Trip & Route Card
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F8FAFC'),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(
                            color: PdfColor.fromHex('#E2E8F0'), width: 1),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "VEHICLE & ROUTE",
                            style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#1E3A8A'),
                                letterSpacing: 0.5),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            "Vehicle: ${invoiceData['car_type']}",
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#0F172A')),
                          ),
                          if (invoiceData['driver_name'] != null &&
                              invoiceData['driver_name']!.isNotEmpty &&
                              invoiceData['driver_name'] != 'Not Generated') ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              "Driver: ${invoiceData['driver_name']}${invoiceData['driver_phone'] != '' ? ' (${invoiceData['driver_phone']})' : ''}",
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#0F172A')),
                            ),
                          ],
                          pw.SizedBox(height: 2),
                          pw.Text(
                            invoiceData['trip_type'] != 'Local-Duty'
                                ? "Route: ${invoiceData['from']} -> ${invoiceData['to']}"
                                : "Location: ${invoiceData['from']}",
                            style: pw.TextStyle(
                                fontSize: 9,
                                color: PdfColor.fromHex('#475569')),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            "Date: ${invoiceData['starting_date']}",
                            style: pw.TextStyle(
                                fontSize: 9,
                                color: PdfColor.fromHex('#475569')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Meter & Journey Summary Strip
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F1F5F9'),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(
                      color: PdfColor.fromHex('#E2E8F0'), width: 1),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("STARTING",
                            style: pw.TextStyle(
                                fontSize: 7.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#64748B'))),
                        pw.Text(dateFormat.format(startDateTime),
                            style: pw.TextStyle(
                                fontSize: 8.5,
                                color: PdfColor.fromHex('#0F172A'))),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("ENDING",
                            style: pw.TextStyle(
                                fontSize: 7.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#64748B'))),
                        pw.Text(dateFormat.format(endDateTime),
                            style: pw.TextStyle(
                                fontSize: 8.5,
                                color: PdfColor.fromHex('#0F172A'))),
                      ],
                    ),
                    if (invoiceData['trip_type'] == 'Local-Duty' ||
                        invoiceData['trip_type'] == 'Round-Trip') ...[
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("START KM",
                              style: pw.TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#64748B'))),
                          pw.Text(_formatNumber(invoiceData['starting_km']!),
                              style: pw.TextStyle(
                                  fontSize: 8.5,
                                  color: PdfColor.fromHex('#0F172A'))),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("END KM",
                              style: pw.TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#64748B'))),
                          pw.Text(_formatNumber(invoiceData['closing_km']!),
                              style: pw.TextStyle(
                                  fontSize: 8.5,
                                  color: PdfColor.fromHex('#0F172A'))),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("TOTAL KM",
                              style: pw.TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#1E3A8A'))),
                          pw.Text("${_formatNumber(totalKm)} KM",
                              style: pw.TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#1E3A8A'))),
                        ],
                      ),
                    ],
                    if (invoiceData['trip_type'] == 'Round-Trip') ...[
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("DAYS",
                              style: pw.TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#64748B'))),
                          pw.Text("$totalDays Days",
                              style: pw.TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#0F172A'))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Modern Fare Breakdown Table
              pw.ClipRRect(
                horizontalRadius: 6,
                verticalRadius: 6,
                child: pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(4.2),
                    1: const pw.FlexColumnWidth(2.5),
                    2: const pw.FlexColumnWidth(3.3),
                  },
                  children: [
                    _buildModernPdfTableRow(
                        'DESCRIPTION', 'RATE / DETAILS', 'AMOUNT',
                        isHeader: true),
                    if (invoiceData['trip_type'] == 'Local-Duty') ...[
                      _buildModernPdfTableRow(
                        'Package',
                        '${invoiceData['packageHours']} Hours - ${_formatNumber(invoiceData['packageKm'])} Km',
                        '$packageBaseWithCommission',
                      ),
                      _buildModernPdfTableRow(
                        'Extra Km',
                        'Rs ${_formatNumber(invoiceData['extra_km_price'])} * ${_formatNumber(extraKm)} Km',
                        '$extrakmAmount',
                        isAlt: true,
                      ),
                      _buildModernPdfTableRow(
                        'Extra Hrs',
                        'Rs ${_formatNumber(invoiceData['extra_hours_price'])} * ${_formatNumber(extraHours)} Hrs',
                        '$extraHoursAmount',
                      ),
                    ],
                    if (invoiceData['trip_type'] == 'Round-Trip') ...[
                      _buildModernPdfTableRow(
                        'Total Km charge',
                        '${_formatNumber(maxKm)} x $commissionFormulaText',
                        '$baceAmount',
                      ),
                      _buildModernPdfTableRow(
                          'Total Days', '$totalDays Days', '',
                          isAlt: true),
                    ],
                    _buildModernPdfTableRow('Parking', '', '$parking_charge'),
                    if (invoiceData['trip_type'] != 'One-way') ...[
                      _buildModernPdfTableRow('Toll', '', '$toll_charge',
                          isAlt: true),
                      _buildModernPdfTableRow(
                          'Permit Charge', '', '$permit_charge'),
                      _buildModernPdfTableRow(
                          'Driver Allowance', '', '${driver_allowance ?? ""} ',
                          isAlt: true),
                    ],
                    if (invoiceData['trip_type'] == 'One-way') ...[
                      _buildModernPdfTableRow(
                          'Base Amount', '', '$baceAmount'),
                      _buildModernPdfTableRow('Total Charge', '',
                          '${(baceAmount! + parking_charge!)}',
                          isAlt: true),
                    ],
                    if (invoiceData['trip_type'] != 'Local-taxi') ...[
                      if (isIntraState) ...[
                        _buildModernPdfTableRow(
                            'CGST ${_formatNumber(gstPercent / 2)}%',
                            '',
                            '${(gst! / 2)}'),
                        _buildModernPdfTableRow(
                            'SGST ${_formatNumber(gstPercent / 2)}%',
                            '',
                            '${(gst! / 2)}',
                            isAlt: true),
                      ] else ...[
                        _buildModernPdfTableRow(
                            'IGST ${_formatNumber(gstPercent)}%',
                            '',
                            '$gst'),
                      ],
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Total & Payment Summary Row
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Left side info
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (userType == 'agent') ...[
                          pw.Container(
                            padding: const pw.EdgeInsets.all(7),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex('#EFF6FF'),
                              borderRadius:
                                  const pw.BorderRadius.all(pw.Radius.circular(4)),
                              border: pw.Border.all(
                                  color: PdfColor.fromHex('#BFDBFE'), width: 0.8),
                            ),
                            child: pw.Text(
                              "Agent Commission is included in the above amount",
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColor.fromHex('#1E3A8A')),
                            ),
                          ),
                          pw.SizedBox(height: 6),
                        ],
                        if (!_isAgentInvoice) ...[
                          pw.Container(
                            padding: const pw.EdgeInsets.all(7),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex('#F8FAFC'),
                              borderRadius:
                                  const pw.BorderRadius.all(pw.Radius.circular(4)),
                              border: pw.Border.all(
                                  color: PdfColor.fromHex('#E2E8F0'), width: 0.8),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("BANK PAYMENT DETAILS",
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                        fontSize: 8,
                                        color: PdfColor.fromHex('#1E3A8A'))),
                                pw.SizedBox(height: 2),
                                pw.Text("Bank: Federal Bank | A/c: RENTOX CAR",
                                    style: pw.TextStyle(
                                        fontSize: 8,
                                        color: PdfColor.fromHex('#334155'))),
                                pw.Text(
                                    "A/c No: 15390200008421 | IFSC: FDRL0001539",
                                    style: pw.TextStyle(
                                        fontSize: 8,
                                        color: PdfColor.fromHex('#334155'))),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  // Right side Payment Summary Card
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F8FAFC'),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(
                            color: PdfColor.fromHex('#CBD5E1'), width: 1),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex('#1E3A8A'),
                              borderRadius:
                                  const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text("TOTAL",
                                    style: pw.TextStyle(
                                        color: PdfColors.white,
                                        fontWeight: pw.FontWeight.bold,
                                        fontSize: 10)),
                                pw.Text(_formatCurrency(netTotal),
                                    style: pw.TextStyle(
                                        color: PdfColors.white,
                                        fontWeight: pw.FontWeight.bold,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 5),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text("Advance Amount",
                                  style: pw.TextStyle(
                                      fontSize: 8.5,
                                      color: PdfColor.fromHex('#475569'))),
                              pw.Text(_formatCurrency(advancedAmount),
                                  style: pw.TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColor.fromHex('#059669'))),
                            ],
                          ),
                          pw.SizedBox(height: 3),
                          pw.Divider(
                              color: PdfColor.fromHex('#E2E8F0'),
                              thickness: 0.6),
                          pw.SizedBox(height: 3),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text("Balance Amount",
                                  style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColor.fromHex('#0F172A'))),
                              pw.Text(_formatCurrency(balanceAmount),
                                  style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                      color: balanceAmount > 0
                                          ? PdfColor.fromHex('#DC2626')
                                          : PdfColor.fromHex('#0F172A'))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // Modern Footer & Signature
              pw.Divider(color: PdfColor.fromHex('#CBD5E1'), thickness: 0.8),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (!_isAgentInvoice) ...[
                        pw.Text(
                          "Kindly issue a crossed cheque in favour of AGNI CAR RENTAL \"Subject To Mumbai Jurisdiction\"",
                          style: pw.TextStyle(
                              fontSize: 7,
                              color: PdfColor.fromHex('#64748B')),
                        ),
                      ] else ...[
                        pw.Text(
                          "Thank you for choosing $_agentHeaderName",
                          style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColor.fromHex('#1E3A8A')),
                        ),
                      ],
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                          width: 100,
                          height: 1,
                          color: PdfColor.fromHex('#94A3B8')),
                      pw.SizedBox(height: 2),
                      pw.Text("Authorized Signatory",
                          style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#334155'))),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  Future<void> _sharePDF(BuildContext context) async {
    try {
      final pdf = await _generateDocument();
      final outputDir = await getTemporaryDirectory();
      final file = File("${outputDir.path}/invoice_${widget.bookingId}.pdf");
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Invoice for Booking #${widget.bookingId}',
      );
    } catch (e) {
      print("Error sharing: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sharing invoice: $e")),
      );
    }
  }

  Future<void> _savePDF(BuildContext context) async {
    if (Platform.isIOS) {
      await _sharePDF(context);
      return;
    }
    try {
      final pdf = await _generateDocument();

      Directory? targetDir;
      if (Platform.isAndroid) {
        targetDir = Directory('/storage/emulated/0/Download');
        if (!await targetDir.exists()) {
          targetDir = await getExternalStorageDirectory();
        }
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      final fileName = "invoice_${widget.bookingId}.pdf";
      final file = File("${targetDir!.path}/$fileName");
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Invoice saved to: ${file.path}"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: "OPEN",
            textColor: Colors.white,
            onPressed: () {
              OpenFile.open(file.path);
            },
          ),
        ),
      );
    } catch (e) {
      print("Error saving: $e");
      try {
        final pdf = await _generateDocument();
        final targetDir = await getApplicationDocumentsDirectory();
        final file = File("${targetDir.path}/invoice_${widget.bookingId}.pdf");
        await file.writeAsBytes(await pdf.save());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Saved to app folder. Tap to view invoice."),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: "VIEW",
              textColor: Colors.white,
              onPressed: () {
                OpenFile.open(file.path);
              },
            ),
          ),
        );
      } catch (ex) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving invoice: $ex")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Invoice #${invoiceData['invoiceNumber']}",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: "Download PDF",
            onPressed: () => _savePDF(context),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: "Share PDF",
            onPressed: () => _sharePDF(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: _buildInvoiceContent(),
      ),
    );
  }

  Widget _buildInvoiceContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modern Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      "CAR RENTAL INVOICE",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "Bill #${invoiceData['invoiceNumber']}",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isAgentInvoice) ...[
                Text(
                  _agentHeaderName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                if (_agentHeaderAddress.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_agentHeaderAddress,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: const Color(0xFF475569))),
                ],
                if (_agentHeaderContact.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_agentHeaderContact,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: const Color(0xFF475569))),
                ],
                if (_agentHeaderGst.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text("GSTIN: $_agentHeaderGst",
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E3A8A))),
                ],
              ] else ...[
                Text(
                  "RENTOX CAR",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                    "7, Jalaram Niwas, Ganesh Gawde Road, Mulund (W), Mumbai - 400080",
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: const Color(0xFF475569))),
                const SizedBox(height: 2),
                Text(
                    "Tel: 9619936999 | Email: agnicarrental@gmail.com | Web: www.agnicarrental.com",
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: const Color(0xFF475569))),
                const SizedBox(height: 2),
                Text("GSTIN: 27AABPG5706A3ZB",
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E3A8A))),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Date: ${invoiceData['invoieceDate']}",
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: const Color(0xFF64748B))),
                  Text("Trip: ${invoiceData['trip_type']}",
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E3A8A))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Customer & Trip Info Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "PASSENGER & ROUTE DETAILS",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E3A8A),
                  letterSpacing: 0.5,
                ),
              ),
              const Divider(height: 16, color: Color(0xFFE2E8F0)),
              _buildInfoRow(
                  Icons.person_outline, "Passenger", invoiceData['cus_name']!),
              if (!_isAgentInvoice &&
                  invoiceData['gst_number'] != 'Not Generated' &&
                  invoiceData['gst_number'] != '') ...[
                _buildInfoRow(Icons.business_outlined, "Business Name",
                    invoiceData['business_name']!),
                _buildInfoRow(Icons.location_city_outlined, "Address",
                    invoiceData['business_address']!),
                _buildInfoRow(Icons.receipt_long_outlined, "GSTIN",
                    invoiceData['gst_number']!),
              ],
              _buildInfoRow(Icons.directions_car_outlined, "Vehicle",
                  invoiceData['car_type']!),
              if (invoiceData['driver_name'] != null &&
                  invoiceData['driver_name']!.isNotEmpty &&
                  invoiceData['driver_name'] != 'Not Generated') ...[
                _buildInfoRow(Icons.person_pin_circle_outlined, "Driver Name",
                    invoiceData['driver_name']!),
              ],
              if (invoiceData['driver_phone'] != null &&
                  invoiceData['driver_phone']!.isNotEmpty &&
                  invoiceData['driver_phone'] != 'Not Generated') ...[
                _buildInfoRow(Icons.phone_outlined, "Driver Phone",
                    invoiceData['driver_phone']!),
              ],
              _buildInfoRow(Icons.trip_origin, "From", invoiceData['from']!),
              if (invoiceData['trip_type'] != 'Local-Duty') ...[
                _buildInfoRow(
                    Icons.location_on_outlined, "To", invoiceData['to']!),
              ],
              _buildInfoRow(Icons.calendar_today_outlined, "Trip Date",
                  invoiceData['starting_date']!),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Table & Fare Breakdown
        _buildTable(),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
          ),
          const Text(": ", style: TextStyle(color: Color(0xFF94A3B8))),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final dateFormat = DateFormat('yyyy-MM-dd hh:mm a');
    final totalKm = double.parse(invoiceData['closing_km']!) -
        double.parse(invoiceData['starting_km']!);
    final startingDate = invoiceData['starting_date'];
    final startingTime = invoiceData['starting_time'];
    final closingDate = invoiceData['closing_date'];
    final closingTime = invoiceData['closing_time'];
    final startDateTime =
        DateTime.tryParse('$startingDate $startingTime') ?? DateTime.now();
    var endDateTime =
        DateTime.tryParse('$closingDate $closingTime') ?? DateTime.now();
    if (endDateTime.isBefore(startDateTime)) {
      endDateTime = endDateTime.add(const Duration(days: 1));
    }
    final duration = endDateTime.difference(startDateTime);
    var hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    String? commission;
    double? packageBaseWithCommission;
    String commissionFormulaText = '';
    int? totalDays = 0;
    double? extraKm;
    double? extrakmAmount;
    num? extraHours;
    double? extraHoursAmount;
    double? gst;
    double? netTotal;
    String? driver_allowance;
    double? baceAmount;
    double baseKmCharge = 0.0;
    double agentCommissionAmount = 0.0;
    double commissionRate = 0.0;

    var maxKm;
    double kmRate =
        double.tryParse(invoiceData['kmRate']?.toString() ?? '') ?? 0.0;
    double gstPercent = double.parse(invoiceData['gstPercent'].toString());
    bool isIntraState = true;
    String custGst = (invoiceData['gst_number'] ?? '').trim();
    if (custGst.isNotEmpty && custGst != 'Not Generated' && custGst != 'None') {
      String stateCode = custGst.length >= 2 ? custGst.substring(0, 2) : '';
      if (stateCode.isNotEmpty && stateCode != '27') {
        isIntraState = false;
      }
    }
    double? agent_commission =
        double.tryParse(invoiceData['agent_commission'].toString()) ?? 0.0;
    double? permit_charge =
        double.tryParse(invoiceData['permit_charge'].toString()) ?? 0.0;
    double? parking_charge =
        double.tryParse(invoiceData['parking_charge'].toString()) ?? 0.0;
    double? toll_charge =
        double.tryParse(invoiceData['toll_charge'].toString()) ?? 0.0;
    if (invoiceData['trip_type'] == 'Local-Duty') {
      final packageKm = double.tryParse(invoiceData['packageKm'] ?? '0') ?? 0;
      final packageHours =
          double.tryParse(invoiceData['packageHours'] ?? '0') ?? 0;
      final extraKmPrice =
          double.tryParse(invoiceData['extra_km_price'] ?? '0') ?? 0;
      final extraHoursPrice =
          double.tryParse(invoiceData['extra_hours_price'] ?? '0') ?? 0;
      final packageBaseFare =
          double.tryParse(invoiceData['packageBaseFare'] ?? '0') ?? 0;
      double driverAllowance = 0.0;

      extraKm = totalKm > packageKm ? totalKm - packageKm : 0;
      extrakmAmount = extraKm * extraKmPrice;

      if (minutes > 30) hours += 1;
      extraHours = hours > packageHours ? hours - packageHours : 0;
      extraHoursAmount = extraHours * extraHoursPrice;

      bool isStartBefore5AM = startDateTime.hour < 5;
      bool isEndAfter1130PM = endDateTime.hour > 23 ||
          (endDateTime.hour == 23 && endDateTime.minute > 30);
      if (isStartBefore5AM || isEndAfter1130PM) {
        driverAllowance =
            double.tryParse(invoiceData['driver_allowance'] ?? '0') ?? 0;
      }

      double totalBeforeGst =
          packageBaseFare + extrakmAmount + extraHoursAmount + agent_commission;

      gst = totalBeforeGst * gstPercent / 100;
      netTotal = totalBeforeGst +
          gst +
          parking_charge +
          toll_charge +
          permit_charge +
          driverAllowance;

      baceAmount = double.parse(packageBaseFare.toStringAsFixed(2));
      packageBaseWithCommission =
          double.parse((packageBaseFare + agent_commission).toStringAsFixed(2));
      extrakmAmount = double.parse(extrakmAmount.toStringAsFixed(2));
      extraHoursAmount = double.parse(extraHoursAmount.toStringAsFixed(2));
      driverAllowance = double.parse(driverAllowance.toStringAsFixed(2));
      totalBeforeGst = double.parse(totalBeforeGst.toStringAsFixed(2));
      gst = double.parse(gst.toStringAsFixed(2));
      netTotal = double.parse(netTotal.toStringAsFixed(2));
      driver_allowance = driverAllowance.toString();
    }

    if (invoiceData['trip_type'] == 'Round-Trip') {
      double? driver_allowanceXdays;
      driver_allowance = invoiceData['driver_allowance'].toString();
      double runningKm = double.parse(invoiceData['closing_km'] ?? '0') -
          double.parse(invoiceData['starting_km'] ?? '0');
      double daily_limit = double.parse(invoiceData['daily_limit'] ?? '0');
      commission = userType == 'agent' ? '+${agent_commission.toString()}' : '';

      int days = 1;
      try {
        final bStartStr = invoiceData['booked_start_date'] ?? '';
        final bReturnStr = invoiceData['booked_return_date'] ?? '';
        if (bStartStr.isNotEmpty &&
            bReturnStr.isNotEmpty &&
            bStartStr != '0000-00-00' &&
            bReturnStr != '0000-00-00') {
          try {
            final bStart = DateFormat('dd MMM yyyy').parse(bStartStr);
            final bReturn = DateFormat('dd MMM yyyy').parse(bReturnStr);
            days = bReturn.difference(bStart).inDays + 1;
          } catch (_) {
            final bStart = DateTime.parse(bStartStr);
            final bReturn = DateTime.parse(bReturnStr);
            days = bReturn.difference(bStart).inDays + 1;
          }
        }
      } catch (e) {
        debugPrint("Error parsing booked dates: $e");
      }
      if (days <= 0) days = 1;
      maxKm = max(runningKm, (daily_limit * days));
      double dailyAllowance = double.tryParse(driver_allowance) ?? 400.0;
      bool isEarlyMorning = _isEarlyMorningTime(startingTime ?? '') ||
          ((startDateTime.hour >= 1 && startDateTime.hour < 6) ||
              (startDateTime.hour == 6 && startDateTime.minute == 0));
      double earlyMorningAllowance = isEarlyMorning ? 300.0 : 0.0;
      driver_allowanceXdays = (dailyAllowance * days) + earlyMorningAllowance;
      driver_allowance = driver_allowanceXdays.toStringAsFixed(2);
      totalDays = days;

      double commissionRateVal = 0.0;
      if (agent_commission > 0 && days > 0 && daily_limit > 0) {
        commissionRateVal =
            (agent_commission / (daily_limit * days)).roundToDouble();
      }
      commissionRate = commissionRateVal;
      baseKmCharge = (maxKm ?? 0) * kmRate;
      agentCommissionAmount = (maxKm ?? 0) * commissionRateVal;
      double effectiveKmRate = kmRate + commissionRateVal;
      baceAmount = baseKmCharge + agentCommissionAmount;

      commissionFormulaText = effectiveKmRate % 1 == 0
          ? effectiveKmRate.toInt().toString()
          : (effectiveKmRate.toStringAsFixed(2).endsWith('.00')
              ? effectiveKmRate.toInt().toString()
              : effectiveKmRate.toStringAsFixed(1));

      gst = baceAmount! * gstPercent / 100;

      netTotal = baceAmount +
          gst +
          parking_charge +
          toll_charge +
          permit_charge +
          driver_allowanceXdays;
    }

    double base_charge = 0.0;
    if (invoiceData['trip_type'] == 'One-way') {
      double distance = double.parse(invoiceData['distance'].toString());
      double driver_allowanceVal;

      driver_allowanceVal = (distance < 200) ? 300 : 400;

      baceAmount = invoiceData['total_amount'] != '0'
          ? double.parse(invoiceData['total_amount'].toString())
          : (distance * kmRate) + driver_allowanceVal + agent_commission;

      double totalbeforeGst = baceAmount;

      gst = baceAmount * gstPercent / 100;
      netTotal =
          baceAmount + gst + parking_charge + toll_charge + permit_charge;

      base_charge = baceAmount;

      baceAmount = double.parse(baceAmount.toStringAsFixed(2));
      totalbeforeGst = double.parse(totalbeforeGst.toStringAsFixed(2));
      gst = double.parse(gst.toStringAsFixed(2));
      netTotal = double.parse(netTotal.toStringAsFixed(2));
      driver_allowance = driver_allowanceVal.toString();
    }

    if (invoiceData['trip_type'] == 'Local-taxi') {
      netTotal = double.parse(invoiceData['total_amount'].toString());
    }

    final double advancedAmount =
        double.tryParse(invoiceData['paid_amount']?.toString() ?? '') ?? 0.0;
    final double balanceAmount = (netTotal ?? 0.0) - advancedAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meter & Timeline Strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("STARTING",
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B))),
                      Text(dateFormat.format(startDateTime),
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A))),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("ENDING",
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B))),
                      Text(dateFormat.format(endDateTime),
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A))),
                    ],
                  ),
                ],
              ),
              if (invoiceData['trip_type'] == 'Local-Duty' ||
                  invoiceData['trip_type'] == 'Round-Trip') ...[
                const Divider(height: 14, color: Color(0xFFE2E8F0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMeterCell("START KM", _formatNumber(invoiceData['starting_km']!)),
                    _buildMeterCell("END KM", _formatNumber(invoiceData['closing_km']!)),
                    _buildMeterCell("TOTAL KM", "${_formatNumber(totalKm)} KM",
                        isHighlight: true),
                    if (invoiceData['trip_type'] == 'Round-Trip')
                      _buildMeterCell("DAYS", "$totalDays Days"),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Modern Fare Breakdown Table
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(4.2),
                1: FlexColumnWidth(2.5),
                2: FlexColumnWidth(3.3),
              },
              children: [
                _buildModernTableRow(
                    'DESCRIPTION', 'RATE / DETAILS', 'AMOUNT',
                    isHeader: true),
                if (invoiceData['trip_type'] == 'Local-Duty') ...[
                  _buildModernTableRow(
                    'Package',
                    '${invoiceData['packageHours']} Hours - ${_formatNumber(invoiceData['packageKm'])} Km',
                    '$packageBaseWithCommission',
                  ),
                  _buildModernTableRow(
                    'Extra Km',
                    'Rs ${_formatNumber(invoiceData['extra_km_price'])} * ${_formatNumber(extraKm)} Km',
                    '$extrakmAmount',
                    isAlt: true,
                  ),
                  _buildModernTableRow(
                    'Extra Hrs',
                    'Rs ${_formatNumber(invoiceData['extra_hours_price'])} * ${_formatNumber(extraHours)} Hrs',
                    '$extraHoursAmount',
                  ),
                ],
                if (invoiceData['trip_type'] == 'Round-Trip') ...[
                  _buildModernTableRow(
                    'Total Km charge',
                    '${_formatNumber(maxKm)} x $commissionFormulaText',
                    '$baceAmount',
                  ),
                  _buildModernTableRow('Total Days', '$totalDays Days', '',
                      isAlt: true),
                ],
                _buildModernTableRow('Parking', '', '$parking_charge'),
                if (invoiceData['trip_type'] != 'One-way') ...[
                  _buildModernTableRow('Toll', '', '$toll_charge',
                      isAlt: true),
                  _buildModernTableRow('Permit Charge', '', '$permit_charge'),
                  _buildModernTableRow(
                      'Driver Allowance', '', '${driver_allowance ?? ""} ',
                      isAlt: true),
                ],
                if (invoiceData['trip_type'] == 'One-way') ...[
                  _buildModernTableRow(
                      'Base Amount', '', '$baceAmount'),
                  _buildModernTableRow('Total Charge', '',
                      '${(baceAmount! + parking_charge!)}',
                      isAlt: true),
                ],
                if (invoiceData['trip_type'] != 'Local-taxi') ...[
                  if (isIntraState) ...[
                    _buildModernTableRow(
                        'CGST ${_formatNumber(gstPercent / 2)}%',
                        '',
                        '${(gst! / 2)}'),
                    _buildModernTableRow(
                        'SGST ${_formatNumber(gstPercent / 2)}%',
                        '',
                        '${(gst! / 2)}',
                        isAlt: true),
                  ] else ...[
                    _buildModernTableRow('IGST ${_formatNumber(gstPercent)}%',
                        '', '$gst'),
                  ],
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Total & Payment Summary Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "TOTAL FARE",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _formatCurrency(netTotal),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Advance Amount",
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: const Color(0xFF475569))),
                  Text(_formatCurrency(advancedAmount),
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF059669))),
                ],
              ),
              const Divider(height: 16, color: Color(0xFFE2E8F0)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Balance Amount",
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A))),
                  Text(_formatCurrency(balanceAmount),
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: balanceAmount > 0
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF0F172A))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Agent Commission Note
        if (userType == 'agent') ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: Color(0xFF1E3A8A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Agent Commission is included in the above amount",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E3A8A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Bank Details Card (if not agent)
        if (!_isAgentInvoice) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("BANK PAYMENT DETAILS",
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: const Color(0xFF1E3A8A))),
                const SizedBox(height: 4),
                Text("Bank: Federal Bank  |  A/c: RENTOX CAR",
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: const Color(0xFF334155))),
                Text("A/c No: 15390200008421  |  IFSC: FDRL0001539",
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: const Color(0xFF334155))),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Signatory & Footer note
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  !_isAgentInvoice
                      ? "Kindly issue a crossed cheque in favour of AGNI CAR RENTAL \"Subject To Mumbai Jurisdiction\""
                      : "Thank you for choosing $_agentHeaderName",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Container(width: 100, height: 1, color: const Color(0xFF94A3B8)),
                  const SizedBox(height: 4),
                  Text("Authorized Sign.",
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMeterCell(String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B))),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                color: isHighlight
                    ? const Color(0xFF1E3A8A)
                    : const Color(0xFF0F172A))),
      ],
    );
  }

  TableRow _buildModernTableRow(
    String col1,
    String col2,
    String col3, {
    bool isHeader = false,
    bool isAlt = false,
    bool isTotal = false,
  }) {
    final bgColor = isHeader
        ? const Color(0xFF1E3A8A)
        : isTotal
            ? const Color(0xFFF1F5F9)
            : isAlt
                ? const Color(0xFFF8FAFC)
                : Colors.white;

    final textColor = isHeader
        ? Colors.white
        : isTotal
            ? const Color(0xFF0F172A)
            : const Color(0xFF1E293B);

    final textWeight =
        (isHeader || isTotal) ? FontWeight.bold : FontWeight.normal;
    final fontSize = isHeader ? 11.5 : (isTotal ? 12.5 : 11.5);

    String displayCol3 = '';
    if (col3.isNotEmpty) {
      if (isHeader || col3 == 'TOTAL' || col3 == 'AMOUNT') {
        displayCol3 = col3;
      } else {
        displayCol3 = _formatCurrency(col3);
      }
    }

    return TableRow(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: isHeader
                ? const Color(0xFF1E3A8A)
                : const Color(0xFFE2E8F0),
            width: isTotal ? 1.5 : 0.8,
          ),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Text(
            col1,
            style: GoogleFonts.poppins(
              fontWeight: (col1 == 'TOTAL' || isHeader)
                  ? FontWeight.bold
                  : (isTotal ? FontWeight.bold : FontWeight.w500),
              fontSize: fontSize,
              color: textColor,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          child: Text(
            col2,
            style: GoogleFonts.poppins(
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              fontSize: fontSize,
              color: isHeader ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              displayCol3,
              softWrap: false,
              maxLines: 1,
              style: GoogleFonts.poppins(
                fontWeight: (col1 == 'TOTAL' || isHeader)
                    ? FontWeight.bold
                    : (isTotal ? FontWeight.bold : FontWeight.w600),
                fontSize: fontSize,
                color: isHeader
                    ? Colors.white
                    : (col1 == 'TOTAL'
                        ? const Color(0xFF1E3A8A)
                        : textColor),
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _isEarlyMorningTime(String timeStr) {
    if (timeStr.isEmpty) return false;
    try {
      final clean = timeStr.trim().toUpperCase();
      int hour = -1;
      int minute = 0;
      if (clean.contains('AM') || clean.contains('PM')) {
        final parts =
            clean.replaceAll('AM', '').replaceAll('PM', '').trim().split(':');
        hour = int.parse(parts[0]);
        if (parts.length > 1) minute = int.parse(parts[1]);
        if (clean.contains('AM')) {
          if (hour == 12) hour = 0;
        } else if (clean.contains('PM')) {
          if (hour != 12) hour += 12;
        }
      } else {
        final parts = clean.split(':');
        hour = int.parse(parts[0]);
        if (parts.length > 1) minute = int.parse(parts[1]);
      }
      return (hour >= 1 && hour < 6) || (hour == 6 && minute == 0);
    } catch (_) {
      return false;
    }
  }
}
