-- Sample Data for Testing
-- File: 05-sample-data.sql

-- Insert sample accounts
INSERT INTO accounts (id, name, slug, plan_type) VALUES
  ('550e8400-e29b-41d4-a716-446655440000', 'Example Organization', 'example-org', 'pro'),
  ('550e8400-e29b-41d4-a716-446655440001', 'Demo Company', 'demo-company', 'free'),
  ('550e8400-e29b-41d4-a716-446655440002', 'Enterprise Corp', 'enterprise-corp', 'enterprise');

-- Insert sample users (Note: In production, these would be created through Supabase Auth)
-- These are placeholder entries for demonstration
INSERT INTO users (id, account_id, email, full_name, role, status, joined_at) VALUES
  ('550e8400-e29b-41d4-a716-446655441000', '550e8400-e29b-41d4-a716-446655440000', 'owner@example-org.com', 'John Owner', 'owner', 'active', NOW()),
  ('550e8400-e29b-41d4-a716-446655441001', '550e8400-e29b-41d4-a716-446655440000', 'admin@example-org.com', 'Jane Admin', 'admin', 'active', NOW()),
  ('550e8400-e29b-41d4-a716-446655441002', '550e8400-e29b-41d4-a716-446655440000', 'editor@example-org.com', 'Bob Editor', 'editor', 'active', NOW()),
  ('550e8400-e29b-41d4-a716-446655441003', '550e8400-e29b-41d4-a716-446655440001', 'user@demo-company.com', 'Alice User', 'owner', 'active', NOW());

-- Insert sample sites
INSERT INTO sites (id, account_id, name, slug, description, theme, status, repo_url, auto_publish) VALUES
  ('550e8400-e29b-41d4-a716-446655442000', '550e8400-e29b-41d4-a716-446655440000', 'Company Blog', 'blog', 'Our company blog featuring industry insights and updates', 'modern', 'published', 'https://github.com/example-org/blog', true),
  ('550e8400-e29b-41d4-a716-446655442001', '550e8400-e29b-41d4-a716-446655440000', 'Project Portfolio', 'projects', 'Showcase of our latest projects and case studies', 'portfolio', 'published', 'https://github.com/example-org/projects', false),
  ('550e8400-e29b-41d4-a716-446655442002', '550e8400-e29b-41d4-a716-446655440000', 'Documentation', 'docs', 'Technical documentation and guides', 'docs', 'draft', NULL, false),
  ('550e8400-e29b-41d4-a716-446655442003', '550e8400-e29b-41d4-a716-446655440001', 'Personal Blog', 'blog', 'Personal thoughts and experiences', 'minimal', 'published', 'https://github.com/demo-company/blog', true);

