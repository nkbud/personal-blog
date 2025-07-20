#!/bin/bash

# Multi-site Hugo build and deployment script
set -e

REPO_ROOT="/home/runner/work/personal-blog/personal-blog"
SITES_DIR="$REPO_ROOT/sites"
PUBLIC_DIR="$REPO_ROOT/public"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# List of sites to build
SITES=("projects" "services" "research" "hobbies" "tutorials" "technology" "academics")

print_status "Starting multi-site Hugo build and deployment..."

# Clean public directory
print_status "Cleaning public directory..."
rm -rf "$PUBLIC_DIR"
mkdir -p "$PUBLIC_DIR"

# Copy CNAME file to public directory
if [ -f "$REPO_ROOT/CNAME" ]; then
    print_status "Copying CNAME file..."
    cp "$REPO_ROOT/CNAME" "$PUBLIC_DIR/"
else
    print_warning "CNAME file not found at $REPO_ROOT/CNAME"
fi

# Build each site
for site in "${SITES[@]}"; do
    site_path="$SITES_DIR/$site"
    
    if [ ! -d "$site_path" ]; then
        print_error "Site directory not found: $site_path"
        continue
    fi
    
    print_status "Building site: $site"
    
    # Check if site has a valid config
    if [ ! -f "$site_path/hugo.toml" ] && [ ! -f "$site_path/config.toml" ] && [ ! -f "$site_path/config.yaml" ]; then
        print_error "No configuration file found for site: $site"
        continue
    fi
    
    # Build the site
    if hugo -s "$site_path" --quiet; then
        print_success "Successfully built site: $site"
    else
        print_error "Failed to build site: $site"
        exit 1
    fi
done

# Create a main index.html file that redirects to projects or shows a landing page
cat > "$PUBLIC_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>oioio.ai - Multi-site Portfolio</title>
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
            margin: 0; 
            padding: 0; 
            min-height: 100vh;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: white;
            border-radius: 15px;
            padding: 50px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 600px;
        }
        h1 { 
            color: #2c3e50; 
            font-size: 3em;
            margin-bottom: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .subtitle {
            color: #7f8c8d;
            font-size: 1.2em;
            margin-bottom: 40px;
        }
        .sections {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-top: 40px;
        }
        .section-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 10px;
            text-decoration: none;
            transition: transform 0.3s ease;
        }
        .section-card:hover {
            transform: translateY(-5px);
        }
        .section-title {
            font-weight: bold;
            font-size: 1.1em;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>oioio.ai</h1>
        <p class="subtitle">Scalable Multi-Site Architecture</p>
        
        <div class="sections">
            <a href="/projects/" class="section-card">
                <div class="section-title">Projects</div>
            </a>
            <a href="/services/" class="section-card">
                <div class="section-title">Services</div>
            </a>
            <a href="/research/" class="section-card">
                <div class="section-title">Research</div>
            </a>
            <a href="/hobbies/" class="section-card">
                <div class="section-title">Hobbies</div>
            </a>
            <a href="/tutorials/" class="section-card">
                <div class="section-title">Tutorials</div>
            </a>
            <a href="/technology/" class="section-card">
                <div class="section-title">Technology</div>
            </a>
            <a href="/academics/" class="section-card">
                <div class="section-title">Academics</div>
            </a>
        </div>
    </div>
</body>
</html>
EOF

print_success "Created main landing page"

# Optional: Deploy to gh-pages branch
if [ "$1" = "--deploy" ]; then
    print_status "Deploying to gh-pages branch..."
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not in a git repository"
        exit 1
    fi
    
    # Stash any uncommitted changes
    git stash push -m "Stash before deployment"
    
    # Create or switch to gh-pages branch
    if git show-ref --verify --quiet refs/heads/gh-pages; then
        git checkout gh-pages
    else
        git checkout --orphan gh-pages
        git rm -rf .
    fi
    
    # Copy public contents to root
    cp -r "$PUBLIC_DIR"/* .
    
    # Add all files
    git add .
    
    # Commit changes
    if git commit -m "Deploy sites - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"; then
        print_success "Changes committed to gh-pages branch"
        
        # Push to origin
        if git push origin gh-pages; then
            print_success "Deployed to gh-pages branch"
        else
            print_error "Failed to push to gh-pages branch"
        fi
    else
        print_warning "No changes to commit"
    fi
    
    # Switch back to main branch
    git checkout main
    git stash pop || true
fi

print_success "Multi-site build completed!"
print_status "Total sites built: ${#SITES[@]}"
print_status "Output directory: $PUBLIC_DIR"

# Show directory structure
print_status "Built site structure:"
ls -la "$PUBLIC_DIR"