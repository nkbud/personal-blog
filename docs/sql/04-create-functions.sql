-- Database Functions and Triggers
-- File: 04-create-functions.sql

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to all relevant tables
CREATE TRIGGER update_accounts_updated_at 
  BEFORE UPDATE ON accounts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at 
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sites_updated_at 
  BEFORE UPDATE ON sites
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_content_updated_at 
  BEFORE UPDATE ON content
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tasks_updated_at 
  BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_assets_updated_at 
  BEFORE UPDATE ON assets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_account_billing_updated_at 
  BEFORE UPDATE ON account_billing
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to create default billing record for new accounts
CREATE OR REPLACE FUNCTION create_account_billing()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO account_billing (account_id, current_plan)
  VALUES (NEW.id, 'free');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER create_account_billing_trigger
  AFTER INSERT ON accounts
  FOR EACH ROW EXECUTE FUNCTION create_account_billing();

-- Function to validate user roles and permissions
CREATE OR REPLACE FUNCTION validate_user_role()
RETURNS TRIGGER AS $$
BEGIN
  -- Ensure there's always at least one owner per account
  IF TG_OP = 'UPDATE' AND OLD.role = 'owner' AND NEW.role != 'owner' THEN
    IF NOT EXISTS (
      SELECT 1 FROM users 
      WHERE account_id = NEW.account_id 
      AND role = 'owner' 
      AND id != NEW.id
    ) THEN
      RAISE EXCEPTION 'Cannot change role: account must have at least one owner';
    END IF;
  END IF;
  
  -- Prevent users from changing their own role if they're the only owner
  IF TG_OP = 'UPDATE' AND auth.uid() = NEW.id AND OLD.role = 'owner' AND NEW.role != 'owner' THEN
    IF NOT EXISTS (
      SELECT 1 FROM users 
      WHERE account_id = NEW.account_id 
      AND role = 'owner' 
      AND id != NEW.id
    ) THEN
      RAISE EXCEPTION 'Cannot change your own role: you are the only owner';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_user_role_trigger
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION validate_user_role();

-- Function to queue daily content review tasks
CREATE OR REPLACE FUNCTION queue_daily_content_review()
RETURNS void AS $$
BEGIN
  -- Find scheduled content that should be published
  INSERT INTO tasks (site_id, type, payload, account_id)
  SELECT 
    site_id,
    'PUBLISH' as type,
    json_build_object('content_id', id, 'scheduled', true) as payload,
    (SELECT account_id FROM sites WHERE sites.id = content.site_id)
  FROM content 
  WHERE status = 'scheduled' 
    AND scheduled_for <= NOW()
    AND scheduled_for > NOW() - INTERVAL '1 day';
    
  -- Queue research tasks for active sites
  INSERT INTO tasks (site_id, type, payload, account_id)
  SELECT 
    id as site_id,
    'RESEARCH' as type,
    json_build_object('auto_research', true) as payload,
    account_id
  FROM sites 
  WHERE settings->>'auto_research' = 'true'
    AND last_built_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql;

-- Function to generate slug from title
CREATE OR REPLACE FUNCTION generate_slug(title text)
RETURNS text AS $$
BEGIN
  RETURN lower(
    regexp_replace(
      regexp_replace(
        regexp_replace(title, '[^a-zA-Z0-9\s-]', '', 'g'),
        '\s+', '-', 'g'
      ),
      '-+', '-', 'g'
    )
  );
END;
$$ LANGUAGE plpgsql;

-- Function to ensure unique slugs within site
CREATE OR REPLACE FUNCTION ensure_unique_content_slug()
RETURNS TRIGGER AS $$
DECLARE
  base_slug text;
  counter integer := 1;
  new_slug text;
