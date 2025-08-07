#!/bin/bash
#
# HNM (Huddle Node Manager) - IPFS Troubleshoot Manager
# Advanced diagnostic and repair functionality for the modern Huddle Node Manager
# A utility for diagnosing and fixing common IPFS issues
#

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to check if IPFS daemon is running
check_daemon() {
    if ! ipfs swarm peers &>/dev/null; then
        echo -e "${RED}❌ IPFS daemon is not running${NC}"
        echo -e "${YELLOW}Try starting the daemon with:${NC} hnm start"
        return 1
    else
        echo -e "${GREEN}✅ IPFS daemon is running${NC}"
        return 0
    fi
}

# Function to check IPFS API availability
check_api() {
    API_ADDR=$(ipfs config Addresses.API 2>/dev/null)
    if [ -z "$API_ADDR" ]; then
        echo -e "${RED}❌ Could not determine API address${NC}"
        return 1
    fi
    
    # Extract host and port from API address
    # Format is typically /ip4/127.0.0.1/tcp/5001
    HOST=$(echo "$API_ADDR" | grep -o '/ip4/[0-9.]*' | sed 's/\/ip4\///')
    PORT=$(echo "$API_ADDR" | grep -o '/tcp/[0-9]*' | sed 's/\/tcp\///')
    
    if [ -z "$HOST" ] || [ -z "$PORT" ]; then
        echo -e "${RED}❌ Could not parse API address: $API_ADDR${NC}"
        return 1
    fi
    
    # Check if the API port is open
    if command -v nc &>/dev/null; then
        if nc -z "$HOST" "$PORT" &>/dev/null; then
            echo -e "${GREEN}✅ IPFS API is accessible at $HOST:$PORT${NC}"
            return 0
        else
            echo -e "${RED}❌ IPFS API port is not accessible at $HOST:$PORT${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️ Cannot check API port (nc command not available)${NC}"
        # Try a basic API call instead
        if ipfs id &>/dev/null; then
            echo -e "${GREEN}✅ IPFS API appears to be working${NC}"
            return 0
        else
            echo -e "${RED}❌ IPFS API is not responding${NC}"
            return 1
        fi
    fi
}

# Function to check if a hash exists in IPFS
check_hash_exists() {
    HASH="$1"
    if [ -z "$HASH" ]; then
        echo -e "${RED}❌ No hash provided${NC}"
        return 1
    fi
    
    if ipfs cat "$HASH" &>/dev/null; then
        echo -e "${GREEN}✅ Content with hash $HASH exists in IPFS${NC}"
        return 0
    else
        echo -e "${RED}❌ Content with hash $HASH does not exist or is not accessible${NC}"
        return 1
    fi
}

# Function to check if a hash is pinned
check_hash_pinned() {
    HASH="$1"
    if [ -z "$HASH" ]; then
        echo -e "${RED}❌ No hash provided${NC}"
        return 1
    fi
    
    if ipfs pin ls --type=recursive "$HASH" &>/dev/null || ipfs pin ls --type=direct "$HASH" &>/dev/null; then
        echo -e "${GREEN}✅ Content with hash $HASH is pinned${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️ Content with hash $HASH is not pinned${NC}"
        return 1
    fi
}

# Function to check MFS health
check_mfs_health() {
    echo -e "${BLUE}🔍 Checking MFS health...${NC}"
    
    # Check if we can access MFS root
    if ! ipfs files stat / &>/dev/null; then
        echo -e "${RED}❌ Cannot access MFS root${NC}"
        echo -e "${YELLOW}Attempting to repair MFS...${NC}"
        
        # Try to repair MFS by creating a temporary file
        if ipfs files mkdir -p /tmp_check &>/dev/null && ipfs files rm -r /tmp_check &>/dev/null; then
            echo -e "${GREEN}✅ MFS repaired successfully${NC}"
        else
            echo -e "${RED}❌ Failed to repair MFS${NC}"
            echo -e "${YELLOW}Try restarting the IPFS daemon:${NC} hnm restart"
            return 1
        fi
    else
        echo -e "${GREEN}✅ MFS root is accessible${NC}"
    fi
    
    # Check if /pins directory exists
    if ! ipfs files stat /pins &>/dev/null; then
        echo -e "${YELLOW}⚠️ /pins directory does not exist in MFS${NC}"
        echo -e "${BLUE}Creating /pins directory...${NC}"
        
        if ipfs files mkdir -p /pins &>/dev/null; then
            echo -e "${GREEN}✅ Created /pins directory successfully${NC}"
        else
            echo -e "${RED}❌ Failed to create /pins directory${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}✅ /pins directory exists${NC}"
    fi
    
    return 0
}

