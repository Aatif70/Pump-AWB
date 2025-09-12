import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api/api_constants.dart';
import '../models/shift_sales_report.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShiftSalesReportService {
  Future<ShiftSalesReportResponse> fetchShiftSalesReport(
      DateTime startDate, DateTime endDate) async {
    try {
      final url = ApiConstants.getShiftSalesReportUrl(startDate, endDate);
      print('ShiftSalesReportService: URL => ' + url);
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(ApiConstants.authTokenKey);

      if (authToken == null) {
        throw Exception('Authentication token not found');
      }

      final masked = authToken.length > 12
          ? authToken.substring(0, 6) + '...' + authToken.substring(authToken.length - 4)
          : '***masked***';
      print('ShiftSalesReportService: Auth => Bearer ' + masked);

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      print('ShiftSalesReportService: status=${response.statusCode}');
      print('ShiftSalesReportService: rawBody=${response.body}');

      if (response.statusCode == ApiConstants.statusOk) {
        final Map<String, dynamic> bodyJson = json.decode(response.body) as Map<String, dynamic>;
        print('ShiftSalesReportService: parsed keys=${bodyJson.keys.join(', ')}');
        try {
          final parsed = ShiftSalesReportResponse.fromJson(bodyJson);
          print('ShiftSalesReportService: parsed data count=${parsed.data.length}, success=${parsed.success}');
          return parsed;
        } catch (e) {
          print('ShiftSalesReportService: parsing error => $e');
          rethrow;
        }
      } else {
        throw Exception('Failed to load shift sales report: ${response.statusCode}');
      }
    } catch (e) {
      print('ShiftSalesReportService: EXCEPTION => $e');
      throw Exception('Error fetching shift sales report: $e');
    }
  }
} 