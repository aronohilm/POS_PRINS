import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'settings.dart';
import 'terminal_connection_page.dart';
import 'logs_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class QRCodeScannerPage extends StatefulWidget {
  const QRCodeScannerPage({super.key});

  @override
  State<QRCodeScannerPage> createState() => _QRCodeScannerPageState();
}

class _QRCodeScannerPageState extends State<QRCodeScannerPage> {
  String _scanResult = 'Not yet scanned';
  bool _isLoading = false;

  Future<void> _startScan() async {
    setState(() {
      _isLoading = true;
      _scanResult = 'Scanning...';
    });

    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('api_key');
    final poiId = prefs.getString('selected_terminal');

    if (apiKey == null || poiId == null) {
      _showToast("Missing API key or POIID");
      return;
    }

    final sessionId = Random().nextInt(1000000);
    final scanCommand = {
      "Session": {"Id": sessionId, "Type": "Once"},
      "Operation": [{"Type": "ScanBarcode", "TimeoutMs": 10000}]
    };

    final encodedCommand = base64Encode(utf8.encode(jsonEncode(scanCommand)));

    final now = DateTime.now().toUtc();
    final serviceId = 'SID${now.millisecondsSinceEpoch % 1000000}';
    final saleId = 'ScannerTest';

    final payload = {
      "SaleToPOIRequest": {
        "MessageHeader": {
          "ProtocolVersion": "3.0",
          "MessageClass": "Service",
          "MessageCategory": "Admin",
          "MessageType": "Request",
          "ServiceID": serviceId,
          "SaleID": saleId,
          "POIID": poiId
        },
        "AdminRequest": {
          "ServiceIdentification": encodedCommand
        }
      }
    };

    try {
      final response = await http.post(
        Uri.parse("https://terminal-api-test.adyen.com/sync"),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
        },
        body: jsonEncode(payload),
      );

      final decoded = jsonDecode(response.body);
      final result = decoded['SaleToPOIResponse']?['AdminResponse']?['Response']?['Result'];
      final additionalResponse = decoded['SaleToPOIResponse']?['AdminResponse']?['Response']?['AdditionalResponse'];

      if (result == 'Success' && additionalResponse != null) {
        final base64Decoded = utf8.decode(base64Decode(additionalResponse));
        setState(() => _scanResult = base64Decoded);
      } else {
        setState(() => _scanResult = 'Scan failed: $result');
      }
    } catch (e) {
      setState(() => _scanResult = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Scanner'),
        backgroundColor: const Color(0xFF002244),
      ),
      backgroundColor: const Color(0xFF001F3F),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _startScan,
              child: const Text('Start QR Scan'),
            ),
            const SizedBox(height: 20),
            const Text('Scan Result:', style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: Text(_scanResult, style: const TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
