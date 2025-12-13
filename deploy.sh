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

# Criar diretórios
mkdir -p $INFRA_DIR/{nginx/conf.d,certbot/conf,certbot/www,init-scripts}
mkdir -p $WEBSITE_DIR
mkdir -p $PERSONAL_DIR/{backend,web}

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
    print_warning "Criando .env da infraestrutura com senhas geradas..."
    
    POSTGRES_PASSWORD=$(generate_password)
    REDIS_PASSWORD=$(generate_password)
    JWT_SECRET=$(generate_password)
    JWT_REFRESH_SECRET=$(generate_password)
    
    cat > "$INFRA_DIR/.env" << EOF
# ===========================================
# Infinity IT Solutions - Variáveis de Ambiente
# ===========================================
# GERADO AUTOMATICAMENTE - Guarde essas senhas!

# PostgreSQL
POSTGRES_USER=personal_trainer
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=personal_trainer_db

# Redis
REDIS_PASSWORD=$REDIS_PASSWORD

# JWT
JWT_SECRET=$JWT_SECRET
JWT_REFRESH_SECRET=$JWT_REFRESH_SECRET

# Website Path
WEBSITE_PATH=../website
EOF
    
    print_success ".env da infraestrutura criado"
    print_warning "IMPORTANTE: Guarde as senhas do arquivo $INFRA_DIR/.env"
else
    # Carregar variáveis existentes
    source "$INFRA_DIR/.env"
    print_success ".env da infraestrutura já existe"
fi

# Carregar variáveis do .env
source "$INFRA_DIR/.env"

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

print_success "Repositórios atualizados"

# ===========================================
# STEP 4: Start infrastructure
# ===========================================
print_step "Iniciando infraestrutura (Postgres, Redis)..."
cd $INFRA_DIR

docker compose up -d postgres redis
print_success "Postgres e Redis iniciados (rede criada automaticamente)"

# Wait for database
print_step "Aguardando banco de dados..."
sleep 10

# ===========================================
# STEP 5: Build and start backend (Personal Trainer)
# ===========================================
print_step "Construindo e iniciando backend Personal Trainer..."
cd $PERSONAL_DIR/backend

# Criar .env do backend se não existir
if [ ! -f ".env" ]; then
    print_warning "Criando .env do backend..."
    
    cat > ".env" << EOF
# ===========================================
# Personal Trainer Backend - Variáveis de Ambiente
# ===========================================
# GERADO AUTOMATICAMENTE

NODE_ENV=production
PORT=3000

# Database
DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}?schema=public"

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
fi

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
# STEP 7: Start Nginx (Reverse Proxy)
# ===========================================
print_step "Iniciando Nginx (Reverse Proxy)..."
cd $INFRA_DIR
docker compose up -d nginx

print_success "Nginx iniciado"

# ===========================================
# STEP 8: Start Infinity Website (Site Institucional)
# ===========================================
print_step "Construindo e iniciando site institucional..."
cd $INFRA_DIR
docker compose up -d --build infinity-website

print_success "Site institucional iniciado (www.infinityitsolutions.com.br)"

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
echo ""
echo "Arquivos de configuração:"
echo "  - Infraestrutura: $INFRA_DIR/.env"
echo "  - Backend: $PERSONAL_DIR/backend/.env"
echo "  - Frontend: $PERSONAL_DIR/web/.env"
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
