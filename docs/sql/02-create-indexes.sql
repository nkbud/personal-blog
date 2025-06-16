-- Database Indexes for Performance
-- File: 02-create-indexes.sql

-- Essential indexes for multi-tenant queries
CREATE INDEX idx_users_account_id ON users(account_id);
CREATE INDEX idx_users_email_account ON users(email, account_id);
CREATE INDEX idx_sites_account_id ON sites(account_id);
CREATE INDEX idx_sites_account_slug ON sites(account_id, slug);
CREATE INDEX idx_content_site_id ON content(site_id);
CREATE INDEX idx_content_author_id ON content(author_id);
CREATE INDEX idx_tasks_account_id ON tasks(account_id);
CREATE INDEX idx_tasks_site_id ON tasks(site_id);
CREATE INDEX idx_assets_account_id ON assets(account_id);
CREATE INDEX idx_assets_site_id ON assets(site_id);

-- Performance indexes for common queries
CREATE INDEX idx_content_status_published ON content(site_id, status) WHERE status = 'published';
CREATE INDEX idx_content_published_date ON content(published_at DESC) WHERE status = 'published';
CREATE INDEX idx_tasks_status_scheduled ON tasks(status, scheduled_for) WHERE status = 'QUEUED';
CREATE INDEX idx_tasks_priority_created ON tasks(priority DESC, created_at ASC) WHERE status = 'QUEUED';
CREATE INDEX idx_assets_account_site ON assets(account_id, site_id);
CREATE INDEX idx_users_status_active ON users(account_id) WHERE status = 'active';

-- Search and filtering indexes
CREATE INDEX idx_content_tags ON content USING gin(tags);
CREATE INDEX idx_content_categories ON content USING gin(categories);
CREATE INDEX idx_tasks_payload ON tasks USING gin(payload);
CREATE INDEX idx_sites_settings ON sites USING gin(settings);
CREATE INDEX idx_accounts_settings ON accounts USING gin(settings);

-- Full-text search indexes
CREATE INDEX idx_content_search ON content USING gin(to_tsvector('english', title || ' ' || COALESCE(content_md, '')));
CREATE INDEX idx_sites_search ON sites USING gin(to_tsvector('english', name || ' ' || COALESCE(description, '')));

-- Composite indexes for complex queries
CREATE INDEX idx_content_site_status_date ON content(site_id, status, created_at DESC);
CREATE INDEX idx_tasks_account_type_status ON tasks(account_id, type, status);
CREATE INDEX idx_assets_account_folder_date ON assets(account_id, folder, created_at DESC);

-- Billing and subscription indexes
CREATE INDEX idx_account_billing_stripe_customer ON account_billing(stripe_customer_id);
CREATE INDEX idx_accounts_plan_trial ON accounts(plan_type, trial_ends_at) WHERE trial_ends_at IS NOT NULL;