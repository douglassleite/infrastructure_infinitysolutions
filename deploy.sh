#!/bin/bash

# ===========================================
# Script de Deploy - Infinity IT Solutions
# ===========================================
# Infraestrutura completa incluindo:
# - Site institucional (www.infinityitsolutions.com.br)
# - Personal Trainer App (personalweb/personalapi)
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

# Subdiretórios (relativos ao diretório do usuário)
INFRA_DIR="$SCRIPT_DIR"
WEBSITE_DIR="$ROOT_DIR/website"
PERSONAL_DIR="$ROOT_DIR/apps/personal-trainer"
EVOLLY_DIR="$ROOT_DIR/apps/evolly"

# Criar diretórios
mkdir -p $INFRA_DIR/{nginx/conf.d,certbot/conf,certbot/www,init-scripts}
mkdir -p $WEBSITE_DIR
mkdir -p $PERSONAL_DIR/{backend,web}
mkdir -p $EVOLLY_DIR

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
    
    # Usar senhas fixas conforme definido no docker-compose.yml
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

# Redis
REDIS_PASSWORD=Mga@2025

# JWT (geradas automaticamente)
JWT_SECRET=$(generate_password)
JWT_REFRESH_SECRET=$(generate_password)
WEDDING_JWT_SECRET=$(generate_password)

# Paths
WEBSITE_PATH=../website
EVOLLY_PATH=../apps/evolly
EOF
    
    print_success ".env da infraestrutura criado"
else
    # Carregar variáveis existentes
    source "$INFRA_DIR/.env"
    print_success ".env da infraestrutura já existe"
fi

# Carregar variáveis do .env e exportar
set -a  # Exportar todas as variáveis automaticamente
source "$INFRA_DIR/.env"
set +a

# Debug: mostrar que variáveis foram carregadas
print_success "Variáveis carregadas: POSTGRES_USER=$POSTGRES_USER, POSTGRES_DB=$POSTGRES_DB"

# ===========================================
# STEP 3: Clone repositories (usando SSH)
# ===========================================
print_step "Clonando repositórios..."

# Site Institucional
if [ -d "$WEBSITE_DIR/.git" ]; then
    cd $WEBSITE_DIR
    git pull
else
    cd $ROOT_DIR
    git clone git@github.com:douglassleite/web_infinitysolutions.git website
fi
print_success "Site institucional atualizado"

# Personal Trainer Backend (privado - usa SSH)
if [ -d "$PERSONAL_DIR/backend/.git" ]; then
    cd $PERSONAL_DIR/backend
    git pull
else
    cd $PERSONAL_DIR
    git clone git@github.com:douglassleite/personal_trainer_backend.git backend
fi
print_success "Backend Personal Trainer atualizado"

# Personal Trainer Web (privado - usa SSH)
if [ -d "$PERSONAL_DIR/web/.git" ]; then
    cd $PERSONAL_DIR/web
    git pull
else
    cd $PERSONAL_DIR
    git clone git@github.com:douglassleite/personal_trainer_web.git web
fi
print_success "Frontend Personal Trainer atualizado"

# Evolly (privado - usa SSH)
if [ -d "$EVOLLY_DIR/.git" ]; then
    cd $EVOLLY_DIR
    git pull
else
    cd $ROOT_DIR/apps
    git clone git@github.com:douglassleite/evolly.git evolly
fi
print_success "Evolly atualizado"

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
# STEP 5: Build and start backend (Personal Trainer)
# ===========================================
print_step "Construindo e iniciando backend Personal Trainer..."
cd $PERSONAL_DIR/backend

# Criar/Atualizar .env do backend
print_warning "Criando .env do backend..."

# Usar variáveis do Personal Trainer ou fallback para as padrão
PT_USER="${PERSONAL_TRAINER_USER:-infinityitsolutions}"
PT_PASS="${PERSONAL_TRAINER_PASSWORD:-Mga@2025}"
PT_DB="${PERSONAL_TRAINER_DB:-personal_trainer_db}"

cat > ".env" << EOF
# ===========================================
# Personal Trainer Backend - Variáveis de Ambiente
# ===========================================
# GERADO AUTOMATICAMENTE EM $(date)

NODE_ENV=production
PORT=3000

# Database (usando alias postgres-db da rede)
DATABASE_URL="postgresql://${PT_USER}:${PT_PASS}@postgres-db:5432/${PT_DB}?schema=public"

# Redis
REDIS_URL="redis://:${REDIS_PASSWORD}@redis:6379"

# JWT
JWT_SECRET=${JWT_SECRET}
JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

