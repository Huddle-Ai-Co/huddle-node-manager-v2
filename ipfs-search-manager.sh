#!/bin/bash
#
# HNM (Huddle Node Manager) - IPFS Search Manager
# Advanced semantic search functionality for the modern Huddle Node Manager
# A utility for semantic search across IPFS content
#

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get the actual script directory using a more reliable method
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ASCII Art Logo
show_logo() {
cat << "EOF"
┌─────────────────────────────────────────────────────────────────┐
│                      HUDDLE NODE MANAGER                       │
│                                                                 │
│  🔍 Search Manager                                              │
│  🔍 Advanced IPFS Semantic Search                              │
│  ⬆️  Upgraded from IPFS Search Manager                         │
│  🔧 Part of Huddle Node Manager Suite                          │
└─────────────────────────────────────────────────────────────────┘
EOF
echo ""
}

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

# Source the API key manager functions
if [ -f "$SCRIPT_DIR/api_key_manager.sh" ]; then
    source "$SCRIPT_DIR/api_key_manager.sh"
fi

# Updated check_api_key function to use the new API key manager
check_api_key() {
    if command -v get_api_key >/dev/null 2>&1; then
        # Use the new API key manager
        local api_key
        api_key=$(get_api_key)
        if [ $? -eq 0 ] && [ ! -z "$api_key" ]; then
            export HUDDLEAI_API_KEY="$api_key"
            return 0
        else
            echo "⚠️ API key not found. Please run: ./api_key_manager.sh setup"
            return 1
        fi
    else
        # Fallback to legacy method
        if [ -z "$HUDDLEAI_API_KEY" ]; then
            if [ -f "$HOME/.ipfs/huddleai_api_key" ]; then
                export HUDDLEAI_API_KEY=$(cat "$HOME/.ipfs/huddleai_api_key")
            else
                echo "⚠️ HuddleAI API key not found."
                echo "Please enter your HuddleAI API key:"
                read -r -s HUDDLEAI_API_KEY
                if [ -n "$HUDDLEAI_API_KEY" ]; then
                    mkdir -p "$HOME/.ipfs"
                    echo "$HUDDLEAI_API_KEY" > "$HOME/.ipfs/huddleai_api_key"
                    chmod 600 "$HOME/.ipfs/huddleai_api_key"
                    echo "✅ API key saved to $HOME/.ipfs/huddleai_api_key"
                else
                    echo "❌ No API key provided"
                    return 1
                fi
            fi
        fi
        return 0
    fi
}

