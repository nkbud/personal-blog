-- Multi-Tenant SaaS Database Schema
-- File: 01-create-tables.sql

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Multi-tenant boundary - represents each customer/organization
CREATE TABLE accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text UNIQUE NOT NULL, -- URL-friendly identifier
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  -- Subscription and billing
  plan_type text DEFAULT 'free', -- 'free', 'pro', 'enterprise'
  trial_ends_at timestamptz,
  subscription_id text, -- Stripe subscription ID
  
  -- Account settings
  settings jsonb DEFAULT '{}',
  
  -- Constraints
  CONSTRAINT accounts_slug_format CHECK (slug ~ '^[a-z0-9-]+$')
);

-- Users within each tenant account
CREATE TABLE users (
  id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  account_id uuid NOT NULL REFERENCES accounts ON DELETE CASCADE,
  
  -- Profile information
  email text NOT NULL,
  full_name text,
  avatar_url text,
  
  -- Role and permissions
  role text NOT NULL DEFAULT 'member', -- 'owner', 'admin', 'editor', 'member'
  permissions jsonb DEFAULT '[]',
  
  -- Status
  status text DEFAULT 'active', -- 'active', 'invited', 'suspended'
  invited_at timestamptz,
  joined_at timestamptz,
  last_active_at timestamptz,
  
  -- Timestamps
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  -- Constraints
  UNIQUE(email, account_id),
  CONSTRAINT users_role_check CHECK (role IN ('owner', 'admin', 'editor', 'member'))
);

-- Individual sites/blogs within each account
CREATE TABLE sites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid NOT NULL REFERENCES accounts ON DELETE CASCADE,
  
  -- Site identification
  name text NOT NULL,
  slug text NOT NULL, -- e.g. "blog", "projects", "docs"
  description text,
  
  -- GitHub integration
  repo_url text, -- GitHub repository URL
  repo_id bigint, -- GitHub repository ID
  github_token_encrypted text, -- Encrypted GitHub access token
  
  -- Configuration
  theme text NOT NULL DEFAULT 'default',
  domain text, -- Custom domain
  
  -- Publishing settings
  publish_schedule text, -- cron expression or '@daily', '@weekly'
  auto_publish boolean DEFAULT false,
  build_command text DEFAULT 'hugo',
  output_dir text DEFAULT 'public',
  
  -- Status
  status text DEFAULT 'draft', -- 'draft', 'published', 'archived'
  last_built_at timestamptz,
  last_deployed_at timestamptz,
  
  -- Settings and metadata
  settings jsonb DEFAULT '{}',
  metadata jsonb DEFAULT '{}',
  
  -- Timestamps
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  -- Constraints
  UNIQUE(account_id, slug),
  CONSTRAINT sites_slug_format CHECK (slug ~ '^[a-z0-9-]+$'),
  CONSTRAINT sites_status_check CHECK (status IN ('draft', 'published', 'archived'))
);

-- Content items (posts, pages, etc.) for each site
CREATE TABLE content (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id uuid NOT NULL REFERENCES sites ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES users ON DELETE RESTRICT,
  
  -- Content identification
  title text NOT NULL,
  slug text NOT NULL,
  type text NOT NULL DEFAULT 'post', -- 'post', 'page', 'draft'
  
  -- Content body
  content_md text, -- Markdown content
  content_html text, -- Rendered HTML
  excerpt text,
  
  -- Metadata
  tags text[] DEFAULT '{}',
  categories text[] DEFAULT '{}',
  featured_image_url text,
  seo_title text,
  seo_description text,
  
  -- Publishing
  status text DEFAULT 'draft', -- 'draft', 'published', 'scheduled', 'archived'
  published_at timestamptz,
  scheduled_for timestamptz,
  
  -- Settings
  allow_comments boolean DEFAULT true,
  is_featured boolean DEFAULT false,
  custom_fields jsonb DEFAULT '{}',
  
  -- Timestamps
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  -- Constraints
  UNIQUE(site_id, slug),
  CONSTRAINT content_slug_format CHECK (slug ~ '^[a-z0-9-]+$'),
  CONSTRAINT content_status_check CHECK (status IN ('draft', 'published', 'scheduled', 'archived'))
);

