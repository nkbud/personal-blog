# oioio.ai - Scalable Hugo Multi-Site Architecture

A scalable Hugo architecture that treats each major content section as an independent Hugo site with its own theme and content. All sites are served under https://oioio.ai/ from a single GitHub repo via GitHub Pages.

## 📁 Repository Structure

```
oioio-ai/
├── CNAME                          # Domain configuration for GitHub Pages
├── public/                        # Combined static output for all sites
├── scripts/
│   ├── deploy.sh                  # Multi-site build + deploy script
│   └── setup_sites.sh            # Site configuration setup script
└── sites/
    ├── projects/                  # Hugo site: oioio.ai/projects
    ├── services/                  # Hugo site: oioio.ai/services
    ├── research/                  # Hugo site: oioio.ai/research
    ├── hobbies/                   # Hugo site: oioio.ai/hobbies
    ├── tutorials/                 # Hugo site: oioio.ai/tutorials
    ├── technology/                # Hugo site: oioio.ai/technology
    └── academics/                 # Hugo site: oioio.ai/academics
```

## 🧱 Individual Hugo Sites

Each Hugo site in the `sites/` directory:

- **Is independently buildable**: `hugo -s sites/<section>`
- **Defines**:
  - `baseURL = "/<section>/"`
  - `publishDir = "../../public/<section>"`
- **Includes**:
  - Its own `hugo.toml` configuration
  - A unique theme in `themes/<section>-theme`
  - Section-specific content in `content/`

## 🚀 Building and Deployment

### Build Individual Sites

```bash
# Build a specific site
hugo -s sites/projects

# Build with development server
hugo server -s sites/projects
```

### Build All Sites

```bash
# Run the deployment script
./scripts/deploy.sh

# Build and deploy to gh-pages branch
./scripts/deploy.sh --deploy
```

### Deployment Script Features

The `scripts/deploy.sh` script:
- ✅ Cleans and rebuilds all sites into their respective folders in `/public`
- ✅ Copies `CNAME` into `/public`
- ✅ Creates a main landing page connecting all sections
- ✅ Optionally commits and pushes to `gh-pages` branch
- ✅ Provides colored output for build status
- ✅ Validates site configurations before building

## 🎨 Themes

Each site has its own unique theme with:
- Custom layouts for list and single pages
- Responsive design with gradient styling
- Navigation between all sections
- Section-specific branding and colors

## 📝 Content Management

### Adding Content

```bash
# Add content to a specific site
hugo new content posts/my-post.md -s sites/projects

# Or create manually
mkdir -p sites/projects/content/posts
touch sites/projects/content/posts/my-post.md
```

### Content Structure

Each site follows standard Hugo content organization:
```
sites/<section>/
├── content/
│   ├── _index.md              # Section homepage
│   └── posts/
│       ├── _index.md          # Posts list page
│       └── welcome.md         # Sample post
```

## 🔧 Configuration

Each site's `hugo.toml` contains:
```toml
baseURL = '/<section>/'
languageCode = 'en-us'
title = '<Section> - oioio.ai'
publishDir = '../../public/<section>'
theme = '<section>-theme'
```

## 🌐 Live Sites

When deployed, the architecture provides:

- **Main site**: https://oioio.ai/ (landing page with links to all sections)
- **Projects**: https://oioio.ai/projects/
- **Services**: https://oioio.ai/services/
- **Research**: https://oioio.ai/research/
- **Hobbies**: https://oioio.ai/hobbies/
- **Tutorials**: https://oioio.ai/tutorials/
- **Technology**: https://oioio.ai/technology/
- **Academics**: https://oioio.ai/academics/

## 📋 Development Workflow

1. **Create content** for a specific section
2. **Test locally** with `hugo server -s sites/<section>`
3. **Build individually** or use the deployment script
4. **Deploy** to GitHub Pages with `./scripts/deploy.sh --deploy`

## 🛠️ Setup

If you need to reconfigure the sites or add new ones, use:

```bash
./scripts/setup_sites.sh
```

This script will recreate all site configurations, themes, and sample content.
