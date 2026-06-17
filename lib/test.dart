import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:agni_car_rental/config/api_config.dart';

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

  Future<void> _downloadPDF(BuildContext context) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('yyyy-MM-dd hh:mm a');

    // Generate the PDF content based on invoiceData
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Center(
                  child: pw.Text("CAR INVOICE",
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 8),
              pw.Text("AGNI CAR RENTAL",
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.Text(
                  "7, Jalaram Niwas, Ganesh Gawde Road, \nMulund (W), Mumbai - 400080",
                  style: pw.TextStyle(fontSize: 12)),
              pw.Text(
                  "Tel: 9619936999 | Email: agnicarrental@gmail.com \nWebsite: www.agnicarrental.com",
                  style: pw.TextStyle(fontSize: 12)),
              pw.Text("GST No: 27AABPG5706A3ZB",
                  style: pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 8),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text("Date: ${invoiceData['invoieceDate']}",
                    style: pw.TextStyle(fontSize: 12)),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Container(
                    width: 100,
                    child: pw.Text("Bill No:",
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  ),
                  pw.Expanded(
                      child: pw.Text("${invoiceData['invoiceNumber']}",
                          style: pw.TextStyle(fontSize: 12))),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Container(
                    width: 100,
                    child: pw.Text("Passenger:",
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  ),
                  pw.Expanded(
                      child: pw.Text("${invoiceData['cus_name']}",
                          style: pw.TextStyle(fontSize: 12))),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Container(
                    width: 100,
                    child: pw.Text("Vehicle:",
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  ),
                  pw.Expanded(
                      child: pw.Text("${invoiceData['car_type']}",
                          style: pw.TextStyle(fontSize: 12))),
                ],
              ),
              pw.SizedBox(height: 8),
              // Add other data rows here
            ],
          );
        },
      ),
    );

    // Get the application's documents directory
    final outputDir = await getApplicationDocumentsDirectory();
    final file = File("${outputDir.path}/invoice.pdf");
    await file.writeAsBytes(await pdf.save());

    // Open the PDF after saving
    OpenFile.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Invoice"),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            onPressed: () => _downloadPDF(context),
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
        Text("AGNI CAR RENTAL",
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
        Text("Account Name: Agni Car Rental", style: TextStyle(fontSize: 12)),
        Text("Account Number: 1234567890", style: TextStyle(fontSize: 12)),
        Text("IFSC Code: ABCD12345", style: TextStyle(fontSize: 12)),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      children: [
        Container(
          width: 120,
          child: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _buildTable() {
    return Table(
      columnWidths: {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          children: [
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("Package Fare",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(invoiceData['packageBaseFare']!),
              ),
            ),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(invoiceData['total_amount']!),
              ),
            ),
          ],
        ),
        TableRow(
          children: [
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("Extra KM",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(invoiceData['extra_km_price']!),
              ),
            ),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(invoiceData['total_amount']!),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
