#!/usr/bin/env python3
"""
Converts a Markdown file to PDF using WeasyPrint.
Handles images, tables, and other formatting.
"""

import os
import sys
import markdown
import weasyprint
from weasyprint import HTML, CSS
import re
from weasyprint.text.fonts import FontConfiguration

def convert_md_to_pdf(md_file, output_pdf=None):
    """
    Convert a markdown file to PDF using WeasyPrint.
    
    Args:
        md_file: Path to markdown file
        output_pdf: Path for output PDF file. If None, uses same name as md_file with .pdf extension
    """
    if not output_pdf:
        output_pdf = os.path.splitext(md_file)[0] + '.pdf'
    
    print(f"Converting {md_file} to {output_pdf}...")
    
    # Read markdown content
    with open(md_file, 'r', encoding='utf-8') as f:
        md_content = f.read()
    
    # Fix image paths in markdown
    # This assumes images are relative to the markdown file
    md_dir = os.path.dirname(os.path.abspath(md_file))
    def fix_image_path(match):
        img_path = match.group(1)
        if not img_path.startswith(('http://', 'https://')):
            full_img_path = os.path.abspath(os.path.join(md_dir, img_path))
            return f'![Image]({full_img_path})'
        return match.group(0)
    
    md_content = re.sub(r'!\[.*?\]\((.*?)\)', fix_image_path, md_content)
    
    # Convert markdown to HTML
    html_content = markdown.markdown(
        md_content,
        extensions=[
            'markdown.extensions.tables',
            'markdown.extensions.fenced_code',
            'markdown.extensions.codehilite',
            'markdown.extensions.toc',
            'markdown.extensions.sane_lists'
        ]
    )
    
    # Add CSS for styling
    css_content = """
    body {
        font-family: "DejaVu Sans", Arial, Helvetica, sans-serif;
        font-size: 12px;
        line-height: 1.5;
        margin: 1.5cm;
    }
    h1 {
        font-size: 24px;
        font-weight: bold;
        margin-top: 20px;
        margin-bottom: 10px;
        text-align: center;
    }
    h2 {
        font-size: 20px;
        font-weight: bold;
        margin-top: 15px;
        margin-bottom: 7px;
        border-bottom: 1px solid #ddd;
        padding-bottom: 5px;
    }
    h3 {
        font-size: 16px;
        font-weight: bold;
        margin-top: 12px;
        margin-bottom: 6px;
    }
    p {
        margin-top: 5px;
        margin-bottom: 5px;
    }
    code {
        font-family: monospace;
        background-color: #f5f5f5;
        padding: 2px 4px;
        border-radius: 3px;
    }
    pre {
        background-color: #f5f5f5;
        padding: 10px;
        border-radius: 3px;
        overflow-x: auto;
    }
    blockquote {
        margin-left: 20px;
        padding-left: 10px;
        border-left: 4px solid #ddd;
        color: #555;
    }
    ul, ol {
        margin-top: 5px;
        margin-bottom: 5px;
        padding-left: 30px;
    }
    a {
        color: #0366d6;
        text-decoration: none;
    }
    img {
        max-width: 100%;
        height: auto;
    }
    table {
        border-collapse: collapse;
        width: 100%;
        margin: 10px 0;
    }
    th, td {
        border: 1px solid #ddd;
        padding: 8px;
        text-align: left;
    }
    th {
        background-color: #f2f2f2;
        font-weight: bold;
    }
    tr:nth-child(even) {
        background-color: #f9f9f9;
    }
    figure {
        margin: 15px 0;
        text-align: center;
    }
    figcaption {
        font-style: italic;
        margin-top: 5px;
        color: #666;
    }
    @page {
        size: A4;
        margin: 1.5cm;
        @top-right {
            content: "Page " counter(page) " of " counter(pages);
            font-size: 9pt;
        }
    }
    """
    
    # Create complete HTML document
    complete_html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>{os.path.basename(md_file)}</title>
        <style>
            {css_content}
        </style>
    </head>
    <body>
        {html_content}
    </body>
    </html>
    """
    
    # Configure fonts
    font_config = FontConfiguration()
    
    # Render HTML to PDF
    HTML(string=complete_html, base_url=md_dir).write_pdf(
        output_pdf,
        font_config=font_config,
        optimize_size=('fonts', 'images')
    )
    
    print(f"Conversion complete. PDF saved to {output_pdf}")
    return output_pdf

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python convert_md_to_pdf.py <markdown_file> [output_pdf]")
        sys.exit(1)
    
    md_file = sys.argv[1]
    output_pdf = sys.argv[2] if len(sys.argv) > 2 else None
    
    convert_md_to_pdf(md_file, output_pdf) 