# Function to diagnose MFS import issues
diagnose_mfs_import() {
    HASH="$1"
    if [ -z "$HASH" ]; then
        echo -e "${RED}❌ No hash provided${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔍 Diagnosing why hash $HASH was not imported to MFS...${NC}"
    
    # Step 1: Check if the daemon is running
    check_daemon || return 1
    
    # Step 2: Check if the API is accessible
    check_api || return 1
    
    # Step 3: Check if the content exists in IPFS
    check_hash_exists "$HASH" || {
        echo -e "${YELLOW}Attempting to re-add content...${NC}"
        echo -e "${RED}❌ Cannot automatically re-add content as the original file path is unknown${NC}"
        echo -e "${YELLOW}Please re-add the content manually${NC}"
        return 1
    }
    
    # Step 4: Check MFS health
    check_mfs_health || return 1
    
    # Step 5: Try to manually import the content to MFS
    echo -e "${BLUE}🔄 Attempting to manually import content to MFS...${NC}"
    
    # First check if it already exists
    if ipfs files stat "/pins/$HASH" &>/dev/null; then
        echo -e "${GREEN}✅ Content already exists at /pins/$HASH${NC}"
        return 0
    fi
    
    # Try to determine if it's a file or directory
    TYPE=$(ipfs files stat --format='<type>' /ipfs/$HASH 2>/dev/null || echo "unknown")
    
    # Import the content to MFS using method 1: direct copy
    echo -e "${BLUE}Method 1: Direct copy...${NC}"
    if ipfs files cp "/ipfs/$HASH" "/pins/$HASH" &>/dev/null; then
        echo -e "${GREEN}✅ Successfully imported content to /pins/$HASH${NC}"
        echo -e "${GREEN}✅ You can now see this content in WebUI under Files > /pins/$HASH${NC}"
        
        # Verify the import was successful
        PINS_CONTENT=$(ipfs files ls /pins)
        if echo "$PINS_CONTENT" | grep -q "$HASH"; then
            echo -e "${GREEN}✅ Import verified successfully${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️ Import verification failed, trying alternative methods...${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Direct copy failed, trying alternative methods...${NC}"
    fi
    
    # Method 2: Use write command for files
    if [ "$TYPE" != "directory" ]; then
        echo -e "${BLUE}Method 2: Using write command...${NC}"
        if ipfs files write --create --parents "/pins/$HASH" "/ipfs/$HASH" &>/dev/null; then
            echo -e "${GREEN}✅ Successfully imported content to /pins/$HASH using write method${NC}"
            
            # Verify the import was successful
            PINS_CONTENT=$(ipfs files ls /pins)
            if echo "$PINS_CONTENT" | grep -q "$HASH"; then
                echo -e "${GREEN}✅ Import verified successfully${NC}"
                return 0
            else
                echo -e "${YELLOW}⚠️ Import verification failed, trying next method...${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️ Write method failed, trying next method...${NC}"
        fi
    fi
    
    # Method 3: Read content and write to temp file, then import
    if [ "$TYPE" != "directory" ]; then
        echo -e "${BLUE}Method 3: Read and write via temporary file...${NC}"
        TEMP_FILE=$(mktemp)
        if ipfs cat "$HASH" > "$TEMP_FILE" 2>/dev/null; then
            if ipfs files write --create --parents "/pins/$HASH" "$TEMP_FILE" &>/dev/null; then
                rm "$TEMP_FILE"
                echo -e "${GREEN}✅ Successfully imported content to /pins/$HASH using read/write method${NC}"
                
                # Verify the import was successful
                PINS_CONTENT=$(ipfs files ls /pins)
                if echo "$PINS_CONTENT" | grep -q "$HASH"; then
                    echo -e "${GREEN}✅ Import verified successfully${NC}"
                    return 0
                else
                    echo -e "${YELLOW}⚠️ Import verification failed, trying next method...${NC}"
                fi
            else
                rm "$TEMP_FILE"
                echo -e "${YELLOW}⚠️ Write from temp file failed, trying next method...${NC}"
            fi
        else
            rm "$TEMP_FILE"
            echo -e "${YELLOW}⚠️ Could not read content from IPFS, trying next method...${NC}"
        fi
    fi
    
    # Method 4: For directories, try mkdir and copy contents
    if [ "$TYPE" = "directory" ]; then
        echo -e "${BLUE}Method 4: Create directory and copy contents...${NC}"
        if ipfs files mkdir -p "/pins/$HASH" &>/dev/null; then
            echo -e "${GREEN}✅ Created directory /pins/$HASH${NC}"
            
            # Try to copy contents
            echo -e "${BLUE}Attempting to copy directory contents...${NC}"
            
            # Get list of items in the directory
            ITEMS=$(ipfs ls "$HASH" 2>/dev/null | awk '{print $2}')
            
            if [ ! -z "$ITEMS" ]; then
                SUCCESS=true
                echo "$ITEMS" | while read -r ITEM; do
                    if [ ! -z "$ITEM" ]; then
                        if ! ipfs files cp "/ipfs/$HASH/$ITEM" "/pins/$HASH/$ITEM" &>/dev/null; then
                            SUCCESS=false
                            echo -e "${YELLOW}⚠️ Failed to copy item: $ITEM${NC}"
                        fi
                    fi
                done
                
                if [ "$SUCCESS" = true ]; then
                    echo -e "${GREEN}✅ Successfully copied directory contents${NC}"
                    return 0
                fi
            else
                echo -e "${YELLOW}⚠️ No items found in directory or failed to list contents${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️ Failed to create directory, trying next method...${NC}"
        fi
    fi
    
    # Method 5: Try to fix potential MFS corruption
    echo -e "${BLUE}Method 5: Checking for MFS corruption...${NC}"
    
    # Check MFS space usage
    MFS_SPACE=$(ipfs files stat --format='<cumulsize>' / 2>/dev/null)
    if [ -n "$MFS_SPACE" ] && [ "$MFS_SPACE" -gt 1073741824 ]; then # 1GB
        echo -e "${YELLOW}⚠️ MFS is using a large amount of space ($((MFS_SPACE/1048576)) MB)${NC}"
        echo -e "${YELLOW}Consider cleaning up unnecessary files in MFS${NC}"
    fi
    
    # Check for stale lock files
    echo -e "${BLUE}Checking for stale lock files...${NC}"
    LOCK_FILES=$(find "$(ipfs config Datastore.Path 2>/dev/null)" -name "LOCK" 2>/dev/null | wc -l)
    if [ "$LOCK_FILES" -gt 1 ]; then
        echo -e "${YELLOW}⚠️ Multiple lock files found in the repository${NC}"
        echo -e "${YELLOW}This might indicate a problem with the repository${NC}"
        echo -e "${YELLOW}Consider restarting the daemon:${NC} hnm restart"
    fi
    
    # All methods failed
    echo -e "${RED}❌ All import methods failed${NC}"
    echo -e "${YELLOW}Recommended actions:${NC}"
    echo -e "1. ${YELLOW}Restart the IPFS daemon:${NC} hnm restart"
    echo -e "2. ${YELLOW}Check repository health:${NC} $0 repo"
    echo -e "3. ${YELLOW}Run garbage collection:${NC} ipfs repo gc"
    echo -e "4. ${YELLOW}Try adding the content again${NC}"
    
    return 1
}

