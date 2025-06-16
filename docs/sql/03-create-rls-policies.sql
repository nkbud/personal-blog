-- Row Level Security (RLS) Policies
-- File: 03-create-rls-policies.sql

-- Enable RLS on all tables
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE content ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE account_billing ENABLE ROW LEVEL SECURITY;

-- Helper function to get current user's account
CREATE OR REPLACE FUNCTION auth.current_user_account_id()
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT account_id FROM users WHERE id = auth.uid();
$$;

-- Helper function to check if user has role
CREATE OR REPLACE FUNCTION auth.user_has_role(required_role text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() 
    AND (
      role = required_role 
      OR (required_role = 'member' AND role IN ('admin', 'owner'))
      OR (required_role = 'editor' AND role IN ('admin', 'owner'))
      OR (required_role = 'admin' AND role = 'owner')
    )
  );
$$;

-- Accounts: Users can only access their own account
CREATE POLICY "Users can access their account" ON accounts
  FOR ALL USING (id = auth.current_user_account_id());

-- Users: Account-scoped access
CREATE POLICY "Users are account-scoped" ON users
  FOR ALL USING (account_id = auth.current_user_account_id());

-- Additional policy for user management by admins
CREATE POLICY "Admins can manage users" ON users
  FOR ALL USING (
    account_id = auth.current_user_account_id() 
    AND auth.user_has_role('admin')
  );

-- Sites: Account-scoped access
CREATE POLICY "Sites are account-scoped" ON sites
  FOR ALL USING (account_id = auth.current_user_account_id());

-- Content: Site-scoped access (through account)
CREATE POLICY "Content is site-scoped" ON content
  FOR ALL USING (
    site_id IN (
      SELECT id FROM sites WHERE account_id = auth.current_user_account_id()
    )
  );

-- Content editing restrictions
CREATE POLICY "Authors can edit their content" ON content
  FOR UPDATE USING (
    author_id = auth.uid() 
    OR auth.user_has_role('editor')
  );

-- Tasks: Account-scoped access
CREATE POLICY "Tasks are account-scoped" ON tasks
  FOR ALL USING (account_id = auth.current_user_account_id());

-- Task creation restrictions
CREATE POLICY "Members can create tasks" ON tasks
  FOR INSERT WITH CHECK (
    account_id = auth.current_user_account_id()
    AND auth.user_has_role('member')
  );

-- Assets: Account-scoped access
CREATE POLICY "Assets are account-scoped" ON assets
  FOR ALL USING (account_id = auth.current_user_account_id());

-- Asset upload restrictions
CREATE POLICY "Members can upload assets" ON assets
  FOR INSERT WITH CHECK (
    account_id = auth.current_user_account_id()
    AND uploaded_by = auth.uid()
  );

-- Billing: Account owners only
CREATE POLICY "Account billing access" ON account_billing
  FOR ALL USING (
    account_id = auth.current_user_account_id()
    AND auth.user_has_role('owner')
  );

-- Plans: Public read access
CREATE POLICY "Plans are publicly readable" ON plans
  FOR SELECT USING (true);

-- Special policies for service accounts
-- Allow service role to bypass RLS for background tasks
CREATE POLICY "Service role bypass" ON tasks
  FOR ALL TO service_role USING (true);

CREATE POLICY "Service role asset access" ON assets
  FOR ALL TO service_role USING (true);

CREATE POLICY "Service role content access" ON content
  FOR ALL TO service_role USING (true);

-- Audit logging policy
CREATE POLICY "Audit logs are account-scoped" ON tasks
  FOR SELECT USING (
    account_id = auth.current_user_account_id()
    AND type = 'AUDIT_LOG'
  );