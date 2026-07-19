class Supplier {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;

  Supplier({this.id, required this.name, this.phone, this.address, this.notes});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'notes': notes,
      };

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
        id: map['id'] as int?,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        address: map['address'] as String?,
        notes: map['notes'] as String?,
      );
}
