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
  final TextEditingController _terminalSuffixController = TextEditingController();

  Future<void> _triggerBarcodeScan() async {
    setState(() {
      _isLoading = true;
      _scanResult = '';
    });

    final terminalSuffix = _terminalSuffixController.text.trim();
    if (terminalSuffix.length != 3) {
      setState(() {
        _scanResult = 'Please enter last 3 digits of POIID';
        _isLoading = false;
      });
      return;
    }

    final fullPoiId = 'S1F2L-000158251517$terminalSuffix';

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
          "POIID": fullPoiId
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
        },
        body: jsonEncode(payload),
      );

      final body = jsonDecode(response.body);
      final additionalResponse = body['SaleToPOIResponse']?['AdminResponse']?['Response']?['AdditionalResponse'];
      if (additionalResponse != null) {
        final parts = additionalResponse.split('additionalData=');
        if (parts.length > 1) {
          final jsonPart = Uri.decodeFull(parts[1]);
          try {
            final parsed = jsonDecode(jsonPart);
            final scannedData = parsed['Barcode']?['Data'];

            if (scannedData != null && scannedData is String) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('api_key', scannedData);
              setState(() => _scanResult = 'API Key updated in settings');
            } else {
              setState(() => _scanResult = 'No valid API key scanned');
            }
          } catch (e) {
            setState(() => _scanResult = 'Invalid scan response');
          }
        } else {
          setState(() => _scanResult = 'Unexpected response format');
        }
      } else {
        setState(() => _scanResult = 'No response received. The scanner might still be busy. Please wait a few seconds and try again.');
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
            TextFormField(
              controller: _terminalSuffixController,
              maxLength: 3,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Enter last 3 digits of POIID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
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
