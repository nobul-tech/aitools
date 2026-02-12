# Quantum Documentation

This directory contains Quantum StorNext documentation, including source PDFs and their converted markdown versions.

## Files

### StorNext 7.1 Man Pages
- **6-68799-01_RevD_StorNext_71_Man_Pages.pdf** - Source PDF documentation for StorNext 7.1 manual pages
- **6-68799-01_RevD_StorNext_71_Man_Pages.md** - Converted markdown version using Marker

### Xcellis Command Line Utilities
- **xcellis Command Line Utilities.pdf** - Source PDF for Xcellis command line utilities documentation
- **xcellis Command Line Utilities.md** - Converted markdown version using Marker

### StorNext Log Location and Description
- **StorNext_log_location_and_description.pdf** - Source PDF for StorNext log file locations and descriptions
- **StorNext_log_location_and_description.md** - Converted markdown version using Marker

### CVLOG Stats Definitions
- **cvlogStatsDefined.pdf** - Source PDF for CVLOG statistics definitions
- **cvlogStatsDefined.md** - Converted markdown version using Marker

## Conversion

All markdown files were generated using **[Marker](https://github.com/VikParuchuri/marker)**, a state-of-the-art PDF-to-markdown conversion tool that provides superior output quality for RAG (Retrieval-Augmented Generation) use cases.

### Why Marker?

Marker was chosen over custom conversion utilities because it provides:
- **Superior text quality** - Better handling of ligatures, spacing, and special characters
- **Proper markdown structure** - Consistent heading hierarchy and formatting
- **Code block detection** - Automatically formats code examples with proper syntax highlighting
- **Table conversion** - Converts tables to proper markdown format
- **Better semantic search** - Higher quality embeddings for RAG systems

See `../conversionutils/COMPARISON_REPORT.md` for a detailed comparison.

### Previous Conversion Tools

The custom conversion utilities (`pdf_to_man_markdown.py` and `pdf_to_markdown.py`) are still available in `../conversionutils/` for reference, but are no longer used for production conversions.
