# Quantum Documentation

This directory contains Quantum StorNext documentation, including source PDFs and their converted markdown versions.

## Files

### StorNext 7.1 Man Pages
- **6-68799-01_RevD_StorNext_71_Man_Pages.pdf** - Source PDF documentation for StorNext 7.1 manual pages
- **stornext_71_man_pages.md** - Converted markdown version of the StorNext 7.1 manual pages

### Xcellis Command Line Utilities
- **xcellis Command Line Utilities.pdf** - Source PDF for Xcellis command line utilities documentation
- **xcellis_command_line_utilities.md** - Converted markdown version

### StorNext Log Location and Description
- **StorNext_log_location_and_description.pdf** - Source PDF for StorNext log file locations and descriptions
- **stornext_log_location_and_description.md** - Converted markdown version

### CVLOG Stats Definitions
- **cvlogStatsDefined.pdf** - Source PDF for CVLOG statistics definitions
- **cvlog_stats_defined.md** - Converted markdown version

## Conversion

All markdown files were generated using the conversion utilities in `../conversionutils/`:
- `pdf_to_man_markdown.py` - For man pages with table of contents
- `pdf_to_markdown.py` - For general PDF documents
