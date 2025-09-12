import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import '../models/government_testing_model.dart';
import 'api_constants.dart';
import 'api_response.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GovernmentTestingRepository {
  // Submit government testing data
  Future<ApiResponse<GovernmentTesting>> submitGovernmentTesting(GovernmentTesting testing) async {
    try {
      // Debug logs for tracking
      debugPrint('TESTING_DEBUG: Sending testing data:');
      debugPrint('TESTING_DEBUG: employeeId: ${testing.employeeId}');
      debugPrint('TESTING_DEBUG: nozzleId: ${testing.nozzleId}');
      debugPrint('TESTING_DEBUG: petrolPumpId: ${testing.petrolPumpId}');
      debugPrint('TESTING_DEBUG: shiftId: ${testing.shiftId}');
      debugPrint('TESTING_DEBUG: testingLiters: ${testing.testingLiters}');
      debugPrint('TESTING_DEBUG: notes: ${testing.notes}');
      
      // Handle potential null or empty fuelTankId 
      if (testing.fuelTankId == null || testing.fuelTankId!.isEmpty) {
        debugPrint('TESTING_DEBUG: fuelTankId is null or empty, setting to null for JSON payload');
        testing.fuelTankId = null; // Set to null instead of empty string for API
      }
      
      // Ensure fuelTypeId is set
      if (testing.fuelTypeId == null || testing.fuelTypeId!.isEmpty) {
        debugPrint('TESTING_DEBUG: Warning - fuelTypeId is not set');
      }
      
      // Convert to JSON
      final jsonPayload = testing.toJson();
      debugPrint('TESTING_DEBUG: Full JSON payload:');
      debugPrint('TESTING_DEBUG: ${json.encode(jsonPayload)}');

      // Get authentication token
      final token = await ApiConstants.getAuthToken();
      debugPrint('TESTING_DEBUG: Authentication token present: ${token != null && token.isNotEmpty}');
      if (token == null || token.isEmpty) {
        return ApiResponse<GovernmentTesting>(
          success: false,
          errorMessage: 'Authentication token is missing. Please login again.',
        );
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.governmentTestingEndpoint}');
      debugPrint('API_CONSTANTS: Government Testing URL: $uri');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(jsonPayload),
      );

      // Log the response for debugging
      debugPrint('TESTING_DEBUG: Response status code: ${response.statusCode}');
      debugPrint('TESTING_DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        
        if (responseData['success'] == true) {
          debugPrint('TESTING_DEBUG: Successfully submitted government testing data');
          return ApiResponse<GovernmentTesting>(
            success: true,
            data: GovernmentTesting.fromJson(responseData['data']),
          );
        } else {
          debugPrint('TESTING_DEBUG: API returned success: false - ${responseData['message']}');
          return ApiResponse<GovernmentTesting>(
            success: false,
            errorMessage: responseData['message'] ?? 'Failed to submit government testing data',
          );
        }
      } else {
        // Error handling with meaningful messages
        String errorMessage = 'Failed to submit government testing data';
        
        try {
          if (response.body.isNotEmpty) {
            final errorResponse = json.decode(response.body);
            if (errorResponse['message'] != null) {
              errorMessage = errorResponse['message'];
              debugPrint('TESTING_DEBUG: Error message from API: $errorMessage');
            }
            
            // Check for validation errors
            if (errorResponse['validationErrors'] != null) {
              final validationErrors = errorResponse['validationErrors'];
              debugPrint('TESTING_DEBUG: Validation errors: $validationErrors');
              
              // Build more detailed error message
              if (validationErrors is Map && validationErrors.isNotEmpty) {
                String validationMessage = '';
                validationErrors.forEach((key, value) {
                  validationMessage += '${value.toString()}, ';
                });
                if (validationMessage.isNotEmpty) {
                  errorMessage += ': ${validationMessage.substring(0, validationMessage.length - 2)}';
                }
              }
            }
          } else {
            // Empty response body
            errorMessage = 'Status code ${response.statusCode}: ${response.reasonPhrase}';
            debugPrint('TESTING_DEBUG: Empty response body with status code: ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('TESTING_DEBUG: Error parsing error response: $e');
          errorMessage = 'Status code ${response.statusCode}: ${response.reasonPhrase}';
        }
        
        return ApiResponse<GovernmentTesting>(
          success: false,
          errorMessage: errorMessage,
        );
      }
    } catch (e) {
      debugPrint('TESTING_DEBUG: Exception during submission: $e');
      return ApiResponse<GovernmentTesting>(
        success: false,
        errorMessage: 'An error occurred: ${e.toString()}',
      );
    }
  }

  // Get all government testings
  Future<ApiResponse<List<GovernmentTesting>>> getAllGovernmentTestings() async {
    try {
      debugPrint('TESTING_DEBUG: Getting all government testings');
      
      // Get authentication token
      final token = await ApiConstants.getAuthToken();
      if (token == null || token.isEmpty) {
        debugPrint('TESTING_DEBUG: Authentication token is missing');
        return ApiResponse<List<GovernmentTesting>>(
          success: false,
          errorMessage: 'Authentication token is missing. Please login again.',
        );
      }
      
      // Get petrol pump ID
      final prefs = await SharedPreferences.getInstance();
      final petrolPumpId = prefs.getString('petrolPumpId');
      debugPrint('TESTING_DEBUG: Retrieved petrolPumpId: $petrolPumpId');
      
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        debugPrint('TESTING_DEBUG: Petrol pump ID is missing');
        return ApiResponse<List<GovernmentTesting>>(
          success: false,
          errorMessage: 'Petrol pump ID is missing. Please login again.',
        );
      }
      
      // Include petrol pump ID in the URL
      final uri = Uri.parse(ApiConstants.getGovernmentTestingByPumpUrl(petrolPumpId));
      debugPrint('TESTING_DEBUG: API URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      debugPrint('TESTING_DEBUG: Response status code: ${response.statusCode}');
      debugPrint('TESTING_DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> testingListJson = responseData['data'];
          final List<GovernmentTesting> testings = testingListJson
              .map((json) => GovernmentTesting.fromJson(json))
              .toList();
              
          debugPrint('TESTING_DEBUG: Successfully retrieved ${testings.length} government testings');

          return ApiResponse<List<GovernmentTesting>>(
            success: true,
            data: testings,
          );
        } else {
          debugPrint('TESTING_DEBUG: API returned success: false - ${responseData['message']}');
          return ApiResponse<List<GovernmentTesting>>(
            success: false,
            errorMessage: responseData['message'] ?? 'Failed to get government testings',
          );
        }
      } else {
        debugPrint('TESTING_DEBUG: Failed with status code: ${response.statusCode}');
        String errorMessage = 'Failed to get government testings';
        
        try {
          if (response.body.isNotEmpty) {
            final errorData = json.decode(response.body);
            if (errorData['message'] != null) {
              errorMessage = errorData['message'];
            }
          }
        } catch (e) {
          debugPrint('TESTING_DEBUG: Error parsing response: $e');
        }
        
        return ApiResponse<List<GovernmentTesting>>(
          success: false,
          errorMessage: errorMessage,
        );
      }
    } catch (e) {
      debugPrint('TESTING_DEBUG: Exception during getAllGovernmentTestings: $e');
      return ApiResponse<List<GovernmentTesting>>(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Get government testing by ID
  Future<ApiResponse<GovernmentTesting>> getGovernmentTestingById(String id) async {
    try {
      // Get authentication token
      final token = await ApiConstants.getAuthToken();
      if (token == null || token.isEmpty) {
        return ApiResponse<GovernmentTesting>(
          success: false,
          errorMessage: 'Authentication token is missing. Please login again.',
        );
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.governmentTestingEndpoint}/$id');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['success'] == true && responseData['data'] != null) {
          return ApiResponse<GovernmentTesting>(
            success: true,
            data: GovernmentTesting.fromJson(responseData['data']),
          );
        } else {
          return ApiResponse<GovernmentTesting>(
            success: false,
            errorMessage: responseData['message'] ?? 'Government testing not found',
          );
        }
      } else {
        return ApiResponse<GovernmentTesting>(
          success: false,
          errorMessage: 'Failed to get government testing',
        );
      }
    } catch (e) {
      return ApiResponse<GovernmentTesting>(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Get government testings by nozzle ID
  Future<ApiResponse<List<GovernmentTesting>>> getGovernmentTestingsByNozzleId(String nozzleId) async {
    try {
      // Get authentication token
      final token = await ApiConstants.getAuthToken();
      if (token == null || token.isEmpty) {
        return ApiResponse<List<GovernmentTesting>>(
          success: false,
          errorMessage: 'Authentication token is missing. Please login again.',
        );
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.governmentTestingEndpoint}/nozzle/$nozzleId');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> testingListJson = responseData['data'];
          final List<GovernmentTesting> testings = testingListJson
              .map((json) => GovernmentTesting.fromJson(json))
              .toList();

          return ApiResponse<List<GovernmentTesting>>(
            success: true,
            data: testings,
          );
        } else {
          return ApiResponse<List<GovernmentTesting>>(
            success: false,
            errorMessage: responseData['message'] ?? 'No government testings found for this nozzle',
          );
        }
      } else {
        return ApiResponse<List<GovernmentTesting>>(
          success: false,
          errorMessage: 'Failed to get government testings',
        );
      }
    } catch (e) {
      return ApiResponse<List<GovernmentTesting>>(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
} 