-- Insert sample content
INSERT INTO content (id, site_id, author_id, title, slug, type, content_md, excerpt, tags, categories, status, published_at, is_featured) VALUES
  (
    '550e8400-e29b-41d4-a716-446655443000',
    '550e8400-e29b-41d4-a716-446655442000',
    '550e8400-e29b-41d4-a716-446655441002',
    'Welcome to Our New Blog',
    'welcome-to-our-new-blog',
    'post',
    '# Welcome to Our New Blog

We''re excited to launch our new company blog! This space will be dedicated to sharing industry insights, company updates, and thought leadership pieces.

## What to Expect

- Weekly industry analysis
- Product updates and announcements
- Behind-the-scenes content
- Guest posts from industry experts

Stay tuned for more great content!',
    'We''re excited to launch our new company blog with industry insights and company updates.',
    ARRAY['announcement', 'company'],
    ARRAY['general'],
    'published',
    NOW() - INTERVAL '2 days',
    true
  ),
  (
    '550e8400-e29b-41d4-a716-446655443001',
    '550e8400-e29b-41d4-a716-446655442000',
    '550e8400-e29b-41d4-a716-446655441002',
    'The Future of Multi-Tenant SaaS',
    'future-of-multi-tenant-saas',
    'post',
    '# The Future of Multi-Tenant SaaS

Multi-tenant Software as a Service (SaaS) architectures are becoming increasingly important in today''s cloud-first world. Let''s explore the key trends and technologies shaping this space.

## Key Benefits

1. **Cost Efficiency**: Shared infrastructure reduces per-tenant costs
2. **Scalability**: Easier to scale resources across multiple tenants
3. **Maintenance**: Centralized updates and maintenance
4. **Security**: Robust isolation between tenant data

## Implementation Strategies

When building multi-tenant SaaS applications, consider these architectural patterns:

- **Database per Tenant**: Maximum isolation but higher overhead
- **Shared Database with Tenant ID**: Good balance of isolation and efficiency
- **Row-Level Security**: Excellent for PostgreSQL-based solutions

## Conclusion

The future of multi-tenant SaaS lies in finding the right balance between isolation, performance, and cost-effectiveness.',
    'Exploring key trends and technologies in multi-tenant SaaS architectures.',
    ARRAY['saas', 'architecture', 'technology'],
    ARRAY['technology', 'analysis'],
    'published',
    NOW() - INTERVAL '5 days',
    false
  ),
  (
    '550e8400-e29b-41d4-a716-446655443002',
    '550e8400-e29b-41d4-a716-446655442001',
    '550e8400-e29b-41d4-a716-446655441001',
    'Project Alpha: E-commerce Platform',
    'project-alpha-ecommerce-platform',
    'post',
    '# Project Alpha: E-commerce Platform

Our latest project involves building a modern e-commerce platform with advanced features and seamless user experience.

## Project Overview

- **Duration**: 6 months
- **Team Size**: 8 developers
- **Technologies**: React, Node.js, PostgreSQL, Stripe
- **Status**: Completed

## Key Features

1. Real-time inventory management
2. Advanced search and filtering
3. Mobile-responsive design
4. Integrated payment processing
5. Multi-vendor support

## Challenges Solved

- Performance optimization for large product catalogs
- Complex pricing rules and discounts
- Secure payment processing
- Scalable architecture

## Results

The platform successfully handles 10,000+ concurrent users and processes over $1M in transactions monthly.',
    'A comprehensive e-commerce platform built with modern technologies.',
    ARRAY['ecommerce', 'react', 'nodejs'],
    ARRAY['projects', 'case-study'],
    'published',
    NOW() - INTERVAL '10 days',
    true
  ),
  (
    '550e8400-e29b-41d4-a716-446655443003',
    '550e8400-e29b-41d4-a716-446655442000',
    '550e8400-e29b-41d4-a716-446655441002',
    'Building Scalable APIs with Supabase',
    'building-scalable-apis-supabase',
    'post',
    '# Building Scalable APIs with Supabase

Supabase provides an excellent foundation for building scalable APIs. In this post, we''ll explore best practices and patterns.

## Getting Started

Supabase offers several ways to build APIs:
- Auto-generated REST APIs from your database schema
- Custom PostgreSQL functions
- Edge Functions for serverless computing

## Best Practices

1. **Database Design**: Start with a well-normalized schema
2. **Row Level Security**: Implement proper RLS policies
3. **Indexing**: Add appropriate indexes for performance
4. **Caching**: Use Redis or similar for frequently accessed data

## Example Implementation

```sql
-- Example RLS policy
CREATE POLICY "Users can access their own data" ON user_data
  FOR ALL USING (user_id = auth.uid());
```

This ensures users can only access their own data.',
    'Best practices for building scalable APIs using Supabase.',
    ARRAY['supabase', 'api', 'postgresql'],
    ARRAY['technology', 'tutorial'],
    'draft',
    NULL,
    false
  );

