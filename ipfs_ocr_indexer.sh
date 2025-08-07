#!/bin/bash

# IPFS OCR Document Indexer
# This script processes documents with OCR, creates vector embeddings,
# and stores them on IPFS to create a decentralized vector index

# Configuration
API_ENDPOINT="https://huddleai-apim.azure-api.net/hocr/v2/api/ocr"
SUBSCRIPTION_KEY="ee5e7e98141646538d5d90531b8c3689"
EMBEDDING_API="https://api.openai.com/v1/embeddings"  # You'll need to set your OpenAI API key
OPENAI_API_KEY="your_openai_api_key_here"  # Replace with your actual API key
VECTOR_DIMENSION=1536  # Dimension for OpenAI embeddings
CHUNK_SIZE=1000  # Text chunk size for vector embeddings
PAGE_CHUNK_SIZE=5  # Pages per chunk for OCR processing
TEST_MODE=true  # Set to true to skip actual API calls for vector embeddings

# Directory structure
TEMP_DIR="./ipfs_ocr_temp"
INDEX_DIR="$TEMP_DIR/index"
VECTORS_DIR="$TEMP_DIR/vectors"
DOCUMENTS_DIR="$TEMP_DIR/documents"
METADATA_DIR="$TEMP_DIR/metadata"

# Create necessary directories
mkdir -p "$INDEX_DIR" "$VECTORS_DIR" "$DOCUMENTS_DIR" "$METADATA_DIR"

# Function to check if IPFS is running
check_ipfs() {
    if ! ipfs swarm peers &>/dev/null; then
        echo "Error: IPFS daemon is not running. Please start it with 'ipfs daemon' or use your helper script."
        exit 1
    fi
    echo "✅ IPFS daemon is running"
}

# Function to get PDF page count
get_pdf_page_count() {
    local PDF_FILE=$1
    # Try to use pdfinfo if available
    if command -v pdfinfo &> /dev/null; then
        pdfinfo "$PDF_FILE" | grep "Pages:" | awk '{print $2}'
    else
        # Default to a reasonable estimate based on file size
        local FILE_SIZE_KB=$(du -k "$PDF_FILE" | cut -f1)
        local FILE_SIZE_MB=$(echo "$FILE_SIZE_KB / 1024" | bc)
        # Estimate 10 pages per MB with a minimum of 1
        local ESTIMATED_PAGES=$((FILE_SIZE_MB * 10))
        if [ $ESTIMATED_PAGES -lt 1 ]; then
            ESTIMATED_PAGES=1
        fi
        echo $ESTIMATED_PAGES
    fi
}

