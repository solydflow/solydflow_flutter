class SolydPackage {
  final String identifier;
  final String name;
  final int amountKobo;
  final String currency;
  final String duration;

  SolydPackage({
    required this.identifier,
    required this.name,
    required this.amountKobo,
    required this.currency,
    required this.duration,
  });

  factory SolydPackage.fromJson(Map<String, dynamic> json) {
    return SolydPackage(
      identifier: json['identifier'],
      name: json['name'],
      amountKobo: json['amount_kobo'],
      currency: json['currency'],
      duration: json['duration'],
    );
  }
}

