#!/bin/bash

# ===========================================
# Script de Deploy - Infinity IT Solutions
# ===========================================
# Infraestrutura completa incluindo:
# - Infra (Nginx, PostgreSQL, Redis, Certbot)
# - Site institucional (www.infinityitsolutions.com.br)
# - Personal Trainer App (personalweb/personalapi)
# - Evolly (evolly.infinityitsolutions.com.br)
# - Evolly Clients (sites de clientes)
# ===========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# ===========================================
# STEP 1: Install Docker if not present
# ===========================================
print_step "Verificando Docker..."
if ! command -v docker &> /dev/null; then
    print_warning "Docker não encontrado. Instalando..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    print_success "Docker instalado"
    print_warning "IMPORTANTE: Faça logout e login para usar Docker sem sudo!"
else
    print_success "Docker já instalado"
fi

# Verificar se usuário está no grupo docker
if ! groups | grep -q docker; then
    print_warning "Adicionando usuário ao grupo docker..."
    sudo usermod -aG docker $USER
    print_warning "IMPORTANTE: Faça logout e login para aplicar!"
fi

# Install Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_warning "Docker Compose não encontrado. Instalando..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_success "Docker Compose instalado"
else
    print_success "Docker Compose já instalado"
fi

# ===========================================
# STEP 2: Create directories
# ===========================================
print_step "Criando estrutura de diretórios..."

# Diretório raiz baseado na localização do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Subdiretórios (todos no mesmo nível)
INFRA_DIR="$SCRIPT_DIR"
WEBSITE_DIR="$ROOT_DIR/web_infinitysolutions"
PERSONAL_BACKEND_DIR="$ROOT_DIR/personal_trainer_backend"
PERSONAL_WEB_DIR="$ROOT_DIR/personal_trainer_web"
EVOLLY_DIR="$ROOT_DIR/evolly"
EVOLLY_CLIENTS_DIR="$ROOT_DIR/evolly-clients"

# Criar diretórios de infra
mkdir -p $INFRA_DIR/{nginx/conf.d,nginx/sites,certbot/conf,certbot/www,init-scripts}

print_success "Diretórios criados em $ROOT_DIR"

# ===========================================
# Função para gerar senha aleatória
# ===========================================
generate_password() {
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32
}

# ===========================================
# STEP 2.5: Create .env files if not exist
# ===========================================
print_step "Verificando arquivos de configuração..."

# Gerar senhas se não existirem
if [ ! -f "$INFRA_DIR/.env" ]; then
    print_warning "Criando .env da infraestrutura..."

    cat > "$INFRA_DIR/.env" << EOF
# ===========================================
# Infinity IT Solutions - Variáveis de Ambiente
# ===========================================

# PostgreSQL (usuário admin)
POSTGRES_USER=infinityitsolutions
POSTGRES_PASSWORD=Mga@2025
POSTGRES_DB=infinitysolutions_db

# Personal Trainer Database
PERSONAL_TRAINER_DB=personal_trainer_db
PERSONAL_TRAINER_USER=personal_trainer
PERSONAL_TRAINER_PASSWORD=Mga@2025

# Evolly Database
EVOLLY_DB=evolly_db
EVOLLY_USER=evolly
EVOLLY_PASSWORD=Mga@2025

# Redis
REDIS_PASSWORD=Mga@2025

# JWT (geradas automaticamente)
JWT_SECRET=$(generate_password)
JWT_REFRESH_SECRET=$(generate_password)
EVOLLY_JWT_SECRET=$(generate_password)
EOF

    print_success ".env da infraestrutura criado"
else
    print_success ".env da infraestrutura já existe"
fi

# Carregar variáveis do .env e exportar
set -a
source "$INFRA_DIR/.env"
set +a

print_success "Variáveis carregadas: POSTGRES_USER=$POSTGRES_USER"

# ===========================================
# STEP 3: Clone repositories (usando SSH)
# ===========================================
print_step "Clonando repositórios..."

# Site Institucional
if [ -d "$WEBSITE_DIR/.git" ]; then
    cd $WEBSITE_DIR && git pull
else
    cd $ROOT_DIR
    git clone git@github.com:douglassleite/web_infinitysolutions.git web_infinitysolutions
fi
print_success "Site institucional atualizado"