# Updated verify_api_key function to use the new API key manager
verify_api_key() {
    if command -v verify_all_services >/dev/null 2>&1; then
        # Use the new API key manager
        local api_key
        api_key=$(get_api_key)
        if [ $? -eq 0 ] && [ ! -z "$api_key" ]; then
            verify_all_services "$api_key" >/dev/null 2>&1
            return $?
        else
            return 1
        fi
    else
        # Fallback to legacy method
        if [ -z "$HUDDLEAI_API_KEY" ]; then
            echo "❌ No API key found"
            return 1
        fi
        
        echo "🔍 Verifying API key..."
        # Get the actual script directory using a more reliable method
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        VERIFY_RESULT=$(cd "$SCRIPT_DIR" && python3 -c "
import sys
import os
# Add the api directory to Python path
api_dir = os.path.join('$SCRIPT_DIR', 'api')
sys.path.insert(0, api_dir)
try:
    from apim.client import client
    success, message = client.verify_api_key()
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
                echo "✅ $MESSAGE"
                return 0
            else
                echo "❌ $MESSAGE"
                return 1
            fi
        else
            echo "❌ Python verification failed"
            return 1
        fi
    fi
}

# Function to create vector embeddings directory if it doesn't exist
ensure_embeddings_dir() {
    EMBEDDINGS_DIR="$HOME/.ipfs/embeddings"
    if [ ! -d "$EMBEDDINGS_DIR" ]; then
        mkdir -p "$EMBEDDINGS_DIR"
        echo -e "${GREEN}Created embeddings directory at $EMBEDDINGS_DIR${NC}"
    fi
    return 0
}

# Function to extract text from various file types
extract_text() {
    local file_path="$1"
    local file_type=$(file -b --mime-type "$file_path")
    
    echo -e "${BLUE}📄 Extracting text from $file_type file...${NC}"
    
    case "$file_type" in
        text/plain)
            cat "$file_path"
            ;;
        application/pdf)
            if command -v pdftotext &> /dev/null; then
                pdftotext -layout "$file_path" -
            else
                echo -e "${YELLOW}⚠️ pdftotext not installed. Install poppler-utils for PDF text extraction.${NC}"
                return 1
            fi
            ;;
        application/msword)
            if command -v antiword &> /dev/null; then
                antiword "$file_path"
            else
                echo -e "${YELLOW}⚠️ antiword not installed. Install antiword for Word document text extraction.${NC}"
                return 1
            fi
            ;;
        image/*)
            echo -e "${BLUE}🖼️ Processing image file using enhanced AI pipeline...${NC}"
            use_image_processor "$file_path"
            ;;
        *)
            echo -e "${YELLOW}⚠️ Unsupported file type: $file_type, trying OCR API${NC}"
            use_ocr_api "$file_path"
            ;;
    esac
    
    return 0
}

# Function to process images using the enhanced image processor
use_image_processor() {
    local file_path="$1"
    
    echo -e "${BLUE}🔍 Processing image with AI enhancement, object detection, and OCR...${NC}"
    
    # Check API key
    check_api_key || return 1
    
    # Use Python API client to process image comprehensively
    IMAGE_RESULT=$(cd "$SCRIPT_DIR" && python3 -c "
import sys
import json
import os
# Add the api directory to Python path
api_dir = os.path.join('$SCRIPT_DIR', 'api')
sys.path.insert(0, api_dir)
try:
    from apim.image_processor import image_processor
    
    result = image_processor.process_image_comprehensive('$file_path')
    
    if result and 'description' in result:
        # Extract text from OCR results
        ocr_text = result.get('text_extracted', {}).get('text', '')
        
        # Generate comprehensive description
        description = result.get('description', '')
        
        # Add object detection info
        objects = result.get('objects_detected', [])
        if objects:
            object_info = f'Objects detected: {len(objects)} items including '
            object_labels = [obj.get('label', 'unknown') for obj in objects[:3]]
            object_info += ', '.join(object_labels)
            if len(objects) > 3:
                object_info += f' and {len(objects) - 3} more'
            description = f'{object_info}. {description}'
        
        # Combine all text content
        full_text = f'{description}'
        if ocr_text.strip():
            full_text += f' Text content: {ocr_text}'
        
        print(full_text)
        sys.exit(0)
    else:
        print('Image processing failed or returned no results')
        sys.exit(1)
except Exception as e:
    print(f'Image processing error: {str(e)}')
    sys.exit(1)
")
    
    if [ $? -eq 0 ]; then
        echo "$IMAGE_RESULT"
        return 0
    else
        echo -e "${YELLOW}⚠️ Image processing failed: $IMAGE_RESULT${NC}"
        # Fallback to basic OCR
        use_ocr_api "$file_path"
    fi
}

# Function to use OCR API for text extraction
use_ocr_api() {
    local file_path="$1"
    
    # Check API key
    check_api_key || return 1
    
    # Use Python API client to extract text using OCR
    OCR_RESULT=$(cd "$SCRIPT_DIR" && python3 -c "
import sys
import os
# Add the api directory to Python path
api_dir = os.path.join('$SCRIPT_DIR', 'api')
sys.path.insert(0, api_dir)
try:
    from apim.ocr.client import OCRClient
    
    ocr_client = OCRClient()
    result = ocr_client.extract_text_from_document('$file_path', wait_for_completion=True, timeout=120)
    
    if result and 'text' in result:
        print(result['text'])
        sys.exit(0)
    else:
        print('OCR extraction failed or returned no text')
        sys.exit(1)
except Exception as e:
    print(f'OCR API error: {str(e)}')
    sys.exit(1)
")
    
    if [ $? -eq 0 ]; then
        echo "$OCR_RESULT"
        return 0
    else
        echo -e "${YELLOW}⚠️ OCR extraction failed: $OCR_RESULT${NC}"
        # Return minimal content to allow processing to continue
        echo "Binary file: $(basename "$file_path")"
        return 0
    fi
}

# Function to extract metadata from various file types
extract_metadata() {
    local file_path="$1"
    local file_type=$(file -b --mime-type "$file_path")
    local output_file="$2"
    local content_hash="$3"  # Add content hash parameter for better titles
    
    echo -e "${BLUE}📋 Extracting metadata from file...${NC}"
    
    # Initialize metadata JSON
    echo "{" > "$output_file"
    
    # Common metadata for all files
    echo "  \"metadata_storage_name\": \"$(basename "$file_path")\"," >> "$output_file"
    echo "  \"metadata_storage_size\": \"$(stat -f%z "$file_path")\"," >> "$output_file"
    echo "  \"metadata_content_type\": \"$file_type\"," >> "$output_file"
    
    # Initialize title and author variables for fallback logic
    local extracted_title=""
    local extracted_author=""
    local extracted_creation_date=""
    
    # Extract file-specific metadata based on file type
    case "$file_type" in
        application/pdf)
            if command -v pdfinfo &> /dev/null; then
                # Extract PDF metadata
                extracted_author=$(pdfinfo "$file_path" | grep "Author:" | sed 's/Author://' | tr -d '\r\n' | xargs)
                extracted_title=$(pdfinfo "$file_path" | grep "Title:" | sed 's/Title://' | tr -d '\r\n' | xargs)
                extracted_creation_date=$(pdfinfo "$file_path" | grep "CreationDate:" | sed 's/CreationDate://' | tr -d '\r\n' | xargs)
                local page_count=$(pdfinfo "$file_path" | grep "Pages:" | sed 's/Pages://' | tr -d '\r\n' | xargs)
                
                # Add to metadata JSON
                [ ! -z "$page_count" ] && echo "  \"metadata_page_count\": \"$page_count\"," >> "$output_file"
            fi
            ;;
        application/msword|application/vnd.openxmlformats-officedocument.wordprocessingml.document)
            # For Word documents, try to extract metadata if available tools
            if command -v exiftool &> /dev/null; then
                extracted_author=$(exiftool -Author "$file_path" 2>/dev/null | sed 's/Author://' | tr -d '\r\n' | xargs)
                extracted_title=$(exiftool -Title "$file_path" 2>/dev/null | sed 's/Title://' | tr -d '\r\n' | xargs)
                extracted_creation_date=$(exiftool -CreateDate "$file_path" 2>/dev/null | sed 's/Create Date://' | tr -d '\r\n' | xargs)
                local word_count=$(exiftool -WordCount "$file_path" 2>/dev/null | sed 's/Word Count://' | tr -d '\r\n' | xargs)
                
                # Add to metadata JSON
                [ ! -z "$word_count" ] && echo "  \"metadata_word_count\": \"$word_count\"," >> "$output_file"
            fi
            ;;
        application/vnd.ms-powerpoint|application/vnd.openxmlformats-officedocument.presentationml.presentation)
            # For PowerPoint documents
            if command -v exiftool &> /dev/null; then
                extracted_author=$(exiftool -Author "$file_path" 2>/dev/null | sed 's/Author://' | tr -d '\r\n' | xargs)
                extracted_title=$(exiftool -Title "$file_path" 2>/dev/null | sed 's/Title://' | tr -d '\r\n' | xargs)
                extracted_creation_date=$(exiftool -CreateDate "$file_path" 2>/dev/null | sed 's/Create Date://' | tr -d '\r\n' | xargs)
                local slide_count=$(exiftool -Slides "$file_path" 2>/dev/null | sed 's/Slides://' | tr -d '\r\n' | xargs)
                
                # Add to metadata JSON
                [ ! -z "$slide_count" ] && echo "  \"metadata_slide_count\": \"$slide_count\"," >> "$output_file"
            fi
            ;;
        text/html)
            # Extract metadata from HTML files
            if command -v grep &> /dev/null; then
                extracted_title=$(grep -o '<title>[^<]*</title>' "$file_path" 2>/dev/null | sed 's/<title>//;s/<\/title>//' | head -1)
                local description=$(grep -o '<meta name="description" content="[^"]*"' "$file_path" 2>/dev/null | sed 's/<meta name="description" content="//;s/"//' | head -1)
                local keywords=$(grep -o '<meta name="keywords" content="[^"]*"' "$file_path" 2>/dev/null | sed 's/<meta name="keywords" content="//;s/"//' | head -1)
                
                # Add to metadata JSON
                [ ! -z "$description" ] && echo "  \"metadata_description\": \"$description\"," >> "$output_file"
                [ ! -z "$keywords" ] && echo "  \"metadata_keywords\": \"$keywords\"," >> "$output_file"
            fi
            ;;
        text/plain|text/markdown)
            # For plain text and markdown files, try to extract title from first line
            if [ -f "$file_path" ]; then
                local first_line=$(head -n 1 "$file_path" | tr -d '\r\n' | xargs)
                # If first line looks like a title (short, no periods at end), use it
                if [ ${#first_line} -lt 100 ] && [[ ! "$first_line" =~ \.$  ]]; then
                    extracted_title="$first_line"
                fi
                
                # Try to extract author from common patterns
                local author_line=$(grep -i "author:\|by:\|written by" "$file_path" | head -n 1 | sed 's/.*author:\s*//i;s/.*by:\s*//i;s/.*written by\s*//i' | tr -d '\r\n' | xargs)
                [ ! -z "$author_line" ] && extracted_author="$author_line"
            fi
            ;;
        *)
            # For other file types, try generic metadata extraction
            if command -v exiftool &> /dev/null; then
                extracted_author=$(exiftool -Author "$file_path" 2>/dev/null | sed 's/Author://' | tr -d '\r\n' | xargs)
                extracted_title=$(exiftool -Title "$file_path" 2>/dev/null | sed 's/Title://' | tr -d '\r\n' | xargs)
                extracted_creation_date=$(exiftool -CreateDate "$file_path" 2>/dev/null | sed 's/Create Date://' | tr -d '\r\n' | xargs)
            fi
            ;;
    esac
    
    # Apply fallback logic for title
    if [ -z "$extracted_title" ] || [ "$extracted_title" = "null" ]; then
        local filename=$(basename "$file_path")
        local filename_no_ext="${filename%.*}"
        
        # Use filename without extension, or content hash if it's a temp file
        if [[ "$filename" =~ ^tmp\. ]] && [ ! -z "$content_hash" ]; then
            extracted_title="Content ${content_hash:0:8}"
        else
            extracted_title="$filename_no_ext"
        fi
    fi
    
    # Apply fallback logic for author
    if [ -z "$extracted_author" ] || [ "$extracted_author" = "null" ]; then
        # Try to get system user as fallback
        local system_user=$(whoami 2>/dev/null || echo "System")
        extracted_author="$system_user"
    fi
    
    # Apply fallback for creation date
    if [ -z "$extracted_creation_date" ] || [ "$extracted_creation_date" = "null" ]; then
        # Use file modification time as fallback
        if command -v stat &> /dev/null; then
            extracted_creation_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file_path" 2>/dev/null || date -u +"%Y-%m-%d %H:%M:%S")
        else
            extracted_creation_date=$(date -u +"%Y-%m-%d %H:%M:%S")
        fi
    fi
    
    # Add the processed metadata to JSON
    echo "  \"metadata_title\": \"$extracted_title\"," >> "$output_file"
    echo "  \"metadata_author\": \"$extracted_author\"," >> "$output_file"
    echo "  \"metadata_creation_date\": \"$extracted_creation_date\"," >> "$output_file"
    
    # Check for custom metadata file
    local metadata_file="${file_path}.metadata.txt"
    if [ -f "$metadata_file" ]; then
        echo -e "${BLUE}📋 Found custom metadata file, extracting...${NC}"
        
        # Read source URL (first line)
        local source_url=$(head -n 1 "$metadata_file" | tr -d '\r\n')
        [ ! -z "$source_url" ] && echo "  \"metadata_source_url\": \"$source_url\"," >> "$output_file"
        
        # Read tags (second line)
        local tags=$(sed -n '2p' "$metadata_file" | tr -d '\r\n')
        [ ! -z "$tags" ] && echo "  \"metadata_tags\": \"$tags\"," >> "$output_file"
        
        # Read any additional metadata lines (key:value format)
        tail -n +3 "$metadata_file" | while IFS=: read -r key value; do
            if [ ! -z "$key" ] && [ ! -z "$value" ]; then
                # Clean up key and value
                key=$(echo "$key" | tr -d '\r\n' | xargs)
                value=$(echo "$value" | tr -d '\r\n' | xargs)
                echo "  \"metadata_custom_${key}\": \"$value\"," >> "$output_file"
            fi
        done
    fi
    
    # Close JSON object (remove trailing comma from last line if present)
    sed -i '' '$ s/,$//' "$output_file"
    echo "}" >> "$output_file"
    
    echo -e "${GREEN}✅ Metadata extraction complete${NC}"
    return 0
}

