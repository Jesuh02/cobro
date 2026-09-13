import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import 'clay.dart';

class MarcaAplicacion extends StatelessWidget {
  const MarcaAplicacion({super.key});

  @override
  Widget build(BuildContext context) {
    final TextStyle? baseStyle = Theme.of(context).textTheme.titleMedium;
    const Widget logo = ClayIcon(
      icon: Icons.monetization_on_rounded,
      size: 42,
      iconSize: 24,
      radius: 13,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth <= 0) {
          return const SizedBox.shrink();
        }

        if (constraints.maxWidth < 132) {
          return Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: math.min(42, constraints.maxWidth),
              height: 42,
              child: const FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: logo,
              ),
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            logo,
            const SizedBox(width: 11),
            Flexible(
              child: Text.rich(
                TextSpan(
                  style: baseStyle?.copyWith(
                    color: context.clay.text,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                  children: const <InlineSpan>[
                    TextSpan(text: 'App'),
                    TextSpan(
                      text: 'Créditos',
                      style: TextStyle(color: CobroAppTheme.primary),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}

