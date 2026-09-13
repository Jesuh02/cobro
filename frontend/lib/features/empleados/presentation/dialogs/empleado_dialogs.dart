import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../data/models/models.dart';

Future<bool> mostrarDialogoCrearEmpleado({
  required BuildContext context,
  required bool esAdministrador,
  required ApiClient apiClient,
  required void Function(String) mostrarMensaje,
  required String Function(Object) mensajeError,
  required Future<void> Function() onRecargar,
  required void Function(bool) setGuardando,
}) async {
  if (!esAdministrador) {
    mostrarMensaje('Solo el administrador puede crear usuarios');
    return false;
  }

  final bool? creado = await _pedirDatosUsuario(
    context: context,
    titulo: 'Crear empleado',
    accion: 'Crear empleado',
    apiClient: apiClient,
    mostrarMensaje: mostrarMensaje,
    mensajeError: mensajeError,
    onRecargar: onRecargar,
    setGuardando: setGuardando,
  );

  if (creado ?? false) {
    mostrarMensaje('Empleado creado');
  }

  return creado ?? false;
}

Future<EmpleadoGestion?> mostrarDialogoModificarEmpleado({
  required BuildContext context,
  required EmpleadoGestion empleado,
  required bool esAdministrador,
  required ApiClient apiClient,
  required void Function(String) mostrarMensaje,
}) async {
  if (!esAdministrador) {
    mostrarMensaje('Solo el administrador puede modificar empleados');
    return null;
  }

  final Map<String, String>? datos = await _pedirDatosEmpleado(
    context: context,
    titulo: 'Modificar empleado',
    accion: 'Guardar',
    empleado: empleado,
    mostrarMensaje: mostrarMensaje,
  );

  if (datos == null) {
    return null;
  }

  final Map<String, dynamic> respuesta = await apiClient.patchObject(
    '/usuarios/${empleado.id}',
    <String, dynamic>{...datos},
  );
  return EmpleadoGestion.fromJson(respuesta);
}

Future<bool?> _pedirDatosUsuario({
  required BuildContext context,
  required String titulo,
  required String accion,
  required ApiClient apiClient,
  required void Function(String) mostrarMensaje,
  required String Function(Object) mensajeError,
  required Future<void> Function() onRecargar,
  required void Function(bool) setGuardando,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final TextEditingController nombreController = TextEditingController();
      final TextEditingController usuarioController = TextEditingController();
      final TextEditingController contrasenaController =
          TextEditingController();
      final TextEditingController correoController = TextEditingController();
      bool mostrarContrasena = false;
      bool guardandoDialog = false;

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
          title: Text(titulo),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: nombreController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.badge_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: usuarioController,
                    decoration: const InputDecoration(
                      labelText: 'Usuario',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: correoController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(Icons.mail_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contrasenaController,
                    obscureText: !mostrarContrasena,
                    decoration: InputDecoration(
                      labelText: 'Contrasena',
                      helperText: 'Minimo 12 caracteres',
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setDialogState(
                            () => mostrarContrasena = !mostrarContrasena,
                          );
                        },
                        icon: Icon(
                          mostrarContrasena
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: guardandoDialog
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: guardandoDialog
                  ? null
                  : () async {
                      final String nombre = nombreController.text.trim();
                      final String nombreUsuario =
                          usuarioController.text.trim().toLowerCase();
                      final String correo = correoController.text.trim();
                      final String contrasena = contrasenaController.text;

                      if (nombre.length < 3) {
                        mostrarMensaje(
                          'El nombre debe tener minimo 3 caracteres',
                        );
                        return;
                      }
                      if (nombreUsuario.length < 3) {
                        mostrarMensaje(
                          'El usuario debe tener minimo 3 caracteres',
                        );
                        return;
                      }
                      if (!correo.contains('@')) {
                        mostrarMensaje('Ingresa un correo valido');
                        return;
                      }
                      if (contrasena.length < 12) {
                        mostrarMensaje(
                          'La contrasena debe tener minimo 12 caracteres',
                        );
                        return;
                      }

                      setDialogState(() => guardandoDialog = true);
                      setGuardando(true);

                      try {
                        await apiClient.postObject(
                          '/usuarios',
                          <String, dynamic>{
                            'nombreCompleto': nombre,
                            'usuario': nombreUsuario,
                            'correo': correo,
                            'contrasena': contrasena,
                          },
                          queueOffline: true,
                        );
                        await onRecargar();

                        if (!dialogContext.mounted) {
                          return;
                        }

                        Navigator.of(dialogContext).pop(true);
                      } catch (error) {
                        if (dialogContext.mounted) {
                          mostrarMensaje(mensajeError(error));
                          setDialogState(() => guardandoDialog = false);
                        }
                      } finally {
                        setGuardando(false);
                      }
                    },
              icon: guardandoDialog
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(accion),
            ),
          ],
        ),
      );
    },
  );
}

Future<Map<String, String>?> _pedirDatosEmpleado({
  required BuildContext context,
  required String titulo,
  required String accion,
  required EmpleadoGestion empleado,
  required void Function(String) mostrarMensaje,
}) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (BuildContext dialogContext) {
      final TextEditingController nombreController =
          TextEditingController(text: empleado.nombreCompleto);
      final TextEditingController usuarioController =
          TextEditingController(text: empleado.usuario);
      final TextEditingController correoController =
          TextEditingController(text: empleado.correo);
      final TextEditingController contrasenaController =
          TextEditingController();
      bool mostrarContrasena = false;

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
          title: Text(titulo),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: nombreController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.badge_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: usuarioController,
                    decoration: const InputDecoration(
                      labelText: 'Usuario',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: correoController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(Icons.mail_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contrasenaController,
                    obscureText: !mostrarContrasena,
                    decoration: InputDecoration(
                      labelText: 'Nueva contrasena',
                      helperText: 'Dejala vacia para conservar la actual',
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setDialogState(
                            () => mostrarContrasena = !mostrarContrasena,
                          );
                        },
                        icon: Icon(
                          mostrarContrasena
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                final String nombre = nombreController.text.trim();
                final String nombreUsuario =
                    usuarioController.text.trim().toLowerCase();
                final String correo = correoController.text.trim();
                final String contrasena = contrasenaController.text;

                if (nombre.length < 3) {
                  mostrarMensaje('El nombre debe tener minimo 3 caracteres');
                  return;
                }
                if (nombreUsuario.length < 3) {
                  mostrarMensaje(
                    'El usuario debe tener minimo 3 caracteres',
                  );
                  return;
                }
                if (!correo.contains('@')) {
                  mostrarMensaje('Ingresa un correo valido');
                  return;
                }
                if (contrasena.isNotEmpty && contrasena.length < 12) {
                  mostrarMensaje(
                    'La nueva contrasena debe tener minimo 12 caracteres',
                  );
                  return;
                }

                Navigator.of(dialogContext).pop(<String, String>{
                  'nombreCompleto': nombre,
                  'usuario': nombreUsuario,
                  'correo': correo,
                  if (contrasena.isNotEmpty) 'contrasena': contrasena,
                });
              },
              icon: const Icon(Icons.check_rounded),
              label: Text(accion),
            ),
          ],
        ),
      );
    },
  );
}