# Personal Trainer Backend
if [ -d "$PERSONAL_BACKEND_DIR/.git" ]; then
    cd $PERSONAL_BACKEND_DIR && git pull
else
    cd $ROOT_DIR
    git clone git@github.com:douglassleite/personal_trainer_backend.git personal_trainer_backend
fi
print_success "Backend Personal Trainer atualizado"

# Personal Trainer Web
if [ -d "$PERSONAL_WEB_DIR/.git" ]; then
    cd $PERSONAL_WEB_DIR && git pull
else
    cd $ROOT_DIR
    git clone git@github.com:douglassleite/personal_trainer_web.git personal_trainer_web
fi
print_success "Frontend Personal Trainer atualizado"

# Evolly
if [ -d "$EVOLLY_DIR/.git" ]; then
    cd $EVOLLY_DIR && git pull
else
    cd $ROOT_DIR
    git clone git@github.com:douglassleite/evolly.git evolly
fi
print_success "Evolly atualizado"

# Evolly Clients
if [ -d "$EVOLLY_CLIENTS_DIR/.git" ]; then
    cd $EVOLLY_CLIENTS_DIR && git pull
else
    cd $ROOT_DIR
    git clone git@github.com:douglassleite/evolly-clients.git evolly-clients
fi
print_success "Evolly Clients atualizado"

# Configurar .env do evolly-clients
if [ ! -f "$EVOLLY_CLIENTS_DIR/.env" ]; then
    cp "$EVOLLY_CLIENTS_DIR/.env.example" "$EVOLLY_CLIENTS_DIR/.env"
    print_success ".env do evolly-clients criado"
fi

print_success "Repositórios atualizados"

# ===========================================
# STEP 4: Create networks and Start infrastructure
# ===========================================
print_step "Criando redes Docker..."

# Criar rede principal se não existir
if ! docker network inspect infinityitsolutions-network &> /dev/null; then
    docker network create infinityitsolutions-network
    print_success "Rede infinityitsolutions-network criada"
else
    print_success "Rede infinityitsolutions-network já existe"
fi

# Criar rede para compatibilidade com backend
if ! docker network inspect personal_trainer_infrastructure_app-network &> /dev/null; then
    docker network create personal_trainer_infrastructure_app-network
    print_success "Rede backend criada"
else
    print_success "Rede backend já existe"
fi

# Criar rede para compatibilidade com frontend
if ! docker network inspect personal-trainer-network &> /dev/null; then
    docker network create personal-trainer-network
    print_success "Rede frontend criada"
else
    print_success "Rede frontend já existe"
fi

print_step "Iniciando infraestrutura (Postgres, Redis)..."
cd $INFRA_DIR

docker compose up -d postgres redis
print_success "Postgres e Redis iniciados"

# Wait for database
print_step "Aguardando banco de dados..."
sleep 10

# ===========================================
# STEP 5: Configure databases
# ===========================================
print_step "Configurando bancos de dados..."

# Personal Trainer DB
docker exec infinity-postgres-db psql -U infinityitsolutions -d postgres -tc "SELECT 1 FROM pg_roles WHERE rolname='personal_trainer'" | grep -q 1 || \
docker exec infinity-postgres-db psql -U infinityitsolutions -d postgres -c "CREATE ROLE personal_trainer WITH LOGIN PASSWORD '${PERSONAL_TRAINER_PASSWORD:-Mga@2025}';"

docker exec infinity-postgres-db psql -U infinityitsolutions -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='personal_trainer_db'" | grep -q 1 || \
docker exec infinity-postgres-db psql -U infinityitsolutions -d postgres -c "CREATE DATABASE personal_trainer_db OWNER personal_trainer;"

print_success "Banco personal_trainer_db configurado"

# Evolly DB
docker exec infinity-postgres-db psql -U infinityitsolutions -d postgres -tc "SELECT 1 FROM pg_roles WHERE rolname='evolly'" | grep -q 1 || \
docker exec infinity-postgres-db psql -U infinityitsolutions -d postgres -c "CREATE ROLE evolly WITH LOGIN PASSWORD '${EVOLLY_PASSWORD:-Mga@2025}';"

docker exec infinity-postgres-db psql -U infinityitsolutions -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='evolly_db'" | grep -q 1 || \
docker exec infinity-postgres-db psql -U infinityitsolutions -d postgres -c "CREATE DATABASE evolly_db OWNER evolly;"

