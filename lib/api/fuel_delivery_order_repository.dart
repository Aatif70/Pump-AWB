import 'dart:convert';
import 'package:flutter/cupertino.dart';

import '../models/fuel_delivery_order_model.dart';
import 'api_service.dart';
import 'api_response.dart' as api_response_model;
import '../utils/shared_prefs.dart';
import 'api_constants.dart';

class FuelDeliveryOrderRepository {
  final ApiService _apiService = ApiService();
  final SharedPrefs _prefs = SharedPrefs();

  Future<api_response_model.ApiResponse<String>> createFuelDeliveryOrder(FuelDeliveryOrder order) async {
    try {
      final petrolPumpId = await SharedPrefs.getPumpId();
      
      if (petrolPumpId == null) {
        return api_response_model.ApiResponse<String>(
          success: false,
          errorMessage: 'Petrol pump ID not found',
        );
      }
      
      // Get the auth token - using correct method name
      final token = await SharedPrefs.getAuthToken();
      if (token == null || token.isEmpty) {
        debugPrint('===== AUTH ERROR =====');
        debugPrint('Authentication token is null or empty');
        return api_response_model.ApiResponse<String>(
          success: false,
          errorMessage: 'Authentication token not found. Please login again.',
        );
      }
      
      debugPrint('===== AUTH INFO =====');
      debugPrint('Token exists: ${token.isNotEmpty}');
      debugPrint('Token length: ${token.length}');
      
      // Convert order to JSON map
      final Map<String, dynamic> jsonMap = order.toJson();
      
      // Create a full URL with base URL and endpoint
      final String url = '${ApiConstants.baseUrl}/api/FuelDeliveryOrder/petrol-pump/$petrolPumpId';
      
      // debugPrint the JSON data for debugging
      debugPrint('===== DEBUGGING API REQUEST =====');
      debugPrint('API Endpoint: $url');
      
      // debugPrint the JSON as a formatted string to better see the structure
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonMap);
      debugPrint('Request Payload:');
      debugPrint(jsonString);
      
      final response = await _apiService.post<dynamic>(
        url,
        body: jsonMap,
        token: token, // Pass the token to the API service
        fromJson: (json) => json,
      );
      
      // debugPrint the API response
      debugPrint('===== API RESPONSE =====');
      debugPrint('Success: ${response.success}');
      debugPrint('Error: ${response.errorMessage}');
      debugPrint('Data: ${response.data}');
      
      if (response.success) {
        return api_response_model.ApiResponse<String>(
          success: true,
          data: 'Fuel delivery order created successfully',
        );
      } else {
        return api_response_model.ApiResponse<String>(
          success: false,
          errorMessage: 'Failed to create fuel delivery order: ${response.errorMessage}',
        );
      }
    } catch (e) {
      debugPrint('===== REPOSITORY ERROR =====');
      debugPrint(e.toString());
      print(e.runtimeType);
      if (e is FormatException) {
        debugPrint('Format Exception Details: ${e.message}');
        debugPrint('Source: ${e.source}');
        debugPrint('Offset: ${e.offset}');
      }
      
      return api_response_model.ApiResponse<String>(
        success: false,
        errorMessage: 'Error creating fuel delivery order: ${e.toString()}',
      );
    }
  }
} 