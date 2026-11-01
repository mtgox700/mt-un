#!/usr/bin/env bash
# uniion — installation d'un VPS de production (Ubuntu 24.04 LTS, 4 vCPU / 16 Go / 160 Go NVMe).
# À lancer en root, une seule fois, sur une machine neuve :  bash install-vps.sh
# Prérequis : DNS app.<domaine> et api.<domaine> pointant vers le VPS ; clé SSH déjà déposée.
set -euo pipefail

read -rp "Domaine (ex. uniion.fr) : " DOMAINE
read -rp "E-mail technique (certificats, alertes) : " ACME_EMAIL
read -rp "Utilisateur d'exploitation [deploy] : " DEPLOY; DEPLOY=${DEPLOY:-deploy}

echo "== 1. Système et durcissement"
apt-get update && apt-get -y full-upgrade
apt-get -y install ca-certificates curl git ufw fail2ban unattended-upgrades jq openssl restic debian-keyring debian-archive-keyring apt-transport-https
dpkg-reconfigure -f noninteractive unattended-upgrades
id "$DEPLOY" &>/dev/null || { adduser --disabled-password --gecos "" "$DEPLOY"; usermod -aG sudo "$DEPLOY"; }
mkdir -p /home/$DEPLOY/.ssh && cp -n /root/.ssh/authorized_keys /home/$DEPLOY/.ssh/ && chown -R $DEPLOY: /home/$DEPLOY/.ssh
sed -i -E 's/^#?PermitRootLogin.*/PermitRootLogin no/; s/^#?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh
ufw default deny incoming && ufw default allow outgoing
ufw allow 22/tcp && ufw allow 80/tcp && ufw allow 443/tcp && ufw --force enable
systemctl enable --now fail2ban

echo "== 2. Docker"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list
apt-get update && apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
usermod -aG docker "$DEPLOY"
# ATTENTION : Docker contourne ufw pour les ports publiés. Tous les ports Supabase sont liés à
# 127.0.0.1 par docker-compose.override.yml ; ce garde-fou bloque le reste.
cat > /etc/docker/daemon.json <<'EOF'
{ "ip": "127.0.0.1", "log-driver": "json-file", "log-opts": { "max-size": "20m", "max-file": "5" } }
EOF
systemctl restart docker

echo "== 3. Supabase auto-hébergé"
mkdir -p /srv/uniion && cd /srv/uniion
git clone --depth 1 https://github.com/supabase/supabase supabase-src
cp -r supabase-src/docker ./supabase && rm -rf supabase-src
cp "$(dirname "$0")/docker-compose.override.yml" ./supabase/
cp "$(dirname "$0")/.env.example" ./supabase/.env
# Routeur des Edge Functions fourni par Supabase ; nos fonctions sont déployées à côté par la CI.
mkdir -p /srv/uniion/functions && cp -r ./supabase/volumes/functions/main /srv/uniion/functions/

b64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '='; }
JWT_SECRET=$(openssl rand -hex 32)
jwt() { local h p s now; now=$(date +%s)
  h=$(printf '{"alg":"HS256","typ":"JWT"}' | b64url)
  p=$(printf '{"role":"%s","iss":"supabase","iat":%d,"exp":%d}' "$1" "$now" $((now + 5*365*86400)) | b64url)
  s=$(printf '%s.%s' "$h" "$p" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | b64url)
  echo "$h.$p.$s"; }
set_env() { sed -i "s|^$1=.*|$1=$2|" supabase/.env; }
set_env DOMAINE "$DOMAINE"
set_env SITE_URL "https://app.$DOMAINE"
set_env API_EXTERNAL_URL "https://api.$DOMAINE"
set_env SUPABASE_PUBLIC_URL "https://api.$DOMAINE"
set_env POSTGRES_PASSWORD "$(openssl rand -hex 24)"
set_env JWT_SECRET "$JWT_SECRET"
set_env ANON_KEY "$(jwt anon)"
set_env SERVICE_ROLE_KEY "$(jwt service_role)"
set_env DASHBOARD_PASSWORD "$(openssl rand -hex 16)"
set_env SECRET_KEY_BASE "$(openssl rand -hex 32)"
set_env VAULT_ENC_KEY "$(openssl rand -hex 16)"
set_env LOGFLARE_PUBLIC_ACCESS_TOKEN "$(openssl rand -hex 24)"
set_env LOGFLARE_PRIVATE_ACCESS_TOKEN "$(openssl rand -hex 24)"
set_env POOLER_TENANT_ID "uniion"
set_env COFFRE_CLE_MAITRE "$(openssl rand -base64 32)"
set_env SANTE_JETON "$(openssl rand -hex 24)"
set_env FILE_JETON "$(openssl rand -hex 24)"
set_env OUVERTURE_JETON "$(openssl rand -hex 32)"
set_env ACME_EMAIL "$ACME_EMAIL"
chmod 600 supabase/.env
echo "!! Copiez supabase/.env dans le coffre de mots de passe de l'équipe (COFFRE_CLE_MAITRE : sa perte rend les notes et messages illisibles)."

echo "== 4. Caddy (TLS automatique, en-têtes de sécurité)"
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list
apt-get update && apt-get -y install caddy
cp "$(dirname "$0")/Caddyfile" /etc/caddy/Caddyfile
mkdir -p /etc/systemd/system/caddy.service.d
printf '[Service]\nEnvironment=DOMAINE=%s\nEnvironment=ACME_EMAIL=%s\n' "$DOMAINE" "$ACME_EMAIL" > /etc/systemd/system/caddy.service.d/env.conf
mkdir -p /srv/uniion/front && chown -R $DEPLOY: /srv/uniion
systemctl daemon-reload && systemctl restart caddy

echo "== 5. Démarrage"
cd /srv/uniion/supabase && docker compose pull && docker compose up -d
until docker exec supabase-db pg_isready -U postgres &>/dev/null; do sleep 3; done
source .env
# Secrets lus par pg_cron pour déclencher la file de tâches (migration 8).
docker exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 <<SQL
select vault.create_secret('http://kong:8000/functions/v1/file-taches', 'file_url');
select vault.create_secret('$FILE_JETON', 'file_jeton');
select vault.create_secret('$ANON_KEY', 'anon_key');
SQL
echo "== 6. Sauvegardes : renseigner RESTIC_*, HOTE_SAUVEGARDE, KUMA_PUSH_* dans /srv/uniion/supabase/.env puis :"
echo "   cp $(dirname "$0")/{backup,restore-test,disque}.sh /srv/uniion/ && chmod +x /srv/uniion/*.sh && crontab -u $DEPLOY $(dirname "$0")/crontab"
echo "Terminé. Studio : ssh -L 8000:127.0.0.1:8000 $DEPLOY@<vps> puis http://localhost:8000 (jamais exposé publiquement)."