# Function to process a file with OCR in chunks
process_file_with_ocr() {
    local FILE=$1
    local FILE_ID=$(echo "$FILE" | md5sum | cut -d' ' -f1)
    local BASENAME=$(basename "$FILE")
    local OUTPUT_DIR="$TEMP_DIR/chunks_${BASENAME%.*}"
    mkdir -p "$OUTPUT_DIR"
    
    # Get estimated page count
    local PAGE_COUNT=30
    if [[ "$FILE" == *.pdf ]]; then
        PAGE_COUNT=$(get_pdf_page_count "$FILE")
    fi
    
    echo "Processing file with OCR: $FILE"
    echo "Estimated page count: $PAGE_COUNT"
    echo "Started at: $(date)"
    
    # Process file in page chunks
    local CHUNK_START=1
    local SUCCESS_COUNT=0
    local FAIL_COUNT=0
    
    while [ $CHUNK_START -le $PAGE_COUNT ]; do
        local CHUNK_END=$((CHUNK_START + PAGE_CHUNK_SIZE - 1))
        if [ $CHUNK_END -gt $PAGE_COUNT ]; then
            CHUNK_END=$PAGE_COUNT
        fi
        
        local PAGE_RANGE="${CHUNK_START}-${CHUNK_END}"
        local CHUNK_OUTPUT="$OUTPUT_DIR/chunk_${PAGE_RANGE}.json"
        local CHUNK_ERROR="$OUTPUT_DIR/chunk_${PAGE_RANGE}.err"
        
        echo "Processing page range: $PAGE_RANGE"
        
        # Calculate timeout based on chunk size (30 seconds per page with a minimum of 120 seconds)
        local CHUNK_SIZE=$((CHUNK_END - CHUNK_START + 1))
        local TIMEOUT=$((CHUNK_SIZE * 30))
        if [ $TIMEOUT -lt 120 ]; then
            TIMEOUT=120
        fi
        echo "Setting timeout to $TIMEOUT seconds for this chunk"
        
        # Process the chunk
        curl -X POST "$API_ENDPOINT" \
             -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
             -H "Accept: application/json" \
             -F "file=@$FILE;type=application/pdf" \
             -F "output_format=text" \
             -F "processing_type=advanced" \
             -F "use_fallback=true" \
             -F "extract_images=false" \
             -F "extract_tables=false" \
             -F "page_range=$PAGE_RANGE" \
             --max-time $TIMEOUT \
             --retry 2 \
             --retry-delay 5 \
             -s 2> "$CHUNK_ERROR" > "$CHUNK_OUTPUT"
        
        if [ $? -eq 0 ] && [ -s "$CHUNK_OUTPUT" ] && ! grep -q "statusCode.*[45][0-9][0-9]" "$CHUNK_OUTPUT"; then
            echo "✓ Successfully processed page range: $PAGE_RANGE"
            ((SUCCESS_COUNT++))
        else
            echo "✗ Failed to process page range: $PAGE_RANGE"
            ((FAIL_COUNT++))
        fi
        
        # Move to next chunk
        CHUNK_START=$((CHUNK_END + 1))
        
        # Add a small delay between chunks to avoid overwhelming the API
        if [ $CHUNK_START -le $PAGE_COUNT ]; then
            echo "Waiting 5 seconds before processing next chunk..."
            sleep 5
        fi
    done
    
    # Combine chunks into a single output file
    local COMBINED_OUTPUT="$TEMP_DIR/output_${BASENAME%.*}_response.json"
    echo "Combining chunks into $COMBINED_OUTPUT..."
    
    # Create a combined JSON structure
    echo "{" > "$COMBINED_OUTPUT"
    echo "  \"file_id\": \"combined_${FILE_ID}\"," >> "$COMBINED_OUTPUT"
    echo "  \"original_filename\": \"$BASENAME\"," >> "$COMBINED_OUTPUT"
    echo "  \"total_pages\": $PAGE_COUNT," >> "$COMBINED_OUTPUT"
    echo "  \"file_type\": \"pdf\"," >> "$COMBINED_OUTPUT"
    echo "  \"success\": true," >> "$COMBINED_OUTPUT"
    echo "  \"processing_time\": 0," >> "$COMBINED_OUTPUT"
    echo "  \"pages\": [" >> "$COMBINED_OUTPUT"
    
    # Add each chunk's pages to the combined output
    local FIRST_PAGE=true
    for CHUNK_FILE in "$OUTPUT_DIR"/chunk_*.json; do
        if [ -s "$CHUNK_FILE" ] && grep -q "\"pages\":" "$CHUNK_FILE"; then
            # Extract individual pages from the chunk
            local PAGE_START=$(grep -n "\"pages\":" "$CHUNK_FILE" | cut -d: -f1)
            local PAGE_END=$(grep -n "\"total_pages\":" "$CHUNK_FILE" | cut -d: -f1)
            
            if [ -n "$PAGE_START" ] && [ -n "$PAGE_END" ]; then
                # Extract the content between "pages": [ and the next ],
                local PAGES_JSON=$(sed -n "/\"pages\":/,/\],/p" "$CHUNK_FILE")
                # Remove the "pages": [ and the trailing ],
                PAGES_JSON=$(echo "$PAGES_JSON" | sed '1d;$d')
                
                # Process each page object in the chunk
                echo "$PAGES_JSON" | grep -o "{[^}]*}" | while read -r PAGE_OBJ; do
                    if [ "$FIRST_PAGE" = true ]; then
                        FIRST_PAGE=false
                    else
                        echo "," >> "$COMBINED_OUTPUT"
                    fi
                    echo "    $PAGE_OBJ" >> "$COMBINED_OUTPUT"
                done
            fi
        fi
    done
    
    echo "  ]" >> "$COMBINED_OUTPUT"
    echo "}" >> "$COMBINED_OUTPUT"
    
    echo "Finished OCR processing at: $(date)"
    
    # Extract plain text from the OCR result for vector embedding
    local TEXT_OUTPUT="$TEMP_DIR/text_${BASENAME%.*}.txt"
    echo "Extracting plain text from OCR result..."
    
    # Use jq if available, otherwise fallback to grep and sed
    if command -v jq &> /dev/null; then
        jq -r '.pages[].text' "$COMBINED_OUTPUT" > "$TEXT_OUTPUT"
    else
        grep -o '"text":"[^"]*"' "$COMBINED_OUTPUT" | sed 's/"text":"//;s/"$//' > "$TEXT_OUTPUT"
    fi
    
    echo "Text extraction complete. Saved to $TEXT_OUTPUT"
    echo "-----------------------------------"
    
    # Return the path to the extracted text file
    echo "$TEXT_OUTPUT"
}

