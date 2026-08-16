import 'package:flutter/material.dart';

import '../shared/resource_crud_page.dart';

class AfiliadosPage extends StatelessWidget {
  const AfiliadosPage({super.key});

  static const _definition = ResourceDefinition(
    title: 'Afiliados',
    singular: 'Afiliado',
    endpoint: '/v1/afiliados',
    permissionPrefix: 'afiliados',
    searchHint: 'Nombre, teléfono, correo o clave de elector',
    fields: [
      ResourceField(keyName: 'nombre', label: 'Nombre', required: true),
      ResourceField(keyName: 'apellido_paterno', label: 'Apellido paterno'),
      ResourceField(keyName: 'apellido_materno', label: 'Apellido materno'),
      ResourceField(
        keyName: 'edad',
        label: 'Edad',
        type: ResourceFieldType.number,
      ),
      ResourceField(
        keyName: 'sexo',
        label: 'Sexo',
        type: ResourceFieldType.select,
        options: {'M': 'Masculino', 'F': 'Femenino', 'Otro': 'Otro'},
      ),
      ResourceField(keyName: 'telefono', label: 'Teléfono'),
      ResourceField(
        keyName: 'email',
        label: 'Correo',
        type: ResourceFieldType.email,
      ),
      ResourceField(keyName: 'clave_elector', label: 'Clave de elector'),
      ResourceField(
        keyName: 'tipo_vinculo',
        label: 'Tipo de vínculo',
        type: ResourceFieldType.select,
        options: {'dv': 'DV', 'comite': 'Comité', 'mov': 'MOV'},
      ),
      ResourceField(keyName: 'numero_mov', label: 'Número MOV'),
      ResourceField(keyName: 'municipio', label: 'Municipio', required: true),
      ResourceField(keyName: 'cve_mun', label: 'Clave municipal'),
      ResourceField(keyName: 'localidad', label: 'Localidad'),
      ResourceField(keyName: 'colonia', label: 'Colonia'),
      ResourceField(keyName: 'calle', label: 'Calle'),
      ResourceField(keyName: 'numero_ext', label: 'Número exterior'),
      ResourceField(keyName: 'numero_int', label: 'Número interior'),
      ResourceField(keyName: 'cp', label: 'Código postal'),
      ResourceField(
        keyName: 'lat',
        label: 'Latitud',
        type: ResourceFieldType.number,
      ),
      ResourceField(
        keyName: 'lng',
        label: 'Longitud',
        type: ResourceFieldType.number,
      ),
      ResourceField(keyName: 'seccion', label: 'Sección'),
      ResourceField(
        keyName: 'distrito_federal',
        label: 'Distrito federal',
        type: ResourceFieldType.number,
      ),
      ResourceField(
        keyName: 'distrito_local',
        label: 'Distrito local',
        type: ResourceFieldType.number,
      ),
      ResourceField(
        keyName: 'perfil',
        label: 'Perfil',
        type: ResourceFieldType.multiline,
      ),
      ResourceField(
        keyName: 'observaciones',
        label: 'Observaciones',
        type: ResourceFieldType.multiline,
      ),
      ResourceField(
        keyName: 'estatus',
        label: 'Estatus',
        type: ResourceFieldType.select,
        options: {
          'pendiente': 'Pendiente',
          'validado': 'Validado',
          'descartado': 'Descartado',
        },
      ),
      ResourceField(
        keyName: 'fecha_convencimiento',
        label: 'Fecha de convencimiento (AAAA-MM-DD)',
      ),
    ],
    titleBuilder: _title,
    subtitleBuilder: _subtitle,
  );

  static String _title(Map<String, dynamic> item) => [
    item['nombre'],
    item['apellido_paterno'],
    item['apellido_materno'],
  ].where((value) => value != null && '$value'.trim().isNotEmpty).join(' ');

  static String _subtitle(Map<String, dynamic> item) =>
      '${item['municipio'] ?? 'Sin municipio'} · Sección ${item['seccion'] ?? '—'}';

  @override
  Widget build(BuildContext context) =>
      const ResourceCrudPage(definition: _definition);
}
