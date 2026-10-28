import 'package:flutter/material.dart';

import '../../../../core/ui/clay.dart';

class SuperAdminNavigation extends StatelessWidget {
  const SuperAdminNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.instituciones,
    required this.gestionAcceso,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget instituciones;
  final Widget gestionAcceso;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final bool disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Column(
      children: <Widget>[
        Material(
          color: clay.surface,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compacto = constraints.maxWidth < 480;

              return SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compacto ? 16 : 28,
                    vertical: 12,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Semantics(
                        container: true,
                        label: 'Secciones de SuperAdmin',
                        child: SegmentedButton<int>(
                          key: const ValueKey<String>(
                            'super-admin-navigation',
                          ),
                          segments: <ButtonSegment<int>>[
                            ButtonSegment<int>(
                              value: 0,
                              icon: compacto
                                  ? null
                                  : const Icon(Icons.apartment_rounded),
                              label: const Text(
                                'Instituciones',
                                key: ValueKey<String>(
                                  'super-admin-tab-instituciones',
                                ),
                              ),
                              tooltip: 'Administrar instituciones y pagos',
                            ),
                            ButtonSegment<int>(
                              value: 1,
                              icon: compacto
                                  ? null
                                  : const Icon(Icons.manage_accounts_rounded),
                              label: const Text(
                                'Gestión de acceso',
                                key: ValueKey<String>(
                                  'super-admin-tab-acceso',
                                ),
                              ),
                              tooltip: 'Activar o desactivar usuarios',
                            ),
                          ],
                          selected: <int>{selectedIndex},
                          onSelectionChanged: (Set<int> selection) {
                            onSelected(selection.single);
                          },
                          expandedInsets: EdgeInsets.zero,
                          showSelectedIcon: false,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Divider(height: 1, color: clay.border),
        Expanded(
          child: AnimatedSwitcher(
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: selectedIndex == 0 ? instituciones : gestionAcceso,
          ),
        ),
      ],
    );
  }
}
