# Skills Codex del proyecto

Este directorio documenta las skills recomendadas para trabajar en este
proyecto con Codex.

Importante: las skills instaladas en `~/.codex/skills` son locales de cada
maquina. Clonar este repositorio no las instala automaticamente. Despues de
clonar el proyecto, cada persona debe ejecutar los comandos de instalacion de
esta guia si quiere tener el mismo set de skills.

## Skills incluidas en el repo

La skill `sql-toolkit` esta versionada en este repositorio porque fue agregada
desde un archivo descargado por el usuario:

- `docs/codex-skills/sql-toolkit/SKILL.md`

Para instalarla localmente en Codex:

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
cp -R docs/codex-skills/sql-toolkit "${CODEX_HOME:-$HOME/.codex}/skills/"
```

## Skills externas recomendadas

Estas skills se instalan desde repositorios externos y quedan en
`~/.codex/skills`:

### Seguridad y navegador

```bash
python3 ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \
  --repo openai/skills \
  --path skills/.curated/security-best-practices \
         skills/.curated/security-threat-model \
         skills/.curated/playwright
```

### Flutter

```bash
python3 ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \
  --repo flutter/agent-plugins \
  --path skills/flutter-add-widget-test \
         skills/flutter-build-responsive-layout \
         skills/flutter-fix-layout-issues \
         skills/flutter-use-http-package \
         skills/flutter-apply-architecture-best-practices \
         skills/flutter-add-integration-test
```

### Dart

```bash
python3 ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \
  --repo dart-lang/skills \
  --path skills/dart-run-static-analysis \
         skills/dart-add-unit-test \
         skills/dart-generate-test-mocks \
         skills/dart-resolve-package-conflicts \
         skills/dart-use-pattern-matching \
         skills/dart-write-documentation
```

## Verificacion

Despues de instalar, verificar que cada skill tenga su `SKILL.md`:

```bash
for skill in \
  sql-toolkit \
  security-best-practices \
  security-threat-model \
  playwright \
  flutter-add-widget-test \
  flutter-build-responsive-layout \
  flutter-fix-layout-issues \
  flutter-use-http-package \
  flutter-apply-architecture-best-practices \
  flutter-add-integration-test \
  dart-run-static-analysis \
  dart-add-unit-test \
  dart-generate-test-mocks \
  dart-resolve-package-conflicts \
  dart-use-pattern-matching \
  dart-write-documentation
do
  test -f "${CODEX_HOME:-$HOME/.codex}/skills/$skill/SKILL.md" \
    && echo "$skill ok" \
    || echo "$skill falta"
done
```

## Uso

Las skills no actuan por si solas. Codex puede usarlas cuando el pedido encaja
o cuando se nombran explicitamente.

Ejemplos:

```text
Usa sql-toolkit para disenar una consulta PostgreSQL de cartera vencida por ruta.
Usa flutter-add-widget-test para cubrir el formulario de creacion de credito.
Usa dart-run-static-analysis para revisar el frontend y proponer fixes.
Usa security-best-practices para revisar el backend y priorizar riesgos.
```