# Function to check repository health
check_repo_health() {
    echo -e "${BLUE}Checking IPFS repository health...${NC}"
    
    # Check if repo is accessible
    if ! ipfs repo stat >/dev/null 2>&1; then
        echo -e "${RED}❌ IPFS repository is not accessible${NC}"
        echo -e "${YELLOW}Possible solutions:${NC}"
        echo -e "• Restart IPFS daemon: ${CYAN}hnm restart${NC}"
        echo -e "• Check repository permissions"
        echo -e "• Run repository verification: ${CYAN}ipfs repo verify${NC}"
        return 1
    fi
    
    # Get repository statistics
    local repo_stats
    repo_stats=$(ipfs repo stat 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ IPFS repository is accessible${NC}"
        echo -e "${BLUE}Repository statistics:${NC}"
        echo "$repo_stats" | while read -r line; do
            echo "  $line"
        done
    else
        echo -e "${YELLOW}⚠️  Repository is accessible but statistics unavailable${NC}"
    fi
    
    return 0
}

# Function to check and fix corrupted API keys
check_and_fix_api_key_corruption() {
    echo "🔍 Checking for API key corruption..."
    
    local api_key_file="$HOME/.ipfs/huddleai_api_key"
    local huddle_key_file="$HOME/.ipfs/huddle_network_api_key"
    
    # Check both possible API key files
    for key_file in "$api_key_file" "$huddle_key_file"; do
        if [[ -f "$key_file" ]]; then
            echo "  📁 Checking $key_file"
            
            # Read the API key and check for corruption
            local api_key=$(cat "$key_file" 2>/dev/null)
            local key_length=${#api_key}
            
            # Check for ANSI escape sequences or other corruption
            if [[ "$api_key" =~ $'\x1b' ]] || [[ "$api_key" =~ [[:cntrl:]] ]] || [[ $key_length -ne 32 ]]; then
                echo "  ⚠️  Corrupted API key detected!"
                echo "     - Length: $key_length (expected: 32)"
                echo "     - Contains control characters: $(echo "$api_key" | grep '[[:cntrl:]]' >/dev/null && echo "Yes" || echo "No")"
                
                # Try to extract clean API key
                local clean_key=$(echo "$api_key" | sed 's/\x1b\[[0-9;]*[mGKHF]//g' | sed 's/[[:cntrl:]]//g' | tr -d '[:space:]')
                
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
                
                if [[ ${#extracted_key} -eq 32 ]] && [[ "$extracted_key" =~ ^[a-fA-F0-9]{32}$ ]]; then
                    echo "  🔧 Cleaning API key..."
                    echo "$extracted_key" > "$key_file"
                    chmod 600 "$key_file"
                    echo "  ✅ API key cleaned and saved"
                    return 0
                else
                    echo "  ❌ Could not extract valid API key from corrupted data"
                    echo "     Extracted: '$extracted_key' (length: ${#extracted_key})"
                    return 1
                fi
            else
                echo "  ✅ API key appears clean"
            fi
        fi
    done
    
    return 0
}

# Function to validate API key format
validate_api_key_format() {
    local api_key="$1"
    
    # Check if it's exactly 32 hex characters
    if [[ ${#api_key} -eq 32 ]] && [[ "$api_key" =~ ^[a-fA-F0-9]{32}$ ]]; then
        return 0
    fi
    
    return 1
}

# Enhanced API key status check with automatic fixing
check_api_key_status() {
    echo "🔍 Checking Huddle Network API key status..."
    
    # First, check for and fix any corruption
    if ! check_and_fix_api_key_corruption; then
        echo "❌ API key corruption detected but could not be automatically fixed"
        echo "💡 Recommended action: Run './hnm keys setup' to configure a new API key"
        return 1
    fi
    
    # Check if API key manager exists
    local api_key_manager="$SCRIPT_DIR/api_key_manager.sh"
    if [[ ! -f "$api_key_manager" ]]; then
        echo "❌ API key manager not found at: $api_key_manager"
        return 1
    fi
    
    # Run API key check
    local check_output
    if check_output=$(bash "$api_key_manager" check 2>&1); then
        echo "✅ API key is valid and working"
        echo "$check_output" | grep -E "(verified|working|services)" || true
        return 0
    else
        local exit_code=$?
        echo "❌ API key verification failed"
        echo "$check_output"
        
        # Check if it's a corruption issue that we can fix
        if echo "$check_output" | grep -q "badly formed\|400\|Bad Request"; then
            echo ""
            echo "🔧 Detected possible API key corruption, attempting automatic fix..."
            
            if check_and_fix_api_key_corruption; then
                echo "🔄 Retrying verification after cleanup..."
                if check_output=$(bash "$api_key_manager" check 2>&1); then
                    echo "✅ API key verification successful after cleanup!"
                    return 0
                fi
            fi
        fi
        
        echo ""
        echo "🛠️  Troubleshooting steps:"
        echo "   1. Verify your API key is correct"
        echo "   2. Check network connectivity"
        echo "   3. Ensure API key has proper permissions"
        echo "   4. Run './hnm keys setup' to reconfigure"
        
        return $exit_code
    fi
}

# Function to verify API key connectivity
verify_api_key_connectivity() {
    echo -e "${BLUE}Testing Huddle Network API connectivity...${NC}"
    
    local api_key_manager="$SCRIPT_DIR/api_key_manager.sh"
    
    # Test network connectivity to Huddle Network
    echo -e "${BLUE}Testing network connectivity...${NC}"
    if command -v curl >/dev/null 2>&1; then
        if curl -s --max-time 10 "https://huddleai-apim.azure-api.net" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Network connectivity to Huddle Network is working${NC}"
        else
            echo -e "${RED}❌ Cannot reach Huddle Network endpoints${NC}"
            echo -e "${YELLOW}Possible issues:${NC}"
            echo -e "• Network connectivity problems"
            echo -e "• Firewall blocking outbound connections"
            echo -e "• DNS resolution issues"
            echo -e "• Huddle Network services may be temporarily unavailable"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  curl not available, skipping network test${NC}"
    fi
    
    # Verify API key with the Huddle Network services
    echo -e "${BLUE}Verifying API key with Huddle Network services...${NC}"
    if bash "$api_key_manager" verify >/dev/null 2>&1; then
        echo -e "${GREEN}✅ API key verification successful${NC}"
        return 0
    else
        echo -e "${RED}❌ API key verification failed${NC}"
        
        # Get detailed error information
        local verify_output
        verify_output=$(bash "$api_key_manager" verify 2>&1)
        
        if echo "$verify_output" | grep -q "401"; then
            echo -e "${YELLOW}Issue: Unauthorized (401)${NC}"
            echo -e "${YELLOW}• API key is invalid or expired${NC}"
            echo -e "${CYAN}Solution: Reset and reconfigure API key${NC}"
            echo -e "  ${CYAN}hnm troubleshoot api-key reset${NC}"
        elif echo "$verify_output" | grep -q "403"; then
            echo -e "${YELLOW}Issue: Forbidden (403)${NC}"
            echo -e "${YELLOW}• API key lacks necessary permissions${NC}"
            echo -e "${YELLOW}• Subscription may be inactive${NC}"
            echo -e "${CYAN}Solution: Check subscription status in Huddle Network portal${NC}"
        elif echo "$verify_output" | grep -q "429"; then
            echo -e "${YELLOW}Issue: Rate limit exceeded (429)${NC}"
            echo -e "${YELLOW}• Too many requests sent${NC}"
            echo -e "${CYAN}Solution: Wait and try again later${NC}"
        elif echo "$verify_output" | grep -q "timeout\|connection"; then
            echo -e "${YELLOW}Issue: Network connectivity${NC}"
            echo -e "${YELLOW}• Connection timeout or network issues${NC}"
            echo -e "${CYAN}Solution: Check network connectivity${NC}"
        else
            echo -e "${YELLOW}Issue: Unknown error${NC}"
            echo -e "${YELLOW}Raw output:${NC}"
            echo "$verify_output"
        fi
        
        return 1
    fi
}

# Function to run API key setup
run_api_key_setup() {
    echo -e "${BLUE}Starting Huddle Network API key setup...${NC}"
    
    local api_key_manager="$SCRIPT_DIR/api_key_manager.sh"
    
    echo -e "${YELLOW}This will guide you through setting up your Huddle Network API key.${NC}"
    echo -e "${YELLOW}You'll need a subscription key for Huddle Network ML services.${NC}"
    echo ""
    
    # Run the setup
    if bash "$api_key_manager" setup; then
        echo -e "${GREEN}✅ API key setup completed successfully${NC}"
        
        # Verify the setup
        echo -e "${BLUE}Verifying new API key...${NC}"
        if verify_api_key_connectivity; then
            echo -e "${GREEN}✅ API key setup and verification successful${NC}"
            echo -e "${GREEN}You can now use ML features in search (embeddings, OCR, etc.)${NC}"
        else
            echo -e "${YELLOW}⚠️  API key was configured but verification failed${NC}"
            echo -e "${YELLOW}You may need to check your subscription or try again${NC}"
        fi
    else
        echo -e "${RED}❌ API key setup failed${NC}"
        echo -e "${YELLOW}Please check the error messages above and try again${NC}"
    fi
}

# Function to reset API key
reset_api_key() {
    echo -e "${BLUE}Resetting Huddle Network API key configuration...${NC}"
    
    local api_key_manager="$SCRIPT_DIR/api_key_manager.sh"
    
    echo -e "${YELLOW}This will remove your current API key and allow you to set a new one.${NC}"
    read -p "Are you sure you want to reset the API key? (y/N): " -r
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if bash "$api_key_manager" reset; then
            echo -e "${GREEN}✅ API key reset successfully${NC}"
            echo -e "${BLUE}You can now setup a new API key:${NC}"
            echo -e "  ${CYAN}hnm troubleshoot api-key setup${NC}"
        else
            echo -e "${RED}❌ API key reset failed${NC}"
        fi
    else
        echo -e "${YELLOW}API key reset cancelled${NC}"
    fi
}

# Function to run comprehensive API key diagnostics
run_api_key_diagnostics() {
    echo -e "${BLUE}Running comprehensive Huddle Network API key diagnostics...${NC}"
    echo "================================================================="
    echo ""
    
    local overall_status=0
    
    echo -e "${BLUE}1. Checking API key configuration...${NC}"
    echo "-----------------------------------"
    if ! check_api_key_status; then
        overall_status=1
    fi
    echo ""
    
    echo -e "${BLUE}2. Testing API key connectivity...${NC}"
    echo "----------------------------------"
    if ! verify_api_key_connectivity; then
        overall_status=1
    fi
    echo ""
    
    echo -e "${BLUE}3. Summary${NC}"
    echo "----------"
    if [ $overall_status -eq 0 ]; then
        echo -e "${GREEN}✅ Huddle Network API key diagnostics passed!${NC}"
        echo -e "${GREEN}Your API key is properly configured and working.${NC}"
    else
        echo -e "${YELLOW}⚠️  Huddle Network API key issues detected.${NC}"
        echo -e "${YELLOW}Available actions:${NC}"
        echo -e "   • ${CYAN}hnm troubleshoot api-key setup${NC} - Setup new API key"
        echo -e "   • ${CYAN}hnm troubleshoot api-key reset${NC} - Reset current API key"
        echo -e "   • ${CYAN}hnm troubleshoot api-key verify${NC} - Test connectivity"
    fi
    
    return $overall_status
}

# Function to handle API key troubleshooting commands
handle_api_key_command() {
    local subcommand="$1"
    
    case "$subcommand" in
        status)
            check_api_key_status
            ;;
        verify)
            verify_api_key_connectivity
            ;;
        setup)
            run_api_key_setup
            ;;
        reset)
            reset_api_key
            ;;
        network)
            verify_api_key_connectivity
            ;;
        all)
            run_api_key_diagnostics
            ;;
        "")
            run_api_key_diagnostics
            ;;
        *)
            echo -e "${RED}❌ Unknown API key command: $subcommand${NC}"
            echo -e "${YELLOW}Available commands:${NC}"
            echo -e "  status    - Check API key configuration status"
            echo -e "  verify    - Test API key connectivity"
            echo -e "  setup     - Setup new API key"
            echo -e "  reset     - Reset current API key"
            echo -e "  network   - Test network connectivity"
            echo -e "  all       - Run comprehensive API key diagnostics"
            exit 1
            ;;
    esac
}