# Function to clean text content (remove ANSI codes, OCR processing messages, etc.)
clean_text_content() {
    local TEXT="$1"
    
    # Remove ANSI escape sequences
    TEXT=$(echo "$TEXT" | sed -e 's/\x1b\[[0-9;]*m//g')
    
    # Remove OCR processing messages
    TEXT=$(echo "$TEXT" | sed -e 's/📄 Extracting text from [^\.]*\.\.\.//g')
    
    # Remove extra whitespace
    TEXT=$(echo "$TEXT" | sed -e 's/^[[:space:]]*//g' | sed -e 's/[[:space:]]*$//g' | sed -e 's/[[:space:]]\+/ /g')
    
    echo "$TEXT"
}

# Function to generate embeddings for text content
generate_embeddings() {
    local TEXT_FILE="$1"
    local OUTPUT_FILE="$2"
    
    # Check if API key is configured
    local API_KEY_STATUS=""
    if [ -f "$(dirname "$0")/api_key_manager.sh" ]; then
        API_KEY_STATUS=$(./api_key_manager.sh check 2>/dev/null | grep -o "verified\|invalid\|not found" | head -n 1)
    else
        # Try modern command
        API_KEY_STATUS=$(./hnm keys check 2>/dev/null | grep -o "verified\|invalid\|not found" | head -n 1)
    fi
    
    if [ "$API_KEY_STATUS" != "verified" ]; then
        echo -e "${YELLOW}⚠️ API key not configured or invalid${NC}"
        echo -e "${BLUE}💡 To enable semantic search:${NC}"
        echo "   1. Configure your API key: ./hnm keys setup"
        echo "   2. Re-index your content: hnm search build"
        echo ""
        echo -e "${BLUE}🔄 Attempting to continue with basic functionality...${NC}"
        
        # Try to create a basic index without embeddings
        local TEXT_CONTENT=$(cat "$TEXT_FILE")
        local TEXT_PREVIEW=$(clean_text_content "${TEXT_CONTENT:0:200}")
        
        cat > "$OUTPUT_FILE" << EOF
{
  "text_preview": $(echo "$TEXT_PREVIEW" | jq -R .),
  "embedding": null,
  "model_used": "none",
  "dimensions": 0,
  "metadata": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "note": "Basic indexing only - no semantic search available without API key"
  }
}
EOF
        
        echo -e "${YELLOW}⚠️ Created basic index without embeddings${NC}"
        echo -e "${YELLOW}   Semantic search will not be available for this content${NC}"
        return 0
    fi
    
    # Use Python with better libraries for text processing and embedding generation
    echo -e "${BLUE}🔗 Connecting to HuddleAI embedding service...${NC}"
    EMBEDDING_RESULT=$(cd "$SCRIPT_DIR" && python3 -c "
import sys
import json
import re
import os

# Add the api directory to Python path
api_dir = os.path.join('$SCRIPT_DIR', 'api')
sys.path.insert(0, api_dir)

def clean_text(text):
    # Remove OCR processing messages
    text = re.sub(r'📄 Extracting text from [^\.]*\.\.\.', '', text)
    
    # Remove extra whitespace, normalize spaces
    text = re.sub(r'\s+', ' ', text)
    text = text.strip()
    
    return text

try:
    # Read and clean the text
    with open('$TEXT_FILE', 'r') as f:
        text_content = f.read()
    
    # Clean the text properly
    clean_content = clean_text(text_content)
    
    # Create preview
    preview = clean_content[:200] if len(clean_content) > 200 else clean_content
    
    # Get embeddings
    from apim.client import client
    result = client.embeddings.embed_text(clean_content, model='auto')
    
    if result:
        # Create output with clean preview text
        output = {
            'text_preview': preview,
            'embedding': result['embedding'],
            'model_used': result['model_used'],
            'dimensions': result['dimensions'],
            'metadata': {
                'timestamp': '$(date -u +"%Y-%m-%dT%H:%M:%SZ")'
            }
        }
        
        print('SUCCESS')
        print(json.dumps(output))
    else:
        print('FAILED')
        print('Could not generate embedding')
except Exception as e:
    print('FAILED')
    print(f'Error: {str(e)}')
")
    
    STATUS=$(echo "$EMBEDDING_RESULT" | head -n 1)
    
    if [ "$STATUS" = "SUCCESS" ]; then
        # Extract the full output (skip the first SUCCESS line)
        OUTPUT_DATA=$(echo "$EMBEDDING_RESULT" | tail -n +2)
        
        # Save the complete output directly to file
        echo "$OUTPUT_DATA" > "$OUTPUT_FILE"
        
        # Extract model used for reporting
        MODEL_USED=$(echo "$OUTPUT_DATA" | jq -r '.model_used')
        
        echo -e "${GREEN}✅ Embeddings generated successfully using model: $MODEL_USED${NC}"
        return 0
    else
        # Extract error message (skip the first FAILED line)
        ERROR_MSG=$(echo "$EMBEDDING_RESULT" | tail -n +2)
        echo -e "${RED}❌ Failed to generate embeddings: $ERROR_MSG${NC}"
        
        # Provide helpful troubleshooting
        echo -e "${BLUE}🔧 Troubleshooting suggestions:${NC}"
        echo "   1. Check your API key: ./hnm keys status"
        echo "   2. Verify API access: ./hnm keys check"
        echo "   3. Run diagnostics: ./hnm troubleshoot api-key"
        echo "   4. Reset API key: ./hnm keys setup"
        echo ""
        
        # Check if it's a specific error we can help with
        if echo "$ERROR_MSG" | grep -q "400"; then
            echo -e "${YELLOW}💡 HTTP 400 Error - This usually means:${NC}"
            echo "   • Your API key doesn't have access to the embeddings service"
            echo "   • You need to subscribe to the embeddings service"
            echo "   • Visit: https://huddleai-apim.developer.azure-api.net"
        elif echo "$ERROR_MSG" | grep -q "401\|403"; then
            echo -e "${YELLOW}💡 Authentication Error - This usually means:${NC}"
            echo "   • Your API key is invalid or expired"
            echo "   • Run: ./hnm keys setup"
        elif echo "$ERROR_MSG" | grep -q "timeout\|connection"; then
            echo -e "${YELLOW}💡 Connection Error - This usually means:${NC}"
            echo "   • Check your internet connection"
            echo "   • The service might be temporarily unavailable"
            echo "   • Try again in a few minutes"
        fi
        
        # Offer to create basic index
        echo ""
        echo -e "${BLUE}🔄 Would you like to create a basic index without embeddings? (y/n)${NC}"
        read -r -n 1 response
        echo ""
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            local TEXT_CONTENT=$(cat "$TEXT_FILE")
            local TEXT_PREVIEW=$(clean_text_content "${TEXT_CONTENT:0:200}")
            
            cat > "$OUTPUT_FILE" << EOF
{
  "text_preview": $(echo "$TEXT_PREVIEW" | jq -R .),
  "embedding": null,
  "model_used": "none",
  "dimensions": 0,
  "metadata": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "note": "Basic indexing only - embedding generation failed",
    "error": $(echo "$ERROR_MSG" | jq -R .)
  }
}
EOF
            
            echo -e "${YELLOW}⚠️ Created basic index without embeddings${NC}"
            return 0
        else
            echo -e "${RED}❌ Indexing cancelled${NC}"
            return 1
        fi
    fi
}