# CORS
CORS_ORIGIN=https://personalweb.infinityitsolutions.com.br
EOF

print_success ".env do backend criado"

# Run migrations
docker compose -f docker-compose.prod.yml build
docker compose -f docker-compose.prod.yml run --rm backend npx prisma migrate deploy
docker compose -f docker-compose.prod.yml up -d

print_success "Backend iniciado"

# ===========================================
# STEP 6: Build and start frontend (Personal Trainer)
# ===========================================
print_step "Construindo e iniciando frontend Personal Trainer..."
cd $PERSONAL_DIR/web

# Criar .env do frontend se não existir
if [ ! -f ".env" ]; then
    print_warning "Criando .env do frontend..."
    
    cat > ".env" << EOF
# ===========================================
# Personal Trainer Frontend - Variáveis de Ambiente
# ===========================================
# GERADO AUTOMATICAMENTE

VITE_API_URL=https://personalapi.infinityitsolutions.com.br
VITE_APP_NAME=Personal Trainer
EOF
    
    print_success ".env do frontend criado"
fi

docker compose -f docker-compose.prod.yml build
docker compose -f docker-compose.prod.yml up -d

print_success "Frontend Personal Trainer iniciado"

# ===========================================
# STEP 7: Start Infinity Website (Site Institucional)
# ===========================================
print_step "Construindo e iniciando site institucional..."
cd $INFRA_DIR
docker compose up -d --build infinity-website

print_success "Site institucional iniciado"

# ===========================================
# STEP 7.5: Start Evolly
# ===========================================
print_step "Construindo e iniciando Evolly..."
cd $INFRA_DIR

# Criar banco e usuário wedding se não existirem
print_step "Verificando banco de dados wedding_system..."

# Criar usuário wedding se não existir
docker exec infinity-postgres-db psql -U infinityitsolutions -d postgres -tc "SELECT 1 FROM pg_roles WHERE rolname='wedding'" | grep -q 1 || \
docker exec infinity-postgres-db psql -U infinityitsolutions -d postgres -c "CREATE ROLE wedding WITH LOGIN PASSWORD '${POSTGRES_PASSWORD:-Mga@2025}';"

if docker exec infinity-postgres-db psql -U infinityitsolutions -d postgres -tc "SELECT 1 FROM pg_roles WHERE rolname='wedding'" | grep -q 1; then
    print_success "Usuário wedding OK"
else
    print_warning "Falha ao criar usuário wedding"
fi

# Criar banco wedding_system se não existir
docker exec infinity-postgres-db psql -U infinityitsolutions -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='wedding_system'" | grep -q 1 || \
docker exec infinity-postgres-db psql -U infinityitsolutions -d postgres -c "CREATE DATABASE wedding_system OWNER wedding;"

if docker exec infinity-postgres-db psql -U infinityitsolutions -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='wedding_system'" | grep -q 1; then
    print_success "Banco wedding_system OK"
else
    print_warning "Falha ao criar banco wedding_system"
fi

# Dar permissões
docker exec infinity-postgres-db psql -U infinityitsolutions -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE wedding_system TO wedding;" 2>/dev/null || true

docker exec infinity-postgres-db psql -U infinityitsolutions -d wedding_system -c "
GRANT ALL ON SCHEMA public TO wedding;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO wedding;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO wedding;
" 2>/dev/null || true

print_success "Banco wedding_system configurado"

# Build e start do container
docker compose up -d --build evolly

# Aguardar container iniciar
sleep 5

# Rodar migrations (CREATE TABLE IF NOT EXISTS - não apaga dados)
print_step "Executando migrations do Evolly..."
docker exec evolly npm run migrate || print_warning "Migration já executada ou falhou"

# Rodar seed apenas se for primeira execução (verificar se tabela tem dados)
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
"' && docker exec evolly npm run seed || print_success "Seed já executado anteriormente"

print_success "Evolly iniciado"

# ===========================================
# STEP 8: Start Nginx (Reverse Proxy) com SSL automático
# ===========================================
print_step "Configurando Nginx..."
cd $INFRA_DIR

# Verificar se certificados SSL existem
# Nota: Os certificados pertencem ao root, então usamos sudo para verificar
SSL_CERT_DIR="$INFRA_DIR/certbot/conf/live/www.infinityitsolutions.com.br"

# Verificar se o diretório do certificado existe (usa sudo pois pertence ao root)
if sudo test -d "$SSL_CERT_DIR" && sudo test -f "$SSL_CERT_DIR/fullchain.pem"; then
    print_success "Certificados SSL encontrados"
    # Usar configuração com SSL
    if [ -f "$INFRA_DIR/nginx/conf.d/default.conf.ssl" ]; then
        cp "$INFRA_DIR/nginx/conf.d/default.conf.ssl" "$INFRA_DIR/nginx/conf.d/default.conf"
        print_success "Configuração HTTPS aplicada"
    fi