# Function to troubleshoot specific content
troubleshoot_content() {
    HASH="$1"
    if [ -z "$HASH" ]; then
        echo -e "${RED}❌ No hash provided${NC}"
        echo -e "${YELLOW}Usage:${NC} hnm troubleshoot content HASH"
        return 1
    fi
    
    echo -e "${BLUE}🔍 Troubleshooting content with hash: $HASH${NC}"
    
    # Check if content exists
    check_hash_exists "$HASH"
    
    # Check if content is pinned
    check_hash_pinned "$HASH"
    
    # Check if content is in MFS
    if ipfs files stat "/pins/$HASH" &>/dev/null; then
        echo -e "${GREEN}✅ Content exists in MFS at /pins/$HASH${NC}"
    else
        echo -e "${YELLOW}⚠️ Content does not exist in MFS${NC}"
        diagnose_mfs_import "$HASH"
    fi
    
    return 0
}

# Function to handle command-line flag issues
handle_flag_issues() {
    echo -e "${BLUE}🔍 Checking for common command-line flag issues...${NC}"
    
    echo -e "${YELLOW}Common flag issues:${NC}"
    echo -e "1. ${YELLOW}--no-import flag:${NC} Should be placed before the file path"
    echo -e "   ${GREEN}Correct:${NC} hnm content add --no-import myfile.txt"
    echo -e "   ${RED}Incorrect:${NC} hnm content add myfile.txt --no-import"
    
    echo -e "2. ${YELLOW}Flag order matters:${NC} Flags should come before file paths"
    echo -e "   ${GREEN}Correct:${NC} hnm content add --quiet --no-import myfile.txt"
    echo -e "   ${RED}Incorrect:${NC} hnm content add myfile.txt --quiet --no-import"
    
    echo -e "3. ${YELLOW}Multiple files:${NC} Only the last file will be processed"
    echo -e "   ${GREEN}For multiple files:${NC} Use a directory or add files one by one"
    
    echo -e "${BLUE}Try running your command again with the correct flag order${NC}"
    return 0
}

