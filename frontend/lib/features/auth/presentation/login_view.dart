import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/ui/clay.dart';
import 'widgets/login_expansive_background.dart';
import 'widgets/login_fintech_header.dart';

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
    final bool isDark = widget.themeMode == ThemeMode.dark;

    return Scaffold(
      body: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: isDark
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0xFFF8FAFC),
                      Color(0xFFF1F5F9),
                      Color(0xFFE4EBF2),
                    ],
                  ),
            color: isDark ? context.clay.background : null,
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: <Widget>[
              // Entorno ambiental expansivo de órbitas, auras y rutas
              Positioned.fill(
                child: LoginExpansiveBackground(
                  isDark: isDark,
                ),
              ),

              // Contenedor centrado y scrollable
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? context.clay.surface
                            : context.clay.surfaceHigh,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark
                              ? context.clay.border
                              : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: <BoxShadow>[
                          if (isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 36,
                              offset: const Offset(0, 16),
                            )
                          else ...<BoxShadow>[
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.09),
                              blurRadius: 38,
                              offset: const Offset(0, 18),
                            ),
                            BoxShadow(
                              color: const Color(0xFF1683F3).withValues(alpha: 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // Cabecera ilustrada con tarjetas de cobro, ruta y GPS
                          LoginFintechHeader(
                            themeMode: widget.themeMode,
                          ),

                          // Formulario de autenticación
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                TextField(
                                  controller: widget.usuarioController,
                                  enabled: !widget.guardando,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: 'Usuario',
                                    labelStyle: TextStyle(
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF475569),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    floatingLabelStyle: const TextStyle(
                                      color: CobroAppTheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    hintText: 'Ingresa tu usuario asignado',
                                    hintStyle: TextStyle(
                                      color: isDark
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF94A3B8),
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(0xFF1E293B).withValues(alpha: 0.7)
                                        : const Color(0xFFF1F5F9),
                                    prefixIcon: const SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: Center(
                                        child: Text(
                                          '👤',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFF94A3B8),
                                        width: 1.4,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: CobroAppTheme.primary,
                                        width: 2.0,
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFF94A3B8),
                                        width: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: widget.contrasenaController,
                                  enabled: !widget.guardando,
                                  obscureText: !_mostrarContrasena,
                                  onSubmitted: (_) => widget.onIniciarSesion(),
                                  decoration: InputDecoration(
                                    labelText: 'Contraseña',
                                    labelStyle: TextStyle(
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF475569),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    floatingLabelStyle: const TextStyle(
                                      color: CobroAppTheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    hintText: '••••••••',
                                    hintStyle: TextStyle(
                                      color: isDark
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF94A3B8),
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(0xFF1E293B).withValues(alpha: 0.7)
                                        : const Color(0xFFF1F5F9),
                                    prefixIcon: const SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: Center(
                                        child: Text(
                                          '🔑',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ),
                                    suffixIcon: IconButton(
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        elevation: 0,
                                        side: BorderSide.none,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _mostrarContrasena =
                                              !_mostrarContrasena;
                                        });
                                      },
                                      tooltip: _mostrarContrasena
                                          ? 'Ocultar contraseña'
                                          : 'Mostrar contraseña',
                                      icon: Opacity(
                                        opacity: _mostrarContrasena ? 1.0 : 0.6,
                                        child: const Text(
                                          '👁️',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFF94A3B8),
                                        width: 1.4,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: CobroAppTheme.primary,
                                        width: 2.0,
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFF94A3B8),
                                        width: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                                if (widget.error != null) ...<Widget>[
                                  const SizedBox(height: 12),
                                  Text(
                                    widget.error!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: CobroAppTheme.danger,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                SizedBox(
                                  height: 48,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: CobroAppTheme.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: widget.guardando
                                        ? null
                                        : widget.onIniciarSesion,
                                    icon: widget.guardando
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 20,
                                          ),
                                    label: const Text(
                                      'Entrar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Botón flotante de cambio de tema en la esquina superior de la página
              Positioned(
                top: 18,
                right: 18,
                child: Tooltip(
                  message: isDark ? 'Activar modo claro' : 'Activar modo oscuro',
                  child: Material(
                    color: isDark
                        ? context.clay.surfaceHigh.withValues(alpha: 0.85)
                        : context.clay.surface.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    elevation: 3,
                    shadowColor: Colors.black26,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        widget.onThemeModeChanged(
                          isDark ? ThemeMode.light : ThemeMode.dark,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: isDark
                              ? const Color(0xFFFDE68A)
                              : CobroAppTheme.primary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
