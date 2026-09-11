class Customer {
  final String id;
  final String name;
  final String? phone;
  final bool isActive;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    required this.isActive,
  });
}