BEGIN
  -- Generate base slug if not provided
  IF NEW.slug IS NULL OR NEW.slug = '' THEN
    NEW.slug := generate_slug(NEW.title);
  END IF;
  
  base_slug := NEW.slug;
  new_slug := base_slug;
  
  -- Check for conflicts and append counter if needed
  WHILE EXISTS (
    SELECT 1 FROM content 
    WHERE site_id = NEW.site_id 
    AND slug = new_slug 
    AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
  ) LOOP
    counter := counter + 1;
    new_slug := base_slug || '-' || counter;
  END LOOP;
  
  NEW.slug := new_slug;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ensure_unique_content_slug_trigger
  BEFORE INSERT OR UPDATE ON content
  FOR EACH ROW EXECUTE FUNCTION ensure_unique_content_slug();

-- Function to track asset usage
CREATE OR REPLACE FUNCTION track_asset_usage()
RETURNS TRIGGER AS $$
BEGIN
  -- Update usage count for assets referenced in content
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    UPDATE assets 
    SET usage_count = usage_count + 1,
        last_used_at = NOW()
    WHERE file_path = ANY(
      SELECT unnest(
        regexp_split_to_array(
          COALESCE(NEW.content_md, '') || ' ' || COALESCE(NEW.featured_image_url, ''),
          '\bhttps?://[^\s]+\b'
        )
      )
    );
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER track_asset_usage_trigger
  AFTER INSERT OR UPDATE ON content
  FOR EACH ROW EXECUTE FUNCTION track_asset_usage();

-- Function to clean up old completed tasks
CREATE OR REPLACE FUNCTION cleanup_old_tasks()
RETURNS void AS $$
BEGIN
  DELETE FROM tasks 
  WHERE status IN ('SUCCEEDED', 'FAILED')
    AND completed_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

-- Function to get account usage statistics
CREATE OR REPLACE FUNCTION get_account_usage(account_uuid uuid)
RETURNS jsonb AS $$
DECLARE
  usage_stats jsonb;
BEGIN
  SELECT json_build_object(
    'sites_count', (SELECT COUNT(*) FROM sites WHERE account_id = account_uuid),
    'users_count', (SELECT COUNT(*) FROM users WHERE account_id = account_uuid AND status = 'active'),
    'content_count', (SELECT COUNT(*) FROM content c JOIN sites s ON c.site_id = s.id WHERE s.account_id = account_uuid),
    'storage_used_mb', (SELECT COALESCE(SUM(file_size), 0) / 1024 / 1024 FROM assets WHERE account_id = account_uuid),
    'tasks_pending', (SELECT COUNT(*) FROM tasks WHERE account_id = account_uuid AND status = 'QUEUED'),
    'last_activity', (SELECT MAX(updated_at) FROM users WHERE account_id = account_uuid)
  ) INTO usage_stats;
  
  RETURN usage_stats;
END;
$$ LANGUAGE plpgsql;

-- Function to check account limits
CREATE OR REPLACE FUNCTION check_account_limits(account_uuid uuid, action_type text)
RETURNS boolean AS $$
DECLARE
  current_plan record;
  usage_stats jsonb;
BEGIN
  -- Get current plan limits
  SELECT p.* INTO current_plan 
  FROM plans p 
  JOIN account_billing ab ON p.id = ab.current_plan 
  WHERE ab.account_id = account_uuid;
  
  -- Get current usage
  usage_stats := get_account_usage(account_uuid);
  
  -- Check specific limits based on action type
  CASE action_type
    WHEN 'create_site' THEN
      RETURN current_plan.max_sites IS NULL OR (usage_stats->>'sites_count')::int < current_plan.max_sites;
    WHEN 'invite_user' THEN
      RETURN current_plan.max_users IS NULL OR (usage_stats->>'users_count')::int < current_plan.max_users;
    WHEN 'upload_asset' THEN
      RETURN current_plan.max_storage_gb IS NULL OR (usage_stats->>'storage_used_mb')::int < (current_plan.max_storage_gb * 1024);
    ELSE
      RETURN true;
  END CASE;
END;
$$ LANGUAGE plpgsql;