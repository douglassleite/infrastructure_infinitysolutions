-- ===========================================
-- Criar bancos de dados adicionais
-- Este script é executado automaticamente pelo PostgreSQL na primeira inicialização
-- ===========================================

-- Criar banco do Personal Trainer
SELECT 'CREATE DATABASE personal_trainer_db'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'personal_trainer_db')\gexec

-- Criar usuário personal_trainer se não existir
DO
$do$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'personal_trainer') THEN
      CREATE ROLE personal_trainer WITH LOGIN PASSWORD 'Mga@2025';
   END IF;
END
$do$;

-- Dar permissões ao usuário personal_trainer no banco personal_trainer_db
GRANT ALL PRIVILEGES ON DATABASE personal_trainer_db TO personal_trainer;
GRANT ALL PRIVILEGES ON DATABASE personal_trainer_db TO infinityitsolutions;

-- Conectar ao banco personal_trainer_db e dar permissões no schema
\c personal_trainer_db

GRANT ALL ON SCHEMA public TO personal_trainer;
GRANT ALL ON SCHEMA public TO infinityitsolutions;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO personal_trainer;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO personal_trainer;
