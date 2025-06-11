import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:math';

class ScanApiKeyPage extends StatefulWidget {
  const ScanApiKeyPage({super.key});

  @override
  State<ScanApiKeyPage> createState() => _ScanApiKeyPageState();
}

class _ScanApiKeyPageState extends State<ScanApiKeyPage> {
  String _scanResult = '';
  bool _isLoading = false;

  Future<void> _triggerBarcodeScan() async {
    setState(() {
      _isLoading = true;
      _scanResult = '';
    });

    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('api_key');
    final poiId = prefs.getString('selected_terminal');

    if (apiKey == null || poiId == null) {
      setState(() {
        _scanResult = 'API key or POI ID missing in settings';
        _isLoading = false;
      });
      return;
    }

    final sessionId = Random().nextInt(999999);
    final now = DateTime.now().toUtc();
    final saleId = 'ScanKey${now.millisecondsSinceEpoch % 1000000}';
    final serviceId = 'SID${now.millisecondsSinceEpoch % 1000000}';

    final scanPayload = {
      "Session": {
        "Id": sessionId,
        "Type": "Once"
      },
      "Operation": [
        {
          "Type": "ScanBarcode",
          "TimeoutMs": 10000
        }
      ]
    };

    final encodedPayload = base64.encode(utf8.encode(jsonEncode(scanPayload)));

    final payload = {
      "SaleToPOIRequest": {
        "MessageHeader": {
          "ProtocolVersion": "3.0",
          "MessageClass": "Service",
          "MessageCategory": "Admin",
          "MessageType": "Request",
          "SaleID": saleId,
          "ServiceID": serviceId,
          "POIID": poiId
        },
        "AdminRequest": {
          "ServiceIdentification": encodedPayload
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

      final body = jsonDecode(response.body);
      final additionalResponse = body['SaleToPOIResponse']?['AdminResponse']?['Response']?['AdditionalResponse'];
      if (additionalResponse != null) {
        final decoded = utf8.decode(base64.decode(additionalResponse));
        final parsed = jsonDecode(decoded);
        final scannedData = parsed['Barcode']?['Data'];

        if (scannedData != null && scannedData is String) {
          await prefs.setString('api_key', scannedData);
          setState(() => _scanResult = 'API Key saved: $scannedData');
        } else {
          setState(() => _scanResult = 'No valid data scanned');
        }
      } else {
        setState(() => _scanResult = 'No response received');
      }
    } catch (e) {
      setState(() => _scanResult = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR API Key Scanner'),
        backgroundColor: const Color(0xFF002244),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _triggerBarcodeScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A3A6A),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Scan QR Code for API Key', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 20),
            Text(
              _scanResult,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            )
          ],
        ),
      ),
    );
  }
}
