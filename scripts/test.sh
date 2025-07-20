#!/bin/bash

# Test script for Hugo multi-site architecture
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

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    exit 1
}

SITES=("projects" "services" "research" "hobbies" "tutorials" "technology" "academics")

print_test "Starting Hugo multi-site architecture validation..."

# Test 1: Check directory structure
print_test "Validating directory structure..."
for dir in "sites" "scripts" "public"; do
    if [ -d "$REPO_ROOT/$dir" ]; then
        print_pass "Directory $dir exists"
    else
        print_fail "Directory $dir missing"
    fi
done

# Test 2: Check CNAME file
print_test "Validating CNAME configuration..."
if [ -f "$REPO_ROOT/CNAME" ]; then
    content=$(cat "$REPO_ROOT/CNAME")
    if [ "$content" = "oioio.ai" ]; then
        print_pass "CNAME file configured correctly"
    else
        print_fail "CNAME file has incorrect content: $content"
    fi
else
    print_fail "CNAME file missing"
fi

# Test 3: Check each site structure
print_test "Validating individual site structures..."
for site in "${SITES[@]}"; do
    site_path="$SITES_DIR/$site"
    
    if [ ! -d "$site_path" ]; then
        print_fail "Site directory missing: $site"
    fi
    
    # Check config file
    if [ ! -f "$site_path/hugo.toml" ]; then
        print_fail "Config file missing for site: $site"
    fi
    
    # Check theme directory
    if [ ! -d "$site_path/themes/${site}-theme" ]; then
        print_fail "Theme directory missing for site: $site"
    fi
    
    # Check content directory
    if [ ! -d "$site_path/content" ]; then
        print_fail "Content directory missing for site: $site"
    fi
    
    print_pass "Site $site structure is valid"
done

# Test 4: Check site configurations
print_test "Validating site configurations..."
for site in "${SITES[@]}"; do
    config_file="$SITES_DIR/$site/hugo.toml"
    
    # Check baseURL
    if grep -q "baseURL = '/$site/'" "$config_file"; then
        print_pass "Site $site has correct baseURL"
    else
        print_fail "Site $site has incorrect baseURL"
    fi
    
    # Check publishDir
    if grep -q "publishDir = '../../public/$site'" "$config_file"; then
        print_pass "Site $site has correct publishDir"
    else
        print_fail "Site $site has incorrect publishDir"
    fi
    
    # Check theme
    if grep -q "theme = '${site}-theme'" "$config_file"; then
        print_pass "Site $site has correct theme"
    else
        print_fail "Site $site has incorrect theme"
    fi
done

# Test 5: Test individual site builds
print_test "Testing individual site builds..."
for site in "${SITES[@]}"; do
    if hugo -s "$SITES_DIR/$site" --quiet; then
        print_pass "Site $site builds successfully"
    else
        print_fail "Site $site failed to build"
    fi
done

# Test 6: Test deployment script
print_test "Testing deployment script..."
if [ -f "$REPO_ROOT/scripts/deploy.sh" ]; then
    if [ -x "$REPO_ROOT/scripts/deploy.sh" ]; then
        print_pass "Deployment script exists and is executable"
    else
        print_fail "Deployment script is not executable"
    fi
else
    print_fail "Deployment script missing"
fi

# Test 7: Test full deployment
print_test "Testing full deployment build..."
if "$REPO_ROOT/scripts/deploy.sh" > /dev/null 2>&1; then
    print_pass "Full deployment completed successfully"
else
    print_fail "Full deployment failed"
fi

# Test 8: Check generated public structure
print_test "Validating generated public structure..."
for site in "${SITES[@]}"; do
    if [ -d "$PUBLIC_DIR/$site" ]; then
        if [ -f "$PUBLIC_DIR/$site/index.html" ]; then
            print_pass "Site $site generated correctly in public/"
        else
            print_fail "Site $site missing index.html in public/"
        fi
    else
        print_fail "Site $site directory missing in public/"
    fi
done

# Test 9: Check main landing page
print_test "Validating main landing page..."
if [ -f "$PUBLIC_DIR/index.html" ]; then
    if grep -q "oioio.ai" "$PUBLIC_DIR/index.html"; then
        print_pass "Main landing page generated correctly"
    else
        print_fail "Main landing page missing oioio.ai branding"
    fi
else
    print_fail "Main landing page missing"
fi

# Test 10: Check CNAME in public
print_test "Validating CNAME in public directory..."
if [ -f "$PUBLIC_DIR/CNAME" ]; then
    content=$(cat "$PUBLIC_DIR/CNAME")
    if [ "$content" = "oioio.ai" ]; then
        print_pass "CNAME correctly copied to public/"
    else
        print_fail "CNAME in public/ has incorrect content"
    fi
else
    print_fail "CNAME file missing from public/"
fi

print_test "All tests completed successfully! 🎉"
echo -e "${GREEN}Hugo multi-site architecture is working correctly.${NC}"