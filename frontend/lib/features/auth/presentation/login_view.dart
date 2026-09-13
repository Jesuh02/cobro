import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/ui/clay.dart';

class LoginView extends StatefulWidget {
  const LoginView({
    required this.usuarioController,
    required this.contrasenaController,
    required this.guardando,
    required this.onIniciarSesion,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.error,
    super.key,
  });

  final TextEditingController usuarioController;
  final TextEditingController contrasenaController;
  final bool guardando;
  final VoidCallback onIniciarSesion;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String? error;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  bool _mostrarContrasena = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(color: context.clay.background),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: ClaySurface(
                  radius: 18,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CircleAvatar(
                            backgroundColor:
                                CobroAppTheme.primary.withValues(alpha: 0.12),
                            foregroundColor: CobroAppTheme.primary,
                            child: const Icon(Icons.lock_rounded),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Iniciar sesion',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Tooltip(
                            message: 'Cambiar tema',
                            child: IconButton(
                              onPressed: () {
                                widget.onThemeModeChanged(
                                  widget.themeMode == ThemeMode.dark
                                      ? ThemeMode.light
                                      : ThemeMode.dark,
                                );
                              },
                              icon: Icon(
                                widget.themeMode == ThemeMode.dark
                                    ? Icons.light_mode_rounded
                                    : Icons.dark_mode_rounded,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: widget.usuarioController,
                        enabled: !widget.guardando,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Usuario',
                          prefixIcon: Icon(Icons.person_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: widget.contrasenaController,
                        enabled: !widget.guardando,
                        obscureText: !_mostrarContrasena,
                        onSubmitted: (_) => widget.onIniciarSesion(),
                        decoration: InputDecoration(
                          labelText: 'Contrasena',
                          prefixIcon: const Icon(Icons.key_rounded),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _mostrarContrasena = !_mostrarContrasena;
                              });
                            },
                            icon: Icon(
                              _mostrarContrasena
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                      ),
                      if (widget.error != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          widget.error!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: CobroAppTheme.danger,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed:
                            widget.guardando ? null : widget.onIniciarSesion,
                        icon: widget.guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login_rounded),
                        label: const Text('Entrar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
