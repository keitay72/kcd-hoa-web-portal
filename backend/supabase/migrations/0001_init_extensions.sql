-- =========================================================
-- Migration: 0001_init_extensions.sql
-- Purpose: Initialize required PostgreSQL extensions for KC Disposal
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

-- UUID + cryptographic helpers
create extension if not exists pgcrypto;

-- Case-insensitive email handling
create extension if not exists citext;

-- Optional: text search/trigram support for admin search capabilities
create extension if not exists pg_trgm;

-- Optional: supports additional GIN index patterns
create extension if not exists btree_gin;

commit;
