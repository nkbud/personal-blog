# Database Schema - Multi-Tenant Design

## Schema Overview

The database schema is designed with multi-tenancy as a core principle. The `accounts` table serves as the primary tenant boundary, with all other entities scoped to specific accounts through foreign key relationships.

## Core Tables

### Accounts (Tenant Boundary)
```sql
-- Multi-tenant boundary - represents each customer/organization
create table accounts (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique not null, -- URL-friendly identifier
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  
  -- Subscription and billing
  plan_type text default 'free', -- 'free', 'pro', 'enterprise'
  trial_ends_at timestamptz,
  subscription_id text, -- Stripe subscription ID
  
  -- Account settings
  settings jsonb default '{}',
  
  -- Constraints
  constraint accounts_slug_format check (slug ~ '^[a-z0-9-]+$')
);
```

### Users
```sql
-- Users within each tenant account
create table users (
  id uuid primary key references auth.users on delete cascade,
  account_id uuid not null references accounts on delete cascade,
  
  -- Profile information
  email text not null,
  full_name text,
  avatar_url text,
  
  -- Role and permissions
  role text not null default 'member', -- 'owner', 'admin', 'editor', 'member'
  permissions jsonb default '[]',
  
  -- Status
  status text default 'active', -- 'active', 'invited', 'suspended'
  invited_at timestamptz,
  joined_at timestamptz,
  last_active_at timestamptz,
  
  -- Timestamps
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  
  -- Constraints
  unique(email, account_id),
  constraint users_role_check check (role in ('owner', 'admin', 'editor', 'member'))
);
```

### Sites
```sql
-- Individual sites/blogs within each account
create table sites (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts on delete cascade,
  
  -- Site identification
  name text not null,
  slug text not null, -- e.g. "blog", "projects", "docs"
  description text,
  
  -- GitHub integration
  repo_url text, -- GitHub repository URL
  repo_id bigint, -- GitHub repository ID
  github_token_encrypted text, -- Encrypted GitHub access token
  
  -- Configuration
  theme text not null default 'default',
  domain text, -- Custom domain
  
  -- Publishing settings
  publish_schedule text, -- cron expression or '@daily', '@weekly'
  auto_publish boolean default false,
  build_command text default 'hugo',
  output_dir text default 'public',
  
  -- Status
  status text default 'draft', -- 'draft', 'published', 'archived'
  last_built_at timestamptz,
  last_deployed_at timestamptz,
  
  -- Settings and metadata
  settings jsonb default '{}',
  metadata jsonb default '{}',
  
  -- Timestamps
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  
  -- Constraints
  unique(account_id, slug),
  constraint sites_slug_format check (slug ~ '^[a-z0-9-]+$'),
  constraint sites_status_check check (status in ('draft', 'published', 'archived'))
);
```

### Content
```sql
-- Content items (posts, pages, etc.) for each site
create table content (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references sites on delete cascade,
  author_id uuid not null references users on delete restrict,
  
  -- Content identification
  title text not null,
  slug text not null,
  type text not null default 'post', -- 'post', 'page', 'draft'
  
  -- Content body
  content_md text, -- Markdown content
  content_html text, -- Rendered HTML
  excerpt text,
  
  -- Metadata
  tags text[] default '{}',
  categories text[] default '{}',
  featured_image_url text,
  seo_title text,
  seo_description text,
  
  -- Publishing
  status text default 'draft', -- 'draft', 'published', 'scheduled', 'archived'
  published_at timestamptz,
  scheduled_for timestamptz,
  
  -- Settings
  allow_comments boolean default true,
  is_featured boolean default false,
  custom_fields jsonb default '{}',
  
  -- Timestamps
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  
  -- Constraints
  unique(site_id, slug),
  constraint content_slug_format check (slug ~ '^[a-z0-9-]+$'),
  constraint content_status_check check (status in ('draft', 'published', 'scheduled', 'archived'))
);
```

### Tasks (Job Queue)
```sql
-- Background tasks and job queue
create table tasks (
  id uuid primary key default gen_random_uuid(),
  site_id uuid references sites on delete cascade,
  account_id uuid not null references accounts on delete cascade,
  created_by uuid references users on delete set null,
  
  -- Task definition
  type text not null, -- 'PUBLISH', 'RESEARCH', 'UPLOAD_ASSET', 'REBUILD_SITE', etc.
  priority integer default 0,
  
  -- Task data
  payload jsonb not null default '{}',
  context jsonb default '{}',
  
  -- Execution
  status text default 'QUEUED', -- 'QUEUED', 'RUNNING', 'SUCCEEDED', 'FAILED', 'CANCELLED'
  started_at timestamptz,
  completed_at timestamptz,
  
  -- Results
  result jsonb,
  error_message text,
  retry_count integer default 0,
  max_retries integer default 3,
  
  -- Scheduling
  scheduled_for timestamptz default now(),
  timeout_seconds integer default 300,
  
  -- Timestamps
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  
  -- Constraints
  constraint tasks_status_check check (status in ('QUEUED', 'RUNNING', 'SUCCEEDED', 'FAILED', 'CANCELLED')),
  constraint tasks_priority_range check (priority >= -100 and priority <= 100)
);
```