-- Insert sample tasks
INSERT INTO tasks (id, site_id, account_id, created_by, type, payload, status, priority) VALUES
  (
    '550e8400-e29b-41d4-a716-446655444000',
    '550e8400-e29b-41d4-a716-446655442000',
    '550e8400-e29b-41d4-a716-446655440000',
    '550e8400-e29b-41d4-a716-446655441002',
    'PUBLISH',
    '{"content_id": "550e8400-e29b-41d4-a716-446655443003", "target": "production"}',
    'QUEUED',
    5
  ),
  (
    '550e8400-e29b-41d4-a716-446655444001',
    '550e8400-e29b-41d4-a716-446655442000',
    '550e8400-e29b-41d4-a716-446655440000',
    '550e8400-e29b-41d4-a716-446655441001',
    'REBUILD_SITE',
    '{"full_rebuild": true, "trigger_reason": "theme_update"}',
    'SUCCEEDED',
    0
  ),
  (
    '550e8400-e29b-41d4-a716-446655444002',
    '550e8400-e29b-41d4-a716-446655442001',
    '550e8400-e29b-41d4-a716-446655440000',
    '550e8400-e29b-41d4-a716-446655441001',
    'RESEARCH',
    '{"topic": "latest web development trends", "create_draft": true}',
    'RUNNING',
    3
  );

-- Insert sample assets
INSERT INTO assets (id, account_id, site_id, uploaded_by, filename, original_filename, file_path, file_size, mime_type, width, height, alt_text, folder) VALUES
  (
    '550e8400-e29b-41d4-a716-446655445000',
    '550e8400-e29b-41d4-a716-446655440000',
    '550e8400-e29b-41d4-a716-446655442000',
    '550e8400-e29b-41d4-a716-446655441002',
    'hero-image.jpg',
    'company-hero-2024.jpg',
    'tenant-assets/550e8400-e29b-41d4-a716-446655440000/blog/hero-image.jpg',
    1024000,
    'image/jpeg',
    1920,
    1080,
    'Company hero image showing our office',
    'images'
  ),
  (
    '550e8400-e29b-41d4-a716-446655445001',
    '550e8400-e29b-41d4-a716-446655440000',
    '550e8400-e29b-41d4-a716-446655442001',
    '550e8400-e29b-41d4-a716-446655441001',
    'project-alpha-screenshot.png',
    'ecommerce-platform-demo.png',
    'tenant-assets/550e8400-e29b-41d4-a716-446655440000/projects/project-alpha-screenshot.png',
    2048000,
    'image/png',
    1600,
    900,
    'Screenshot of Project Alpha e-commerce platform',
    'projects'
  );

-- Update asset usage counts based on content references
UPDATE assets 
SET usage_count = 1, last_used_at = NOW()
WHERE id IN (
  '550e8400-e29b-41d4-a716-446655445000',
  '550e8400-e29b-41d4-a716-446655445001'
);

-- Update some task completion timestamps
UPDATE tasks 
SET 
  started_at = NOW() - INTERVAL '2 hours',
  completed_at = NOW() - INTERVAL '1 hour'
WHERE status = 'SUCCEEDED';

UPDATE tasks 
SET started_at = NOW() - INTERVAL '30 minutes'
WHERE status = 'RUNNING';

-- Insert sample site settings
UPDATE sites 
SET settings = jsonb_build_object(
  'auto_research', true,
  'publish_schedule', '@daily',
  'theme_config', jsonb_build_object(
    'primary_color', '#3b82f6',
    'font_family', 'Inter',
    'layout', 'centered'
  ),
  'seo', jsonb_build_object(
    'meta_description', 'Company blog featuring industry insights and updates',
    'keywords', ARRAY['technology', 'business', 'insights']
  )
)
WHERE slug = 'blog';

-- Insert sample account settings
UPDATE accounts 
SET settings = jsonb_build_object(
  'branding', jsonb_build_object(
    'logo_url', 'https://example.com/logo.png',
    'primary_color', '#3b82f6',
    'company_name', 'Example Organization'
  ),
  'notifications', jsonb_build_object(
    'email_on_publish', true,
    'weekly_digest', true,
    'security_alerts', true
  ),
  'integrations', jsonb_build_object(
    'analytics_tracking_id', 'GA-XXXXXXXXX',
    'slack_webhook_url', 'https://hooks.slack.com/...'
  )
)
WHERE slug = 'example-org';