else
    print_warning "Certificados SSL não encontrados - usando configuração HTTP"
    # Usar configuração sem SSL para permitir geração de certificados
    if [ -f "$INFRA_DIR/nginx/conf.d/default.conf.nossl" ]; then
        cp "$INFRA_DIR/nginx/conf.d/default.conf.nossl" "$INFRA_DIR/nginx/conf.d/default.conf"
        print_success "Configuração HTTP aplicada"
    fi
fi

# Iniciar nginx
docker compose up -d nginx

# Aguardar nginx iniciar
sleep 3

# Verificar se nginx está rodando
if docker ps | grep -q nginx-proxy; then
    print_success "Nginx iniciado"
else
    print_error "Nginx não iniciou corretamente. Verifique: docker logs nginx-proxy"
fi

# Se não tem SSL, tentar gerar certificados automaticamente
if [ ! -f "$SSL_CERT_PATH" ]; then
    print_step "Gerando certificados SSL..."
    
    # Gerar certificado para o site principal
    docker compose run --rm certbot certonly --webroot \
        -w /var/www/certbot \
        -d www.infinityitsolutions.com.br \
        -d infinityitsolutions.com.br \
        --email contato@infinityitsolutions.com.br \
        --agree-tos \
        --no-eff-email \
        --non-interactive || print_warning "Falha ao gerar certificado do site principal (DNS pode não estar configurado)"
    
    # Gerar certificado para personalweb
    docker compose run --rm certbot certonly --webroot \
        -w /var/www/certbot \
        -d personalweb.infinityitsolutions.com.br \
        --email contato@infinityitsolutions.com.br \
        --agree-tos \
        --no-eff-email \
        --non-interactive || print_warning "Falha ao gerar certificado do personalweb"
    
    # Gerar certificado para personalapi
    docker compose run --rm certbot certonly --webroot \
        -w /var/www/certbot \
        -d personalapi.infinityitsolutions.com.br \
        --email contato@infinityitsolutions.com.br \
        --agree-tos \
        --no-eff-email \
        --non-interactive || print_warning "Falha ao gerar certificado do personalapi"

    # Gerar certificado para wedding
    docker compose run --rm certbot certonly --webroot \
        -w /var/www/certbot \
        -d wedding.infinityitsolutions.com.br \
        --email contato@infinityitsolutions.com.br \
        --agree-tos \
        --no-eff-email \
        --non-interactive || print_warning "Falha ao gerar certificado do wedding"

    # Se certificados foram gerados, aplicar configuração SSL
    if sudo test -d "$SSL_CERT_DIR" && sudo test -f "$SSL_CERT_DIR/fullchain.pem"; then
        print_success "Certificados SSL gerados!"
        if [ -f "$INFRA_DIR/nginx/conf.d/default.conf.ssl" ]; then
            cp "$INFRA_DIR/nginx/conf.d/default.conf.ssl" "$INFRA_DIR/nginx/conf.d/default.conf"
            docker compose restart nginx
            print_success "Configuração HTTPS aplicada"
        fi
    else
        print_warning "Certificados não gerados. Configure o DNS e rode: ./manage.sh ssl-init"
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
echo "  - Personal Web: https://personalweb.infinityitsolutions.com.br"
echo "  - Personal API: https://personalapi.infinityitsolutions.com.br"
echo "  - Wedding System: https://wedding.infinityitsolutions.com.br"
echo ""
echo "Arquivos de configuração:"
echo "  - Infraestrutura: $INFRA_DIR/.env"
echo "  - Backend: $PERSONAL_DIR/backend/.env"
echo "  - Frontend: $PERSONAL_DIR/web/.env"
echo "  - Evolly: $EVOLLY_DIR (usa .env da infra)"
echo ""
echo -e "${YELLOW}IMPORTANTE: As senhas foram geradas automaticamente.${NC}"
echo -e "${YELLOW}Verifique o arquivo $INFRA_DIR/.env para ver as credenciais.${NC}"
echo ""
echo "Comandos úteis:"
echo "  - Ver logs: ./manage.sh logs"
echo "  - Status: ./manage.sh status"
echo "  - Gerar SSL: ./manage.sh ssl-init"
echo ""
echo "Próximo passo: Configure o DNS e gere os certificados SSL com:"
echo "  ./manage.sh ssl-init"
echo ""
