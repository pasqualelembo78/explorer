#!/bin/bash
# =============================================================
# fix_fmt_v2.sh  - Soluzione definitiva per l'errore fmt
# Usa libfmt-dev di sistema invece del bundle rotto
#
# Eseguire dalla root del progetto:
#   cd /root/explorer && bash fix_fmt_v2.sh
# =============================================================
set -e

EXPLORER_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== [1/5] Installazione libfmt-dev dal sistema ==="
apt-get install -y libfmt-dev
echo "    libfmt-dev installato: $(dpkg -l libfmt-dev | awk '/^ii/{print $3}')"

echo ""
echo "=== [2/5] Aggiornamento ext/CMakeLists.txt ==="
cat > "$EXPLORER_DIR/ext/CMakeLists.txt" << 'CMAKE_EOF'
cmake_minimum_required(VERSION 3.5.2)

# mstch template library
add_subdirectory("mstch")

# myext: il bundle fmt è rimosso, usiamo libfmt-dev di sistema
project(myext)

add_library(myext STATIC)
set_target_properties(myext PROPERTIES LINKER_LANGUAGE CXX)

# Expose ext/ per minicsv.h e altri header locali
target_include_directories(myext PUBLIC
        "${CMAKE_CURRENT_SOURCE_DIR}"
)
CMAKE_EOF
echo "    ext/CMakeLists.txt aggiornato."

echo ""
echo "=== [3/5] Aggiornamento src/tools.h ==="
cp "$EXPLORER_DIR/src/tools.h" "$EXPLORER_DIR/src/tools.h.bak"
sed -i \
    's|#include "\.\./ext/fmt/ostream\.h"|#include <fmt/ostream.h>|g;
     s|#include "\.\./ext/fmt/format\.h"|#include <fmt/format.h>|g' \
    "$EXPLORER_DIR/src/tools.h"
echo "    src/tools.h aggiornato (backup: tools.h.bak)"

echo ""
echo "=== [4/5] Aggiornamento CMakeLists.txt radice ==="
cp "$EXPLORER_DIR/CMakeLists.txt" "$EXPLORER_DIR/CMakeLists.txt.bak"
python3 - "$EXPLORER_DIR/CMakeLists.txt" << 'PYEOF'
import sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()

# Aggiunge find_package(fmt REQUIRED) se non già presente
if 'find_package(fmt' not in content:
    content = content.replace(
        'find_package(Sanitizers)',
        'find_package(fmt REQUIRED)\n\n#info https://github.com/arsenm/sanitizers-cmake\nfind_package(Sanitizers)'
    )

# Aggiunge fmt::fmt alle librerie se non già presente
if 'fmt::fmt' not in content:
    content = content.replace(
        'set(LIBRARIES\n        myxrm\n        myext\n        mstch',
        'set(LIBRARIES\n        myxrm\n        myext\n        mstch\n        fmt::fmt'
    )

with open(path, 'w') as f:
    f.write(content)
print("    CMakeLists.txt radice aggiornato.")
PYEOF

echo ""
echo "=== [5/5] Pulizia build e ricompilazione ==="
echo "    Esegui ora:"
echo ""
echo "    cd $EXPLORER_DIR/build"
echo "    rm -rf *"
echo "    cmake .. -DMONERO_DIR=/root/mevacoin"
echo "    make -j\$(nproc) 2>&1 | tee build.log"
echo ""
echo "======================================================"
echo "  fix_fmt_v2 completato correttamente."
echo "======================================================"
