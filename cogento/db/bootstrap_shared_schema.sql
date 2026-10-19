-- Bootstrap Schema for Shared Database (cogento_shared)
-- Purpose: Complete schema definition for the shared database
-- Date: 2026-01-16
-- Note: This represents the final state after all migrations (post-migration 018)

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- TENANTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS tenants (
    tenant_id VARCHAR(100) PRIMARY KEY,  -- e.g., 'kgtc', 'org1', 'org2'
    name VARCHAR(255) NOT NULL,         -- Display name: 'KGTC', 'Organization Name'
    domain VARCHAR(255),                -- Optional custom domain: 'example.com'
    status VARCHAR(50) DEFAULT 'active', -- 'active', 'suspended', 'deleted'
    is_default BOOLEAN DEFAULT FALSE,   -- Indicates if this tenant is the default tenant
    config JSONB NOT NULL DEFAULT '{}'::jsonb,  -- App-managed configuration (theme, features, limits, product_display)
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,  -- Tenant-defined custom metadata
    
    -- Stripe API keys (consolidated - single pair per tenant)
    stripe_secret_key_encrypted VARCHAR(500),  -- Encrypted secret key for the environment specified in stripe_environment
    stripe_publishable_key VARCHAR(255),        -- Publishable key for the environment specified in stripe_environment
    stripe_environment VARCHAR(50) DEFAULT 'test', -- 'test' or 'live'. Determines which environment the keys are for.
    stripe_key_encryption_method VARCHAR(50) DEFAULT 'aes-256-gcm', -- Encryption method
    
    -- Database configuration
    database_name VARCHAR(255),        -- Name of the tenant database (e.g., cogento_kgtc)
    superadmin_email VARCHAR(255),     -- Email address of the superadmin user in the tenant database
    
    -- License (trial/free/premium token; trial auto-set on create)
    license_token TEXT,

    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_by VARCHAR(255)            -- Who updated (for audit)
);

-- Tenants table indexes
CREATE INDEX IF NOT EXISTS idx_tenants_status ON tenants(status);
CREATE INDEX IF NOT EXISTS idx_tenants_domain ON tenants(domain) WHERE domain IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tenants_config_gin ON tenants USING GIN(config);
CREATE INDEX IF NOT EXISTS idx_tenants_metadata_gin ON tenants USING GIN(metadata);
CREATE INDEX IF NOT EXISTS idx_tenants_stripe_environment ON tenants(stripe_environment);
CREATE INDEX IF NOT EXISTS idx_tenants_is_default ON tenants(is_default) WHERE is_default = TRUE;
CREATE INDEX IF NOT EXISTS idx_tenants_database_name ON tenants(database_name);

-- Tenants table comments
COMMENT ON TABLE tenants IS 'Tenant configuration (app-managed), metadata (tenant custom), and Stripe keys';
COMMENT ON COLUMN tenants.config IS 'App-managed configuration: theme, features, limits, product_display settings';
COMMENT ON COLUMN tenants.metadata IS 'Tenant-defined custom metadata: any tenant-level properties the org wants to store';
COMMENT ON COLUMN tenants.tenant_id IS 'Unique identifier for the tenant (used in URLs, headers, database names)';
COMMENT ON COLUMN tenants.is_default IS 'Indicates if this tenant is the default tenant for users not signed into a specific club';
COMMENT ON COLUMN tenants.database_name IS 'Name of the tenant database (e.g., cogento_kgtc)';
COMMENT ON COLUMN tenants.superadmin_email IS 'Email address of the superadmin user in the tenant database';
COMMENT ON COLUMN tenants.stripe_secret_key_encrypted IS 'Encrypted Stripe secret key for the environment specified in stripe_environment';
COMMENT ON COLUMN tenants.stripe_publishable_key IS 'Stripe publishable key for the environment specified in stripe_environment';
COMMENT ON COLUMN tenants.stripe_environment IS 'Stripe environment: "test" or "live". Determines which environment the stripe_secret_key_encrypted and stripe_publishable_key are for.';

-- ============================================================================
-- USERS TABLE (formerly superusers)
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'superuser',  -- User role: "superuser" for shared database administrators
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by VARCHAR(255),  -- Who created this user
    last_login_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE
);

-- Users table indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- Users table comments
COMMENT ON TABLE users IS 'Shared database users with role = "superuser" for cross-tenant administration. Cogento system must have at least one superuser.';
COMMENT ON COLUMN users.role IS 'superuser for cross-tenant administration (system must have at least one)';

-- ============================================================================
-- LOGIN_TOKENS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS login_tokens (
    token_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    code VARCHAR(255) NOT NULL,  -- OTP code (6 digits) or remember-me token (43 chars)
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    token_type VARCHAR(20) NOT NULL DEFAULT 'otp' CHECK (token_type IN ('otp', 'remember_me')),
    used_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Login tokens table indexes
CREATE INDEX IF NOT EXISTS idx_login_tokens_user_id ON login_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_login_tokens_email_code ON login_tokens(email, code) WHERE used_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_login_tokens_token_type ON login_tokens(token_type) WHERE token_type = 'remember_me';
CREATE INDEX IF NOT EXISTS idx_login_tokens_remember_me_lookup ON login_tokens(user_id, token_type, expires_at) 
    WHERE token_type = 'remember_me' AND used_at IS NULL;

-- Login tokens table comments
COMMENT ON TABLE login_tokens IS 'Login tokens for passwordless authentication - OTP codes and remember-me tokens for shared database users';
COMMENT ON COLUMN login_tokens.user_id IS 'Reference to users(user_id) table in shared database - all authenticated users have records in users table with role = "superuser"';
COMMENT ON COLUMN login_tokens.code IS 'OTP code (6 digits) for token_type=otp, or remember-me token (43 chars) for token_type=remember_me';
COMMENT ON COLUMN login_tokens.token_type IS 'Type of token: "otp" for one-time password codes (short-lived), "remember_me" for device remember tokens (long-lived)';
