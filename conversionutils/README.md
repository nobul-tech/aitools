# Conversion Utilities

> **Note:** [Marker](https://github.com/VikParuchuri/marker) is now the preferred tool for PDF-to-markdown conversion. The utilities in this directory are retained for reference and edge cases. See [COMPARISON_REPORT.md](COMPARISON_REPORT.md) for a detailed quality comparison.

This directory contains utilities for converting vendor PDFs and other documentation formats to markdown.

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

### pdf_to_markdown.py

A general-purpose PDF-to-markdown converter using PyMuPDF.

**Usage:**
```bash
python pdf_to_markdown.py input.pdf -o output.md
```

## Related Files

- [COMPARISON_REPORT.md](COMPARISON_REPORT.md) -- Quality comparison: Marker vs. these utilities
- [marker_config_guide.md](marker_config_guide.md) -- Marker configuration reference
- [marker_systemwide_config.md](marker_systemwide_config.md) -- System-wide Marker setup
