class CustomerInfo {
  final String userID;
  final Map<String, bool> activeEntitlements; // {"gold": true, "silver": false}
  final Map<String, DateTime> allEntitlements; // {"gold": "2025-12-31..."}
  final List<String> activePackages;

  CustomerInfo({
    required this.userID,
    required this.activeEntitlements,
    required this.allEntitlements,
    required this.activePackages,
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

    List<String> packages = [];
    if (json['active_packages'] != null) {
      packages = List<String>.from(json['active_packages']);
    }

    return CustomerInfo(
      userID: json['user_id'],
      activeEntitlements: active,
      allEntitlements: dates,
      activePackages: packages,
    );
  }

  // Convert back to JSON for storage
  Map<String, dynamic> toJson() {
    // Convert Dates back to ISO Strings
    Map<String, String> entitlementsString = {};
    allEntitlements.forEach((key, date) {
      entitlementsString[key] = date.toIso8601String();
    });

    return {
      'user_id': userID,
      'active': activeEntitlements,
      'entitlements': entitlementsString,
      'active_packages': activePackages,
    };
  }
}
