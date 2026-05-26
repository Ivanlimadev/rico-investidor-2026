enum SubscriptionPlan {
  free('Grátis', 'Anúncios · recursos limitados'),
  pro('Pro', 'Sem anúncios · alertas e carteiras ampliadas');

  const SubscriptionPlan(this.label, this.description);

  final String label;
  final String description;

  bool get isPro => this == SubscriptionPlan.pro;
}
