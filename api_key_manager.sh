#!/bin/bash
#
# HNM API Key Manager
# Comprehensive API key management and troubleshooting for Huddle Node Manager
# Manages access to Huddle Network ML services (embeddings, OCR, NLP, transcription)
#

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
API_KEY_FILE="$HOME/.ipfs/huddle_network_api_key"
API_CONFIG_FILE="$HOME/.ipfs/apim_config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ASCII Art Logo
show_logo() {
cat << "EOF"
┌─────────────────────────────────────────────────────────────────┐
│                🔑 HUDDLE NETWORK API KEY MANAGER               │
│                                                                 │
│  🔧 Comprehensive API Key Management                           │
│  🛠️ Troubleshooting & Recovery Tools                          │
│  ✅ Multi-Service Verification                                 │
│  🔄 Automatic Setup & Configuration                            │
│  🌐 Huddle Network ML Services Integration                     │
└─────────────────────────────────────────────────────────────────┘
EOF
echo ""
}

# Function to ensure directories exist
ensure_directories() {
    mkdir -p "$HOME/.ipfs"
    return 0
}

# Function to check if API key exists
api_key_exists() {
    if [ -f "$API_KEY_FILE" ] && [ -s "$API_KEY_FILE" ]; then
        return 0
    fi
    return 1
}

# Function to get available services dynamically
get_available_services() {
    if [ -f "$API_CONFIG_FILE" ] && command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json
try:
    with open('$API_CONFIG_FILE', 'r') as f:
        config = json.load(f)
    services = list(config.get('services', {}).keys())
    if services:
        print(', '.join(services))
    else:
        print('No services configured')
except:
    print('Unable to read services')
" 2>/dev/null
    else
        echo "embeddings, OCR, NLP, transcription"  # fallback
    fi
}

# Function to get developer portal URL dynamically
get_developer_portal_url() {
    if [ -f "$API_CONFIG_FILE" ] && command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json
try:
    with open('$API_CONFIG_FILE', 'r') as f:
        config = json.load(f)
    base_url = config.get('base_url', 'https://huddleai-apim.azure-api.net')
    # Convert API URL to developer portal URL
    portal_url = base_url.replace('.azure-api.net', '.developer.azure-api.net')
    print(portal_url)
except:
    print('https://huddleai-apim.developer.azure-api.net')
" 2>/dev/null
    else
        echo "https://huddleai-apim.developer.azure-api.net"  # fallback
    fi
}

# Function to get API key from file or environment
get_api_key() {
    # Check new environment variable
    if [ ! -z "$HUDDLE_NETWORK_API_KEY" ]; then
        echo "$HUDDLE_NETWORK_API_KEY"
        return 0
    fi
    
    # Check new file location
    if api_key_exists; then
        cat "$API_KEY_FILE"
        return 0
    fi
    
    return 1
}

# Function to save API key
save_api_key() {
    local api_key="$1"
    
    if [ -z "$api_key" ]; then
        echo -e "${RED}❌ No API key provided to save${NC}"
        return 1
    fi
    
    ensure_directories
    
    echo "$api_key" > "$API_KEY_FILE"
    chmod 600 "$API_KEY_FILE"
    export HUDDLE_NETWORK_API_KEY="$api_key"
    
    echo -e "${GREEN}✅ API key saved successfully${NC}"
    return 0
}

# Function to prompt for API key
prompt_for_api_key() {
    echo -e "${YELLOW}⚠️ Huddle Network API key not found${NC}"
    local portal_url=$(get_developer_portal_url)
    echo -e "${BLUE}Please obtain your API key from: $portal_url${NC}"
    echo ""
    echo "Enter your Huddle Network API key:"
    read -r -s API_KEY
    
    if [ -z "$API_KEY" ]; then
        echo -e "${RED}❌ No API key provided${NC}"
        return 1
    fi
    
    save_api_key "$API_KEY"
    return 0
}

