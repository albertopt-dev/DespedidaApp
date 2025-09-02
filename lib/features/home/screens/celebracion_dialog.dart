import 'package:flutter/material.dart';

class CelebracionDialog extends StatelessWidget {
  const CelebracionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¡Prueba superada!'),
      content: const Text('¡Enhorabuena, la base ha sido completada!'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}