# Function to index content in IPFS
index_content() {
    # Check if we have a hash or path
    if [ -z "$1" ]; then
        echo -e "${RED}❌ Error: No content hash or file path specified${NC}"
        echo -e "${YELLOW}Usage:${NC} hnm index [hash or file path]"
        return 1
    fi
    
    # Ensure daemon is running
    check_daemon || return 1
    
    # Ensure embeddings directory exists
    ensure_embeddings_dir || return 1
    
    # Determine if input is a hash or file path
    if [[ "$1" =~ ^Qm[a-zA-Z0-9]{44}$ || "$1" =~ ^bafy[a-zA-Z0-9]{44}$ ]]; then
        # Input is a hash
        CONTENT_HASH="$1"
        echo -e "${BLUE}🔍 Indexing content with hash: $CONTENT_HASH${NC}"
        
        # Check if content exists in IPFS
        if ! ipfs cat "$CONTENT_HASH" &>/dev/null; then
            echo -e "${RED}❌ Content not found in IPFS${NC}"
            return 1
        fi
        
        # Create temporary file for content
        TEMP_FILE=$(mktemp)
        if ! ipfs cat "$CONTENT_HASH" > "$TEMP_FILE"; then
            echo -e "${RED}❌ Failed to retrieve content from IPFS${NC}"
            rm "$TEMP_FILE"
            return 1
        fi
    else
        # Input is a file path
        if [ ! -f "$1" ]; then
            echo -e "${RED}❌ File not found: $1${NC}"
            return 1
        fi
        
        echo -e "${BLUE}🔍 Indexing file: $1${NC}"
        
        # Add file to IPFS if it's not already there
        echo -e "${BLUE}Adding file to IPFS...${NC}"
        CONTENT_HASH=$(ipfs add -Q "$1")
        
        if [ -z "$CONTENT_HASH" ]; then
            echo -e "${RED}❌ Failed to add file to IPFS${NC}"
            return 1
        fi
        
        echo -e "${GREEN}✅ File added to IPFS with hash: $CONTENT_HASH${NC}"
        TEMP_FILE="$1"
    fi
    
    # Extract text from the file
    echo -e "${BLUE}Extracting text from content...${NC}"
    TEXT_FILE=$(mktemp)
    if ! extract_text "$TEMP_FILE" > "$TEXT_FILE"; then
        echo -e "${YELLOW}⚠️ Text extraction may be incomplete${NC}"
    fi
    
    # Extract metadata from the file
    METADATA_FILE=$(mktemp)
    extract_metadata "$TEMP_FILE" "$METADATA_FILE" "$CONTENT_HASH"
    
    # Generate embeddings
    EMBEDDING_FILE="$HOME/.ipfs/embeddings/$CONTENT_HASH.json"
    if generate_embeddings "$TEXT_FILE" "$EMBEDDING_FILE"; then
        echo -e "${GREEN}✅ Embeddings generated successfully${NC}"
        
        # Merge metadata with embeddings
        if [ -f "$METADATA_FILE" ]; then
            echo -e "${BLUE}Merging metadata with embeddings...${NC}"
            
            # Validate that both files are non-empty and contain valid JSON
            if [ ! -s "$EMBEDDING_FILE" ]; then
                echo -e "${YELLOW}⚠️ Warning: Embedding file is empty, skipping merge${NC}"
            elif [ ! -s "$METADATA_FILE" ]; then
                echo -e "${YELLOW}⚠️ Warning: Metadata file is empty, skipping merge${NC}"
            elif ! jq empty "$EMBEDDING_FILE" 2>/dev/null; then
                echo -e "${YELLOW}⚠️ Warning: Embedding file contains invalid JSON, skipping merge${NC}"
            elif ! jq empty "$METADATA_FILE" 2>/dev/null; then
                echo -e "${YELLOW}⚠️ Warning: Metadata file contains invalid JSON, skipping merge${NC}"
            else
                # Create a temporary file for the merged JSON
                MERGED_FILE=$(mktemp)
                
                # Merge the embedding and metadata JSON files
                if jq -s '.[0] * .[1]' "$EMBEDDING_FILE" "$METADATA_FILE" > "$MERGED_FILE" 2>/dev/null; then
                    # Replace the original embedding file with the merged file
                    mv "$MERGED_FILE" "$EMBEDDING_FILE"
                    echo -e "${GREEN}✅ Metadata merged with embeddings${NC}"
                else
                    echo -e "${YELLOW}⚠️ Warning: Failed to merge metadata with embeddings${NC}"
                    rm -f "$MERGED_FILE"
                fi
            fi
        fi
        
        echo -e "${GREEN}✅ Content indexed successfully${NC}"
        echo -e "${BLUE}Content hash: $CONTENT_HASH${NC}"
        echo -e "${BLUE}Embeddings stored in: $HOME/.ipfs/embeddings/${CONTENT_HASH}.json${NC}"
    else
        echo -e "${RED}❌ Failed to index content${NC}"
    fi
    
    # Clean up temporary files
    if [[ "$1" =~ ^Qm[a-zA-Z0-9]{44}$ || "$1" =~ ^bafy[a-zA-Z0-9]{44}$ ]]; then
        rm "$TEMP_FILE"
    fi
    rm "$TEXT_FILE" "$METADATA_FILE"
    
    return 0
}

