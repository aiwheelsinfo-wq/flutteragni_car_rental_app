import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:agni_car_rental/config/api_config.dart';
import 'package:share_plus/share_plus.dart';

class InvoicePage extends StatefulWidget {
  String bookingId;

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
    'agni_share': '0',
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
  };

  @override
  void initState() {
    super.initState();
    fetchInvoiceData("123");
  }

  Future<void> fetchInvoiceData(String invoiceId) async {
    userType = await secureStorage.read(key: "userType");
    final url = Uri.parse(
        "${ApiConfig.baseUrl}/get_invoice_data.php/get_invoice_data.php?bookingId=${widget.bookingId}");

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
            invoiceData['agni_share'] =
                (data['agni_share'] ?? '0').toString();
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

  pw.TableRow _buildPdfTableRow(String col1, String col2, String col3) {
    return pw.TableRow(
      children: [
        pw.Padding(
            padding: const pw.EdgeInsets.all(4.0),
            child: pw.Text(col1,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
        pw.Padding(
            padding: const pw.EdgeInsets.all(4.0),
            child: pw.Text(col2, style: const pw.TextStyle(fontSize: 10))),
        pw.Padding(
            padding: const pw.EdgeInsets.all(4.0),
            child: pw.Text(col3, style: const pw.TextStyle(fontSize: 10))),
      ],
    );
  }

  Future<pw.Document> _generateDocument() async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('yyyy-MM-dd hh:mm a');
    
    final totalKm = double.parse(invoiceData['closing_km']!) -
        double.parse(invoiceData['starting_km']!);
    final startingDate = invoiceData['starting_date']; // e.g., "2025-04-26"
    final startingTime = invoiceData['starting_time']; // e.g., "09:00:00"
    final closingDate = invoiceData['closing_date']; // e.g., "2025-04-26"
    final closingTime = invoiceData['closing_time']; // e.g., "17:30:00"
    final startDateTime = DateTime.parse('$startingDate $startingTime');
    final endDateTime = DateTime.parse('$closingDate $closingTime');
    final duration = endDateTime.difference(startDateTime);
    var hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    String? commission;
    double? packageBaseWithCommission;
    int? totalDays = 0;
    double? extraKm;
    double? extrakmAmount;
    num? extraHours;
    double? extraHoursAmount;
    double? gst;
    double? netTotal;
    String? driver_allowance;
    double? baceAmount;

    var maxKm;
    double kmRate =
        double.tryParse(invoiceData['kmRate']?.toString() ?? '') ?? 0.0;
    double gstPercent = double.parse(invoiceData['gstPercent'].toString());
    double? agent_commission =
        double.tryParse(invoiceData['agent_commission'].toString()) ?? 0.0;
    double? permit_charge =
        double.tryParse(invoiceData['permit_charge'].toString()) ?? 0.0;
    double? parking_charge =
        double.tryParse(invoiceData['parking_charge'].toString()) ?? 0.0;
    double? toll_charge =
        double.tryParse(invoiceData['toll_charge'].toString()) ?? 0.0;
    if (invoiceData['trip_type'] == 'Local-Duty') {
      // Parse inputs safely
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

      // Extra km
      extraKm = totalKm > packageKm ? totalKm - packageKm : 0;
      extrakmAmount = extraKm * extraKmPrice;

      // Extra hours
      if (minutes > 30) hours += 1;
      extraHours = hours > packageHours ? hours - packageHours : 0;
      extraHoursAmount = extraHours * extraHoursPrice;

      // Special allowance: start before 5AM or end after 11:30PM
      bool isStartBefore5AM = startDateTime.hour < 5;
      bool isEndAfter1130PM = endDateTime.hour > 23 ||
          (endDateTime.hour == 23 && endDateTime.minute > 30);
      if (isStartBefore5AM || isEndAfter1130PM) {
        driverAllowance =
            double.tryParse(invoiceData['driver_allowance'] ?? '0') ?? 0;
      }

      // Total base before GST
      double totalBeforeGst =
          packageBaseFare + extrakmAmount + extraHoursAmount + agent_commission;

      // GST and net total
      gst = totalBeforeGst * gstPercent / 100;
      netTotal = totalBeforeGst +
          gst +
          parking_charge +
          toll_charge +
          permit_charge +
          driverAllowance;

      // Format all numbers to 2 decimal places
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
      Duration diff = endDateTime.difference(startDateTime);
      int days = diff.inDays;
      double? driver_allowanceXdays;

      driver_allowance = invoiceData['driver_allowance'].toString();

      double runningKm = double.parse(invoiceData['closing_km'] ?? '0') -
          double.parse(invoiceData['starting_km'] ?? '0');
      double daily_limit = double.parse(invoiceData['daily_limit'] ?? '0');

      commission = userType == 'agent' ? '+${agent_commission.toString()}' : '';

      if (startDateTime.day == endDateTime.day) {
        days += 1;
      } else {
        days += 1;

        if (diff < const Duration(hours: 24)) {
          days += 1;
        }

        if ((endDateTime.hour == 23)) {
          days += 1;
        }

        if (endDateTime.hour < 6 ||
            (endDateTime.hour == 6 && endDateTime.minute < 30)) {
          days += 1;
        }

        if (startDateTime.hour < 6 ||
            (startDateTime.hour == 6 && startDateTime.minute < 30)) {
          days += 1;
        }
      }
      maxKm = runningKm;
      driver_allowanceXdays = double.parse(driver_allowance) * days;
      driver_allowance = driver_allowanceXdays.toString();
      totalDays = days;

      double agniShare = double.tryParse(invoiceData['agni_share']?.toString() ?? '') ?? 0.0;
      double agentRate = 0.0;
      int divisorDays = days <= 0 ? 1 : days;
      if (agent_commission > 0) {
        if (invoiceData['booking_status'] == 'Completed' && runningKm > 0) {
          agentRate = (agent_commission / runningKm).roundToDouble();
        } else {
          agentRate = (agent_commission / (300 * divisorDays)).roundToDouble();
        }
      }
      double finalRate = kmRate + agniShare + agentRate;
      baceAmount = (maxKm ?? 0) * finalRate;

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
          : (distance * kmRate) + driver_allowanceVal;

      double totalbeforeGst = (distance * kmRate) + agent_commission;

      gst = baceAmount * gstPercent / 100;
      netTotal = baceAmount + gst + parking_charge;

      base_charge = double.tryParse(invoiceData['base_charge']?.toString() ?? '') ?? 0.0;
      if (base_charge == 0.0) {
        base_charge = baceAmount - agent_commission;
      }

      // Format all values to 2 decimal places
      baceAmount = double.parse(baceAmount.toStringAsFixed(2));
      totalbeforeGst = double.parse(totalbeforeGst.toStringAsFixed(2));
      gst = double.parse(gst.toStringAsFixed(2));
      netTotal = double.parse(netTotal.toStringAsFixed(2));
      driver_allowance = driver_allowanceVal.toString();
    }

    if (invoiceData['trip_type'] == 'Local-taxi') {
      netTotal = double.parse(invoiceData['total_amount'].toString());
    }

    final double advancedAmount = double.tryParse(invoiceData['paid_amount']?.toString() ?? '') ?? 0.0;
    final double balanceAmount = (netTotal ?? 0.0) - advancedAmount;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text("CAR INVOICE",
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 8),
              pw.Text("RENTOX CAR ",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.Text(
                  "7, Jalaram Niwas, Ganesh Gawde Road, \nMulund (W), Mumbai - 400080",
                  style: const pw.TextStyle(fontSize: 12)),
              pw.Text(
                  "Tel: 9619936999 | Email: agnicarrental@gmail.com \nWebsite: www.agnicarrental.com",
                  style: const pw.TextStyle(fontSize: 12)),
              pw.Text("GST No: 27AABPG5706A3ZB", style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 8),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text("Date: ${invoiceData['invoieceDate']}",
                    style: const pw.TextStyle(fontSize: 12)),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Container(
                      width: 100,
                      child: pw.Text("Bill No:",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
                  pw.Expanded(child: pw.Text("${invoiceData['invoiceNumber']}", style: const pw.TextStyle(fontSize: 12))),
                ],
              ),
              if (invoiceData['gst_number'] != 'Not Generated' &&
                  invoiceData['gst_number'] != '') ...[
                pw.Row(
                  children: [
                    pw.Container(
                        width: 100,
                        child: pw.Text("Business Name:",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
                    pw.Expanded(child: pw.Text(invoiceData['business_name']!, style: const pw.TextStyle(fontSize: 12))),
                  ],
                ),
                pw.Row(
                  children: [
                    pw.Container(
                        width: 100,
                        child: pw.Text("Address:",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
                    pw.Expanded(child: pw.Text(invoiceData['business_address']!, style: const pw.TextStyle(fontSize: 12))),
                  ],
                ),
                pw.Row(
                  children: [
                    pw.Container(
                        width: 100,
                        child: pw.Text("GST No:",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
                    pw.Expanded(child: pw.Text(invoiceData['gst_number']!, style: const pw.TextStyle(fontSize: 12))),
                  ],
                ),
              ],
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Container(
                      width: 100,
                      child: pw.Text("Passenger:",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
                  pw.Expanded(child: pw.Text(invoiceData['cus_name']!, style: const pw.TextStyle(fontSize: 12))),
                ],
              ),
              pw.Row(
                children: [
                  pw.Container(
                      width: 100,
                      child: pw.Text("Trip Type:",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
                  pw.Expanded(child: pw.Text(invoiceData['trip_type']!, style: const pw.TextStyle(fontSize: 12))),
                ],
              ),
              pw.Row(
                children: [
                  pw.Container(
                      width: 100,
                      child: pw.Text("Vehicle:",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
                  pw.Expanded(child: pw.Text(invoiceData['car_type']!, style: const pw.TextStyle(fontSize: 12))),
                ],
              ),
              pw.Row(
                children: [
                  pw.Container(
                      width: 100,
                      child: pw.Text("From",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
                  pw.Expanded(child: pw.Text('${invoiceData['from']}', style: const pw.TextStyle(fontSize: 12))),
                ],
              ),
              if (invoiceData['trip_type'] != 'Local-Duty') ...[
                pw.Row(
                  children: [
                    pw.Container(
                        width: 100,
                        child: pw.Text("To ",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
                    pw.Expanded(child: pw.Text('${invoiceData['to']}', style: const pw.TextStyle(fontSize: 12))),
                  ],
                ),
              ],
              pw.Row(
                children: [
                  pw.Container(
                      width: 100,
                      child: pw.Text("Date:",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
                  pw.Expanded(child: pw.Text(invoiceData['starting_date']!, style: const pw.TextStyle(fontSize: 12))),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(2),
                },
                border: pw.TableBorder.all(),
                children: [
                  _buildPdfTableRow('Starting Date', dateFormat.format(startDateTime), ''),
                  _buildPdfTableRow('Ending Date', dateFormat.format(endDateTime), ''),

                  if (invoiceData['trip_type'] == 'Local-Duty' ||
                      invoiceData['trip_type'] == 'Round-Trip') ...[
                    _buildPdfTableRow('Starting Km ', invoiceData['starting_km']!, ''),
                    _buildPdfTableRow('Ending Km ', invoiceData['closing_km']!, ''),
                    _buildPdfTableRow('Total Km', totalKm.toStringAsFixed(2), ''),
                  ],
                  if (invoiceData['trip_type'] == 'Local-Duty') ...[
                    _buildPdfTableRow(
                        'Package',
                        '${invoiceData['packageHours'].toString()} Hours - ${invoiceData['packageKm'].toString()} Km',
                        '$packageBaseWithCommission'),
                    _buildPdfTableRow(
                        'Extra Km',
                        'Rs ${invoiceData['extra_km_price']} *  $extraKm Km ',
                        '$extrakmAmount'),
                    _buildPdfTableRow(
                        'Extra Hrs',
                        'Rs ${invoiceData['extra_hours_price']} * $extraHours Hrs',
                        '$extraHoursAmount'),
                  ],
                  if (invoiceData['trip_type'] == 'Round-Trip') ...[
                    _buildPdfTableRow('Vehicle Base Rate', '', 'Rs ${kmRate.toStringAsFixed(2)} / KM'),
                    _buildPdfTableRow('Agni Commission', '', 'Rs ${agniShare.toStringAsFixed(2)} / KM'),
                    if (agentRate > 0)
                      _buildPdfTableRow('Agent Commission', '', 'Rs ${agentRate.toStringAsFixed(2)} / KM'),
                    _buildPdfTableRow('Final Rate', '', 'Rs ${finalRate.toStringAsFixed(2)} / KM'),
                    _buildPdfTableRow(
                        'Total Km charge', '${maxKm?.toStringAsFixed(0)} KM x Rs ${finalRate.toStringAsFixed(2)}', '${baceAmount!.toStringAsFixed(2)}'),
                    _buildPdfTableRow('Total Days', '$totalDays', ''),
                  ],

                  _buildPdfTableRow('Parking', '', '$parking_charge'),
                  _buildPdfTableRow('Toll', '', '$toll_charge'),
                  _buildPdfTableRow('Permit Charge', '', '$permit_charge'),
                  _buildPdfTableRow('Driver Allowance', '', '${driver_allowance ?? ""} '),

                  if (invoiceData['trip_type'] == 'One-way') ...[
                    _buildPdfTableRow('Base Amount', '', '${base_charge.toStringAsFixed(2)}'),
                    _buildPdfTableRow('Agent Commission', '', '${agent_commission.toStringAsFixed(2)}'),
                    _buildPdfTableRow('Total Charge', '', '$baceAmount')
                  ],

                  if (invoiceData['trip_type'] != 'Local-taxi') ...[
                    _buildPdfTableRow('GSTIN', '27AABPG5706A3ZB', ''),
                    _buildPdfTableRow('GST $gstPercent%', '', '$gst'),
                  ],

                  _buildPdfTableRow('TOTAL', '', '$netTotal'),
                  _buildPdfTableRow('Advanced Amount', '', '${advancedAmount.toStringAsFixed(2)}'),
                  _buildPdfTableRow('Balance Amount', '', '${balanceAmount.toStringAsFixed(2)}'),
                ],
              ),
              if (userType == 'agent') ...[
                pw.SizedBox(height: 4),
                pw.Text("Agent Commission is included in the above amount",
                    style: const pw.TextStyle(fontSize: 10)),
              ],
              pw.SizedBox(height: 12),
              pw.Text("Bank Details:",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.Text("Federal Bank", style: const pw.TextStyle(fontSize: 12)),
              pw.Text("RENTOX CAR ", style: const pw.TextStyle(fontSize: 12)),
              pw.Text("A/c No.: 15390200008421", style: const pw.TextStyle(fontSize: 12)),
              pw.Text("IFSC CODE: FDRL0001539", style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 20),
              pw.Text("Authorized Sign.", style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 8),
              pw.Text(
                  "Kindly issue a crossed cheque in favour of AGNI CAR RENTAL \"Subject To Mumbai Jurisdiction\"",
                  style: const pw.TextStyle(fontSize: 10)),
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
      appBar: AppBar(
        title: const Text("Invoice"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt),
            tooltip: "Save Invoice",
            onPressed: () => _savePDF(context),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: "Share Invoice",
            onPressed: () => _sharePDF(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(12.0),
        child: _buildInvoiceContent(),
      ),
    );
  }

  Widget _buildInvoiceContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text("CAR INVOICE",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(height: 8),
        Text("RENTOX CAR ",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(
            "7, Jalaram Niwas, Ganesh Gawde Road, \nMulund (W), Mumbai - 400080",
            style: TextStyle(fontSize: 12)),
        Text(
            "Tel: 9619936999 | Email: agnicarrental@gmail.com \nWebsite: www.agnicarrental.com",
            style: TextStyle(fontSize: 12)),
        Text("GST No: 27AABPG5706A3ZB", style: TextStyle(fontSize: 12)),
        SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text("Date: ${invoiceData['invoieceDate']}",
              style: TextStyle(fontSize: 12)),
        ),
        SizedBox(height: 8),
        _buildRow("Bill No:", "${invoiceData['invoiceNumber']}"),
        if (invoiceData['gst_number'] != 'Not Generated' &&
            invoiceData['gst_number'] != '') ...[
          _buildRow("Business Name:", invoiceData['business_name']!),
          _buildRow("Address:", invoiceData['business_address']!),
          _buildRow("GST No:", invoiceData['gst_number']!),
        ],
        SizedBox(height: 8),
        _buildRow("Passenger:", invoiceData['cus_name']!),
        _buildRow("Trip Type:", invoiceData['trip_type']!),
        _buildRow("Vehicle:", invoiceData['car_type']!),
        _buildRow("From", '${invoiceData['from']}'),
        if (invoiceData['trip_type'] != 'Local-Duty') ...[
          _buildRow("To ", '${invoiceData['to']}'),
        ],
        _buildRow("Date:", invoiceData['starting_date']!),
        SizedBox(height: 8),
        _buildTable(),
        if (userType == 'agent') ...[
          Text("Agent Commission is inluded in the above amount",
              style: TextStyle(fontSize: 10)),
        ],
        SizedBox(height: 12),
        Text("Bank Details:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text("Federal Bank", style: TextStyle(fontSize: 12)),
        Text("RENTOX CAR ", style: TextStyle(fontSize: 12)),
        Text("A/c No.: 15390200008421", style: TextStyle(fontSize: 12)),
        Text("IFSC CODE: FDRL0001539", style: TextStyle(fontSize: 12)),
        SizedBox(height: 20),
        Text("Authorized Sign.", style: TextStyle(fontSize: 12)),
        Text(
            "Kindly issue a crossed cheque in favour of AGNI CAR RENTAL \"Subject To Mumbai Jurisdiction\"",
            style: TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Container(
              width: 100,
              child: Text(label,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final dateFormat =
        DateFormat('yyyy-MM-dd hh:mm a'); // or your desired format
    final totalKm = double.parse(invoiceData['closing_km']!) -
        double.parse(invoiceData['starting_km']!);
    final startingDate = invoiceData['starting_date']; // e.g., "2025-04-26"
    final startingTime = invoiceData['starting_time']; // e.g., "09:00:00"
    final closingDate = invoiceData['closing_date']; // e.g., "2025-04-26"
    final closingTime = invoiceData['closing_time']; // e.g., "17:30:00"
    final startDateTime = DateTime.parse('$startingDate $startingTime');
    final endDateTime = DateTime.parse('$closingDate $closingTime');
    final duration = endDateTime.difference(startDateTime);
    var hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    String? commission;
    double? packageBaseWithCommission;
    int? totalDays = 0;
    double? extraKm;
    double? extrakmAmount;
    num? extraHours;
    double? extraHoursAmount;
    double? gst;
    double? netTotal;
    String? driver_allowance;
    double? baceAmount;

    var maxKm;
    double kmRate =
        double.tryParse(invoiceData['kmRate']?.toString() ?? '') ?? 0.0;
    double gstPercent = double.parse(invoiceData['gstPercent'].toString());
    double? agent_commission =
        double.tryParse(invoiceData['agent_commission'].toString()) ?? 0.0;
    double? permit_charge =
        double.tryParse(invoiceData['permit_charge'].toString()) ?? 0.0;
    double? parking_charge =
        double.tryParse(invoiceData['parking_charge'].toString()) ?? 0.0;
    double? toll_charge =
        double.tryParse(invoiceData['toll_charge'].toString()) ?? 0.0;
    if (invoiceData['trip_type'] == 'Local-Duty') {
      // Parse inputs safely
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

      // Extra km
      extraKm = totalKm > packageKm ? totalKm - packageKm : 0;
      extrakmAmount = extraKm * extraKmPrice;

      // Extra hours
      if (minutes > 30) hours += 1;
      extraHours = hours > packageHours ? hours - packageHours : 0;
      extraHoursAmount = extraHours * extraHoursPrice;

      // Special allowance: start before 5AM or end after 11:30PM
      bool isStartBefore5AM = startDateTime.hour < 5;
      bool isEndAfter1130PM = endDateTime.hour > 23 ||
          (endDateTime.hour == 23 && endDateTime.minute > 30);
      if (isStartBefore5AM || isEndAfter1130PM) {
        driverAllowance =
            double.tryParse(invoiceData['driver_allowance'] ?? '0') ?? 0;
      }

      // Total base before GST
      double totalBeforeGst =
          packageBaseFare + extrakmAmount + extraHoursAmount + agent_commission;

      // GST and net total
      gst = totalBeforeGst * gstPercent / 100;
      netTotal = totalBeforeGst +
          gst +
          parking_charge +
          toll_charge +
          permit_charge +
          driverAllowance;

      // Format all numbers to 2 decimal places
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
      Duration diff = endDateTime.difference(startDateTime);
      int days = diff.inDays;
      // int kmDays = days;
      // int allowanceDays = days;
      double? driver_allowanceXdays;

      driver_allowance = invoiceData['driver_allowance'].toString();

      double runningKm = double.parse(invoiceData['closing_km'] ?? '0') -
          double.parse(invoiceData['starting_km'] ?? '0');
      double daily_limit = double.parse(invoiceData['daily_limit'] ?? '0');

      commission = userType == 'agent' ? '+${agent_commission.toString()}' : '';

      if (startDateTime.day == endDateTime.day) {
        days += 1;
        // allowanceDays += 1;
        // driver_allowanceXdays = double.parse(driver_allowance) * days;
      } else {
        days += 1;

        if (diff < Duration(hours: 24)) {
          days += 1;
        }

        // if (endDateTime.hour >= 2) {
        //   kmDays += 1;
        // }

        // driver_allowanceXdays = double.parse(driver_allowance) * days;

        if ((endDateTime.hour == 23)) {
          days += 1;
        }

        if (endDateTime.hour < 6 ||
            (endDateTime.hour == 6 && endDateTime.minute < 30)) {
          days += 1;
        }

        if (startDateTime.hour < 6 ||
            (startDateTime.hour == 6 && startDateTime.minute < 30)) {
          days += 1;
        }

        //driver_allowanceXdays = double.parse(driver_allowance) * days;
      }
      maxKm = runningKm;
      driver_allowanceXdays = double.parse(driver_allowance) * days;
      driver_allowance = driver_allowanceXdays.toString();
      totalDays = days;

      double agniShare = double.tryParse(invoiceData['agni_share']?.toString() ?? '') ?? 0.0;
      double agentRate = 0.0;
      int divisorDays = days <= 0 ? 1 : days;
      if (agent_commission > 0) {
        if (invoiceData['booking_status'] == 'Completed' && runningKm > 0) {
          agentRate = (agent_commission / runningKm).roundToDouble();
        } else {
          agentRate = (agent_commission / (300 * divisorDays)).roundToDouble();
        }
      }
      double finalRate = kmRate + agniShare + agentRate;
      baceAmount = (maxKm ?? 0) * finalRate;

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
      double driver_allowance;

      driver_allowance = (distance < 200) ? 300 : 400;

      baceAmount = invoiceData['total_amount'] != '0'
          ? double.parse(invoiceData['total_amount'].toString())
          : (distance * kmRate) + driver_allowance;

      double totalbeforeGst = (distance * kmRate) + agent_commission;

      gst = baceAmount * gstPercent / 100;
      netTotal = baceAmount + gst + parking_charge;

      base_charge = double.tryParse(invoiceData['base_charge']?.toString() ?? '') ?? 0.0;
      if (base_charge == 0.0) {
        base_charge = baceAmount - agent_commission;
      }

      // Format all values to 2 decimal places
      baceAmount = double.parse(baceAmount.toStringAsFixed(2));
      totalbeforeGst = double.parse(totalbeforeGst.toStringAsFixed(2));
      gst = double.parse(gst.toStringAsFixed(2));
      netTotal = double.parse(netTotal.toStringAsFixed(2));
    }

    if (invoiceData['trip_type'] == 'Local-taxi') {
      netTotal = double.parse(invoiceData['total_amount'].toString());
    }

    final double advancedAmount = double.tryParse(invoiceData['paid_amount']?.toString() ?? '') ?? 0.0;
    final double balanceAmount = (netTotal ?? 0.0) - advancedAmount;

    return Table(
      columnWidths: {
        0: FlexColumnWidth(3), // First column (e.g., labels) wider
        1: FlexColumnWidth(3), // Second column (e.g., data)
        2: FlexColumnWidth(2), // Third column (e.g., amount)
      },
      border: TableBorder.all(),
      children: [
        _buildTableRow('Starting Date', dateFormat.format(startDateTime), ''),
        _buildTableRow('Ending Date', dateFormat.format(endDateTime), ''),

        if (invoiceData['trip_type'] == 'Local-Duty' ||
            invoiceData['trip_type'] == 'Round-Trip') ...[
          _buildTableRow('Starting Km ', invoiceData['starting_km']!, ''),
          _buildTableRow('Ending Km ', invoiceData['closing_km']!, ''),
          _buildTableRow('Total Km', totalKm.toStringAsFixed(2), ''),
        ],
        if (invoiceData['trip_type'] == 'Local-Duty') ...[
          _buildTableRow(
              'Package',
              '${invoiceData['packageHours'].toString()} Hours - ${invoiceData['packageKm'].toString()} Km',
              '$packageBaseWithCommission'),
          _buildTableRow(
              'Extra Km',
              'Rs ${invoiceData['extra_km_price']} *  $extraKm Km ',
              '$extrakmAmount'),
          _buildTableRow(
              'Extra Hrs',
              'Rs ${invoiceData['extra_hours_price']} * $extraHours Hrs',
              '$extraHoursAmount'),
        ],
        if (invoiceData['trip_type'] == 'Round-Trip') ...[
          _buildTableRow('Vehicle Base Rate', '', '₹${kmRate.toStringAsFixed(2)} / KM'),
          _buildTableRow('Agni Commission', '', '₹${agniShare.toStringAsFixed(2)} / KM'),
          if (agentRate > 0)
            _buildTableRow('Agent Commission', '', '₹${agentRate.toStringAsFixed(2)} / KM'),
          _buildTableRow('Final Rate', '', '₹${finalRate.toStringAsFixed(2)} / KM'),
          _buildTableRow(
              'Total Km charge', '${maxKm?.toStringAsFixed(0)} KM x ₹${finalRate.toStringAsFixed(2)}', '${baceAmount!.toStringAsFixed(2)}'),
          _buildTableRow('Total Days', '$totalDays', ''),
        ],

        _buildTableRow('Parking', '', '$parking_charge'),
        _buildTableRow('Toll', '', '$toll_charge'),
        _buildTableRow('Permit Charge', '', '$permit_charge'),
        _buildTableRow('Driver Allowance', '', '${driver_allowance ?? ""} '),

        if (invoiceData['trip_type'] == 'One-way') ...[
          _buildTableRow('Base Amount', '', '${base_charge.toStringAsFixed(2)}'),
          _buildTableRow('Agent Commission', '', '${agent_commission.toStringAsFixed(2)}'),
          _buildTableRow('Total Charge', '', '$baceAmount')
        ],

        if (invoiceData['trip_type'] != 'Local-taxi') ...[
          _buildTableRow('GSTIN', '27AABPG5706A3ZB', ''),
          _buildTableRow('GST $gstPercent%', '', '$gst'),
        ],

        _buildTableRow('TOTAL', '', '$netTotal'),
        _buildTableRow('Advanced Amount', '', '${advancedAmount.toStringAsFixed(2)}'),
        _buildTableRow('Balance Amount', '', '${balanceAmount.toStringAsFixed(2)}'),

        //   _buildTableRow('IGST 5%', '', '₹${igst.toStringAsFixed(2)}'),
        //   _buildTableRow('Total', '', '₹${totalAmt.toStringAsFixed(2)}'),
      ],
    );
  }

  TableRow _buildTableRow(String col1, String col2, String col3) {
    return TableRow(
      children: [
        Padding(
            padding: EdgeInsets.all(4.0),
            child: Text(col1,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        Padding(
            padding: EdgeInsets.all(4.0),
            child: Text(col2, style: TextStyle(fontSize: 12))),
        Padding(
            padding: EdgeInsets.all(4.0),
            child: Text(col3, style: TextStyle(fontSize: 12))),
      ],
    );
  }
}
