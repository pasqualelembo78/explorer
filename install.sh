#!/bin/bash

# 1. CLONA IL REPOSITORY
git clone https://github.com/pasqualelembo78/explorer.git /opt/mevaexplorer || {
    echo "Errore nel clonare il repository"; exit 1;
}

cd /opt/mevaexplorer || {
    echo "Directory non trovata"; exit 1;
}

# 2. CREA AMBIENTE VIRTUALE PYTHON
apt update && apt install -y python3 python3-venv python3-pip apache2

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

# 5. ABILITA MODULI NECESSARI APACHE
a2enmod proxy proxy_http rewrite headers

# 6. CREA VIRTUALHOST PER MEVACOIN.COM
cat > /etc/apache2/sites-available/mevacoin.conf <<EOF
<VirtualHost *:80>
    ServerName mevacoin.com
    ServerAlias www.mevacoin.com

    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:5000/
    ProxyPassReverse / http://127.0.0.1:5000/

    ErrorLog \${APACHE_LOG_DIR}/mevacoin-error.log
    CustomLog \${APACHE_LOG_DIR}/mevacoin-access.log combined

    RewriteEngine on
    RewriteCond %{SERVER_NAME} =www.mevacoin.com [OR]
    RewriteCond %{SERVER_NAME} =mevacoin.com
    RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]
</VirtualHost>
EOF

# 7. ABILITA IL SITO
a2ensite mevacoin.conf
systemctl reload apache2

echo "✅ MevaCoin Explorer installato"
echo "🌐 Accessibile su: http://mevacoin.com"