-- Background tasks and job queue
CREATE TABLE tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id uuid REFERENCES sites ON DELETE CASCADE,
  account_id uuid NOT NULL REFERENCES accounts ON DELETE CASCADE,
  created_by uuid REFERENCES users ON DELETE SET NULL,
  
  -- Task definition
  type text NOT NULL, -- 'PUBLISH', 'RESEARCH', 'UPLOAD_ASSET', 'REBUILD_SITE', etc.
  priority integer DEFAULT 0,
  
  -- Task data
  payload jsonb NOT NULL DEFAULT '{}',
  context jsonb DEFAULT '{}',
  
  -- Execution
  status text DEFAULT 'QUEUED', -- 'QUEUED', 'RUNNING', 'SUCCEEDED', 'FAILED', 'CANCELLED'
  started_at timestamptz,
  completed_at timestamptz,
  
  -- Results
  result jsonb,
  error_message text,
  retry_count integer DEFAULT 0,
  max_retries integer DEFAULT 3,
  
  -- Scheduling
  scheduled_for timestamptz DEFAULT now(),
  timeout_seconds integer DEFAULT 300,
  
  -- Timestamps
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  -- Constraints
  CONSTRAINT tasks_status_check CHECK (status IN ('QUEUED', 'RUNNING', 'SUCCEEDED', 'FAILED', 'CANCELLED')),
  CONSTRAINT tasks_priority_range CHECK (priority >= -100 AND priority <= 100)
);

-- File uploads and assets
CREATE TABLE assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid NOT NULL REFERENCES accounts ON DELETE CASCADE,
  site_id uuid REFERENCES sites ON DELETE CASCADE,
  uploaded_by uuid NOT NULL REFERENCES users ON DELETE RESTRICT,
  
  -- File information
  filename text NOT NULL,
  original_filename text NOT NULL,
  file_path text NOT NULL, -- Path in Supabase Storage
  file_size bigint NOT NULL,
  mime_type text NOT NULL,
  
  -- Image-specific metadata
  width integer,
  height integer,
  alt_text text,
  
  -- Organization
  folder text DEFAULT 'uploads',
  tags text[] DEFAULT '{}',
  
  -- Usage tracking
  usage_count integer DEFAULT 0,
  last_used_at timestamptz,
  
  -- Timestamps
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  -- Constraints
  CONSTRAINT assets_file_size_limit CHECK (file_size <= 50 * 1024 * 1024) -- 50MB limit
);

-- Subscription plans and billing
CREATE TABLE plans (
  id text PRIMARY KEY, -- 'free', 'pro', 'enterprise'
  name text NOT NULL,
  description text,
  
  -- Limits
  max_sites integer,
  max_users integer,
  max_storage_gb integer,
  max_bandwidth_gb integer,
  
  -- Features
  features jsonb DEFAULT '[]',
  
  -- Pricing
  price_monthly integer, -- Price in cents
  price_yearly integer, -- Price in cents (if different)
  
  -- Metadata
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Account billing information
CREATE TABLE account_billing (
  account_id uuid PRIMARY KEY REFERENCES accounts ON DELETE CASCADE,
  
  -- Stripe integration
  stripe_customer_id text UNIQUE,
  stripe_subscription_id text,
  
  -- Current plan
  current_plan text NOT NULL REFERENCES plans DEFAULT 'free',
  
  -- Usage tracking
  current_usage jsonb DEFAULT '{}',
  
  -- Billing cycle
  billing_cycle_start timestamptz,
  billing_cycle_end timestamptz,
  
  -- Payment status
  payment_status text DEFAULT 'active', -- 'active', 'past_due', 'cancelled'
  
  -- Timestamps
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Insert default plans
INSERT INTO plans (id, name, description, max_sites, max_users, max_storage_gb, features, price_monthly) VALUES
  ('free', 'Free', 'Perfect for getting started', 1, 2, 1, '["basic_themes", "community_support"]', 0),
  ('pro', 'Pro', 'For growing teams', 5, 10, 10, '["custom_themes", "priority_support", "analytics"]', 1900),
  ('enterprise', 'Enterprise', 'For large organizations', NULL, NULL, 100, '["white_label", "sso", "dedicated_support"]', 9900);