### Assets
```sql
-- File uploads and assets
create table assets (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts on delete cascade,
  site_id uuid references sites on delete cascade,
  uploaded_by uuid not null references users on delete restrict,
  
  -- File information
  filename text not null,
  original_filename text not null,
  file_path text not null, -- Path in Supabase Storage
  file_size bigint not null,
  mime_type text not null,
  
  -- Image-specific metadata
  width integer,
  height integer,
  alt_text text,
  
  -- Organization
  folder text default 'uploads',
  tags text[] default '{}',
  
  -- Usage tracking
  usage_count integer default 0,
  last_used_at timestamptz,
  
  -- Timestamps
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  
  -- Constraints
  constraint assets_file_size_limit check (file_size <= 50 * 1024 * 1024) -- 50MB limit
);
```

### Plans and Billing
```sql
-- Subscription plans and billing
create table plans (
  id text primary key, -- 'free', 'pro', 'enterprise'
  name text not null,
  description text,
  
  -- Limits
  max_sites integer,
  max_users integer,
  max_storage_gb integer,
  max_bandwidth_gb integer,
  
  -- Features
  features jsonb default '[]',
  
  -- Pricing
  price_monthly integer, -- Price in cents
  price_yearly integer, -- Price in cents (if different)
  
  -- Metadata
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Account billing information
create table account_billing (
  account_id uuid primary key references accounts on delete cascade,
  
  -- Stripe integration
  stripe_customer_id text unique,
  stripe_subscription_id text,
  
  -- Current plan
  current_plan text not null references plans default 'free',
  
  -- Usage tracking
  current_usage jsonb default '{}',
  
  -- Billing cycle
  billing_cycle_start timestamptz,
  billing_cycle_end timestamptz,
  
  -- Payment status
  payment_status text default 'active', -- 'active', 'past_due', 'cancelled'
  
  -- Timestamps
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

## Indexes for Performance

```sql
-- Essential indexes for multi-tenant queries
create index idx_users_account_id on users(account_id);
create index idx_sites_account_id on sites(account_id);
create index idx_content_site_id on content(site_id);
create index idx_content_status_published on content(site_id, status) where status = 'published';
create index idx_tasks_status_scheduled on tasks(status, scheduled_for) where status = 'QUEUED';
create index idx_assets_account_site on assets(account_id, site_id);

-- Search and filtering indexes
create index idx_content_tags on content using gin(tags);
create index idx_content_categories on content using gin(categories);
create index idx_tasks_payload on tasks using gin(payload);
```

## Row Level Security (RLS) Policies

```sql
-- Enable RLS on all tables
alter table accounts enable row level security;
alter table users enable row level security;
alter table sites enable row level security;
alter table content enable row level security;
alter table tasks enable row level security;
alter table assets enable row level security;

-- Users can only access their own account's data
create policy "Users can access their account" on users
  for all using (account_id = auth.current_user_account_id());

create policy "Sites are account-scoped" on sites
  for all using (account_id = auth.current_user_account_id());

create policy "Content is site-scoped" on content
  for all using (site_id in (
    select id from sites where account_id = auth.current_user_account_id()
  ));

-- Helper function to get current user's account
create or replace function auth.current_user_account_id()
returns uuid
language sql
security definer
as $$
  select account_id from users where id = auth.uid();
$$;
```

## Database Functions and Triggers

```sql
-- Function to update the updated_at timestamp
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Apply to all tables with updated_at
create trigger update_accounts_updated_at before update on accounts
  for each row execute function update_updated_at_column();

create trigger update_users_updated_at before update on users
  for each row execute function update_updated_at_column();

create trigger update_sites_updated_at before update on sites
  for each row execute function update_updated_at_column();

create trigger update_content_updated_at before update on content
  for each row execute function update_updated_at_column();

create trigger update_tasks_updated_at before update on tasks
  for each row execute function update_updated_at_column();

create trigger update_assets_updated_at before update on assets
  for each row execute function update_updated_at_column();
```

## Sample Data

```sql
-- Insert sample data for testing
insert into plans (id, name, description, max_sites, max_users, max_storage_gb, features, price_monthly) values
  ('free', 'Free', 'Perfect for getting started', 1, 2, 1, '["basic_themes", "community_support"]', 0),
  ('pro', 'Pro', 'For growing teams', 5, 10, 10, '["custom_themes", "priority_support", "analytics"]', 1900),
  ('enterprise', 'Enterprise', 'For large organizations', null, null, 100, '["white_label", "sso", "dedicated_support"]', 9900);

-- Sample account
insert into accounts (name, slug, plan_type) values
  ('Example Organization', 'example-org', 'pro');
```