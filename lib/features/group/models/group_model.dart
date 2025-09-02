import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String codigo;
  final String nombre;
  final String? novioUid; // <-- Cambiado aquí
  final List<String> miembros;
  final bool isStarted;
  final List<dynamic> pruebas;
  final DateTime? createdAt;

  GroupModel({
    required this.codigo,
    required this.nombre,
    this.novioUid, // <-- Cambiado aquí
    required this.miembros,
    required this.isStarted,
    required this.pruebas,
    this.createdAt,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      codigo: map['codigo'] ?? '',
      nombre: map['nombre'] ?? '',
      novioUid: map['novioUid'], // <-- Cambiado aquí
      miembros: List<String>.from(map['miembros'] ?? []),
      isStarted: map['isStarted'] ?? false,
      pruebas: map['pruebas'] ?? [],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'nombre': nombre,
      'novioUid': novioUid, // <-- Cambiado aquí
      'miembros': miembros,
      'isStarted': isStarted,
      'pruebas': pruebas,
      'createdAt': createdAt,
    };
  }

  GroupModel copyWith({
    String? codigo,
    String? nombre,
    String? novioUid, // <-- Cambiado aquí
    List<String>? miembros,
    bool? isStarted,
    List<dynamic>? pruebas,
    DateTime? createdAt,
  }) {
    return GroupModel(
      codigo: codigo ?? this.codigo,
      nombre: nombre ?? this.nombre,
      novioUid: novioUid ?? this.novioUid, // <-- Cambiado aquí
      miembros: miembros ?? this.miembros,
      isStarted: isStarted ?? this.isStarted,
      pruebas: pruebas ?? this.pruebas,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}