# Function to perform semantic search with metadata prioritization
search_content() {
    local QUERY="$1"
    local SEARCH_MODE="${2:-semantic}"  # Default to semantic search
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}❌ jq is required but not installed${NC}"
        echo "Please install jq first:"
        echo "  brew install jq"
        return 1
    fi
    
    # Ensure embeddings directory exists
    ensure_embeddings_dir
    
    # Check if we have any indexed content
    local EMBEDDINGS_DIR="$HOME/.ipfs/embeddings"
    local EMBEDDING_COUNT=$(find "$EMBEDDINGS_DIR" -name "*.json" | wc -l)
    
    if [ "$EMBEDDING_COUNT" -eq 0 ]; then
        echo -e "${YELLOW}⚠️ No indexed content found${NC}"
        echo "Index some content first with: hnm search build"
        return 1
    fi
    
    echo -e "${BLUE}🔍 Searching for: \"$QUERY\"${NC}"
    
    # Use Python for advanced search with metadata prioritization
    local TMP_DIR=$(mktemp -d)
    local QUERY_FILE="$TMP_DIR/query.txt"
    local RESULTS_FILE="$TMP_DIR/results.json"
    
    echo "$QUERY" > "$QUERY_FILE"
    
    # Check API key for semantic search
    if ! check_api_key; then
        echo -e "${YELLOW}⚠️ API key not configured - cannot perform semantic search${NC}"
        echo -e "${BLUE}💡 Run: ./hnm keys setup${NC}"
        return 1
    fi
    
    if ! verify_api_key; then
        echo -e "${YELLOW}⚠️ API key verification failed - cannot perform semantic search${NC}"
        echo -e "${BLUE}💡 Run: ./hnm troubleshoot api-key${NC}"
        return 1
    fi
    
    # Use Python for advanced search with metadata prioritization
    python3 -c "
import sys
import os
import json
import glob
import re
import numpy as np
from datetime import datetime

# Add the api directory to Python path
api_dir = os.path.join('$SCRIPT_DIR', 'api')
sys.path.insert(0, api_dir)

# Configure paths
embeddings_dir = os.path.expanduser('$EMBEDDINGS_DIR')
query_file = '$QUERY_FILE'
results_file = '$RESULTS_FILE'
search_mode = '$SEARCH_MODE'

# Helper functions
def clean_text(text):
    if not text:
        return ''
    # Remove OCR processing messages
    text = re.sub(r'📄 Extracting text from [^\.]*\.\.\.', '', text)
    # Remove extra whitespace
    text = re.sub(r'\s+', ' ', text)
    return text.strip()

def load_json_file(file_path):
    try:
        with open(file_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f'Error loading {file_path}: {str(e)}', file=sys.stderr)
        return None

# Read query
with open(query_file, 'r') as f:
    query = f.read().strip()

# Get list of embedding files
embedding_files = glob.glob(os.path.join(embeddings_dir, '*.json'))
print(f'Found {len(embedding_files)} indexed items', file=sys.stderr)

# Function to generate query embedding
def get_query_embedding(query_text):
    try:
        from apim.client import client
        result = client.embeddings.embed_text(query_text, model='auto')
        if result and 'embedding' in result:
            print(f'✅ Query embedding generated using {result.get(\"model_used\", \"unknown model\")}', file=sys.stderr)
            return result['embedding'], result.get('model_used', 'unknown')
        else:
            print('❌ Failed to generate query embedding', file=sys.stderr)
            return None, None
    except Exception as e:
        print(f'❌ Error generating query embedding: {str(e)}', file=sys.stderr)
        return None, None

# Function to calculate similarity between query and document
def calculate_similarity(query_embedding, doc_embedding):
    if not query_embedding or not doc_embedding:
        return 0.0
    
    try:
        # Convert to numpy arrays
        query_vec = np.array(query_embedding)
        doc_vec = np.array(doc_embedding)
        
        # Calculate cosine similarity
        dot_product = np.dot(query_vec, doc_vec)
        norm1 = np.linalg.norm(query_vec)
        norm2 = np.linalg.norm(doc_vec)
        
        if norm1 * norm2 == 0:
            return 0.0
        
        # Cosine similarity as percentage
        return float(dot_product / (norm1 * norm2) * 100)
    except Exception as e:
        print(f'Error calculating similarity: {str(e)}', file=sys.stderr)
        return 0.0

