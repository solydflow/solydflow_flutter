class SolydPaywallConfig {
  final String headline;
  final String subheading;
  final String footerText;
  final String primaryColor;
  final String backgroundColor;
  final String headerImageUrl;
  final String templateName;
  
  // Tier Metadata (Entitlement ID -> Features List)
  final Map<String, List<String>> tierFeatures;

  SolydPaywallConfig({
    required this.headline,
    required this.subheading,
    required this.footerText,
    required this.primaryColor,
    required this.backgroundColor,
    required this.headerImageUrl,
    required this.templateName,
    required this.tierFeatures,
  });

  factory SolydPaywallConfig.fromJson(Map<String, dynamic> json) {
    final config = json['config'] ?? {};
    final List<dynamic> tiers = json['tiers'] ?? [];

    // Map features: "pro_access" -> ["No Ads", "Cloud Sync"]
    Map<String, List<String>> featuresMap = {};
    for (var t in tiers) {
      if (t['features'] != null) {
        featuresMap[t['entitlement_id']] = List<String>.from(t['features']);
      }
    }

    return SolydPaywallConfig(
      headline: config['headline'] ?? "Unlock Full Access",
      subheading: config['subheading'] ?? "",
      footerText: config['footer_text'] ?? "",
      primaryColor: config['primary_color'] ?? "#EA580C",
      backgroundColor: config['background_color'] ?? "#000000",
      headerImageUrl: config['header_image_url'] ?? "",
      templateName: config['template_name'] ?? "",
      tierFeatures: featuresMap,
    );
  }
}
