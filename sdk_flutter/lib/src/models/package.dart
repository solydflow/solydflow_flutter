class SolydPackage {
  final String identifier;    // "gold_monthly"
  final String entitlementID; // "gold"
  final String name;          // "Gold Plan"
  final int amountKobo;
  final String currency;
  final String duration;

  SolydPackage({
    required this.identifier,
    required this.entitlementID,
    required this.name,
    required this.amountKobo,
    required this.currency,
    required this.duration,
  });


  factory SolydPackage.fromJson(Map<String, dynamic> json) {
    return SolydPackage(
      identifier: json['identifier'],
      entitlementID: json['entitlement_id'] ?? "pro", // Fallback
      name: json['name'],
      amountKobo: json['amount_kobo'],
      currency: json['currency'],
      duration: json['duration'],
    );
  }
}