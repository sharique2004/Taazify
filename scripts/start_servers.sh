#!/bin/bash
# ─── Taazify Server Launcher ───
# Starts Ollama, OCR server, and Recipe server together

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

echo "🚀 Starting Taazify servers..."
echo ""

# 1. Ensure venv exists
if [ ! -d "$VENV_DIR" ]; then
    echo "📦 Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install -r "$SCRIPT_DIR/requirements_recipe.txt" -q
    pip install -r "$SCRIPT_DIR/requirements_ocr.txt" -q 2>/dev/null
else
    source "$VENV_DIR/bin/activate"
fi

# 2. Start Recipe Server (port 8001)
echo "🍳 Starting Recipe Server (port 8001)..."
python "$SCRIPT_DIR/recipe_server.py" &
RECIPE_PID=$!
sleep 1

echo ""
echo "═══════════════════════════════════════════"
echo "  ✅ Taazify servers running!"
echo ""
echo "  🍳 Recipe Server:  http://localhost:8001
"
echo ""
echo "  Press Ctrl+C to stop all servers"
echo "═══════════════════════════════════════════"
echo ""

# Trap Ctrl+C to clean up all processes
cleanup() {
    echo ""
    echo "🛑 Shutting down servers..."
    [ -n "$RECIPE_PID" ] && kill $RECIPE_PID 2>/dev/null
    echo "   Done."
    exit 0
}
trap cleanup SIGINT SIGTERM

# Wait for all background processes
wait