# Function to verify API key with specific service
verify_service() {
    local service="$1"
    local api_key="$2"
    
    if [ -z "$api_key" ]; then
        return 1
    fi
    
    echo -e "${BLUE}🔍 Verifying $service service...${NC}"
    
    # Use Python API client to verify key
    VERIFY_RESULT=$(cd "$SCRIPT_DIR" && python3 -c "
import sys
sys.path.append('$SCRIPT_DIR/api')
try:
    from apim.client import client
    success, message = client.verify_api_key('$service')
    print('SUCCESS' if success else 'FAILED')
    print(message)
except Exception as e:
    print('FAILED')
    print(f'Error: {str(e)}')
" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        STATUS=$(echo "$VERIFY_RESULT" | head -n 1)
        MESSAGE=$(echo "$VERIFY_RESULT" | tail -n 1)
        
        if [ "$STATUS" = "SUCCESS" ]; then
            echo -e "${GREEN}  ✅ $service: $MESSAGE${NC}"
            return 0
        else
            echo -e "${RED}  ❌ $service: $MESSAGE${NC}"
            return 1
        fi
    else
        echo -e "${RED}  ❌ $service: Python verification failed${NC}"
        return 1
    fi
}

# Function to verify all services
verify_all_services() {
    local api_key="$1"
    local services=("embeddings" "ocr" "nlp" "transcriber")
    local success_count=0
    local total_count=${#services[@]}
    
    echo -e "${BLUE}🔑 Verifying API key with Huddle Network ML services...${NC}"
    echo "API Key: ${api_key:0:8}...${api_key: -4}"
    echo ""
    
    for service in "${services[@]}"; do
        if verify_service "$service" "$api_key"; then
            ((success_count++))
        fi
    done
    
    echo ""
    echo -e "${BLUE}📊 Verification Summary:${NC}"
    echo -e "  Services verified: $success_count/$total_count"
    
    if [ $success_count -eq $total_count ]; then
        echo -e "${GREEN}🎉 All Huddle Network services verified successfully!${NC}"
        return 0
    elif [ $success_count -gt 0 ]; then
        echo -e "${YELLOW}⚠️ Partial verification - some services may be unavailable${NC}"
        echo -e "${YELLOW}Working services: $success_count/$total_count${NC}"
        return 0
    else
        echo -e "${RED}❌ No services verified - API key may be invalid${NC}"
        return 1
    fi
}

# Function to check API key status
check_api_key() {
    echo -e "${BLUE}🔍 Checking Huddle Network API key status...${NC}"
    
    # Check if API key exists
    local api_key
    api_key=$(get_api_key)
    
    if [ $? -eq 0 ] && [ ! -z "$api_key" ]; then
        echo -e "${GREEN}✅ API key found${NC}"
        
        # Verify the key
        if verify_all_services "$api_key"; then
            echo -e "${GREEN}✅ API key is valid and working with Huddle Network${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️ API key found but verification failed${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ No API key found${NC}"
        return 1
    fi
}

# Function to setup API key
setup_api_key() {
    echo -e "${BLUE}🔧 Setting up Huddle Network API key...${NC}"
    
    # Check if key already exists and is valid
    if check_api_key; then
        echo -e "${GREEN}✅ API key is already configured and working${NC}"
        return 0
    fi
    
    # Prompt for new key
    if prompt_for_api_key; then
        local api_key
        api_key=$(get_api_key)
        
        if verify_all_services "$api_key"; then
            echo -e "${GREEN}🎉 Huddle Network API key setup completed successfully!${NC}"
            return 0
        else
            echo -e "${RED}❌ API key setup failed - key may be invalid${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ API key setup cancelled${NC}"
        return 1
    fi
}

# Function to reset API key
reset_api_key() {
    echo -e "${YELLOW}🔄 Resetting Huddle Network API key...${NC}"
    
    if [ -f "$API_KEY_FILE" ]; then
        rm "$API_KEY_FILE"
        echo -e "${GREEN}✅ API key removed${NC}"
    fi
    
    unset HUDDLE_NETWORK_API_KEY
    
    setup_api_key
}

# Function to show API key info
show_api_key_info() {
    echo -e "${BLUE}📋 Huddle Network API Key Information${NC}"
    echo ""
    
    local api_key
    api_key=$(get_api_key)
    
    if [ $? -eq 0 ] && [ ! -z "$api_key" ]; then
        echo -e "${GREEN}Status:${NC} Found"
        echo -e "${GREEN}Location:${NC} $API_KEY_FILE"
        echo -e "${GREEN}Key:${NC} ${api_key:0:8}...${api_key: -4}"
        echo -e "${GREEN}Environment:${NC} ${HUDDLE_NETWORK_API_KEY:+Set}"
        
        # Check file permissions
        if [ -f "$API_KEY_FILE" ]; then
            local perms=$(stat -f "%A" "$API_KEY_FILE" 2>/dev/null || stat -c "%a" "$API_KEY_FILE" 2>/dev/null)
            echo -e "${GREEN}Permissions:${NC} $perms"
        fi
    else
        echo -e "${RED}Status:${NC} Not found"
        echo -e "${RED}Location:${NC} $API_KEY_FILE (missing)"
        echo -e "${RED}Environment:${NC} Not set"
    fi
    
    echo ""
    
    # Show configuration status
    if [ -f "$API_CONFIG_FILE" ]; then
        echo -e "${GREEN}Configuration:${NC} Found at $API_CONFIG_FILE"
        # Show available services dynamically
        local services=$(get_available_services)
        echo -e "${GREEN}Available Services:${NC} $services"
        
        # Show base URL
        if command -v python3 >/dev/null 2>&1; then
            local base_url=$(python3 -c "
import json
try:
    with open('$API_CONFIG_FILE', 'r') as f:
        config = json.load(f)
    print(config.get('base_url', 'Not configured'))
except:
    print('Unable to read config')
" 2>/dev/null)
            echo -e "${GREEN}Base URL:${NC} $base_url"
        fi
    else
        echo -e "${YELLOW}Configuration:${NC} Using defaults (config file missing)"
        echo -e "${YELLOW}Available Services:${NC} $(get_available_services)"
    fi
}

# Function to troubleshoot API key issues
troubleshoot() {
    echo -e "${BLUE}🔧 Huddle Network API Key Troubleshooting${NC}"
    echo ""
    
    show_api_key_info
    echo ""
    
    local api_key
    api_key=$(get_api_key)
    
    if [ $? -eq 0 ] && [ ! -z "$api_key" ]; then
        echo -e "${BLUE}Running diagnostics...${NC}"
        echo ""
        
        # Test Python environment
        echo -e "${BLUE}🐍 Testing Python environment...${NC}"
        if cd "$SCRIPT_DIR" && python3 -c "import sys; sys.path.append('$SCRIPT_DIR/api'); from apim.client import client; print('✅ Python API client accessible')" 2>/dev/null; then
            echo -e "${GREEN}  ✅ Python API client is accessible${NC}"
        else
            echo -e "${RED}  ❌ Python API client is not accessible${NC}"
            echo -e "${YELLOW}  💡 Try: cd $SCRIPT_DIR && source nlp_venv/bin/activate${NC}"
        fi
        
        # Test network connectivity
        echo -e "${BLUE}🌐 Testing network connectivity...${NC}"
        if curl -s --connect-timeout 5 https://huddleai-apim.azure-api.net >/dev/null; then
            echo -e "${GREEN}  ✅ Network connectivity to Huddle Network is working${NC}"
        else
            echo -e "${RED}  ❌ Cannot reach Huddle Network endpoints${NC}"
            echo -e "${YELLOW}  💡 Check your internet connection${NC}"
        fi
        
        # Verify services individually
        echo ""
        verify_all_services "$api_key"
        
    else
        echo -e "${RED}❌ No API key found - run setup first${NC}"
    fi
}

# Function to search for API keys in various locations
search_api_keys() {
    local search_term="${1:-}"
    echo -e "${BLUE}🔍 Searching for API keys...${NC}"
    echo ""
    
    local found_keys=()
    local search_locations=(
        "$HOME/.ipfs/huddle_network_api_key"
        "$HOME/.ipfs/huddleai_api_key"
        "$HOME/.env"
        "$HOME/.bashrc"
        "$HOME/.zshrc"
        "$HOME/.profile"
        "$(pwd)/.env"
        "$(pwd)/.env.local"
    )
    
    # Search environment variables
    echo -e "${YELLOW}Environment Variables:${NC}"
    if [ ! -z "$HUDDLE_NETWORK_API_KEY" ]; then
        echo -e "  ${GREEN}✅ HUDDLE_NETWORK_API_KEY${NC} (current): ${HUDDLE_NETWORK_API_KEY:0:8}...${HUDDLE_NETWORK_API_KEY: -4}"
        found_keys+=("env:HUDDLE_NETWORK_API_KEY")
    fi
    
    if [ ! -z "$HUDDLEAI_API_KEY" ]; then
        echo -e "  ${YELLOW}⚠️ HUDDLEAI_API_KEY${NC} (legacy): ${HUDDLEAI_API_KEY:0:8}...${HUDDLEAI_API_KEY: -4}"
        found_keys+=("env:HUDDLEAI_API_KEY")
    fi
    
    # Check for HNM configuration
    if [ -f "$API_CONFIG_FILE" ]; then
        echo -e "  ${BLUE}🔍 Checking HNM CLI Configuration...${NC}"
        echo -e "  ${GREEN}✅ Huddle Network configuration found${NC}"
        found_keys+=("config:huddle_network")
    fi
    
    echo ""
    echo -e "${YELLOW}File Locations:${NC}"
    
    # Search files
    for location in "${search_locations[@]}"; do
        if [ -f "$location" ]; then
            local file_size=$(stat -f%z "$location" 2>/dev/null || stat -c%s "$location" 2>/dev/null)
            if [ "$file_size" -gt 0 ]; then
                echo -e "  ${GREEN}✅ Found:${NC} $location (${file_size} bytes)"
                
                # If it's a key file, show preview
                if [[ "$location" == *"api_key"* ]]; then
                    local key_content=$(cat "$location" 2>/dev/null)
                    if [ ! -z "$key_content" ] && [ ${#key_content} -gt 10 ]; then
                        echo -e "     Preview: ${key_content:0:8}...${key_content: -4}"
                        found_keys+=("file:$location")
                    fi
                fi
                
                # Search for API key patterns in env files
                if [[ "$location" == *".env"* ]] || [[ "$location" == *"rc"* ]] || [[ "$location" == *"profile"* ]]; then
                    local matches=$(grep -E "(HUDDLE|HUDDLEAI|API_KEY)" "$location" 2>/dev/null | grep -v "^#" || true)
                    if [ ! -z "$matches" ]; then
                        echo -e "     ${CYAN}Contains API key references:${NC}"
                        echo "$matches" | while read -r line; do
                            echo -e "       ${line:0:50}..."
                        done
                        found_keys+=("file:$location")
                    fi
                fi
            fi
        fi
    done
    
    echo ""
    echo -e "${YELLOW}Summary:${NC}"
    if [ ${#found_keys[@]} -gt 0 ]; then
        echo -e "  ${GREEN}Found ${#found_keys[@]} potential API key location(s)${NC}"
        for key in "${found_keys[@]}"; do
            echo -e "    • $key"
        done
    else
        echo -e "  ${RED}No API keys found in common locations${NC}"
    fi
    
    # Search by term if provided
    if [ ! -z "$search_term" ]; then
        echo ""
        echo -e "${BLUE}🔍 Searching for term: '$search_term'${NC}"
        
        # Search in files
        for location in "${search_locations[@]}"; do
            if [ -f "$location" ]; then
                local matches=$(grep -i "$search_term" "$location" 2>/dev/null || true)
                if [ ! -z "$matches" ]; then
                    echo -e "  ${GREEN}Found in:${NC} $location"
                    echo "$matches" | head -3 | while read -r line; do
                        echo -e "    ${line:0:80}..."
                    done
                fi
            fi
        done
    fi
}

# Function to list all API configurations
list_api_configs() {
    echo -e "${BLUE}📋 API Configuration Inventory${NC}"
    echo ""
    
    # Current active configuration
    echo -e "${YELLOW}Active Configuration:${NC}"
    local api_key=$(get_api_key)
    if [ $? -eq 0 ] && [ ! -z "$api_key" ]; then
        echo -e "  ${GREEN}✅ API Key:${NC} ${api_key:0:8}...${api_key: -4}"
        echo -e "  ${GREEN}✅ Source:${NC} $(get_api_key_source)"
    else
        echo -e "  ${RED}❌ No active API key${NC}"
    fi
    
    # Configuration files
    echo ""
    echo -e "${YELLOW}Configuration Files:${NC}"
    if [ -f "$API_CONFIG_FILE" ]; then
        echo -e "  ${GREEN}✅ Main Config:${NC} $API_CONFIG_FILE"
        if command -v python3 >/dev/null 2>&1; then
            local base_url=$(python3 -c "
import json
try:
    with open('$API_CONFIG_FILE', 'r') as f:
        config = json.load(f)
    print(config.get('base_url', 'Not configured'))
except:
    print('Unable to read')
" 2>/dev/null)
            echo -e "     Base URL: $base_url"
            
            local service_count=$(python3 -c "
import json
try:
    with open('$API_CONFIG_FILE', 'r') as f:
        config = json.load(f)
    print(len(config.get('services', {})))
except:
    print('0')
" 2>/dev/null)
            echo -e "     Services: $service_count configured"
        fi
    else
        echo -e "  ${RED}❌ Main Config:${NC} $API_CONFIG_FILE (missing)"
    fi
    
    # Environment setup
    echo ""
    echo -e "${YELLOW}Environment:${NC}"
    echo -e "  ${GREEN}Python:${NC} $(python3 --version 2>/dev/null || echo 'Not available')"
    echo -e "  ${GREEN}API Client:${NC} $(cd "$SCRIPT_DIR" && python3 -c "import sys; sys.path.append('$SCRIPT_DIR/api'); from apim.client import client; print('Available')" 2>/dev/null || echo 'Not available')"
    
    # Network connectivity
    echo ""
    echo -e "${YELLOW}Network Status:${NC}"
    if curl -s --connect-timeout 5 https://huddleai-apim.azure-api.net >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅ Huddle Network:${NC} Reachable"
    else
        echo -e "  ${RED}❌ Huddle Network:${NC} Not reachable"
    fi
    
    local portal_url=$(get_developer_portal_url)
    if curl -s --connect-timeout 5 "$portal_url" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅ Developer Portal:${NC} Reachable ($portal_url)"
    else
        echo -e "  ${YELLOW}⚠️ Developer Portal:${NC} Not reachable ($portal_url)"
    fi
}

# Function to get API key source
get_api_key_source() {
    if [ ! -z "$HUDDLE_NETWORK_API_KEY" ]; then
        echo "Environment variable (HUDDLE_NETWORK_API_KEY)"
    elif [ -f "$API_KEY_FILE" ] && [ -s "$API_KEY_FILE" ]; then
        echo "File ($API_KEY_FILE)"
    else
        echo "Not found"
    fi
}

# Function to find API key files with modern CLI patterns
find_api_keys() {
    local pattern="${1:-*api*key*}"
    local search_path="${2:-$HOME}"
    
    echo -e "${BLUE}🔍 Finding API key files...${NC}"
    echo -e "${YELLOW}Pattern:${NC} $pattern"
    echo -e "${YELLOW}Search Path:${NC} $search_path"
    echo ""
    
    # Use find command with various patterns
    local find_patterns=(
        "*api*key*"
        "*huddle*"
        "*token*"
        "*.env*"
        "*credential*"
    )
    
    for pattern in "${find_patterns[@]}"; do
        echo -e "${CYAN}Searching for: $pattern${NC}"
        
        # Find files
        local files=$(find "$search_path" -maxdepth 3 -name "$pattern" -type f 2>/dev/null | head -10)
        if [ ! -z "$files" ]; then
            echo "$files" | while read -r file; do
                if [ -f "$file" ]; then
                    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
                    local modified=$(stat -f%Sm "$file" 2>/dev/null || stat -c%y "$file" 2>/dev/null | cut -d' ' -f1)
                    echo -e "  ${GREEN}✅${NC} $file (${size}B, modified: $modified)"
                    
                    # Show content preview if it looks like an API key
                    if [[ "$file" == *"api"* ]] || [[ "$file" == *"key"* ]]; then
                        local content=$(head -1 "$file" 2>/dev/null)
                        if [ ! -z "$content" ] && [ ${#content} -gt 10 ] && [ ${#content} -lt 200 ]; then
                            echo -e "     Preview: ${content:0:12}...${content: -4}"
                        fi
                    fi
                fi
            done
        else
            echo -e "  ${GRAY}No files found${NC}"
        fi
        echo ""
    done
}

# Function to grep for API keys in files
grep_api_keys() {
    local search_term="${1:-API}"
    local search_path="${2:-.}"
    
    echo -e "${BLUE}🔍 Searching for API key patterns...${NC}"
    echo -e "${YELLOW}Term:${NC} $search_term"
    echo -e "${YELLOW}Path:${NC} $search_path"
    echo ""
    
    # Common API key patterns
    local patterns=(
        "API[_-]?KEY"
        "HUDDLE"
        "TOKEN"
        "SECRET"
        "CREDENTIAL"
        "[A-Za-z0-9]{32,}"  # Long alphanumeric strings
    )
    
    for pattern in "${patterns[@]}"; do
        echo -e "${CYAN}Pattern: $pattern${NC}"
        
        # Search in files
        local results=$(grep -r -i "$pattern" "$search_path" --include="*.env*" --include="*.sh" --include="*.json" --include="*.conf" --include="*.config" 2>/dev/null | head -10)
        
        if [ ! -z "$results" ]; then
            echo "$results" | while read -r line; do
                local file=$(echo "$line" | cut -d: -f1)
                local content=$(echo "$line" | cut -d: -f2-)
                echo -e "  ${GREEN}✅${NC} $file"
                echo -e "     ${content:0:80}..."
            done
        else
            echo -e "  ${GRAY}No matches found${NC}"
        fi
        echo ""
    done
}

# Function to check and fix corrupted API keys
fix_api_key() {
    echo "🔧 Checking and fixing API key corruption..."
    
    if [[ ! -f "$API_KEY_FILE" ]]; then
        echo "❌ No API key file found at: $API_KEY_FILE"
        echo "💡 Run './hnm keys setup' to configure your API key"
        return 1
    fi
    
    # Read the current API key
    local current_key=$(cat "$API_KEY_FILE" 2>/dev/null)
    local key_length=${#current_key}
    
    echo "📊 Current API key analysis:"
    echo "   Length: $key_length characters (expected: 32)"
    echo "   File: $API_KEY_FILE"
    
    # Check for corruption indicators
    local has_corruption=false
    local issues=()
    
    # Check for ANSI escape sequences
    if [[ "$current_key" =~ $'\x1b' ]]; then
        has_corruption=true
        issues+=("ANSI escape sequences detected")
    fi
    
    # Check for other control characters
    if [[ "$current_key" =~ [[:cntrl:]] ]]; then
        has_corruption=true
        issues+=("Control characters detected")
    fi
    
    # Check length
    if [[ $key_length -ne 32 ]]; then
        has_corruption=true
        issues+=("Invalid length: $key_length (expected: 32)")
    fi
    
    # Check if it's valid hex
    if ! [[ "$current_key" =~ ^[a-fA-F0-9]{32}$ ]]; then
        has_corruption=true
        issues+=("Invalid format: not 32 hexadecimal characters")
    fi
    
    if [[ "$has_corruption" == "false" ]]; then
        echo "✅ API key appears to be clean and valid"
        return 0
    fi
    
    echo "⚠️  Issues detected:"
    for issue in "${issues[@]}"; do
        echo "   - $issue"
    done
    
    # Attempt to clean the API key
    echo ""
    echo "🔧 Attempting to clean API key..."
    
    # Remove ANSI escape sequences and control characters
    local clean_key=$(echo "$current_key" | sed 's/\x1b\[[0-9;]*[mGKHF]//g' | sed 's/[[:cntrl:]]//g' | tr -d '[:space:]')
    
    # Additional cleaning for common corruption patterns
    clean_key=$(echo "$clean_key" | sed 's/\[C//g' | sed 's/\x1b//g' | tr -cd '[:alnum:]')
    
    # Try to extract a valid 32-character hex string from the cleaned result
    local extracted_key=""
    if [[ ${#clean_key} -gt 32 ]]; then
        # Look for a valid 32-character hex pattern
        extracted_key=$(echo "$clean_key" | grep -o '[a-fA-F0-9]\{32\}' | head -1)
    else
        extracted_key="$clean_key"
    fi
    
    echo "   Original: '$current_key'"
    echo "   Cleaned:  '$clean_key'"
    echo "   Extracted: '$extracted_key'"
    echo "   Length:   ${#extracted_key}"
    
    # Validate the extracted key
    if [[ ${#extracted_key} -eq 32 ]] && [[ "$extracted_key" =~ ^[a-fA-F0-9]{32}$ ]]; then
        echo ""
        echo "✅ Successfully extracted valid API key"
        
        # Create backup of corrupted key
        local backup_file="${API_KEY_FILE}.corrupted.$(date +%s)"
        cp "$API_KEY_FILE" "$backup_file"
        echo "📁 Backup of corrupted key saved to: $backup_file"
        
        # Save the cleaned key
        echo "$extracted_key" > "$API_KEY_FILE"
        chmod 600 "$API_KEY_FILE"
        echo "💾 Cleaned API key saved"
        
        # Verify the fix worked
        echo ""
        echo "🔍 Verifying fix..."
        if verify_all_services; then
            echo "✅ API key fix successful - all services verified!"
            return 0
        else
            echo "⚠️  API key was cleaned but verification still fails"
            echo "💡 The cleaned key may still be invalid - consider running './hnm keys setup'"
            return 1
        fi
    else
        echo ""
        echo "❌ Could not extract valid API key from corrupted data"
        echo "💡 Manual intervention required:"
        echo "   1. Check if you have the correct API key"
        echo "   2. Run './hnm keys setup' to reconfigure"
        echo "   3. Contact support if the issue persists"
        return 1
    fi
}

# Add the get_command_prefix function before the show_help function
get_command_prefix() {
    echo "hnm keys"
}

# Function to show help
show_help() {
    local CMD_PREFIX=$(get_command_prefix)
    
    # Display banner with modern styling
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                 ${YELLOW}HUDDLE NODE MANAGER (HNM)${BLUE}                 ║${NC}"
    echo -e "${BLUE}║                   ${GREEN}API Key Manager 🔑${BLUE}                    ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${CYAN}Manage API keys for Huddle Network services and integrations${NC}\n"
    
    echo -e "${YELLOW}Usage:${NC}"
    echo "  ${CMD_PREFIX} [command] [options]"
    echo ""
    echo -e "${YELLOW}Core Commands:${NC}"
    echo "  check        - Check API key status and verify Huddle Network services"
    echo "  setup        - Setup/configure API key for Huddle Network"
    echo "  reset        - Reset API key (remove and setup new)"
    echo "  info         - Show API key information and available services"
    echo "  troubleshoot - Run comprehensive troubleshooting"
    echo "  verify       - Verify API key with all Huddle Network services"
    echo "  fix          - Check and fix corrupted API key"
    echo ""
    echo -e "${YELLOW}Modern CLI Commands:${NC}"
    echo "  search [term]     - Search for API keys in common locations"
    echo "  find [pattern]    - Find API key files using patterns"
    echo "  list              - List all API configurations and status"
    echo "  grep [term] [path] - Search for API key patterns in files"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  ${CMD_PREFIX} check                         # Quick status check"
    echo "  ${CMD_PREFIX} setup                         # Initial setup"
    echo "  ${CMD_PREFIX} troubleshoot                  # Full diagnostics"
    echo "  ${CMD_PREFIX} search huddle                 # Search for 'huddle' in key locations"
    echo "  ${CMD_PREFIX} find '*api*'                  # Find files matching API patterns"
    echo "  ${CMD_PREFIX} list                          # Show complete configuration inventory"
    echo "  ${CMD_PREFIX} grep API_KEY ~/.env           # Search for API_KEY in .env files"
    echo ""
    echo -e "${BLUE}💡 Pro Tips:${NC}"
    local portal_url=$(get_developer_portal_url)
    local services=$(get_available_services)
    echo "  • Get your API key from: $portal_url"
    echo "  • Run 'troubleshoot' if experiencing issues"
    echo "  • Use 'search' to find existing keys before setup"
    echo "  • Use 'list' for complete configuration overview"
    echo "  • Supports: $services"
}

# Main function
main() {
    case "${1:-check}" in
        check)
            check_api_key
            ;;
        setup)
            setup_api_key
            ;;
        reset)
            reset_api_key
            ;;
        info)
            show_api_key_info
            ;;
        troubleshoot|debug)
            troubleshoot
            ;;
        verify)
            local api_key
            api_key=$(get_api_key)
            if [ $? -eq 0 ] && [ ! -z "$api_key" ]; then
                verify_all_services "$api_key"
            else
                echo -e "${RED}❌ No API key found${NC}"
                exit 1
            fi
            ;;
        fix)
            fix_api_key
            ;;
        search)
            search_api_keys "$2"
            ;;
        find)
            find_api_keys "$2" "$3"
            ;;
        list|ls)
            list_api_configs
            ;;
        grep)
            grep_api_keys "$2" "$3"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $1${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Export functions for use by other scripts
export -f check_api_key verify_all_services get_api_key save_api_key

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 