# Function to create vector embeddings from text
create_vector_embeddings() {
    local TEXT_FILE=$1
    local BASENAME=$(basename "$TEXT_FILE" .txt)
    local CHUNKS_DIR="$VECTORS_DIR/${BASENAME}_chunks"
    mkdir -p "$CHUNKS_DIR"
    
    echo "Creating vector embeddings for: $TEXT_FILE"
    echo "Started at: $(date)"
    
    # Split text into chunks
    local LINE_COUNT=$(wc -l < "$TEXT_FILE")
    local LINES_PER_CHUNK=50  # Adjust based on your needs
    local CHUNK_COUNT=$(( (LINE_COUNT + LINES_PER_CHUNK - 1) / LINES_PER_CHUNK ))
    
    echo "Splitting text into $CHUNK_COUNT chunks..."
    split -l $LINES_PER_CHUNK "$TEXT_FILE" "$CHUNKS_DIR/chunk_"
    
    # Process each chunk and create embeddings
    local VECTORS_FILE="$VECTORS_DIR/${BASENAME}_vectors.json"
    echo "[" > "$VECTORS_FILE"
    
    local FIRST_CHUNK=true
    for CHUNK_FILE in "$CHUNKS_DIR"/chunk_*; do
        local CHUNK_ID=$(basename "$CHUNK_FILE")
        local CHUNK_TEXT=$(cat "$CHUNK_FILE")
        
        echo "Processing chunk: $CHUNK_ID"
        
        # In test mode, generate a fake embedding vector
        if [ "$TEST_MODE" = true ]; then
            echo "TEST MODE: Generating fake embedding vector"
            # Generate a fake embedding with 10 random values (instead of 1536)
            local EMBEDDING="["
            for i in {1..10}; do
                EMBEDDING+="$(echo "scale=6; $RANDOM/32767" | bc)"
                if [ $i -lt 10 ]; then
                    EMBEDDING+=", "
                fi
            done
            EMBEDDING+="]"
        else
            # Create embedding using OpenAI API
            local EMBEDDING_RESULT=$(curl -s -X POST "$EMBEDDING_API" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $OPENAI_API_KEY" \
                -d "{
                    \"input\": \"$CHUNK_TEXT\",
                    \"model\": \"text-embedding-ada-002\"
                }")
            
            # Extract the embedding vector
            local EMBEDDING=$(echo "$EMBEDDING_RESULT" | grep -o '"embedding":\[[^]]*\]' | sed 's/"embedding"://')
        fi
        
        if [ -n "$EMBEDDING" ]; then
            # Add the chunk and its vector to the vectors file
            if [ "$FIRST_CHUNK" = true ]; then
                FIRST_CHUNK=false
            else
                echo "," >> "$VECTORS_FILE"
            fi
            
            echo "  {" >> "$VECTORS_FILE"
            echo "    \"chunk_id\": \"$CHUNK_ID\"," >> "$VECTORS_FILE"
            echo "    \"text\": $(printf '%s' "$CHUNK_TEXT" | jq -R -s '.')," >> "$VECTORS_FILE"
            echo "    \"vector\": $EMBEDDING" >> "$VECTORS_FILE"
            echo "  }" >> "$VECTORS_FILE"
            
            echo "✓ Successfully created embedding for chunk: $CHUNK_ID"
        else
            echo "✗ Failed to create embedding for chunk: $CHUNK_ID"
        fi
        
        # Add a small delay between API calls
        sleep 1
    done
    
    echo "]" >> "$VECTORS_FILE"
    
    echo "Vector embeddings created and saved to: $VECTORS_FILE"
    echo "Finished at: $(date)"
    echo "-----------------------------------"
    
    # Return the path to the vectors file
    echo "$VECTORS_FILE"
}

# Function to upload a file to IPFS and return the CID
upload_to_ipfs() {
    local FILE=$1
    local BASENAME=$(basename "$FILE")
    
    echo "Uploading to IPFS: $BASENAME"
    
    # Upload to IPFS and get the CID
    local CID=$(ipfs add -Q "$FILE")
    
    if [ -n "$CID" ]; then
        echo "✓ Successfully uploaded to IPFS: $BASENAME"
        echo "  CID: $CID"
    else
        echo "✗ Failed to upload to IPFS: $BASENAME"
        return 1
    fi
    
    # Pin the content to ensure it's not garbage collected
    ipfs pin add "$CID"
    
    # Return the CID
    echo "$CID"
}

# Function to update the index with a new document
update_index() {
    local DOCUMENT_PATH=$1
    local TEXT_PATH=$2
    local VECTORS_PATH=$3
    local DOCUMENT_CID=$4
    local TEXT_CID=$5
    local VECTORS_CID=$6
    
    local BASENAME=$(basename "$DOCUMENT_PATH")
    local DOCUMENT_ID=$(echo "$BASENAME" | md5sum | cut -d' ' -f1)
    
    echo "Updating index with document: $BASENAME"
    
    # Create metadata for the document
    local METADATA_FILE="$METADATA_DIR/${DOCUMENT_ID}_metadata.json"
    
    echo "{" > "$METADATA_FILE"
    echo "  \"document_id\": \"$DOCUMENT_ID\"," >> "$METADATA_FILE"
    echo "  \"filename\": \"$BASENAME\"," >> "$METADATA_FILE"
    echo "  \"document_cid\": \"$DOCUMENT_CID\"," >> "$METADATA_FILE"
    echo "  \"text_cid\": \"$TEXT_CID\"," >> "$METADATA_FILE"
    echo "  \"vectors_cid\": \"$VECTORS_CID\"," >> "$METADATA_FILE"
    echo "  \"added_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"," >> "$METADATA_FILE"
    echo "  \"file_type\": \"${BASENAME##*.}\"" >> "$METADATA_FILE"
    echo "}" >> "$METADATA_FILE"
    
    # Upload metadata to IPFS
    local METADATA_CID=$(upload_to_ipfs "$METADATA_FILE")
    
    # Update the master index
    local INDEX_FILE="$INDEX_DIR/master_index.json"
    
    # Create the index file if it doesn't exist
    if [ ! -f "$INDEX_FILE" ]; then
        echo "{" > "$INDEX_FILE"
        echo "  \"documents\": []," >> "$INDEX_FILE"
        echo "  \"last_updated\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"" >> "$INDEX_FILE"
        echo "}" >> "$INDEX_FILE"
    fi
    
    # Add the document to the index
    local TMP_INDEX="$INDEX_DIR/tmp_index.json"
    
    # Use jq if available, otherwise use a more basic approach
    if command -v jq &> /dev/null; then
        jq --arg id "$DOCUMENT_ID" \
           --arg cid "$METADATA_CID" \
           --arg date "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
           '.documents += [{"id": $id, "metadata_cid": $cid}] | .last_updated = $date' \
           "$INDEX_FILE" > "$TMP_INDEX"
        mv "$TMP_INDEX" "$INDEX_FILE"
    else
        # Basic approach using sed
        sed -i.bak 's/"documents": \[/"documents": \[{"id": "'$DOCUMENT_ID'", "metadata_cid": "'$METADATA_CID'"},/g' "$INDEX_FILE"
        sed -i.bak 's/"last_updated": "[^"]*"/"last_updated": "'"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'"/g' "$INDEX_FILE"
        rm -f "$INDEX_FILE.bak"
    fi
    
    # Upload the updated index to IPFS
    local INDEX_CID=$(upload_to_ipfs "$INDEX_FILE")
    
    echo "✓ Index updated and uploaded to IPFS"
    echo "  Index CID: $INDEX_CID"
    echo "-----------------------------------"
    
    # Return the index CID
    echo "$INDEX_CID"
}

# Function to search the vector index
search_vector_index() {
    local QUERY=$1
    local INDEX_CID=$2
    
    echo "Searching vector index for: $QUERY"
    
    # In test mode, generate a fake embedding vector for the query
    if [ "$TEST_MODE" = true ]; then
        echo "TEST MODE: Generating fake query embedding vector"
        local QUERY_EMBEDDING="[0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]"
    else
        # Create an embedding for the query
        local QUERY_EMBEDDING=$(curl -s -X POST "$EMBEDDING_API" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $OPENAI_API_KEY" \
            -d "{
                \"input\": \"$QUERY\",
                \"model\": \"text-embedding-ada-002\"
            }" | grep -o '"embedding":\[[^]]*\]' | sed 's/"embedding"://')
    fi
    
    if [ -z "$QUERY_EMBEDDING" ]; then
        echo "✗ Failed to create embedding for query"
        return 1
    fi
    
    # Download the index from IPFS
    local TMP_INDEX="$TEMP_DIR/tmp_index.json"
    ipfs get -o "$TMP_INDEX" "$INDEX_CID"
    
    # Process each document in the index
    local RESULTS=()
    
    # Use jq to extract document IDs and metadata CIDs
    if command -v jq &> /dev/null; then
        while read -r line; do
            local DOC_ID=$(echo "$line" | jq -r '.id')
            local METADATA_CID=$(echo "$line" | jq -r '.metadata_cid')
            
            # Download metadata
            local TMP_METADATA="$TEMP_DIR/tmp_metadata.json"
            ipfs get -o "$TMP_METADATA" "$METADATA_CID"
            
            # Get vectors CID
            local VECTORS_CID=$(jq -r '.vectors_cid' "$TMP_METADATA")
            
            # Download vectors
            local TMP_VECTORS="$TEMP_DIR/tmp_vectors.json"
            ipfs get -o "$TMP_VECTORS" "$VECTORS_CID"
            
            # Calculate similarity with each vector (this is a simplified approach)
            # In a real implementation, you would use a proper vector similarity calculation
            local MAX_SIMILARITY=0
            local BEST_CHUNK=""
            
            # For now, we'll just print the vectors file path for manual analysis
            echo "Downloaded vectors for document $DOC_ID: $TMP_VECTORS"
            
            # Add to results
            RESULTS+=("$DOC_ID")
        done < <(jq -c '.documents[]' "$TMP_INDEX")
    else
        echo "⚠️ jq not found. Cannot process search without jq."
        return 1
    fi
    
    echo "Search results:"
    for result in "${RESULTS[@]}"; do
        echo "  - Document ID: $result"
    done
    
    echo "-----------------------------------"
}

# Main function to process a document
process_document() {
    local DOCUMENT_PATH=$1
    
    echo "==================================="
    echo "Processing document: $DOCUMENT_PATH"
    echo "==================================="
    
    # Step 1: Process with OCR
    local TEXT_PATH=$(process_file_with_ocr "$DOCUMENT_PATH")
    
    # Step 2: Create vector embeddings
    local VECTORS_PATH=$(create_vector_embeddings "$TEXT_PATH")
    
    # Step 3: Upload original document to IPFS
    local DOCUMENT_CID=$(upload_to_ipfs "$DOCUMENT_PATH")
    
    # Step 4: Upload extracted text to IPFS
    local TEXT_CID=$(upload_to_ipfs "$TEXT_PATH")
    
    # Step 5: Upload vectors to IPFS
    local VECTORS_CID=$(upload_to_ipfs "$VECTORS_PATH")
    
    # Step 6: Update the index
    local INDEX_CID=$(update_index "$DOCUMENT_PATH" "$TEXT_PATH" "$VECTORS_PATH" "$DOCUMENT_CID" "$TEXT_CID" "$VECTORS_CID")
    
    echo "Document processing complete!"
    echo "Document CID: $DOCUMENT_CID"
    echo "Text CID: $TEXT_CID"
    echo "Vectors CID: $VECTORS_CID"
    echo "Index CID: $INDEX_CID"
    echo "==================================="
    
    # Return the index CID
    echo "$INDEX_CID"
}

# Display help message
show_help() {
    echo "IPFS OCR Document Indexer"
    echo "-------------------------"
    echo "Usage: $0 [command] [arguments]"
    echo ""
    echo "Commands:"
    echo "  index [file]         - Process and index a document"
    echo "  search [query] [cid] - Search the index using a query"
    echo "  help                 - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 index document.pdf"
    echo "  $0 search \"quantum computing\" QmIndexCID"
}

# Main script execution
check_ipfs

# Process command line arguments
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

case "$1" in
    index)
        if [ -z "$2" ]; then
            echo "Error: No document specified"
            show_help
            exit 1
        fi
        
        if [ ! -f "$2" ]; then
            echo "Error: Document not found: $2"
            exit 1
        fi
        
        process_document "$2"
        ;;
    search)
        if [ -z "$2" ]; then
            echo "Error: No query specified"
            show_help
            exit 1
        fi
        
        if [ -z "$3" ]; then
            echo "Error: No index CID specified"
            show_help
            exit 1
        fi
        
        search_vector_index "$2" "$3"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Error: Unknown command: $1"
        show_help
        exit 1
        ;;
esac

exit 0 