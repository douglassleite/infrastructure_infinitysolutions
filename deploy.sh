#!/bin/bash

# ===========================================
# Script de Deploy - Personal Trainer
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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Execute como root: sudo ./deploy.sh"
    exit 1
fi

# ===========================================
# STEP 1: Install Docker if not present
# ===========================================
print_step "Verificando Docker..."
if ! command -v docker &> /dev/null; then
    print_warning "Docker não encontrado. Instalando..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    print_success "Docker instalado"
else
    print_success "Docker já instalado"
fi

# Install Docker Compose
if ! command -v docker-compose &> /dev/null; then
    print_warning "Docker Compose não encontrado. Instalando..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    print_success "Docker Compose instalado"
else
    print_success "Docker Compose já instalado"
fi

# ===========================================
# STEP 2: Create directories
# ===========================================
print_step "Criando estrutura de diretórios..."

BASE_DIR="/opt/personal-trainer"
mkdir -p $BASE_DIR/{infrastructure,backend,web}
mkdir -p $BASE_DIR/infrastructure/{nginx/conf.d,certbot/conf,certbot/www,init-scripts}

print_success "Diretórios criados em $BASE_DIR"

# ===========================================
# STEP 3: Clone repositories
# ===========================================
print_step "Clonando repositórios..."

cd $BASE_DIR

# Infrastructure (se ainda não existir)
if [ ! -d "$BASE_DIR/infrastructure/.git" ]; then
    # Se você tiver um repo de infrastructure, clone aqui
    print_warning "Configure manualmente os arquivos de infrastructure"
fi

# Backend
if [ -d "$BASE_DIR/backend/.git" ]; then
    cd $BASE_DIR/backend
    git pull origin main
else
    git clone https://github.com/douglassleite/personal_trainer_backend.git backend
fi

# Web
if [ -d "$BASE_DIR/web/.git" ]; then
    cd $BASE_DIR/web
    git pull origin master
else
    git clone https://github.com/douglassleite/personal_trainer_web.git web
fi

print_success "Repositórios atualizados"

# ===========================================
# STEP 4: Create network
# ===========================================
print_step "Criando rede Docker..."
docker network create app-network 2>/dev/null || true
print_success "Rede app-network configurada"

# ===========================================
# STEP 5: Start infrastructure
# ===========================================
print_step "Iniciando infraestrutura (Postgres, Redis, Nginx)..."
cd $BASE_DIR/infrastructure

if [ ! -f ".env" ]; then
    print_error "Arquivo .env não encontrado em infrastructure/"
    print_warning "Copie .env.example para .env e configure as variáveis"
    exit 1
fi

docker-compose up -d postgres redis
print_success "Postgres e Redis iniciados"

# Wait for database
print_step "Aguardando banco de dados..."
sleep 10

# ===========================================
# STEP 6: Build and start backend
# ===========================================
print_step "Construindo e iniciando backend..."
cd $BASE_DIR/backend

if [ ! -f ".env" ]; then
    print_error "Arquivo .env não encontrado em backend/"
    print_warning "Copie .env.production.example para .env e configure as variáveis"
    exit 1
fi

# Run migrations
docker-compose -f docker-compose.prod.yml build
docker-compose -f docker-compose.prod.yml run --rm backend npx prisma migrate deploy
docker-compose -f docker-compose.prod.yml up -d

print_success "Backend iniciado"

# ===========================================
# STEP 7: Build and start frontend
# ===========================================
print_step "Construindo e iniciando frontend..."
cd $BASE_DIR/web

docker-compose -f docker-compose.prod.yml build
docker-compose -f docker-compose.prod.yml up -d

print_success "Frontend iniciado"

# ===========================================
# STEP 8: Start Nginx
# ===========================================
print_step "Iniciando Nginx..."
cd $BASE_DIR/infrastructure
docker-compose up -d nginx

print_success "Nginx iniciado"

# ===========================================
# DONE
# ===========================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Deploy concluído com sucesso!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "URLs:"
echo "  - Website: https://personalweb.infinityitsolutions.com.br"
echo "  - API: https://personalapi.infinityitsolutions.com.br"
echo ""
echo "Comandos úteis:"
echo "  - Ver logs: docker-compose logs -f"
echo "  - Reiniciar serviço: docker-compose restart <service>"
echo "  - Status: docker ps"
echo ""