# Function to check exact match in metadata fields
def check_exact_matches(query, doc):
    query_lower = query.lower()
    
    # Initialize scores
    metadata_score = 0
    exact_match_found = False
    
    # Check for exact author match - highest priority
    author = doc.get('metadata_author', '')
    if author and author.lower() == query_lower:
        metadata_score += 100  # Perfect author match
        exact_match_found = True
    elif author and query_lower in author.lower():
        metadata_score += 50   # Partial author match
    
    # Check for exact title match
    title = doc.get('metadata_title', '')
    if title and title.lower() == query_lower:
        metadata_score += 90  # Perfect title match
        exact_match_found = True
    elif title and query_lower in title.lower():
        metadata_score += 40  # Partial title match
    
    # Check tags
    tags = doc.get('metadata_tags', '')
    if tags and query_lower in tags.lower():
        metadata_score += 30  # Tag match
    
    # Check preview text
    preview = doc.get('text_preview', '')
    if preview and query_lower in preview.lower():
        metadata_score += 20  # Content match
    
    # If we have an exact match, boost the score significantly
    if exact_match_found:
        metadata_score *= 2
    
    return metadata_score

# Process each document
results = []
query_embedding, model_used = get_query_embedding(query)

for file_path in embedding_files:
    try:
        # Load document data
        doc = load_json_file(file_path)
        if not doc:
            continue
        
        # Get document hash
        doc_hash = os.path.basename(file_path).replace('.json', '')
        
        # Initialize result
        result = {
            'hash': doc_hash,
            'title': doc.get('metadata_title', 'Untitled'),
            'author': doc.get('metadata_author', 'Unknown'),
            'preview': clean_text(doc.get('text_preview', '')),
            'source': doc.get('metadata_source_url', ''),
            'tags': doc.get('metadata_tags', '')
        }
        
        # Calculate semantic similarity if we have embeddings
        if query_embedding and 'embedding' in doc and doc['embedding']:
            result['similarity'] = calculate_similarity(query_embedding, doc['embedding'])
        else:
            result['similarity'] = 0
        
        # Check for exact matches in metadata
        result['metadata_score'] = check_exact_matches(query, doc)
        
        # Calculate final score - combine semantic and metadata scores
        # For author/title searches, metadata should have higher weight
        if result['metadata_score'] > 0:
            # If we have metadata matches, prioritize them
            result['final_score'] = result['metadata_score'] + (result['similarity'] * 0.5)
        else:
            # Otherwise use semantic similarity
            result['final_score'] = result['similarity']
        
        # Only include results that have some relevance
        # Either a positive semantic score or a metadata match
        if result['final_score'] > 0 or result['metadata_score'] > 0:
            results.append(result)
    except Exception as e:
        print(f'Error processing {file_path}: {str(e)}', file=sys.stderr)

# Sort results by final score
results.sort(key=lambda x: x['final_score'], reverse=True)

# Save top results
with open(results_file, 'w') as f:
    json.dump({
        'query': query,
        'model_used': model_used,
        'timestamp': datetime.now().isoformat(),
        'results': results[:5]  # Top 5 results
    }, f)

print(f'Search completed with {len(results)} relevant matches', file=sys.stderr)
"
    
    # Check if search was successful
    if [ -f "$RESULTS_FILE" ]; then
        # Display results
        echo -e "${GREEN}✅ Search results:${NC}"
        
        # Get model used
        MODEL_USED=$(jq -r '.model_used' "$RESULTS_FILE")
        echo -e "${BLUE}Using model: $MODEL_USED${NC}"
        echo "------------------------------------"
        
        # Process each result
        jq -c '.results[]' "$RESULTS_FILE" | while read -r result; do
            TITLE=$(echo "$result" | jq -r '.title')
            AUTHOR=$(echo "$result" | jq -r '.author')
            SIMILARITY=$(echo "$result" | jq -r '.similarity')
            METADATA_SCORE=$(echo "$result" | jq -r '.metadata_score')
            FINAL_SCORE=$(echo "$result" | jq -r '.final_score')
            HASH=$(echo "$result" | jq -r '.hash')
            PREVIEW=$(echo "$result" | jq -r '.preview')
            SOURCE=$(echo "$result" | jq -r '.source')
            TAGS=$(echo "$result" | jq -r '.tags')
            
            # Format scores for better display
            if (( $(echo "$SIMILARITY > 0" | bc -l) )); then
                # Only show positive similarity scores
                SIMILARITY_DISPLAY=$(printf "%.1f%%" "$SIMILARITY")
            else
                SIMILARITY_DISPLAY="--"
            fi
            
            # Format relevance score on a 0-100 scale
            if (( $(echo "$FINAL_SCORE > 100" | bc -l) )); then
                RELEVANCE="100%"
            else
                RELEVANCE=$(printf "%.0f%%" "$FINAL_SCORE")
            fi
            
            # Show why this result matched
            if [ "$METADATA_SCORE" -gt 0 ]; then
                if (( $(echo "$SIMILARITY > 0" | bc -l) )); then
                    MATCH_TYPE="Metadata + Content"
                else
                    MATCH_TYPE="Metadata Match"
                fi
            else
                MATCH_TYPE="Content Match"
            fi
            
            echo -e "${GREEN}Title:${NC} $TITLE"
            echo -e "${GREEN}Author:${NC} $AUTHOR"
            echo -e "${GREEN}Relevance:${NC} $RELEVANCE ($MATCH_TYPE)"
            echo -e "${GREEN}Hash:${NC} $HASH"
            [ ! -z "$SOURCE" ] && echo -e "${GREEN}Source:${NC} $SOURCE"
            [ ! -z "$TAGS" ] && echo -e "${GREEN}Tags:${NC} $TAGS"
            echo -e "${GREEN}Preview:${NC} ${PREVIEW:0:100}..."
            echo "------------------------------------"
        done
    else
        echo -e "${RED}❌ Search failed${NC}"
    fi
    
    # Clean up
    rm -rf "$TMP_DIR"
}

