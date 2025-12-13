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

# Diretório raiz da Infinity IT Solutions
ROOT_DIR="/opt/infinityitsolutions"

# Subdiretórios
INFRA_DIR="$ROOT_DIR/infrastructure"
WEBSITE_DIR="$ROOT_DIR/website"
PERSONAL_DIR="$ROOT_DIR/apps/personal-trainer"

mkdir -p $INFRA_DIR/{nginx/conf.d,certbot/conf,certbot/www,init-scripts}
mkdir -p $WEBSITE_DIR
mkdir -p $PERSONAL_DIR/{backend,web}

print_success "Diretórios criados em $ROOT_DIR"

# ===========================================
# STEP 3: Clone repositories
# ===========================================
print_step "Clonando repositórios..."

# Site Institucional
if [ -d "$WEBSITE_DIR/.git" ]; then
    cd $WEBSITE_DIR
    git pull origin master
else
    cd $ROOT_DIR
    git clone https://github.com/douglassleite/web_infinitysolutions.git website
fi
print_success "Site institucional atualizado"

# Personal Trainer Backend
if [ -d "$PERSONAL_DIR/backend/.git" ]; then
    cd $PERSONAL_DIR/backend
    git pull origin main
else
    cd $PERSONAL_DIR
    git clone https://github.com/douglassleite/personal_trainer_backend.git backend
fi
print_success "Backend Personal Trainer atualizado"

# Personal Trainer Web
if [ -d "$PERSONAL_DIR/web/.git" ]; then
    cd $PERSONAL_DIR/web
    git pull origin master
else
    cd $PERSONAL_DIR
    git clone https://github.com/douglassleite/personal_trainer_web.git web
fi
print_success "Frontend Personal Trainer atualizado"

print_success "Repositórios atualizados"

# ===========================================
# STEP 4: Start infrastructure
# ===========================================
print_step "Iniciando infraestrutura (Postgres, Redis)..."
cd $INFRA_DIR

if [ ! -f ".env" ]; then
    print_error "Arquivo .env não encontrado em infrastructure/"
    print_warning "Copie .env.example para .env e configure as variáveis"
    exit 1
fi

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

if [ ! -f ".env" ]; then
    print_error "Arquivo .env não encontrado em backend/"
    print_warning "Copie .env.production.example para .env e configure as variáveis"
    exit 1
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
echo "Comandos úteis:"
echo "  - Ver logs: docker compose logs -f"
echo "  - Reiniciar serviço: docker compose restart <service>"
echo "  - Status: docker ps"
echo ""
