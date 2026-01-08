#!/bin/bash

# ===========================================
# Script de Deploy para Sites de Casamento
# ===========================================
#
# Uso: ./deploy-site.sh <nome-do-site> <caminho-modelo>
#
# Exemplo:
#   ./deploy-site.sh vanessaemarlo /path/to/evolly/src/custom-sites/vanessaemarlo/modelo-9
#
# O que este script faz:
#   1. Cria a estrutura de pastas para o site
#   2. Copia os arquivos do modelo
#   3. Gera Dockerfile e docker-compose.yml
#   4. Faz build e sobe o container
#
# Após rodar este script, você ainda precisa:
#   1. Configurar o DNS do domínio
#   2. Adicionar configuração no nginx principal
#   3. Gerar certificado SSL com certbot

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Diretório base
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parâmetros
SITE_NAME=$1
MODEL_PATH=$2

# Validação de parâmetros
if [ -z "$SITE_NAME" ] || [ -z "$MODEL_PATH" ]; then
    echo -e "${RED}Erro: Parâmetros obrigatórios faltando${NC}"
    echo ""
    echo "Uso: $0 <nome-do-site> <caminho-modelo>"
    echo ""
    echo "Exemplo:"
    echo "  $0 vanessaemarlo /path/to/modelo-9"
    echo ""
    exit 1
fi

# Verificar se o modelo existe
if [ ! -d "$MODEL_PATH" ]; then
    echo -e "${RED}Erro: Caminho do modelo não existe: $MODEL_PATH${NC}"
    exit 1
fi

# Verificar se index.html existe no modelo
if [ ! -f "$MODEL_PATH/index.html" ]; then
    echo -e "${RED}Erro: index.html não encontrado em $MODEL_PATH${NC}"
    exit 1
fi

SITE_DIR="$SCRIPT_DIR/$SITE_NAME"
CONTAINER_NAME="evolly-$SITE_NAME"

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Deploy do Site: $SITE_NAME${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

# Criar diretório do site se não existir
if [ -d "$SITE_DIR" ]; then
    echo -e "${YELLOW}Diretório já existe. Atualizando arquivos...${NC}"
else
    echo -e "${GREEN}Criando diretório do site...${NC}"
    mkdir -p "$SITE_DIR"
fi

# Criar subdiretório site
mkdir -p "$SITE_DIR/site"

# Copiar arquivos do modelo
echo -e "${GREEN}Copiando arquivos do modelo...${NC}"
cp -r "$MODEL_PATH"/* "$SITE_DIR/site/"

# Criar Dockerfile se não existir
if [ ! -f "$SITE_DIR/Dockerfile" ]; then
    echo -e "${GREEN}Criando Dockerfile...${NC}"
    cat > "$SITE_DIR/Dockerfile" << 'EOF'
FROM nginx:alpine

# Copiar configuração do nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Copiar arquivos do site
COPY site/ /usr/share/nginx/html/

# Expor porta
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1
EOF
fi

# Criar nginx.conf se não existir
if [ ! -f "$SITE_DIR/nginx.conf" ]; then
    echo -e "${GREEN}Criando nginx.conf...${NC}"
    cat > "$SITE_DIR/nginx.conf" << 'EOF'
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript
               application/xml application/xml+rss text/javascript image/svg+xml;

    # Resolver para Docker DNS
    resolver 127.0.0.11 valid=30s ipv6=off;

    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;

        # Health check
        location /health {
            access_log off;
            return 200 '{"status":"ok"}';
            add_header Content-Type application/json;
        }

        # Proxy para API do backend (Evolly)
        location /api/ {
            set $backend http://evolly:8004;
            proxy_pass $backend;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 60s;
            proxy_read_timeout 60s;
        }

        # Arquivos estáticos com cache
        location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 30d;
            add_header Cache-Control "public, immutable";
            try_files $uri =404;
        }

        # HTML sem cache
        location ~* \.html$ {
            expires -1;
            add_header Cache-Control "no-store, no-cache, must-revalidate";
            try_files $uri =404;
        }

        # SPA fallback
        location / {
            try_files $uri $uri/ $uri.html /index.html;
        }

        # Bloquear arquivos sensíveis
        location ~ /\. {
            deny all;
        }
    }
}
EOF
fi

# Criar docker-compose.yml
echo -e "${GREEN}Criando docker-compose.yml...${NC}"
cat > "$SITE_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  $SITE_NAME-site:
    build: .
    container_name: $CONTAINER_NAME
    restart: unless-stopped
    networks:
      - infinityitsolutions-network
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

networks:
  infinityitsolutions-network:
    name: infinityitsolutions-network
    external: true
EOF

# Fazer build e subir container
echo -e "${GREEN}Fazendo build do container...${NC}"
cd "$SITE_DIR"
docker compose build

echo -e "${GREEN}Subindo container...${NC}"
docker compose up -d

# Verificar se container está rodando
sleep 3
if docker ps | grep -q "$CONTAINER_NAME"; then
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}Deploy concluído com sucesso!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo -e "Container: ${YELLOW}$CONTAINER_NAME${NC}"
    echo -e "Status: ${GREEN}Rodando${NC}"
    echo ""
    echo -e "${YELLOW}Próximos passos:${NC}"
    echo "1. Configure o DNS do domínio para apontar para o servidor"
    echo "2. Adicione a configuração no nginx principal (default.conf)"
    echo "3. Gere o certificado SSL com certbot"
    echo ""
    echo "Exemplo de configuração nginx:"
    echo ""
    echo "  upstream $SITE_NAME {"
    echo "      server $CONTAINER_NAME:80;"
    echo "      keepalive 32;"
    echo "  }"
    echo ""
else
    echo -e "${RED}Erro: Container não está rodando${NC}"
    docker compose logs
    exit 1
fi
