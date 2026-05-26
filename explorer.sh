#!/bin/bash
# =============================================================
# install_explorer.sh
# Compila xmrblocks e lo installa come servizio systemd
# sulla porta 18084 con Apache2 come reverse proxy.
#
# Uso:
#   chmod +x install_explorer.sh
#   sudo bash install_explorer.sh
# =============================================================

set -e

# -------------------------------------------------------
# CONFIGURAZIONE — modifica questi valori se necessario
# -------------------------------------------------------
EXPLORER_DIR="/root/explorer"
MEVACOIN_DIR="/root/mevacoin"
BC_PATH="/root/.mevacoin/lmdb"
DAEMON_URL="127.0.0.1:18081"
EXPLORER_PORT="18084"
DOMAIN="explorer.mevacoin.com"
SERVICE_NAME="xmrblocks"
BINARY_INSTALL="/usr/local/bin/xmrblocks"
# -------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo "======================================================"
echo "  Mevacoin Explorer — Build & Install"
echo "======================================================"

# -------------------------------------------------------
# 1. Controlli preliminari
# -------------------------------------------------------
info "[1/7] Controlli preliminari..."

[ ! -d "$EXPLORER_DIR" ] && error "Directory explorer non trovata: $EXPLORER_DIR"
[ ! -d "$MEVACOIN_DIR" ] && error "Directory mevacoin non trovata: $MEVACOIN_DIR"
[ ! -d "$BC_PATH" ]      && warn  "Cartella blockchain non trovata: $BC_PATH (verifica il path)"

command -v cmake   >/dev/null 2>&1 || error "cmake non installato"
command -v make    >/dev/null 2>&1 || error "make non installato"
command -v apache2 >/dev/null 2>&1 || error "apache2 non installato"

info "    Tutti i controlli superati."

# -------------------------------------------------------
# 2. Dipendenze di sistema
# -------------------------------------------------------
info "[2/7] Verifica/installazione dipendenze..."
apt-get install -y --quiet \
    libfmt-dev \
    libboost-all-dev \
    libssl-dev \
    apache2 \
    > /dev/null 2>&1
info "    Dipendenze OK."

# -------------------------------------------------------
# 3. Compilazione
# -------------------------------------------------------
info "[3/7] Compilazione in corso..."

BUILD_DIR="$EXPLORER_DIR/build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Pulisci solo se CMakeCache esiste e punta a un MONERO_DIR diverso
if [ -f CMakeCache.txt ]; then
    CACHED_DIR=$(grep -oP 'MONERO_DIR:PATH=\K.*' CMakeCache.txt 2>/dev/null || echo "")
    if [ "$CACHED_DIR" != "$MEVACOIN_DIR" ]; then
        warn "    CMakeCache obsoleto, pulizia..."
        rm -rf *
    fi
fi

cmake "$EXPLORER_DIR" \
    -DMONERO_DIR="$MEVACOIN_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    > "$BUILD_DIR/cmake.log" 2>&1 || error "cmake fallito. Controlla $BUILD_DIR/cmake.log"

make -j$(nproc) 
[ ! -f "$BUILD_DIR/xmrblocks" ] && error "Binario non trovato dopo la build."
info "    Compilazione completata."

# -------------------------------------------------------
# 4. Installazione binario
# -------------------------------------------------------
info "[4/7] Installazione binario in $BINARY_INSTALL..."
info "[4/7] Pulizia processo explorer..."

systemctl stop xmrblocks 2>/dev/null || true
pkill -f xmrblocks 2>/dev/null || true
fuser -k 18082/tcp 2>/dev/null || true
sleep 2
cp "$BUILD_DIR/xmrblocks" "$BINARY_INSTALL"
chmod 755 "$BINARY_INSTALL"
info "    Binario installato."


info "[4/7] Installazione binario in $BINARY_INSTALL..."
cp "$BUILD_DIR/xmrblocks" "$BINARY_INSTALL"
chmod 755 "$BINARY_INSTALL"
# -------------------------------------------------------
# 5. Creazione servizio systemd
# -------------------------------------------------------
info "[5/7] Creazione servizio systemd: $SERVICE_NAME..."

cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Mevacoin Blockchain Explorer (xmrblocks)
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${BUILD_DIR}
ExecStart=${BINARY_INSTALL} \\
    --bc-path=${BC_PATH} \\
    --daemon-url=${DAEMON_URL} \\
    --port=${EXPLORER_PORT} \\
    --enable-json-api \\
    --enable-autorefresh-option \\
    --no-blocks-on-index=10 \\
    --mempool-refresh-time=5
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=xmrblocks

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

sleep 2
if systemctl is-active --quiet "$SERVICE_NAME"; then
    info "    Servizio $SERVICE_NAME avviato e abilitato all'avvio."
else
    error "Servizio non partito. Controlla: journalctl -u $SERVICE_NAME -n 50"
fi

# -------------------------------------------------------
# 6. Configurazione Apache2
# -------------------------------------------------------
info "[6/7] Configurazione Apache2 per $DOMAIN..."

a2enmod proxy proxy_http > /dev/null 2>&1

cat > /etc/apache2/sites-available/${DOMAIN}.conf << EOF
<VirtualHost *:80>
    ServerName ${DOMAIN}

    ProxyPreserveHost On
    ProxyPass        / http://127.0.0.1:${EXPLORER_PORT}/
    ProxyPassReverse / http://127.0.0.1:${EXPLORER_PORT}/

    ErrorLog  \${APACHE_LOG_DIR}/explorer_error.log
    CustomLog \${APACHE_LOG_DIR}/explorer_access.log combined
</VirtualHost>
EOF

# Disabilita eventuale configurazione precedente sulla stessa porta
a2ensite "${DOMAIN}.conf" > /dev/null 2>&1
apache2ctl configtest 2>&1 | grep -v "^$" || true
systemctl reload apache2

info "    Apache2 configurato e ricaricato."

# -------------------------------------------------------
# 7. HTTPS con Let's Encrypt
# -------------------------------------------------------
info "[7/7] Configurazione HTTPS con Let's Encrypt..."

apt-get install -y certbot python3-certbot-apache > /dev/null 2>&1

# verifica base Apache
systemctl reload apache2

# esegui certificato SSL
certbot --apache -d "$DOMAIN" --non-interactive --agree-tos -m admin@$DOMAIN --redirect || {
    warn "Certbot fallito. Controlla DNS o porta 80 aperta."
}

info "    HTTPS configurato (se DNS corretto)."
# -------------------------------------------------------
# 7. Riepilogo finale
# -------------------------------------------------------
echo ""
echo "======================================================"
echo -e "${GREEN}  Installazione completata con successo!${NC}"
echo "======================================================"
echo ""
echo "  Binario     : $BINARY_INSTALL"
echo "  Porta       : $EXPLORER_PORT"
echo "  Dominio     : http://$DOMAIN"
echo "  Blockchain  : $BC_PATH"
echo "  Daemon RPC  : $DAEMON_URL"
echo ""
echo "  Comandi utili:"
echo "    systemctl status  $SERVICE_NAME"
echo "    systemctl restart $SERVICE_NAME"
echo "    systemctl stop    $SERVICE_NAME"
echo "    journalctl -u     $SERVICE_NAME -f"
echo ""
echo "  Per HTTPS con Let's Encrypt:"
echo "    apt install certbot python3-certbot-apache"
echo "    certbot --apache -d $DOMAIN"
echo "======================================================"