# Permissões Evolly
docker exec infinity-postgres-db psql -U infinityitsolutions -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE evolly_db TO evolly;" 2>/dev/null || true
docker exec infinity-postgres-db psql -U infinityitsolutions -d evolly_db -c "
GRANT ALL ON SCHEMA public TO evolly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO evolly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO evolly;
" 2>/dev/null || true

print_success "Banco evolly_db configurado"

# ===========================================
# STEP 6: Build and start Personal Trainer Backend
# ===========================================
print_step "Construindo e iniciando backend Personal Trainer..."
cd $PERSONAL_BACKEND_DIR

# Criar/Atualizar .env do backend
PT_USER="${PERSONAL_TRAINER_USER:-personal_trainer}"
PT_PASS="${PERSONAL_TRAINER_PASSWORD:-Mga@2025}"
PT_DB="${PERSONAL_TRAINER_DB:-personal_trainer_db}"

cat > ".env" << EOF
# Personal Trainer Backend
NODE_ENV=production
PORT=3000
DATABASE_URL="postgresql://${PT_USER}:${PT_PASS}@postgres-db:5432/${PT_DB}?schema=public"
REDIS_URL="redis://:${REDIS_PASSWORD}@redis:6379"
JWT_SECRET=${JWT_SECRET}
JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d
CORS_ORIGIN=https://personalweb.infinityitsolutions.com.br
EOF

docker compose -f docker-compose.prod.yml build
docker compose -f docker-compose.prod.yml run --rm backend npx prisma migrate deploy || true
docker compose -f docker-compose.prod.yml up -d

print_success "Backend Personal Trainer iniciado"

# ===========================================
# STEP 7: Build and start Personal Trainer Frontend
# ===========================================
print_step "Construindo e iniciando frontend Personal Trainer..."
cd $PERSONAL_WEB_DIR

if [ ! -f ".env" ]; then
    cat > ".env" << EOF
VITE_API_URL=https://personalapi.infinityitsolutions.com.br
VITE_APP_NAME=Personal Trainer
EOF
fi

docker compose -f docker-compose.prod.yml build
docker compose -f docker-compose.prod.yml up -d

print_success "Frontend Personal Trainer iniciado"

# ===========================================
# STEP 8: Build and start Website
# ===========================================
print_step "Construindo e iniciando site institucional..."
cd $WEBSITE_DIR

docker compose up -d --build

print_success "Site institucional iniciado"

# ===========================================
# STEP 9: Build and start Evolly
# ===========================================
print_step "Construindo e iniciando Evolly..."
cd $EVOLLY_DIR

# Criar .env do Evolly se não existir
if [ ! -f ".env" ]; then
    cat > ".env" << EOF
NODE_ENV=production
PORT=8004
DB_HOST=postgres
DB_PORT=5432
DB_NAME=evolly_db
DB_USER=evolly
DB_PASSWORD=${EVOLLY_PASSWORD:-Mga@2025}
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD:-Mga@2025}
JWT_SECRET=${EVOLLY_JWT_SECRET}
JWT_EXPIRES_IN=7d
EOF
fi

docker compose up -d --build

# Aguardar container iniciar
sleep 5

# Migrations
docker exec evolly npm run migrate || print_warning "Migration já executada ou falhou"

