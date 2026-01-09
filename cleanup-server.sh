#!/bin/bash

# ===========================================
# Script de Backup e Limpeza do Servidor
# ===========================================
# Este script faz backup dos bancos de dados e
# remove todos os containers/volumes/projetos
# para permitir um deploy limpo do zero.
#
# Uso: ./cleanup-server.sh
#
# ATENCAO: Este script DELETA tudo! Use com cuidado.
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

# Diretorio do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$ROOT_DIR/backups/$(date +%Y%m%d_%H%M%S)"

echo ""
echo -e "${RED}========================================${NC}"
echo -e "${RED}  ATENCAO: LIMPEZA COMPLETA DO SERVIDOR${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo "Este script vai:"
echo "  1. Fazer backup de TODOS os bancos de dados"
echo "  2. Fazer backup dos certificados SSL"
echo "  3. Parar e remover TODOS os containers"
echo "  4. Remover TODOS os volumes Docker"
echo "  5. Remover TODAS as redes Docker"
echo "  6. Deletar TODOS os projetos"
echo ""
echo -e "${YELLOW}Os backups serao salvos em: $BACKUP_DIR${NC}"
echo ""
read -p "Tem certeza que deseja continuar? (digite 'SIM' para confirmar): " CONFIRM

if [ "$CONFIRM" != "SIM" ]; then
    echo "Operacao cancelada."
    exit 0
fi

# ===========================================
# STEP 1: Criar diretorio de backup
# ===========================================
print_step "Criando diretorio de backup..."
mkdir -p "$BACKUP_DIR"
print_success "Diretorio criado: $BACKUP_DIR"

# ===========================================
# STEP 2: Backup dos bancos de dados
# ===========================================
print_step "Fazendo backup dos bancos de dados..."

# Verificar se o container postgres esta rodando
if docker ps | grep -q infinity-postgres-db; then
    # Backup de todos os bancos
    docker exec infinity-postgres-db pg_dumpall -U infinityitsolutions > "$BACKUP_DIR/all_databases.sql" 2>/dev/null && \
        print_success "Backup completo: all_databases.sql" || \
        print_warning "Falha no backup completo"

    # Backup individual - Personal Trainer
    docker exec infinity-postgres-db pg_dump -U infinityitsolutions personal_trainer_db > "$BACKUP_DIR/personal_trainer_db.sql" 2>/dev/null && \
        print_success "Backup: personal_trainer_db.sql" || \
        print_warning "Banco personal_trainer_db nao existe ou falhou"

    # Backup individual - Evolly (antigo wedding_system)
    docker exec infinity-postgres-db pg_dump -U infinityitsolutions evolly_db > "$BACKUP_DIR/evolly_db.sql" 2>/dev/null && \
        print_success "Backup: evolly_db.sql" || \
        print_warning "Banco evolly_db nao existe"

    # Backup do banco antigo wedding_system (se existir)
    docker exec infinity-postgres-db pg_dump -U infinityitsolutions wedding_system > "$BACKUP_DIR/wedding_system.sql" 2>/dev/null && \
        print_success "Backup: wedding_system.sql (banco antigo)" || \
        print_warning "Banco wedding_system nao existe (ok se ja migrou)"

    # Backup individual - CNPJ
    docker exec infinity-postgres-db pg_dump -U infinityitsolutions cnpj_db > "$BACKUP_DIR/cnpj_db.sql" 2>/dev/null && \
        print_success "Backup: cnpj_db.sql" || \
        print_warning "Banco cnpj_db nao existe ou falhou"
else
    print_warning "Container PostgreSQL nao esta rodando. Pulando backup do banco."
fi

# ===========================================
# STEP 3: Backup dos certificados SSL
# ===========================================
print_step "Fazendo backup dos certificados SSL..."

if [ -d "$SCRIPT_DIR/certbot/conf" ]; then
    sudo cp -r "$SCRIPT_DIR/certbot/conf" "$BACKUP_DIR/certbot-conf" 2>/dev/null && \
        print_success "Backup: certbot-conf/" || \
        print_warning "Falha no backup dos certificados"
else
    print_warning "Pasta de certificados nao encontrada"
fi

# ===========================================
# STEP 4: Backup dos uploads (Evolly)
# ===========================================
print_step "Fazendo backup dos uploads..."

if [ -d "$ROOT_DIR/evolly/public/uploads" ]; then
    cp -r "$ROOT_DIR/evolly/public/uploads" "$BACKUP_DIR/evolly-uploads" 2>/dev/null && \
        print_success "Backup: evolly-uploads/" || \
        print_warning "Falha no backup dos uploads"
else
    print_warning "Pasta de uploads nao encontrada"
fi

# ===========================================
# STEP 5: Listar arquivos de backup
# ===========================================
echo ""
print_step "Arquivos de backup criados:"
ls -lah "$BACKUP_DIR"
echo ""