# Function to list indexed content
list_indexed() {
    local EMBEDDINGS_DIR="$HOME/.ipfs/embeddings"
    
    # Ensure embeddings directory exists
    ensure_embeddings_dir
    
    # Count indexed content
    local COUNT=$(find "$EMBEDDINGS_DIR" -name "*.json" | wc -l)
    
    if [ "$COUNT" -eq 0 ]; then
        echo "No indexed content found"
        return 0
    fi
    
    echo -e "${GREEN}Found $COUNT indexed items:${NC}"
    echo "------------------------------------"
    
    # List all indexed content with preview and metadata
    find "$EMBEDDINGS_DIR" -name "*.json" | while read -r FILE; do
        local HASH=$(basename "$FILE" .json)
        local PREVIEW=$(jq -r '.text_preview' "$FILE" 2>/dev/null || echo "No preview available")
        local TIMESTAMP=$(jq -r '.metadata.timestamp' "$FILE" 2>/dev/null || echo "Unknown date")
        
        echo -e "${GREEN}Hash:${NC} $HASH"
        echo -e "${GREEN}Indexed:${NC} $TIMESTAMP"
        
        # Display metadata if available
        echo -e "${GREEN}Metadata:${NC}"
        jq 'with_entries(select(.key | startswith("metadata_")))' "$FILE" 2>/dev/null | 
        grep -v "metadata\.timestamp" | 
        sed 's/^  "metadata_/  /' | 
        sed 's/":/: /' | 
        sed 's/[{"},]//g' | 
        grep -v "^$" | 
        while read -r line; do
            echo "  $line"
        done
        
        echo -e "${GREEN}Preview:${NC} ${PREVIEW:0:100}..."
        echo "------------------------------------"
    done
}

# Function to remove indexed content
remove_indexed() {
    # Check if we have a hash
    if [ -z "$1" ]; then
        echo -e "${RED}❌ Error: No content hash specified${NC}"
        echo -e "${YELLOW}Usage:${NC} hnm remove [hash]"
        return 1
    fi
    
    CONTENT_HASH="$1"
    EMBEDDINGS_DIR="$HOME/.ipfs/embeddings"
    
    # Check if embeddings exist for this hash
    if [ ! -f "$EMBEDDINGS_DIR/$CONTENT_HASH.json" ]; then
        echo -e "${RED}❌ No index found for hash: $CONTENT_HASH${NC}"
        return 1
    fi
    
    # Remove embeddings and metadata
    echo -e "${BLUE}Removing index for: $CONTENT_HASH${NC}"
    rm -f "$EMBEDDINGS_DIR/$CONTENT_HASH.json"
    
    echo -e "${GREEN}✅ Index removed successfully${NC}"
    return 0
}

# Function to build/rebuild search index for all pinned content
build_search_index() {
    echo -e "${BLUE}🔨 Building search index for all pinned content...${NC}"
    
    # Check API key first
    if ! check_api_key; then
        echo -e "${YELLOW}⚠️ API key not configured${NC}"
        echo -e "${BLUE}💡 You can still build a basic index without embeddings${NC}"
        echo -e "${BLUE}   For semantic search, configure your API key first: ./hnm keys setup${NC}"
        echo ""
        read -p "Continue with basic indexing? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            return 1
        fi
    fi
    
    # Ensure embeddings directory exists
    ensure_embeddings_dir
    
    # Get list of pinned content
    echo -e "${BLUE}📋 Getting list of pinned content...${NC}"
    local PINNED_ITEMS=$(ipfs pin ls --type=all --quiet 2>/dev/null | grep -v "QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn")
    
    if [ -z "$PINNED_ITEMS" ]; then
        echo -e "${YELLOW}⚠️ No pinned content found${NC}"
        echo "Add some content first with: hnm content add [file]"
        return 1
    fi
    
    local TOTAL_ITEMS=$(echo "$PINNED_ITEMS" | wc -l)
    local PROCESSED=0
    local UPDATED=0
    local FAILED=0
    local SKIPPED=0
    
    echo -e "${BLUE}📊 Found $TOTAL_ITEMS pinned items${NC}"
    
    # Check existing index status
    local EMBEDDINGS_DIR="$HOME/.ipfs/embeddings"
    local EXISTING_WITH_EMBEDDINGS=0
    local EXISTING_WITHOUT_EMBEDDINGS=0
    
    if [ -d "$EMBEDDINGS_DIR" ]; then
        EXISTING_WITH_EMBEDDINGS=$(find "$EMBEDDINGS_DIR" -name "*.json" -exec jq -r 'select(.embedding != null) | .text_preview' {} \; 2>/dev/null | wc -l)
        EXISTING_WITHOUT_EMBEDDINGS=$(find "$EMBEDDINGS_DIR" -name "*.json" -exec jq -r 'select(.embedding == null) | .text_preview' {} \; 2>/dev/null | wc -l)
        
        if [ "$EXISTING_WITH_EMBEDDINGS" -gt 0 ] || [ "$EXISTING_WITHOUT_EMBEDDINGS" -gt 0 ]; then
            echo -e "${BLUE}📋 Current index status:${NC}"
            echo "   • Items with embeddings: $EXISTING_WITH_EMBEDDINGS"
            echo "   • Items without embeddings: $EXISTING_WITHOUT_EMBEDDINGS"
            echo ""
            
            if [ "$EXISTING_WITHOUT_EMBEDDINGS" -gt 0 ]; then
                echo -e "${YELLOW}⚠️ Found $EXISTING_WITHOUT_EMBEDDINGS items without embeddings${NC}"
                echo -e "${BLUE}💡 These will be updated if API key is available${NC}"
            fi
        fi
    fi
    
    echo "Starting indexing process..."
    echo "------------------------------------"
    
    # Process each pinned item
    while IFS= read -r HASH; do
        PROCESSED=$((PROCESSED + 1))
        echo -e "${BLUE}[$PROCESSED/$TOTAL_ITEMS] Processing: $HASH${NC}"
        
        # Check if already indexed
        local INDEX_FILE="$EMBEDDINGS_DIR/${HASH}.json"
        local NEEDS_UPDATE=false
        local HAS_EMBEDDINGS=false
        
        if [ -f "$INDEX_FILE" ]; then
            HAS_EMBEDDINGS=$(jq -r '.embedding != null' "$INDEX_FILE" 2>/dev/null)
            if [ "$HAS_EMBEDDINGS" = "true" ]; then
                echo -e "${GREEN}✅ Already indexed with embeddings - skipping${NC}"
                SKIPPED=$((SKIPPED + 1))
                continue
            else
                echo -e "${YELLOW}🔄 Found basic index without embeddings - updating...${NC}"
                NEEDS_UPDATE=true
            fi
        fi
        
        # Try to index the content
        if index_content "$HASH"; then
            if [ "$NEEDS_UPDATE" = true ]; then
                UPDATED=$((UPDATED + 1))
                echo -e "${GREEN}✅ Updated with embeddings${NC}"
            else
                echo -e "${GREEN}✅ Indexed successfully${NC}"
            fi
        else
            FAILED=$((FAILED + 1))
            echo -e "${RED}❌ Failed to index${NC}"
        fi
        
        echo "------------------------------------"
    done <<< "$PINNED_ITEMS"
    
    # Summary
    echo -e "${BLUE}📊 Indexing Summary:${NC}"
    echo "   • Total items processed: $PROCESSED"
    echo "   • Successfully indexed/updated: $((PROCESSED - FAILED - SKIPPED))"
    echo "   • Updated from basic to full index: $UPDATED"
    echo "   • Already indexed (skipped): $SKIPPED"
    echo "   • Failed: $FAILED"
    
    # Final status check
    local FINAL_WITH_EMBEDDINGS=$(find "$EMBEDDINGS_DIR" -name "*.json" -exec jq -r 'select(.embedding != null) | .text_preview' {} \; 2>/dev/null | wc -l)
    local FINAL_WITHOUT_EMBEDDINGS=$(find "$EMBEDDINGS_DIR" -name "*.json" -exec jq -r 'select(.embedding == null) | .text_preview' {} \; 2>/dev/null | wc -l)
    
    echo ""
    echo -e "${BLUE}📋 Final index status:${NC}"
    echo "   • Items with embeddings (semantic search ready): $FINAL_WITH_EMBEDDINGS"
    echo "   • Items without embeddings (basic search only): $FINAL_WITHOUT_EMBEDDINGS"
    
    if [ "$FINAL_WITHOUT_EMBEDDINGS" -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}💡 To enable semantic search for all content:${NC}"
        echo "   1. Configure your API key: ./hnm keys setup"
        echo "   2. Run this command again: hnm search build"
    fi
    
    if [ "$FINAL_WITH_EMBEDDINGS" -gt 0 ]; then
        echo ""
        echo -e "${GREEN}🎉 Search index ready! Try: hnm search query \"your search term\"${NC}"
    fi
}