# Function to display banner
display_banner() {
cat << "EOF"
┌─────────────────────────────────────────────────────────────────┐
│                      HUDDLE NODE MANAGER                       │
│                                                                 │
│  🔧 Troubleshoot Manager                                        │
│  🔧 Advanced IPFS Diagnostics & Repair                         │
│  ⬆️  Upgraded from IPFS Troubleshoot Manager                   │
│  🔧 Part of Huddle Node Manager Suite                          │
└─────────────────────────────────────────────────────────────────┘
EOF
echo ""
}

# Function to get appropriate command prefix based on calling context
get_command_prefix() {
    # Always use modern command format in help text for consistency
    echo "hnm troubleshoot"
}

# Function to show help message
show_help() {
    display_banner
    echo "🏠 HNM (Huddle Node Manager) - Troubleshoot Manager"
    echo "=================================================="
    echo "🔧 Advanced IPFS diagnostic and repair tools"
    echo ""
    
    # Use context-aware command prefix
    local CMD_PREFIX=$(get_command_prefix)
    echo "Usage: $CMD_PREFIX [command] [options]"
    echo ""
    echo "🎯 Commands:"
    echo "  check                  - Run basic health checks"
    echo "  repair                 - Attempt to fix common issues"
    echo "  diagnostics            - Generate detailed diagnostic report"
    echo "  network                - Test network connectivity"
    echo "  clean                  - Clean up temporary files and locks"
    echo "  all                    - Run all diagnostics and repairs"
    echo "  help                   - Show this help message"
    echo ""
    echo "⚙️  Options:"
    echo "  --quiet, -q            - Minimal output"
    echo "  --verbose, -v          - Verbose output"
    echo "  --json                 - Output in JSON format"
    echo ""
    echo "💡 Examples:"
    echo "  $CMD_PREFIX check"
    echo "  $CMD_PREFIX repair"
    echo "  $CMD_PREFIX all"
    echo ""
    echo "🚀 Command Format:"
    echo "   This tool is part of the Huddle Node Manager (HNM) suite"
    echo "   All operations can be performed using the '$CMD_PREFIX' prefix"
}

