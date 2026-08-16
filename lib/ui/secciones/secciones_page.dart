import 'package:flutter/material.dart';

import '../shared/resource_crud_page.dart';

class SeccionesPage extends StatelessWidget {
  const SeccionesPage({super.key});

  static const _definition = ResourceDefinition(
    title: 'Secciones',
    singular: 'Sección',
    endpoint: '/v1/secciones',
    permissionPrefix: 'secciones',
    searchHint: 'Municipio o sección',
    searchParameter: 'q',
    fields: [
      ResourceField(keyName: 'seccion', label: 'Sección', required: true),
      ResourceField(keyName: 'municipio', label: 'Municipio', required: true),
      ResourceField(keyName: 'cve_mun', label: 'Clave municipal'),
      ResourceField(
        keyName: 'lista_nominal',
        label: 'Lista nominal',
        type: ResourceFieldType.number,
      ),
      ResourceField(
        keyName: 'distrito_local',
        label: 'Distrito local',
        type: ResourceFieldType.number,
      ),
      ResourceField(
        keyName: 'distrito_federal',
        label: 'Distrito federal',
        type: ResourceFieldType.number,
      ),
      ResourceField(
        keyName: 'centroid_lat',
        label: 'Latitud',
        type: ResourceFieldType.number,
      ),
      ResourceField(
        keyName: 'centroid_lng',
        label: 'Longitud',
        type: ResourceFieldType.number,
      ),
    ],
    titleBuilder: _title,
    subtitleBuilder: _subtitle,
  );

  static String _title(Map<String, dynamic> item) =>
      'Sección ${item['seccion'] ?? '—'}';
  static String _subtitle(Map<String, dynamic> item) =>
      '${item['municipio'] ?? 'Sin municipio'} · Lista nominal ${item['lista_nominal'] ?? '—'}';

  @override
  Widget build(BuildContext context) =>
      const ResourceCrudPage(definition: _definition);
}
