import 'package:flutter/material.dart';

import '../shared/resource_crud_page.dart';

class ActividadesPage extends StatelessWidget {
  const ActividadesPage({super.key});

  static const _definition = ResourceDefinition(
    title: 'Actividades',
    singular: 'Actividad',
    endpoint: '/v1/actividades',
    permissionPrefix: 'actividades',
    searchHint: 'Buscar actividad',
    fields: [
      ResourceField(keyName: 'titulo', label: 'Título', required: true),
      ResourceField(
        keyName: 'descripcion',
        label: 'Descripción',
        type: ResourceFieldType.multiline,
      ),
      ResourceField(
        keyName: 'inicio',
        label: 'Inicio (AAAA-MM-DD HH:mm)',
        required: true,
      ),
      ResourceField(keyName: 'fin', label: 'Fin (AAAA-MM-DD HH:mm)'),
      ResourceField(
        keyName: 'all_day',
        label: 'Todo el día',
        type: ResourceFieldType.toggle,
      ),
      ResourceField(keyName: 'lugar', label: 'Lugar'),
      ResourceField(
        keyName: 'estado',
        label: 'Estado',
        type: ResourceFieldType.select,
        options: {
          'programada': 'Programada',
          'realizada': 'Realizada',
          'cancelada': 'Cancelada',
        },
      ),
    ],
    titleBuilder: _title,
    subtitleBuilder: _subtitle,
  );

  static String _title(Map<String, dynamic> item) =>
      '${item['titulo'] ?? 'Sin título'}';
  static String _subtitle(Map<String, dynamic> item) =>
      '${item['inicio'] ?? 'Sin fecha'} · ${item['estado'] ?? 'programada'}';

  @override
  Widget build(BuildContext context) =>
      const ResourceCrudPage(definition: _definition);
}
