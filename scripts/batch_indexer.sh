#!/bin/bash
#
# Batch IPFS Content Indexer
# A utility for batch indexing of content in IPFS using parallel processing
#

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Source the image classifier script
source "$(dirname "$0")/scripts/image_classifier_batch.sh"

# ASCII Art Logo
show_logo() {
cat << "EOF"
 _____ ____  _____ ____    ____        _       _     
|_   _|  _ \|  ___/ ___|  | __ )  __ _| |_ ___| |__  
  | | | |_) | |_  \___ \  |  _ \ / _` | __/ __| '_ \ 
  | | |  __/|  _|  ___) | | |_) | (_| | || (__| | | |
  |_| |_|   |_|   |____/  |____/ \__,_|\__\___|_| |_|
                                                    
=====================================================
    IPFS Batch Indexer | Index Content in Parallel
=====================================================
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

# Function to check if API key is set
check_api_key() {
    API_KEY_FILE=~/.ipfs/huddleai_api_key
    
    if [ -z "$HUDDLEAI_API_KEY" ]; then
        if [ -f "$API_KEY_FILE" ]; then
            export HUDDLEAI_API_KEY=$(cat "$API_KEY_FILE")
        else
            echo -e "${YELLOW}⚠️ HuddleAI API key not found${NC}"
            echo "Please set your HuddleAI API key:"
            read -r -s API_KEY
            
            if [ -z "$API_KEY" ]; then
                echo -e "${RED}❌ No API key provided${NC}"
                return 1
            fi
            
            # Save API key
            mkdir -p ~/.ipfs
            echo "$API_KEY" > "$API_KEY_FILE"
            chmod 600 "$API_KEY_FILE"
            export HUDDLEAI_API_KEY="$API_KEY"
            echo -e "${GREEN}✅ API key saved successfully${NC}"
        fi
    fi
    return 0
}

# Function to verify API key
verify_api_key() {
    echo -e "${BLUE}🔑 Verifying API key...${NC}"
    
    # Use Python API client to verify key
    python3 -c "
import sys
sys.path.append('$(dirname "$0")/api')
from apim.client import client
success, message = client.verify_api_key('embeddings')
print('SUCCESS' if success else 'FAILED')
print(message)
" > /tmp/api_check.txt 2>&1
    
    STATUS=$(cat /tmp/api_check.txt | head -n 1)
    MESSAGE=$(cat /tmp/api_check.txt | tail -n 1)
    
    if [ "$STATUS" = "SUCCESS" ]; then
        echo -e "${GREEN}✅ API key verified${NC}"
        return 0
    else
        echo -e "${RED}❌ API key verification failed: $MESSAGE${NC}"
        return 1
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

# Function to validate file before processing
validate_file() {
    local FILE_PATH="$1"
    local STRICT_MODE="${2:-false}"
    
    echo -e "${BLUE}🔍 Validating file: $(basename "$FILE_PATH")${NC}"
    
    # Use the validation script
    if [ "$STRICT_MODE" = "true" ]; then
        "$(dirname "$0")/scripts/validate_content.sh" --strict "$FILE_PATH"
    else
        "$(dirname "$0")/scripts/validate_content.sh" "$FILE_PATH"
    fi
    
    local RESULT=$?
    if [ $RESULT -eq 0 ]; then
        return 0
    else
        echo -e "${RED}❌ File validation failed: $(basename "$FILE_PATH")${NC}"
        return 1
    fi
}

# Function to extract text from various file types
extract_text() {
    local file_path="$1"
    local file_type=$(file -b --mime-type "$file_path")
    
    case "$file_type" in
        text/plain|text/markdown|text/html|application/json|application/xml)
            cat "$file_path"
            ;;
        application/pdf)
            if command -v pdftotext &> /dev/null; then
                pdftotext "$file_path" -
            else
                echo -e "${YELLOW}⚠️ pdftotext not installed. Falling back to OCR API.${NC}"
                use_ocr_api "$file_path"
            fi
            ;;
        application/msword|application/vnd.openxmlformats-officedocument.wordprocessingml.document)
            if command -v antiword &> /dev/null; then
                antiword "$file_path"
            else
                echo -e "${YELLOW}⚠️ antiword not installed. Falling back to OCR API.${NC}"
                use_ocr_api "$file_path"
            fi
            ;;
        image/jpeg|image/png|image/tiff|image/gif|image/bmp)
            echo -e "${YELLOW}🖼️ Processing image with classifier: $file_path${NC}"
            # Use our image classifier to get a description
            local image_description=$(classify_image "$file_path")
            if [ $? -eq 0 ]; then
                echo "$image_description"
            else
                echo -e "${YELLOW}⚠️ Image classification failed, falling back to OCR API${NC}"
                use_ocr_api "$file_path"
            fi
            ;;
        application/zip|application/x-zip-compressed)
            echo -e "${YELLOW}⚠️ Cannot extract text from zip file: $file_path${NC}"
            echo "Archive file: $(basename "$file_path")"
            return 0
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

# Function to use OCR API for text extraction
use_ocr_api() {
    local file_path="$1"
    
    # Check API key
    check_api_key || return 1
    
    # Use Python API client to extract text using OCR
    OCR_RESULT=$(python3 -c "
import sys
import os
sys.path.append('$HOME/huddle-node-manager/api')
try:
    from apim.ocr.client import extract_text_from_document
    
    result = extract_text_from_document('$file_path', wait_for_completion=True, timeout=120)
    
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

# Function to process images using the enhanced image processor
use_image_processor() {
    local file_path="$1"
    
    echo -e "${BLUE}🔍 Processing image with AI enhancement, object detection, and OCR...${NC}"
    
    # Check API key
    check_api_key || return 1
    
    # Use Python API client to process image comprehensively
    IMAGE_RESULT=$(python3 -c "
import sys
import json
sys.path.append('$(dirname "$0")/api')
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

# Function to extract metadata from various file types
extract_metadata() {
    local file_path="$1"
    local file_type=$(file -b --mime-type "$file_path")
    local output_file="$2"
    
    # Initialize metadata JSON
    echo "{" > "$output_file"
    
    # Common metadata for all files
    echo "  \"metadata_storage_name\": \"$(basename "$file_path")\"," >> "$output_file"
    echo "  \"metadata_storage_size\": \"$(stat -f%z "$file_path")\"," >> "$output_file"
    echo "  \"metadata_content_type\": \"$file_type\"," >> "$output_file"
    
    # For image files, add classification data if available
    if [[ "$file_type" == image/* ]]; then
        local temp_classification="/tmp/classification_output.json"
        if [ -f "$temp_classification" ]; then
            # Extract top predictions
            local top_prediction=$(jq -r '.predictions[0].label' "$temp_classification")
            if [ ! -z "$top_prediction" ] && [ "$top_prediction" != "null" ]; then
                echo "  \"metadata_image_class\": \"$top_prediction\"," >> "$output_file"
                
                # Add all predictions as a JSON array
                local all_predictions=$(jq -c '.predictions' "$temp_classification")
                echo "  \"metadata_image_predictions\": $all_predictions," >> "$output_file"
            fi
        fi
    fi
    
    # Close JSON (remove trailing comma from last line if present)
    sed -i '' '$ s/,$//' "$output_file"
    echo "}" >> "$output_file"
    
    return 0
}

# Function to generate batch embeddings
generate_batch_embeddings() {
    local BATCH_DIR="$1"
    local OUTPUT_DIR="$2"
    local BATCH_SIZE="$3"
    
    echo -e "${BLUE}🧠 Generating batch embeddings for $BATCH_SIZE files...${NC}"
    
    # Check API key
    check_api_key || return 1
    
    # Create a JSON file with all texts
    local BATCH_JSON="$BATCH_DIR/batch.json"
    echo "{\"texts\": [" > "$BATCH_JSON"
    
    # Add each text file to the batch
    local COUNT=0
    for TEXT_FILE in "$BATCH_DIR"/*.txt; do
        if [ -f "$TEXT_FILE" ]; then
            TEXT_CONTENT=$(cat "$TEXT_FILE")
            TEXT_HASH=$(basename "$TEXT_FILE" .txt)
            
            # Add to JSON, with comma if not first item
            if [ $COUNT -gt 0 ]; then
                echo "," >> "$BATCH_JSON"
            fi
            
            # Escape JSON special characters
            echo "$(echo "$TEXT_CONTENT" | jq -Rs .)" >> "$BATCH_JSON"
            
            COUNT=$((COUNT + 1))
        fi
    done
    
    echo "]}" >> "$BATCH_JSON"
    
    if [ $COUNT -eq 0 ]; then
        echo -e "${YELLOW}⚠️ No text files found in batch directory${NC}"
        return 1
    fi
    
    # Use Python API client to generate batch embeddings
    EMBEDDING_RESULT=$(python3 -c "
import sys
import json
import os
sys.path.append('$(dirname "$0")/api')
try:
    from apim.client import client
    
    # Load batch texts
    with open('$BATCH_JSON', 'r') as f:
        batch_data = json.load(f)
    
    # Use auto model selection for best results
    result = client.embeddings.embed_batch(batch_data['texts'], model='auto')
    
    if result:
        print('SUCCESS')
        
        # Save individual embeddings
        embeddings = result.get('embeddings')
        model_used = result.get('model_used')
        dimensions = result.get('dimensions')
        
        # Get list of text files
        text_files = sorted([f for f in os.listdir('$BATCH_DIR') if f.endswith('.txt')])
        
        # Create individual embedding files
        for i, text_file in enumerate(text_files):
            if i < len(embeddings):
                hash_id = os.path.splitext(text_file)[0]
                
                # Get text preview
                with open(os.path.join('$BATCH_DIR', text_file), 'r') as f:
                    text_content = f.read()
                    text_preview = text_content[:200]
                
                # Create embedding file
                output_file = os.path.join('$OUTPUT_DIR', hash_id + '.json')
                
                with open(output_file, 'w') as f:
                    json.dump({
                        'text_preview': text_preview,
                        'embedding': embeddings[i],
                        'model_used': model_used,
                        'dimensions': dimensions,
                        'metadata': {
                            'timestamp': '$(date -u +"%Y-%m-%dT%H:%M:%SZ")'
                        }
                    }, f, indent=2)
                
                print(f'Created: {output_file}')
        
        print(f'Model used: {model_used}')
    else:
        print('FAILED')
        print('Could not generate embeddings')
except Exception as e:
    print('FAILED')
    print(f'Error: {str(e)}')
")
    
    STATUS=$(echo "$EMBEDDING_RESULT" | head -n 1)
    
    if [ "$STATUS" = "SUCCESS" ]; then
        # Extract the model used
        MODEL_USED=$(echo "$EMBEDDING_RESULT" | grep "Model used:" | sed 's/Model used: //')
        
        echo -e "${GREEN}✅ Batch embeddings generated successfully using model: $MODEL_USED${NC}"
        return 0
    else
        # Extract error message (skip the first FAILED line)
        ERROR_MSG=$(echo "$EMBEDDING_RESULT" | tail -n +2)
        echo -e "${RED}❌ Failed to generate batch embeddings: $ERROR_MSG${NC}"
        return 1
    fi
}

# Function to process files in batches
process_batch() {
    local FILES=("$@")
    local BATCH_SIZE=10
    local TOTAL=${#FILES[@]}
    local BATCHES=$(( (TOTAL + BATCH_SIZE - 1) / BATCH_SIZE ))
    
    echo -e "${BLUE}Processing $TOTAL files in $BATCHES batches of up to $BATCH_SIZE files each${NC}"
    
    # Ensure embeddings directory exists
    ensure_embeddings_dir || return 1
    
    local INDEXED=0
    local FAILED=0
    local SKIPPED=0
    
    # Process files in batches
    for ((b=0; b<BATCHES; b++)); do
        local START=$((b * BATCH_SIZE))
        local END=$(( (b+1) * BATCH_SIZE < TOTAL ? (b+1) * BATCH_SIZE : TOTAL ))
        local BATCH_COUNT=$((END - START))
        
        echo -e "${BLUE}Processing batch $((b+1))/$BATCHES with $BATCH_COUNT files${NC}"
        
        # Create temporary batch directory
        local BATCH_DIR=$(mktemp -d)
        
        # Track which files in this batch are valid
        local VALID_FILES=()
        local VALID_NAMES=()
        local VALID_COUNT=0
        
        # Process each file in this batch
        for ((i=START; i<END; i++)); do
            local FILE="${FILES[i]}"
            local FILE_NAME=$(basename "$FILE")
            
            echo -e "[$((i+1))/$TOTAL] ${BLUE}Processing:${NC} $FILE_NAME"
            
            # Validate file before processing
            if ! validate_file "$FILE" "$STRICT_MODE"; then
                echo -e "[$((i+1))/$TOTAL] ${YELLOW}⚠️ Skipping invalid file:${NC} $FILE_NAME"
                SKIPPED=$((SKIPPED + 1))
                continue
            fi
            
            # Add file to IPFS
            local CONTENT_HASH=$(ipfs add -Q "$FILE")
            
            if [ -z "$CONTENT_HASH" ]; then
                echo -e "[$((i+1))/$TOTAL] ${RED}Failed to add file to IPFS:${NC} $FILE_NAME"
                FAILED=$((FAILED + 1))
                continue
            fi
            
            echo -e "[$((i+1))/$TOTAL] ${GREEN}Added to IPFS:${NC} $CONTENT_HASH"
            
            # Extract text from the file
            local TEXT_FILE="$BATCH_DIR/$CONTENT_HASH.txt"
            if ! extract_text "$FILE" > "$TEXT_FILE"; then
                echo -e "[$((i+1))/$TOTAL] ${YELLOW}⚠️ Text extraction may be incomplete:${NC} $FILE_NAME"
            fi
            
            # Extract metadata from the file
            local METADATA_FILE="$BATCH_DIR/$CONTENT_HASH.metadata.json"
            extract_metadata "$FILE" "$METADATA_FILE"
            
            # Add to valid files list
            VALID_FILES+=("$FILE")
            VALID_NAMES+=("$FILE_NAME")
            VALID_COUNT=$((VALID_COUNT + 1))
        done
        
        # If no valid files in this batch, continue to next batch
        if [ $VALID_COUNT -eq 0 ]; then
            echo -e "${YELLOW}⚠️ No valid files in this batch, skipping embedding generation${NC}"
            rm -rf "$BATCH_DIR"
            continue
        fi
        
        # Generate batch embeddings
        if generate_batch_embeddings "$BATCH_DIR" "$HOME/.ipfs/embeddings" "$VALID_COUNT"; then
            # Merge metadata with embeddings
            for ((i=0; i<VALID_COUNT; i++)); do
                local FILE="${VALID_FILES[i]}"
                local FILE_NAME="${VALID_NAMES[i]}"
                local CONTENT_HASH=$(ipfs add -Q "$FILE")
                
                if [ ! -z "$CONTENT_HASH" ]; then
                    local EMBEDDING_FILE="$HOME/.ipfs/embeddings/$CONTENT_HASH.json"
                    local METADATA_FILE="$BATCH_DIR/$CONTENT_HASH.metadata.json"
                    
                    if [ -f "$EMBEDDING_FILE" ] && [ -f "$METADATA_FILE" ]; then
                        # Create a temporary file for the merged JSON
                        local MERGED_FILE=$(mktemp)
                        
                        # Merge the embedding and metadata JSON files
                        jq -s '.[0] * .[1]' "$EMBEDDING_FILE" "$METADATA_FILE" > "$MERGED_FILE"
                        
                        # Replace the original embedding file with the merged file
                        mv "$MERGED_FILE" "$EMBEDDING_FILE"
                        
                        echo -e "${GREEN}✅ Indexed successfully:${NC} $FILE_NAME"
                        INDEXED=$((INDEXED + 1))
                    else
                        echo -e "${RED}❌ Failed to index:${NC} $FILE_NAME"
                        FAILED=$((FAILED + 1))
                    fi
                fi
            done
        else
            # If batch embedding failed, mark all valid files in batch as failed
            for ((i=0; i<VALID_COUNT; i++)); do
                echo -e "${RED}❌ Failed to index:${NC} ${VALID_NAMES[i]}"
                FAILED=$((FAILED + 1))
            done
        fi
        
        # Clean up batch directory
        rm -rf "$BATCH_DIR"
        
        # Add delay between batches to avoid rate limiting
        if [ $((b+1)) -lt $BATCHES ]; then
            echo -e "${YELLOW}Waiting 2 seconds before processing next batch...${NC}"
            sleep 2
        fi
    done
    
    echo -e "${GREEN}✅ Batch indexing completed!${NC}"
    echo -e "${BLUE}Total files: $TOTAL${NC}"
    echo -e "${GREEN}Successfully indexed: $INDEXED${NC}"
    echo -e "${YELLOW}Skipped invalid files: $SKIPPED${NC}"
    echo -e "${RED}Failed to index: $FAILED${NC}"
    
    return 0
}

# Function to show help message
show_help() {
    show_logo
    echo -e "${BLUE}IPFS Batch Indexer${NC}"
    echo -e "A utility for batch indexing of content in IPFS using parallel processing"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  $0 [directory] [options]"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  --batch-size N    - Set batch size (default: 10)"
    echo "  --strict          - Enable strict mode"
    echo "  --help            - Show this help message"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 ./data                  # Index all files in ./data directory"
    echo "  $0 ./data --batch-size 20  # Index with batch size of 20"
    echo ""
}

# Main function
main() {
    # No arguments, show help
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    # Parse arguments
    local DIRECTORY=""
    local BATCH_SIZE=10
    local STRICT_MODE=false
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --batch-size)
                BATCH_SIZE="$2"
                shift 2
                ;;
            --strict)
                STRICT_MODE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                if [ -z "$DIRECTORY" ]; then
                    DIRECTORY="$1"
                    shift
                else
                    echo -e "${RED}❌ Unknown argument: $1${NC}"
                    show_help
                    exit 1
                fi
                ;;
        esac
    done
    
    # Check if directory exists
    if [ ! -d "$DIRECTORY" ]; then
        echo -e "${RED}❌ Directory not found: $DIRECTORY${NC}"
        exit 1
    fi
    
    # Ensure daemon is running
    check_daemon || exit 1
    
    # Check API key
    check_api_key || exit 1
    verify_api_key || exit 1
    
    # Find all files in directory
    echo -e "${BLUE}🔍 Scanning directory: $DIRECTORY${NC}"
    
    # Get list of files
    FILES=()
    while IFS= read -r -d '' file; do
        FILES+=("$file")
    done < <(find "$DIRECTORY" -type f -not -path "*/\.*" -print0)
    
    local FILE_COUNT=${#FILES[@]}
    
    if [ $FILE_COUNT -eq 0 ]; then
        echo -e "${YELLOW}⚠️ No files found in directory${NC}"
        exit 0
    fi
    
    echo -e "${BLUE}Found $FILE_COUNT files to process${NC}"
    
    # Process files in batches
    process_batch "${FILES[@]}"
    
    exit $?
}

# If this script is being executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 