# Seed se necessário
docker exec evolly sh -c 'node -e "
const { Pool } = require(\"pg\");
const pool = new Pool();
pool.query(\"SELECT COUNT(*) FROM users\").then(r => {
  if (parseInt(r.rows[0].count) === 0) {
    console.log(\"Banco vazio, executando seed...\");
    process.exit(0);
  } else {
    console.log(\"Dados já existem, pulando seed.\");
    process.exit(1);
  }
}).catch(() => process.exit(0));
"' && docker exec evolly npm run seed || print_success "Seed já executado"

print_success "Evolly iniciado"

# ===========================================
# STEP 10: Start Nginx
# ===========================================
print_step "Configurando Nginx..."
cd $INFRA_DIR

# Verificar se certificados SSL existem
SSL_CERT_DIR="$INFRA_DIR/certbot/conf/live/www.infinityitsolutions.com.br"

if sudo test -d "$SSL_CERT_DIR" && sudo test -f "$SSL_CERT_DIR/fullchain.pem"; then
    print_success "Certificados SSL encontrados"
    if [ -f "$INFRA_DIR/nginx/conf.d/default.conf.ssl" ]; then
        cp "$INFRA_DIR/nginx/conf.d/default.conf.ssl" "$INFRA_DIR/nginx/conf.d/default.conf"
        print_success "Configuração HTTPS aplicada"
    fi
else
    print_warning "Certificados SSL não encontrados - usando configuração HTTP"
    if [ -f "$INFRA_DIR/nginx/conf.d/default.conf.nossl" ]; then
        cp "$INFRA_DIR/nginx/conf.d/default.conf.nossl" "$INFRA_DIR/nginx/conf.d/default.conf"
        print_success "Configuração HTTP aplicada"
    fi
fi

# Iniciar nginx
docker compose up -d nginx

sleep 3

if docker ps | grep -q nginx-proxy; then
    print_success "Nginx iniciado"
else
    print_error "Nginx não iniciou. Verifique: docker logs nginx-proxy"
fi

# Se não tem SSL, tentar gerar
if ! sudo test -f "$SSL_CERT_DIR/fullchain.pem"; then
    print_step "Gerando certificados SSL..."

    docker compose run --rm certbot certonly --webroot \
        -w /var/www/certbot \
        -d www.infinityitsolutions.com.br \
        -d infinityitsolutions.com.br \
        --email contato@infinityitsolutions.com.br \
        --agree-tos --no-eff-email --non-interactive || print_warning "Falha SSL site principal"

    docker compose run --rm certbot certonly --webroot \
        -w /var/www/certbot \
        -d personalweb.infinityitsolutions.com.br \
        --email contato@infinityitsolutions.com.br \
        --agree-tos --no-eff-email --non-interactive || print_warning "Falha SSL personalweb"

    docker compose run --rm certbot certonly --webroot \
        -w /var/www/certbot \
        -d personalapi.infinityitsolutions.com.br \
        --email contato@infinityitsolutions.com.br \
        --agree-tos --no-eff-email --non-interactive || print_warning "Falha SSL personalapi"

    docker compose run --rm certbot certonly --webroot \
        -w /var/www/certbot \
        -d evolly.infinityitsolutions.com.br \
        --email contato@infinityitsolutions.com.br \
        --agree-tos --no-eff-email --non-interactive || print_warning "Falha SSL evolly"

    # Se certificados foram gerados, aplicar HTTPS
    if sudo test -f "$SSL_CERT_DIR/fullchain.pem"; then
        print_success "Certificados SSL gerados!"
        if [ -f "$INFRA_DIR/nginx/conf.d/default.conf.ssl" ]; then
            cp "$INFRA_DIR/nginx/conf.d/default.conf.ssl" "$INFRA_DIR/nginx/conf.d/default.conf"
            docker compose restart nginx
            print_success "Configuração HTTPS aplicada"
        fi
    else
        print_warning "Certificados não gerados. Configure DNS e rode: ./manage.sh ssl-init"
    fi
fi

# ===========================================
# DONE
# ===========================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Deploy concluído com sucesso!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "URLs:"
echo "  - Site Principal: https://www.infinityitsolutions.com.br"
echo "  - Personal Web:   https://personalweb.infinityitsolutions.com.br"
echo "  - Personal API:   https://personalapi.infinityitsolutions.com.br"
echo "  - Evolly:         https://evolly.infinityitsolutions.com.br"
echo ""
echo "Projetos:"
echo "  - Infra:          $INFRA_DIR"
echo "  - Website:        $WEBSITE_DIR"
echo "  - Personal API:   $PERSONAL_BACKEND_DIR"
echo "  - Personal Web:   $PERSONAL_WEB_DIR"
echo "  - Evolly:         $EVOLLY_DIR"
echo "  - Evolly Clients: $EVOLLY_CLIENTS_DIR"
echo ""
echo "Para adicionar clientes Evolly:"
echo "  cd $EVOLLY_CLIENTS_DIR"
echo "  ./deploy-client.sh <nome> subdomain <subdominio> <modelo>"
echo ""
echo "Comandos úteis:"
echo "  - Ver logs:    ./manage.sh logs"
echo "  - Status:      ./manage.sh status"
echo "  - Gerar SSL:   ./manage.sh ssl-init"
echo ""