# Confirmacao final antes de deletar
echo -e "${RED}========================================${NC}"
echo -e "${RED}  PROXIMA ETAPA: DELETAR TUDO${NC}"
echo -e "${RED}========================================${NC}"
echo ""
read -p "Backups criados. Deseja prosseguir com a LIMPEZA? (digite 'DELETAR' para confirmar): " CONFIRM_DELETE

if [ "$CONFIRM_DELETE" != "DELETAR" ]; then
    echo ""
    echo -e "${GREEN}Backups salvos em: $BACKUP_DIR${NC}"
    echo "Limpeza cancelada. Voce pode rodar novamente quando quiser."
    exit 0
fi

# ===========================================
# STEP 6: Parar e remover containers
# ===========================================
print_step "Parando todos os containers..."

# Parar containers por projeto
cd "$SCRIPT_DIR" && docker compose down 2>/dev/null || true

# Personal Trainer
[ -d "$ROOT_DIR/personal_trainer_backend" ] && cd "$ROOT_DIR/personal_trainer_backend" && docker compose -f docker-compose.prod.yml down 2>/dev/null || true
[ -d "$ROOT_DIR/personal_trainer_web" ] && cd "$ROOT_DIR/personal_trainer_web" && docker compose -f docker-compose.prod.yml down 2>/dev/null || true

# Evolly
[ -d "$ROOT_DIR/evolly" ] && cd "$ROOT_DIR/evolly" && docker compose down 2>/dev/null || true

# Website
[ -d "$ROOT_DIR/web_infinitysolutions" ] && cd "$ROOT_DIR/web_infinitysolutions" && docker compose down 2>/dev/null || true

# Evolly Clients
if [ -d "$ROOT_DIR/evolly-clients" ]; then
    for client_dir in "$ROOT_DIR/evolly-clients"/*/; do
        if [ -f "${client_dir}docker-compose.yml" ]; then
            cd "$client_dir" && docker compose down 2>/dev/null || true
        fi
    done
fi

print_success "Containers parados"

# ===========================================
# STEP 7: Remover todos os containers restantes
# ===========================================
print_step "Removendo containers restantes..."
docker ps -aq | xargs -r docker rm -f 2>/dev/null || true
print_success "Containers removidos"

# ===========================================
# STEP 8: Remover volumes
# ===========================================
print_step "Removendo volumes Docker..."
docker volume ls -q | xargs -r docker volume rm -f 2>/dev/null || true
print_success "Volumes removidos"

# ===========================================
# STEP 9: Remover redes
# ===========================================
print_step "Removendo redes Docker..."
docker network rm infinityitsolutions-network 2>/dev/null || true
docker network rm personal_trainer_infrastructure_app-network 2>/dev/null || true
docker network rm personal-trainer-network 2>/dev/null || true
print_success "Redes removidas"

# ===========================================
# STEP 10: Limpar imagens nao usadas
# ===========================================
print_step "Limpando imagens Docker..."
docker system prune -af 2>/dev/null || true
print_success "Imagens limpas"

# ===========================================
# STEP 11: Deletar pastas dos projetos
# ===========================================
print_step "Deletando pastas dos projetos..."

cd "$ROOT_DIR"

# Manter apenas a pasta de backups
rm -rf "$ROOT_DIR/infrastructure_infinitysolutions" 2>/dev/null || true
rm -rf "$ROOT_DIR/web_infinitysolutions" 2>/dev/null || true
rm -rf "$ROOT_DIR/personal_trainer_backend" 2>/dev/null || true
rm -rf "$ROOT_DIR/personal_trainer_web" 2>/dev/null || true
rm -rf "$ROOT_DIR/evolly" 2>/dev/null || true
rm -rf "$ROOT_DIR/evolly-clients" 2>/dev/null || true

# Pastas antigas (se existirem)
rm -rf "$ROOT_DIR/apps" 2>/dev/null || true
rm -rf "$ROOT_DIR/website" 2>/dev/null || true

print_success "Pastas deletadas"

# ===========================================
# DONE
# ===========================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Limpeza concluida!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Backups salvos em: ${YELLOW}$BACKUP_DIR${NC}"
echo ""
echo "Para restaurar o banco de dados apos o novo deploy:"
echo ""
echo "  # Restaurar banco completo"
echo "  cat $BACKUP_DIR/all_databases.sql | docker exec -i infinity-postgres-db psql -U infinityitsolutions"
echo ""
echo "  # Ou restaurar banco individual (Evolly)"
echo "  cat $BACKUP_DIR/evolly_db.sql | docker exec -i infinity-postgres-db psql -U infinityitsolutions -d evolly_db"
echo ""
echo "  # Ou restaurar do banco antigo wedding_system para evolly_db"
echo "  cat $BACKUP_DIR/wedding_system.sql | docker exec -i infinity-postgres-db psql -U infinityitsolutions -d evolly_db"
echo ""
echo "Para fazer novo deploy:"
echo ""
echo "  git clone git@github.com:douglassleite/infrastructure_infinitysolutions.git"
echo "  cd infrastructure_infinitysolutions"
echo "  ./deploy.sh"
echo ""
