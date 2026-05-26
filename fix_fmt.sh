#!/bin/bash
# =============================================================
# fix_fmt.sh
# Risolve il linker error: fmt::v8 incompatibile con fmt v3
# Da eseguire nella root del progetto explorer:
#   cd /root/explorer && bash fix_fmt.sh
# =============================================================

set -e

EXPLORER_DIR="$(cd "$(dirname "$0")" && pwd)"
EXT_DIR="$EXPLORER_DIR/ext"
FMT_DIR="$EXT_DIR/fmt"

echo "=== [1/5] Backup del vecchio ext/fmt ==="
mv "$FMT_DIR" "$FMT_DIR.bak.v3"
mkdir -p "$FMT_DIR"

echo "=== [2/5] Download fmt v8.1.1 ==="
cd /tmp
rm -rf fmt-8.1.1 fmt-8.1.1.tar.gz
wget -q --show-progress \
  https://github.com/fmtlib/fmt/archive/refs/tags/8.1.1.tar.gz \
  -O fmt-8.1.1.tar.gz
tar xzf fmt-8.1.1.tar.gz
echo "    Download completato."

echo "=== [3/5] Copia headers e sorgenti fmt v8 in ext/fmt ==="
# Headers: messi direttamente in ext/fmt/ per compatibilità con tools.h
cp /tmp/fmt-8.1.1/include/fmt/core.h      "$FMT_DIR/"
cp /tmp/fmt-8.1.1/include/fmt/format.h    "$FMT_DIR/"
cp /tmp/fmt-8.1.1/include/fmt/ostream.h   "$FMT_DIR/"
cp /tmp/fmt-8.1.1/include/fmt/format-inl.h "$FMT_DIR/"
cp /tmp/fmt-8.1.1/include/fmt/os.h        "$FMT_DIR/"
cp /tmp/fmt-8.1.1/include/fmt/color.h     "$FMT_DIR/"
cp /tmp/fmt-8.1.1/include/fmt/compile.h   "$FMT_DIR/"
cp /tmp/fmt-8.1.1/include/fmt/printf.h    "$FMT_DIR/"
cp /tmp/fmt-8.1.1/include/fmt/ranges.h    "$FMT_DIR/"
cp /tmp/fmt-8.1.1/include/fmt/chrono.h    "$FMT_DIR/"
cp /tmp/fmt-8.1.1/include/fmt/locale.h    "$FMT_DIR/"  2>/dev/null || true
# Sorgenti compilabili
cp /tmp/fmt-8.1.1/src/format.cc           "$FMT_DIR/format.cc"
cp /tmp/fmt-8.1.1/src/os.cc               "$FMT_DIR/os.cc"
echo "    File copiati in $FMT_DIR"

echo "=== [4/5] Aggiornamento ext/CMakeLists.txt ==="
cat > "$EXT_DIR/CMakeLists.txt" << 'CMAKE_EOF'
cmake_minimum_required(VERSION 3.5.2)

# -------------------------------------------------------
# mstch template library
# -------------------------------------------------------
add_subdirectory("mstch")

# -------------------------------------------------------
# myext: fmt v8 + file accessori
# -------------------------------------------------------
project(myext)

set(SOURCE_HEADERS
        minicsv.h
        fmt/format.h
        fmt/core.h
        fmt/ostream.h)

set(SOURCE_FILES
        fmt/format.cc
        fmt/os.cc)

# fmt v8 deve trovare i propri header dentro ext/fmt/
# Aggiungiamo ext/ come include dir così <fmt/core.h> funziona
# sia per i file nel progetto sia per fmt stesso durante la compilazione
add_library(myext STATIC ${SOURCE_FILES})

target_include_directories(myext PUBLIC
        "${CMAKE_CURRENT_SOURCE_DIR}"       # per ../ext/fmt/format.h (tools.h)
        "${CMAKE_CURRENT_SOURCE_DIR}/fmt"   # per compilare format.cc (include "core.h")
)

# fmt v8 usa FMT_HEADER_ONLY=0 di default (compilazione separata)
target_compile_definitions(myext PUBLIC FMT_SHARED=0)
CMAKE_EOF

echo "    CMakeLists.txt aggiornato."

echo "=== [5/5] Patch src/tools.h: aggiornamento include fmt ==="
# tools.h usa ancora i vecchi path ../ext/fmt/format.h e ../ext/fmt/ostream.h
# fmt v8 ha cambiato la struttura interna: ostream.h ora include format.h
# Sostituiamo con gli header v8 corretti
TOOLS_H="$EXPLORER_DIR/src/tools.h"

# Backup
cp "$TOOLS_H" "$TOOLS_H.bak"

# Sostituisci i due include vecchi con quelli v8
sed -i 's|#include "\.\./ext/fmt/ostream\.h"|#include "../ext/fmt/ostream.h"|g' "$TOOLS_H"
sed -i 's|#include "\.\./ext/fmt/format\.h"|#include "../ext/fmt/format.h"\n#include "../ext/fmt/ostream.h"|g' "$TOOLS_H"

# Rimuovi eventuali righe duplicate di ostream.h
python3 - "$TOOLS_H" << 'PYEOF'
import sys
path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()
seen = set()
out = []
for line in lines:
    key = line.strip()
    if key.startswith('#include') and key in seen:
        continue
    if key.startswith('#include'):
        seen.add(key)
    out.append(line)
with open(path, 'w') as f:
    f.writelines(out)
print("    tools.h deduplicato OK")
PYEOF

echo ""
echo "======================================================"
echo "  Fix completato. Ora riesegui la build:"
echo ""
echo "  cd /root/explorer/build"
echo "  cmake .. -DMONERO_DIR=/root/mevacoin"
echo "  make -j\$(nproc) 2>&1 | tee build.log"
echo "======================================================"
