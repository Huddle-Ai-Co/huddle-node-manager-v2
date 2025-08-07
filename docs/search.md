# IPFS Semantic Search

## Overview

IPFS Semantic Search is an advanced feature that allows you to find content based on meaning rather than exact text matches. It uses vector embeddings and cosine similarity to enable natural language search across your IPFS content. The system extracts both content and metadata from files, providing rich search results and context.

## Requirements

- HuddleAI API subscription (sign up at https://huddleai-apim.developer.azure-api.net)
- Basic command-line tools: `jq`, `curl`
- Optional tools for enhanced metadata extraction:
  - `exiftool` - For extracting metadata from various file formats
  - `pdfinfo` - For extracting metadata from PDF files

## Search Commands

The following commands are available for semantic search:

```
hnm search index [hash/file] - Index content for semantic search
hnm search query "text"      - Perform semantic search with a query
hnm search list              - List indexed content
hnm search remove [hash]     - Remove indexed content
hnm search build             - Build search index from all pinned content
```

### Examples

Index a file:
```
hnm search index my_document.pdf
```

Index content already in IPFS:
```
hnm search index QmbnJGwXFk9ej9SrKGGRSjb7zKkvow1XCfvxqWzwDpY447
```

Search for content:
```
hnm search query "decentralized storage solutions"
```

List indexed content:
```
hnm search list
```

Remove indexed content:
```
hnm search remove QmbnJGwXFk9ej9SrKGGRSjb7zKkvow1XCfvxqWzwDpY447
```

## How It Works

### Indexing Process

1. **Content Extraction**: When you index a file or IPFS hash, the system extracts plain text from the content.
2. **Metadata Extraction**: The system extracts metadata from the file (author, title, creation date, etc.) based on file type.
3. **Vector Generation**: The text is sent to the HuddleAI API to generate vector embeddings.
4. **Storage**: Both the embeddings and metadata are stored in a JSON file in the `~/.ipfs/embeddings/` directory.

### Searching Process

1. **Query Embedding**: Your search query is converted to a vector embedding.
2. **Similarity Calculation**: The system calculates the cosine similarity between your query and all indexed content.
3. **Ranking**: Results are ranked by similarity score and returned with relevant metadata.

## Metadata Extraction

The search system automatically extracts metadata from indexed files to enhance search results and provide context. Different file types have different metadata available:

### Supported Metadata

- **All Files**:
  - File name
  - File size
  - Content type (MIME type)

- **PDF Files** (requires `pdfinfo`):
  - Author
  - Title
  - Creation date
  - Page count

- **Word Documents** (requires `exiftool`):
  - Author
  - Title
  - Creation date
  - Word count

- **PowerPoint Documents** (requires `exiftool`):
  - Author
  - Title
  - Creation date
  - Slide count

- **HTML Files**:
  - Title
  - Description
  - Keywords

### Custom Metadata

You can add custom metadata to any file by creating a `.metadata.txt` file alongside it. For example, for a file named `document.pdf`, create `document.pdf.metadata.txt` with the following format:

```
https://example.com/source-url
tag1,tag2,tag3
custom_field1:custom_value1
custom_field2:custom_value2
```

- First line: Source URL
- Second line: Comma-separated tags
- Additional lines: Custom metadata in key:value format

## Technical Details

### File Structure

Embeddings and metadata are stored in JSON files in the `~/.ipfs/embeddings/` directory. Each file is named after the IPFS hash of the content.

### Performance Considerations

- Indexing large files may take time depending on their size and complexity.
- The search performance depends on the number of indexed items.
- Metadata extraction depends on available tools and file formats.

### Supported File Types

The text extraction works best with the following file types:
- Plain text (.txt)
- Markdown (.md)
- HTML (.html, .htm)
- PDF (.pdf) - requires text layer
- Word documents (.docx, .doc) - with limitations
- Other text-based formats

## API Key Management

To use the semantic search feature, you need a HuddleAI API key:

1. Sign up for a HuddleAI API subscription at https://huddleai-apim.developer.azure-api.net
2. Set your API key using the following command:
```
hnm search apikey
```
3. The key will be securely stored in your home directory.

## Advanced Usage

### Building a Complete Index

To index all your pinned content:
```
hnm search build
```

This will index all content that is currently pinned in your IPFS node.

### Integration with Content Management

The search feature integrates with the content management features of IPFS Node Manager:
- When you add and pin content, consider indexing it for searchability.
- When you unpin content, you may want to remove it from the search index as well.

## Troubleshooting

### Missing API Key

If you see an error about a missing API key, set it using:
```
hnm search apikey
```

### Missing Tools

If metadata extraction is incomplete, you may need to install additional tools:
```
brew install exiftool
brew install poppler (for pdfinfo)
```

### Unsupported File Types

If your file type is not supported for text extraction, you might see warnings. Consider converting the file to a supported format.

### Index Problems

If your search index becomes corrupted, you can remove it and rebuild:
```
rm -rf ~/.ipfs/embeddings
hnm search build
```

## Future Enhancements

- Support for more file types and metadata extraction
- Advanced query capabilities (filtering by metadata)
- Integration with IPFS MFS (Mutable File System)
- Support for more advanced language models 