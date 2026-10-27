#!/usr/bin/env bash
# Script portable para ejecutar Graphify en cualquier repositorio.
# Es 100% autosuficiente: si no existe el entorno, lo crea e instala automáticamente.
# Todos los resultados se almacenan en 'graphify-out/' (ignorado por Git).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCAL_VENV="$PROJECT_ROOT/.venv-graphify"
GRAPHIFY_BIN="$LOCAL_VENV/bin/graphify"

# 1. Resolver ejecutable: usar comando global si existe, o el entorno local
if command -v graphify &>/dev/null; then
    GRAPHIFY_EXEC="graphify"
elif [ -x "$GRAPHIFY_BIN" ]; then
    GRAPHIFY_EXEC="$GRAPHIFY_BIN"
else
    echo "=========================================================="
    echo " Entorno de Graphify no detectado en este proyecto."
    echo " Creando entorno virtual local (.venv-graphify) e instalando dependencias..."
    echo "=========================================================="
    python3 -m venv "$LOCAL_VENV"
    "$LOCAL_VENV/bin/pip" install --quiet graphifyy
    GRAPHIFY_EXEC="$GRAPHIFY_BIN"
    echo "✅ Entorno configurado exitosamente en $LOCAL_VENV"
fi

# 2. Asegurar que .gitignore incluya las carpetas generadas automáticamente
GITIGNORE="$PROJECT_ROOT/.gitignore"
if [ -f "$GITIGNORE" ]; then
    if ! grep -q "graphify-out/" "$GITIGNORE" 2>/dev/null; then
        echo -e "\n# Graphify (Knowledge graph outputs & local virtualenv)\ngraphify-out/\n.venv-graphify/" >> "$GITIGNORE"
        echo "ℹ️ Se añadieron automáticamente 'graphify-out/' y '.venv-graphify/' a tu .gitignore"
    fi
fi

# 3. Asegurar regla automática para que la IA consulte Graphify por sí sola
AGENTS_RULES_DIR="$PROJECT_ROOT/.agents/rules"
RULE_FILE="$AGENTS_RULES_DIR/graphify.md"
if [ ! -f "$RULE_FILE" ]; then
    mkdir -p "$AGENTS_RULES_DIR"
    cat << 'EOF' > "$RULE_FILE"
---
trigger: always_on
description: Consult the graphify knowledge graph at graphify-out/ for codebase and architecture questions.
---

## graphify (Knowledge Graph)

Este proyecto cuenta con un grafo de conocimiento generado en `graphify-out/`.

Reglas para el asistente:
- Para preguntas sobre arquitectura, dependencias o ubicación de funciones/clases, si `graphify-out/graph.json` existe, consulta primero el grafo antes de hacer lecturas masivas o búsquedas ciegas de archivos.
- Puedes usar `./scripts/graphify.sh query "<pregunta o símbolo>"` o inspeccionar el grafo para obtener el subgrafo de dependencias exacto.
- Al modificar código relevante en la sesión, recuerda actualizar el grafo con `./scripts/graphify.sh` (extracción local AST rápida y gratuita).
EOF
    echo "ℹ️ Regla de IA configurada en .agents/rules/graphify.md (la IA consultará el grafo automáticamente)"
fi

# 4. Si no se pasan argumentos, corre la extracción de código AST por defecto
if [ "$#" -eq 0 ]; then
    echo "=========================================================="
    echo " Ejecutando Graphify: Análisis de código AST (Local/Gratuito)"
    echo " Directorio destino: $PROJECT_ROOT/graphify-out/"
    echo "=========================================================="
    "$GRAPHIFY_EXEC" extract "$PROJECT_ROOT" --code-only --out "$PROJECT_ROOT"
    
    echo ""
    echo "=========================================================="
    echo " Generando visor interactivo HTML (graph.html)..."
    echo "=========================================================="
    (cd "$PROJECT_ROOT" && "$GRAPHIFY_EXEC" export html)
    
    echo ""
    echo "✅ Análisis completado. Puedes abrir en tu navegador:"
    echo "   file://$PROJECT_ROOT/graphify-out/graph.html"
else
    # Si se pasan argumentos adicionales (ej: query, export, tree, etc.)
    "$GRAPHIFY_EXEC" "$@"
fi