# Function to run all diagnostic checks
run_all_diagnostics() {
    display_banner
    echo "🔍 Running comprehensive IPFS and Huddle Network diagnostics..."
    echo "================================================================="
    echo ""
    
    local overall_status=0
    
    echo -e "${BLUE}1. Checking IPFS daemon status...${NC}"
    echo "-----------------------------------"
    if ! check_daemon; then
        overall_status=1
    fi
    echo ""
    
    echo -e "${BLUE}2. Checking IPFS API accessibility...${NC}"
    echo "-------------------------------------"
    if ! check_api; then
        overall_status=1
    fi
    echo ""
    
    echo -e "${BLUE}3. Checking MFS health...${NC}"
    echo "-------------------------"
    if ! check_mfs_health; then
        overall_status=1
    fi
    echo ""
    
    echo -e "${BLUE}4. Checking repository health...${NC}"
    echo "--------------------------------"
    if ! check_repo_health; then
        overall_status=1
    fi
    echo ""
    
    echo -e "${BLUE}5. Checking Huddle Network API key configuration...${NC}"
    echo "---------------------------------------------------"
    if ! check_api_key_status; then
        overall_status=1
    fi
    echo ""
    
    echo -e "${BLUE}6. Summary${NC}"
    echo "----------"
    if [ $overall_status -eq 0 ]; then
        echo -e "${GREEN}✅ All diagnostic checks passed!${NC}"
        echo -e "${GREEN}Your IPFS node and Huddle Network API configuration appear to be healthy.${NC}"
    else
        echo -e "${YELLOW}⚠️  Some issues were detected during diagnostics.${NC}"
        echo -e "${YELLOW}Review the output above and consider running:${NC}"
        echo -e "   • ${CYAN}hnm troubleshoot fix${NC} - Apply automatic fixes"
        echo -e "   • ${CYAN}hnm troubleshoot api-key setup${NC} - Setup Huddle Network API key"
        echo -e "   • ${CYAN}hnm restart${NC} - Restart IPFS daemon"
        echo -e "   • ${CYAN}hnm troubleshoot help${NC} - See available diagnostic tools"
    fi
    
    return $overall_status
}

