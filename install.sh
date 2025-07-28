#!/bin/bash

# 1. CLONA IL REPOSITORY
git clone https://github.com/pasqualelembo78/explorer.git /opt/mevaexplorer || {
    echo "Errore nel clonare il repository"; exit 1;
}

cd /opt/mevaexplorer || {
    echo "Directory non trovata"; exit 1;
}

# 2. CREA AMBIENTE VIRTUALE PYTHON
apt update && apt install -y python3 python3-venv python3-pip

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt || pip install flask requests

# 3. CREA FILE SYSTEMD
cat > /etc/systemd/system/mevaexplorer.service <<EOF
[Unit]
Description=MevaCoin Explorer Flask
After=network.target

[Service]
User=root
WorkingDirectory=/opt/mevaexplorer
ExecStart=/opt/mevaexplorer/venv/bin/python app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 4. ABILITA E AVVIA IL SERVIZIO
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable mevaexplorer
systemctl start mevaexplorer

echo "✅ MevaCoin Explorer installato e avviato su http://localhost:5000"
