#!/usr/bin/env python3
"""
Markdown to PDF Converter for Translated Benchmark Documents

This script converts all translated markdown files to PDF format,
preserving formatting and ensuring consistent styling across all languages.
"""

import os
import sys
import argparse
import logging
from pathlib import Path
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Languages and their names for reference
LANGUAGES = {
    "ar": "Arabic",
    "cs": "Czech",
    "en": "English",
    "es": "Spanish",
    "fr": "French",
    "kk": "Kazakh",
    "pt": "Portuguese",
    "ru": "Russian",
    "sk": "Slovak",
    "sv": "Swedish",
    "tr": "Turkish",
    "uz": "Uzbek",
    "zh": "Chinese"
}

def check_dependencies():
    """
    Check if required dependencies are installed.
    """
    try:
        # Check for pandoc
        pandoc_version = subprocess.check_output(['pandoc', '--version'], text=True)
        logger.info(f"Found pandoc: {pandoc_version.splitlines()[0]}")
        
        # Check for wkhtmltopdf (optional, used by some pandoc PDF conversions)
        try:
            wkhtml_version = subprocess.check_output(['wkhtmltopdf', '--version'], text=True)
            logger.info(f"Found wkhtmltopdf: {wkhtml_version.strip()}")
        except (subprocess.SubprocessError, FileNotFoundError):
            logger.warning("wkhtmltopdf not found. PDF quality might be affected.")
        
        return True
    except (subprocess.SubprocessError, FileNotFoundError):
        logger.error("Required dependency 'pandoc' not found. Please install it first.")
        logger.error("Installation instructions: https://pandoc.org/installing.html")
        return False

def convert_markdown_to_pdf(markdown_file, output_file, language_code=None):
    """
    Convert a markdown file to PDF using pandoc.
    
    Args:
        markdown_file: Path to the markdown file
        output_file: Path to save the PDF file
        language_code: ISO language code for the document
    
    Returns:
        bool: True if conversion was successful, False otherwise
    """
    try:
        # Base command
        cmd = [
            'pandoc',
            str(markdown_file),
            '-o', str(output_file),
            '--pdf-engine=xelatex',
            '--variable', 'geometry:margin=1in',
            '--variable', 'fontsize=11pt',
            '--toc',  # Add table of contents
        ]
        
        # Add language-specific settings
        if language_code:
            if language_code == 'ar':
                # For Arabic, use RTL and appropriate font
                cmd.extend([
                    '--variable', 'dir=rtl',
                    '--variable', 'mainfont=Amiri',
                ])
            elif language_code == 'zh':
                # For Chinese, use appropriate font
                cmd.extend([
                    '--variable', 'mainfont=Noto Sans CJK SC',
                ])
            elif language_code == 'ru' or language_code == 'kk' or language_code == 'uz':
                # For Cyrillic-based languages
                cmd.extend([
                    '--variable', 'mainfont=DejaVu Serif',
                ])
        
        # Execute pandoc command
        logger.info(f"Converting {markdown_file} to PDF...")
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        
        if os.path.exists(output_file):
            logger.info(f"Successfully created PDF: {output_file}")
            return True
        else:
            logger.error(f"PDF file not created despite successful command execution")
            return False
            
    except subprocess.CalledProcessError as e:
        logger.error(f"Error converting {markdown_file} to PDF: {e}")
        logger.error(f"STDOUT: {e.stdout}")
        logger.error(f"STDERR: {e.stderr}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error converting {markdown_file} to PDF: {e}")
        return False

def process_file(markdown_file, output_dir):
    """
    Process a single markdown file to convert it to PDF.
    """
    try:
        file_path = Path(markdown_file)
        file_name = file_path.name
        
        # Extract language code from filename
        language_code = None
        for code in LANGUAGES.keys():
            if f"_{code}.md" in file_name:
                language_code = code
                break
        
        # Create output filename
        output_file = output_dir / file_name.replace('.md', '.pdf')
        
        # Convert the file
        success = convert_markdown_to_pdf(file_path, output_file, language_code)
        
        return file_path.name, success
    except Exception as e:
        logger.error(f"Error processing {markdown_file}: {e}")
        return markdown_file, False

def main():
    parser = argparse.ArgumentParser(description="Convert translated markdown files to PDF")
    parser.add_argument("--input-dir", default="Triple_Model_Clinical_Comparison/translations",
                        help="Directory containing translated markdown files")
    parser.add_argument("--output-dir", default="Triple_Model_Clinical_Comparison/pdf_translations",
                        help="Directory to save PDF files")
    parser.add_argument("--max-workers", type=int, default=4,
                        help="Maximum number of parallel conversion workers")
    
    args = parser.parse_args()
    
    # Check dependencies
    if not check_dependencies():
        return 1
    
    # Create output directory if it doesn't exist
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Get all markdown files in the input directory
    input_dir = Path(args.input_dir)
    markdown_files = list(input_dir.glob("*.md"))
    
    if not markdown_files:
        logger.error(f"No markdown files found in {input_dir}")
        return 1
    
    logger.info(f"Found {len(markdown_files)} markdown files to convert")
    
    # Process files in parallel
    results = {}
    with ThreadPoolExecutor(max_workers=args.max_workers) as executor:
        future_to_file = {
            executor.submit(process_file, file, output_dir): file
            for file in markdown_files
        }
        
        for future in as_completed(future_to_file):
            file = future_to_file[future]
            try:
                filename, success = future.result()
                results[filename] = success
            except Exception as e:
                logger.error(f"Error processing {file}: {e}")
                results[str(file)] = False
    
    # Report results
    successful = sum(1 for success in results.values() if success)
    logger.info(f"Conversion complete: {successful}/{len(markdown_files)} files processed successfully")
    
    if successful < len(markdown_files):
        failed = [file for file, success in results.items() if not success]
        logger.warning(f"Failed files: {', '.join(failed)}")
    
    return 0

if __name__ == "__main__":
    exit(main()) 