class CustomerInfo {
  final String userID;
  final Map<String, bool> activeEntitlements; // {"gold": true, "silver": false}
  final Map<String, DateTime> allEntitlements; // {"gold": "2025-12-31..."}

  CustomerInfo({
    required this.userID,
    required this.activeEntitlements,
    required this.allEntitlements,
  });

  factory CustomerInfo.fromJson(Map<String, dynamic> json) {
    // Parse Active Booleans
    Map<String, bool> active = {};
    if (json['active'] != null) {
      json['active'].forEach((key, value) {
        active[key] = value == true;
      });
    }

    // Parse Dates
    Map<String, DateTime> dates = {};
    if (json['entitlements'] != null) {
      json['entitlements'].forEach((key, value) {
        dates[key] = DateTime.parse(value);
      });
    }

    return CustomerInfo(
      userID: json['user_id'],
      activeEntitlements: active,
      allEntitlements: dates,
    );
  }
}
