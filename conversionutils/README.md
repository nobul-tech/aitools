# Conversion Utilities

This directory contains source code for utilities used to convert vendor PDFs and other documentation formats to markdown.

## Available Utilities

### pdf_to_man_markdown.py

A Python utility to convert PDF man pages documentation into clean, LLM-friendly markdown files.

**Features:**
- Extracts text from PDF pages
- Removes page delimiters, footers, and running headers
- Extracts table of contents and man pages
- Adds proper markdown headings (## for commands, ### for sections)
- Cleans up PDF ligatures and spacing issues

**Usage:**
```bash
python pdf_to_man_markdown.py input.pdf -o output.md
```

See [pdf_to_man_markdown_README.md](pdf_to_man_markdown_README.md) for detailed documentation.