# Function to fix common issues
fix_common_issues() {
    echo -e "${BLUE}🔧 Attempting to fix common IPFS issues...${NC}"
    echo "==========================================="
    echo ""
    
    local overall_status=0
    
    echo -e "${BLUE}1. Checking and fixing MFS health...${NC}"
    echo "-----------------------------------"
    if ! check_mfs_health; then
        overall_status=1
    fi
    echo ""
    
    echo -e "${BLUE}2. Checking repository health...${NC}"
    echo "-------------------------------"
    if ! check_repo_health; then
        overall_status=1
    fi
    echo ""
    
    echo -e "${BLUE}3. Checking API accessibility...${NC}"
    echo "-------------------------------"
    if ! check_api; then
        overall_status=1
    fi
    echo ""
    
    echo -e "${BLUE}4. Summary${NC}"
    echo "----------"
    if [ $overall_status -eq 0 ]; then
        echo -e "${GREEN}✅ All automatic fixes completed successfully!${NC}"
        echo -e "${GREEN}Your IPFS node should be working properly now.${NC}"
    else
        echo -e "${YELLOW}⚠️  Some issues could not be automatically fixed.${NC}"
        echo -e "${YELLOW}Consider these additional steps:${NC}"
        echo -e "   • ${CYAN}hnm restart${NC} - Restart IPFS daemon"
        echo -e "   • ${CYAN}hnm troubleshoot all${NC} - Run comprehensive diagnostics"
        echo -e "   • ${CYAN}ipfs repo gc${NC} - Clean up repository"
        echo -e "   • ${CYAN}ipfs repo verify${NC} - Verify repository integrity"
    fi
    
    return $overall_status
}

# Main function
main() {
    # No arguments, show help
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    # Parse command
    COMMAND="$1"
    shift
    
    case "$COMMAND" in
        all)
            run_all_diagnostics
            ;;
        daemon)
            check_daemon
            ;;
        api)
            check_api
            ;;
        mfs)
            check_mfs_health
            ;;
        repo)
            check_repo_health
            ;;
        content)
            troubleshoot_content "$1"
            ;;
        import)
            diagnose_mfs_import "$1"
            ;;
        flags)
            handle_flag_issues
            ;;
        fix)
            fix_common_issues
            ;;
        help|--help|-h)
            show_help
            ;;
        api-key)
            handle_api_key_command "$@"
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $COMMAND${NC}"
            show_help
            exit 1
            ;;
    esac
    
    exit $?
}

# If this script is being executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 