# Function to show metadata for indexed content without embeddings
show_metadata() {
    local EMBEDDINGS_DIR="$HOME/.ipfs/embeddings"
    
    if [ -z "$1" ]; then
        echo -e "${RED}❌ Error: No content hash specified${NC}"
        echo -e "${YELLOW}Usage:${NC} hnm search metadata [hash]"
        echo -e "${YELLOW}       hnm search metadata --all${NC}"
        return 1
    fi
    
    # Ensure embeddings directory exists
    ensure_embeddings_dir
    
    if [ "$1" = "--all" ]; then
        # Show metadata for all indexed content
        echo -e "${GREEN}📋 Metadata for all indexed content:${NC}"
        echo "===================================="
        
        local COUNT=0
        find "$EMBEDDINGS_DIR" -name "*.json" | while read -r FILE; do
            local HASH=$(basename "$FILE" .json)
            COUNT=$((COUNT + 1))
            
            echo -e "${BLUE}[$COUNT] Hash: $HASH${NC}"
            echo "------------------------------------"
            
            # Display metadata without embedding
            if jq -e '.embedding' "$FILE" >/dev/null 2>&1; then
                jq 'del(.embedding)' "$FILE" 2>/dev/null | jq . 2>/dev/null
            else
                jq . "$FILE" 2>/dev/null
            fi
            
            echo ""
        done
        
        if [ "$COUNT" -eq 0 ]; then
            echo -e "${YELLOW}No indexed content found${NC}"
        fi
        
        return 0
    fi
    
    # Show metadata for specific hash
    local HASH="$1"
    local METADATA_FILE="$EMBEDDINGS_DIR/${HASH}.json"
    
    if [ ! -f "$METADATA_FILE" ]; then
        echo -e "${RED}❌ No metadata found for hash: $HASH${NC}"
        echo -e "${YELLOW}💡 Tip: Use 'hnm search list' to see indexed content${NC}"
        return 1
    fi
    
    echo -e "${GREEN}📋 Metadata for: $HASH${NC}"
    echo "===================================="
    
    # Display metadata without embedding vector
    if jq -e '.embedding' "$METADATA_FILE" >/dev/null 2>&1; then
        jq 'del(.embedding)' "$METADATA_FILE" 2>/dev/null | jq . 2>/dev/null
    else
        jq . "$METADATA_FILE" 2>/dev/null
    fi
    
    # Show additional info
    echo ""
    echo -e "${BLUE}🔗 Access content:${NC}"
    echo "  - Local: http://localhost:8080/ipfs/$HASH"
    echo "  - Public: https://ipfs.io/ipfs/$HASH"
    echo "  - Command: ipfs cat $HASH"
    
    return 0
}

# Function to display banner
display_banner() {
cat << "EOF"
┌─────────────────────────────────────────────────────────────────┐
│                      HUDDLE NODE MANAGER                       │
│                                                                 │
│  🏠 Search Manager                                              │
│  🔍 Advanced IPFS Content Search                               │
│  ⬆️  Upgraded from IPFS Search Manager                         │
│  🔧 Part of Huddle Node Manager Suite                          │
└─────────────────────────────────────────────────────────────────┘
EOF
echo ""
}

# Function to get appropriate command prefix based on calling context
get_command_prefix() {
    # Always use modern command format in help text for consistency
    echo "hnm search"
}

# Function to show help message
show_help() {
    display_banner
    echo "🏠 HNM (Huddle Node Manager) - Search Manager"
    echo "============================================="
    echo "🔍 Advanced IPFS content search and indexing with enhanced UX"
    echo ""
    
    # Use context-aware command prefix
    local CMD_PREFIX=$(get_command_prefix)
    echo "Usage: $CMD_PREFIX [command] [options]"
    echo ""
    echo "🎯 Commands:"
    echo "  index [hash]           - Index a specific IPFS content hash"
    echo "  [search terms]         - Search for content in the index"
    echo "  build                  - Rebuild the search index from all pinned content"
    echo "  list                   - List all indexed content"
    echo "  remove [hash]          - Remove indexed content"
    echo "  metadata [hash]        - Show metadata for indexed content"
    echo "  help                   - Show this help message"
    echo ""
    echo "⚙️  Options:"
    echo "  --quiet, -q            - Minimal output"
    echo "  --verbose, -v          - Verbose output"
    echo "  --json                 - Output in JSON format"
    echo ""
    echo "💡 Examples:"
    echo "  $CMD_PREFIX index QmHash123..."
    echo "  $CMD_PREFIX \"blockchain technology\""
    echo "  $CMD_PREFIX build"
    echo ""
    echo "🚀 Command Format:"
    echo "   This tool is part of the Huddle Node Manager (HNM) suite"
    echo "   All operations can be performed using the '$CMD_PREFIX' prefix"
}

# Main function
main() {
    # No arguments, show help
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    # Parse first argument
    FIRST_ARG="$1"
    
    # Check if first argument is a known command
    case "$FIRST_ARG" in
        index)
            shift
            index_content "$1"
            ;;
        search)
            shift
            search_content "$1"
            ;;
        list)
            shift
            list_indexed
            ;;
        remove)
            shift
            remove_indexed "$1"
            ;;
        build)
            shift
            build_search_index
            ;;
        help|--help|-h)
            show_help
            ;;
        metadata)
            shift
            show_metadata "$1"
            ;;
        *)
            # If it's not a known command, treat it as a search query
            # This allows "hnm search quantum computing" to work directly
            search_content "$*"
            ;;
    esac
    
    exit $?
}

# If this script is being executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 