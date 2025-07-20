# Implementation Guide

## Overview

This guide provides step-by-step instructions for implementing the Multi-Tenant SaaS architecture. Follow these steps to set up your own instance of the platform.

## Prerequisites

Before starting the implementation, ensure you have:

- Supabase account and project
- GitHub account with developer access
- Stripe account (for billing features)
- Node.js 18+ and npm/yarn
- Git and basic command line knowledge

## Phase 1: Supabase Project Setup

### 1. Create Supabase Project

1. Visit [supabase.com](https://supabase.com) and create a new project
2. Note your project URL and anon key
3. Enable the following in your Supabase dashboard:
   - Database (PostgreSQL)
   - Auth
   - Storage
   - Edge Functions

### 2. Database Schema Setup

Execute the SQL scripts in order:

```bash
# Connect to your Supabase project
psql "postgresql://postgres:[PASSWORD]@db.[PROJECT_REF].supabase.co:5432/postgres"

# Run schema creation scripts
\i docs/sql/01-create-tables.sql
\i docs/sql/02-create-indexes.sql
\i docs/sql/03-create-rls-policies.sql
\i docs/sql/04-create-functions.sql
\i docs/sql/05-sample-data.sql
```

### 3. Storage Bucket Configuration

Create storage buckets with appropriate policies:

```sql
-- Create tenant-specific storage buckets
INSERT INTO storage.buckets (id, name, public) VALUES 
  ('tenant-assets', 'tenant-assets', true),
  ('tenant-uploads', 'tenant-uploads', false);

-- Create storage policies
CREATE POLICY "Tenant asset access" ON storage.objects FOR ALL 
  USING (bucket_id = 'tenant-assets' AND auth.current_user_account_id()::text = (storage.foldername(name))[1]);
```

### 4. Auth Configuration

Configure authentication providers in Supabase dashboard:

1. **Email/Password**: Enable in Auth settings
2. **Magic Links**: Configure email templates
3. **Social Providers**: 
   - GitHub (for repository integration)
   - Google (optional)
4. **JWT Settings**: Configure custom claims for tenant context

## Phase 2: GitHub Integration Setup

### 1. Create GitHub App

1. Go to GitHub Settings > Developer Settings > GitHub Apps
2. Create new GitHub App with permissions:
   - Repository: Read & Write
   - Contents: Read & Write
   - Actions: Read & Write
   - Metadata: Read

3. Generate and securely store:
   - App ID
   - Private key
   - Webhook secret

### 2. Repository Template Creation

Create a template repository with the following structure:

```bash
mkdir saas-site-template
cd saas-site-template

# Initialize repository
git init
git remote add origin https://github.com/[YOUR-ORG]/saas-site-template.git

# Create directory structure
mkdir -p .github/workflows
mkdir -p sites/{blog,projects}/content
mkdir -p docker/nlweb
mkdir -p scripts

# Create GitHub Actions workflows
touch .github/workflows/{build.yml,deploy.yml}

# Create site configurations
touch sites/blog/config.yaml
touch sites/projects/config.yaml

# Create setup scripts
touch scripts/{setup.sh,deploy.sh}
chmod +x scripts/*.sh
```

### 3. GitHub Actions Setup

Create workflow files:

**.github/workflows/build.yml**:
```yaml
name: Build Sites
on:
  push:
    paths: ['sites/**']
  workflow_dispatch:

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      sites: ${{ steps.changes.outputs.sites }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v2
        id: changes
        with:
          filters: |
            blog:
              - 'sites/blog/**'
            projects:
              - 'sites/projects/**'
      - id: changes
        run: |
          sites="[]"
          if [[ "${{ steps.changes.outputs.blog }}" == "true" ]]; then
            sites=$(echo "$sites" | jq '. += ["blog"]')
          fi
          if [[ "${{ steps.changes.outputs.projects }}" == "true" ]]; then
            sites=$(echo "$sites" | jq '. += ["projects"]')
          fi
          echo "sites=$sites" >> $GITHUB_OUTPUT

  build:
    needs: detect-changes
    if: needs.detect-changes.outputs.sites != '[]'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        site: ${{ fromJson(needs.detect-changes.outputs.sites) }}
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Hugo
        uses: peaceiris/actions-hugo@v2
        with:
          hugo-version: '0.120.0'
          extended: true
          
      - name: Build Site
        run: |
          cd sites/${{ matrix.site }}
          hugo --minify --baseURL="${{ vars.BASE_URL }}/${{ matrix.site }}"
          
      - name: Upload Build Artifacts
        uses: actions/upload-artifact@v3
        with:
          name: ${{ matrix.site }}-build
          path: sites/${{ matrix.site }}/public/
          retention-days: 1
```

**.github/workflows/deploy.yml**:
```yaml
name: Deploy Sites
on:
  workflow_run:
    workflows: ["Build Sites"]
    types: [completed]

jobs:
  deploy:
    if: github.event.workflow_run.conclusion == 'success'
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Download All Artifacts
        uses: actions/download-artifact@v3
        
      - name: Setup Deployment Directory
        run: |
          mkdir -p public
          for site in blog projects; do
            if [ -d "${site}-build" ]; then
              mkdir -p "public/${site}"
              cp -r "${site}-build/"* "public/${site}/"
            fi
          done
          
      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./public
          cname: ${{ vars.CUSTOM_DOMAIN }}
          
      - name: Notify Deployment Webhook
        if: vars.DEPLOYMENT_WEBHOOK_URL
        run: |
          curl -X POST "${{ vars.DEPLOYMENT_WEBHOOK_URL }}" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${{ secrets.WEBHOOK_TOKEN }}" \
            -d '{
              "event": "deployment_complete",
              "repository": "${{ github.repository }}",
              "commit": "${{ github.sha }}",
              "sites": ["blog", "projects"],
              "url": "https://${{ vars.CUSTOM_DOMAIN || github.repository_owner }}.github.io/${{ github.event.repository.name }}"
            }'
```

## Phase 3: Backend Worker Service

### 1. Worker Service Setup

Create a new Node.js project for the worker service:

```bash
mkdir saas-worker
cd saas-worker
npm init -y

# Install dependencies
npm install @supabase/supabase-js @octokit/rest dotenv
npm install -D @types/node typescript ts-node nodemon

# Create TypeScript configuration
cat > tsconfig.json << EOF
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
EOF
```

### 2. Core Worker Implementation

**src/worker.ts**:
```typescript
import { createClient } from '@supabase/supabase-js';
import { Octokit } from '@octokit/rest';
import { TaskProcessor } from './processors/TaskProcessor';
import { GitHubService } from './services/GitHubService';

export class SaaSWorker {
  private supabase;
  private taskProcessor;
  private githubService;

  constructor() {
    this.supabase = createClient(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_KEY!
    );
    
    this.githubService = new GitHubService();
    this.taskProcessor = new TaskProcessor(this.supabase, this.githubService);
  }

  async start() {
    console.log('Starting SaaS Worker...');
    
    // Start real-time subscription
    this.setupRealtimeSubscription();
    
    // Start polling for queued tasks
    this.startTaskPolling();
    
    console.log('Worker started successfully');
  }

  private setupRealtimeSubscription() {
    this.supabase
      .channel('task-changes')
      .on('postgres_changes', 
        { event: 'INSERT', schema: 'public', table: 'tasks' },
        (payload) => this.handleNewTask(payload.new)
      )
      .subscribe();
  }

  private async handleNewTask(task: any) {
    if (task.priority > 50) {
      // Process high-priority tasks immediately
      await this.taskProcessor.processTask(task);
    }
  }

  private startTaskPolling() {
    setInterval(async () => {
      await this.taskProcessor.pollAndProcessTasks();
    }, 30000); // Poll every 30 seconds
  }
}

// Start the worker
if (require.main === module) {
  const worker = new SaaSWorker();
  worker.start().catch(console.error);
}
```

### 3. Task Processors

**src/processors/TaskProcessor.ts**:
```typescript
import { SupabaseClient } from '@supabase/supabase-js';
import { GitHubService } from '../services/GitHubService';

export class TaskProcessor {
  constructor(
    private supabase: SupabaseClient,
    private githubService: GitHubService
  ) {}

  async pollAndProcessTasks() {
    const { data: tasks } = await this.supabase
      .from('tasks')
      .select('*')
      .eq('status', 'QUEUED')
      .lte('scheduled_for', new Date().toISOString())
      .order('priority', { ascending: false })
      .order('created_at', { ascending: true })
      .limit(10);

    if (tasks) {
      for (const task of tasks) {
        await this.processTask(task);
      }
    }
  }

  async processTask(task: any) {
    try {
      await this.updateTaskStatus(task.id, 'RUNNING');
      
      let result;
      switch (task.type) {
        case 'PUBLISH':
          result = await this.handlePublishTask(task);
          break;
        case 'UPLOAD_CONTENT':
          result = await this.handleUploadTask(task);
          break;
        case 'REBUILD_SITE':
          result = await this.handleRebuildTask(task);
          break;
        default:
          throw new Error(`Unknown task type: ${task.type}`);
      }
      
      await this.updateTaskStatus(task.id, 'SUCCEEDED', result);
    } catch (error) {
      await this.handleTaskError(task, error);
    }
  }

  private async handlePublishTask(task: any) {
    const { content_id } = task.payload;
    
    // Fetch content and site information
    const { data: content } = await this.supabase
      .from('content')
      .select('*, sites(*)')
      .eq('id', content_id)
      .single();

    if (!content) {
      throw new Error('Content not found');
    }

    // Convert to Hugo markdown
    const markdownContent = this.convertToHugoMarkdown(content);
    
    // Push to GitHub repository
    await this.githubService.publishContent(
      content.sites.repo_url,
      content.slug,
      markdownContent,
      `Publish: ${content.title}`
    );

    return { published: true, content_id };
  }

  private convertToHugoMarkdown(content: any): string {
    const frontMatter = {
      title: content.title,
      date: content.created_at,
      draft: content.status !== 'published',
      tags: content.tags || [],
      categories: content.categories || []
    };

    const yamlFrontMatter = Object.entries(frontMatter)
      .map(([key, value]) => `${key}: ${JSON.stringify(value)}`)
      .join('\n');

    return `---\n${yamlFrontMatter}\n---\n\n${content.content_md}`;
  }

  private async updateTaskStatus(taskId: string, status: string, result?: any) {
    const updates: any = { status };
    
    if (status === 'RUNNING') {
      updates.started_at = new Date().toISOString();
    } else if (['SUCCEEDED', 'FAILED'].includes(status)) {
      updates.completed_at = new Date().toISOString();
      if (result) {
        updates.result = result;
      }
    }

    await this.supabase
      .from('tasks')
      .update(updates)
      .eq('id', taskId);
  }
}
```

## Phase 4: Frontend Application

### 1. Next.js Application Setup

```bash
npx create-next-app@latest saas-frontend --typescript --tailwind --app
cd saas-frontend

# Install Supabase and additional dependencies
npm install @supabase/supabase-js @supabase/auth-ui-react
npm install lucide-react @radix-ui/react-dialog @radix-ui/react-dropdown-menu
```

### 2. Supabase Client Configuration

**lib/supabase.ts**:
```typescript
import { createClientComponentClient, createServerComponentClient } from '@supabase/auth-helpers-nextjs';
import { cookies } from 'next/headers';

export const createClient = () => createClientComponentClient();

export const createServerClient = () => createServerComponentClient({ cookies });
```

### 3. Authentication Setup

**app/auth/page.tsx**:
```typescript
'use client';

import { Auth } from '@supabase/auth-ui-react';
import { ThemeSupa } from '@supabase/auth-ui-shared';
import { createClient } from '@/lib/supabase';

export default function AuthPage() {
  const supabase = createClient();

  return (
    <div className="flex items-center justify-center min-h-screen bg-gray-50">
      <div className="max-w-md w-full space-y-8 p-8 bg-white rounded-lg shadow-md">
        <div className="text-center">
          <h2 className="text-3xl font-bold text-gray-900">
            Sign in to your account
          </h2>
        </div>
        
        <Auth
          supabaseClient={supabase}
          appearance={{ theme: ThemeSupa }}
          theme="light"
          providers={['github', 'google']}
          redirectTo={`${window.location.origin}/dashboard`}
        />
      </div>
    </div>
  );
}
```

## Phase 5: Deployment and Production Setup

### 1. Environment Configuration

Create environment files for different stages:

**.env.local** (Development):
```env
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_KEY=your_service_key

GITHUB_APP_ID=your_github_app_id
GITHUB_PRIVATE_KEY=your_github_private_key
GITHUB_WEBHOOK_SECRET=your_webhook_secret

STRIPE_SECRET_KEY=your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=your_stripe_webhook_secret
```

### 2. Docker Configuration

**Dockerfile** (Worker Service):
```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY dist ./dist

EXPOSE 3000

CMD ["node", "dist/worker.js"]
```

**docker-compose.yml** (Development):
```yaml
version: '3.8'

services:
  worker:
    build: .
    environment:
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_SERVICE_KEY=${SUPABASE_SERVICE_KEY}
      - GITHUB_APP_ID=${GITHUB_APP_ID}
      - GITHUB_PRIVATE_KEY=${GITHUB_PRIVATE_KEY}
    volumes:
      - ./src:/app/src
    command: npm run dev

  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    environment:
      - NEXT_PUBLIC_SUPABASE_URL=${NEXT_PUBLIC_SUPABASE_URL}
      - NEXT_PUBLIC_SUPABASE_ANON_KEY=${NEXT_PUBLIC_SUPABASE_ANON_KEY}
    volumes:
      - ./frontend:/app
      - /app/node_modules
```

### 3. Production Deployment

#### Vercel Deployment (Frontend)
```bash
npm install -g vercel
vercel --prod
```

#### Fly.io Deployment (Worker)
```bash
# Install Fly CLI
curl -L https://fly.io/install.sh | sh

# Initialize Fly app
fly apps create saas-worker

# Configure secrets
fly secrets set SUPABASE_URL=your_url
fly secrets set SUPABASE_SERVICE_KEY=your_key

# Deploy
fly deploy
```

## Phase 6: Testing and Validation

### 1. Database Testing
```sql
-- Test tenant isolation
SET LOCAL rls.tenant_id = 'tenant-1-uuid';
SELECT * FROM sites; -- Should only return tenant-1 sites

-- Test task processing
INSERT INTO tasks (site_id, type, payload, account_id) VALUES (
  'test-site-uuid',
  'PUBLISH',
  '{"content_id": "test-content-uuid"}',
  'test-account-uuid'
);
```

### 2. API Testing
```bash
# Test task creation endpoint
curl -X POST http://localhost:3000/api/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_token" \
  -d '{"type": "PUBLISH", "site_id": "test-site-id"}'
```

### 3. End-to-End Testing
1. Create test account and user
2. Create test site and content
3. Trigger publish workflow
4. Verify GitHub repository updates
5. Confirm site deployment

## Next Steps

After completing the basic implementation:

1. **Add Premium Features**:
   - AI-powered content generation
   - Advanced analytics
   - Custom themes and branding

2. **Implement Billing**:
   - Stripe integration for subscriptions
   - Usage-based billing
   - Plan upgrade/downgrade flows

3. **Add Monitoring**:
   - Application performance monitoring
   - Error tracking and alerting
   - Usage analytics

4. **Scale Infrastructure**:
   - Load balancing for worker services
   - Database optimization
   - CDN integration for global performance

5. **Security Hardening**:
   - Security audit and penetration testing
   - Rate limiting and DDoS protection
   - Data encryption at rest and in transit