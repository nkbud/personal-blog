#!/bin/bash

# Setup script for Hugo multi-site architecture
set -e

REPO_ROOT="/home/runner/work/personal-blog/personal-blog"
SITES_DIR="$REPO_ROOT/sites"

# List of sites to configure
SITES=("projects" "services" "research" "hobbies" "tutorials" "technology" "academics")

# Configure each site
for site in "${SITES[@]}"; do
    echo "Configuring site: $site"
    
    # Configure hugo.toml
    cat > "$SITES_DIR/$site/hugo.toml" << EOF
baseURL = '/$site/'
languageCode = 'en-us'
title = '${site^} - oioio.ai'
publishDir = '../../public/$site'
theme = '${site}-theme'
EOF

    # Create a simple theme
    mkdir -p "$SITES_DIR/$site/themes/${site}-theme"
    
    # Create theme.toml
    cat > "$SITES_DIR/$site/themes/${site}-theme/theme.toml" << EOF
name = "${site^} Theme"
license = "MIT"
licenselink = ""
description = "A simple theme for the $site section"
min_version = "0.100.0"

[author]
  name = "oioio.ai"
EOF

    # Create basic layouts
    mkdir -p "$SITES_DIR/$site/themes/${site}-theme/layouts/_default"
    
    # Create baseof.html
    cat > "$SITES_DIR/$site/themes/${site}-theme/layouts/_default/baseof.html" << EOF
<!DOCTYPE html>
<html lang="{{ .Site.Language.Lang }}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ .Title }} - {{ .Site.Title }}</title>
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
            max-width: 800px; 
            margin: 40px auto; 
            padding: 20px; 
            line-height: 1.6; 
            color: #333;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .container {
            background: white;
            border-radius: 10px;
            padding: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        h1 { 
            color: #2c3e50; 
            border-bottom: 3px solid #3498db; 
            padding-bottom: 10px; 
        }
        h2 { color: #34495e; }
        a { 
            color: #3498db; 
            text-decoration: none; 
        }
        a:hover { 
            text-decoration: underline; 
        }
        .nav { 
            margin-bottom: 30px; 
            padding: 15px 0; 
            border-bottom: 1px solid #ecf0f1; 
        }
        .nav a { 
            margin-right: 20px; 
            font-weight: 500; 
        }
        .meta { 
            color: #7f8c8d; 
            font-size: 0.9em; 
            margin-bottom: 20px; 
        }
        .section-title {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            font-size: 2.5em;
            font-weight: bold;
            text-align: center;
            margin-bottom: 30px;
        }
    </style>
</head>
<body>
    <div class="container">
        <nav class="nav">
            <a href="/">Home</a>
            <a href="/projects/">Projects</a>
            <a href="/services/">Services</a>
            <a href="/research/">Research</a>
            <a href="/hobbies/">Hobbies</a>
            <a href="/tutorials/">Tutorials</a>
            <a href="/technology/">Technology</a>
            <a href="/academics/">Academics</a>
        </nav>
        
        <div class="section-title">${site^}</div>
        
        <main>
            {{ block "main" . }}{{ end }}
        </main>
    </div>
</body>
</html>
EOF

    # Create list.html
    cat > "$SITES_DIR/$site/themes/${site}-theme/layouts/_default/list.html" << EOF
{{ define "main" }}
<h1>{{ .Title }}</h1>
<p>{{ .Content }}</p>

{{ if .Pages }}
<h2>Latest Posts</h2>
{{ range .Pages }}
<article>
    <h3><a href="{{ .RelPermalink }}">{{ .Title }}</a></h3>
    <div class="meta">{{ .Date.Format "January 2, 2006" }}</div>
    <p>{{ .Summary }}</p>
</article>
{{ end }}
{{ else }}
<p>Welcome to the {{ .Title }} section! Content coming soon.</p>
{{ end }}
{{ end }}
EOF

    # Create single.html
    cat > "$SITES_DIR/$site/themes/${site}-theme/layouts/_default/single.html" << EOF
{{ define "main" }}
<article>
    <h1>{{ .Title }}</h1>
    <div class="meta">{{ .Date.Format "January 2, 2006" }}</div>
    <div>{{ .Content }}</div>
</article>
{{ end }}
EOF

    # Create index.html
    cat > "$SITES_DIR/$site/themes/${site}-theme/layouts/index.html" << EOF
{{ define "main" }}
<h1>Welcome to {{ .Site.Title }}</h1>
<p>This is the main page for the $site section of oioio.ai.</p>

{{ if .Site.Pages }}
<h2>Latest Content</h2>
{{ range first 5 .Site.RegularPages }}
<article>
    <h3><a href="{{ .RelPermalink }}">{{ .Title }}</a></h3>
    <div class="meta">{{ .Date.Format "January 2, 2006" }}</div>
    <p>{{ .Summary }}</p>
</article>
{{ end }}
{{ else }}
<p>Content for this section is coming soon!</p>
{{ end }}
{{ end }}
EOF

    # Create sample content
    mkdir -p "$SITES_DIR/$site/content"
    cat > "$SITES_DIR/$site/content/_index.md" << EOF
---
title: "${site^}"
date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
---

Welcome to the $site section of oioio.ai. This section will contain content related to $site.
EOF

    # Create a sample post
    mkdir -p "$SITES_DIR/$site/content/posts"
    cat > "$SITES_DIR/$site/content/posts/welcome.md" << EOF
---
title: "Welcome to ${site^}"
date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
draft: false
---

This is a sample post for the $site section. Replace this content with your actual $site-related content.

## What you'll find here

- Content related to $site
- Updates and announcements
- Resources and guides

Stay tuned for more content!
EOF

    echo "Site $site configured successfully!"
done

echo "All sites configured!"