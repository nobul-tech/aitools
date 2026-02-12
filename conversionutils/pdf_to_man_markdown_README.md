# PDF to Man Pages Markdown Converter

A Python utility to convert PDF man pages documentation into clean, LLM-friendly markdown files.

## Features

This converter handles all the common issues when extracting text from PDFs:

- **PDF Text Extraction**: Extracts text from all pages using `pypdf`
- **Page Cleanup**: Removes page delimiters (`---`), page markers (`<!-- Page N -->`), and footers
- **Header Removal**: Strips document-wide and per-command running headers
- **TOC Extraction**: Automatically finds and extracts the table of contents
- **Man Page Extraction**: Separates man pages from introductory content
- **Markdown Structure**: Adds proper markdown headings:
  - `##` headings for each command (e.g., `## mount_cvfs (8)`)
  - `###` headings for sections (e.g., `### NAME`, `### SYNOPSIS`, `### DESCRIPTION`)
- **Missing Headings Fix**: Ensures every man page has a command heading before its NAME section
- **Ligature Cleanup**: Replaces PDF ligatures (ﬁ → fi, ﬂ → fl, etc.)
- **Spacing Cleanup**: Collapses spaces inserted within uppercase words (e.g., `UPD AT ING` → `UPDATING`)

## Installation

Requires Python 3.6+ and the `pypdf` library:

```bash
pip install pypdf
```

## Usage

Basic usage:

```bash
python pdf_to_man_markdown.py input.pdf
```

This will create `input.md` in the same directory.

Specify custom output file:

```bash
python pdf_to_man_markdown.py input.pdf -o output.md
```

Or:

```bash
python pdf_to_man_markdown.py input.pdf --output custom_name.md
```

## Command Line Options

- `pdf_path`: Path to input PDF file (required)
- `-o, --output`: Path to output markdown file (optional, defaults to input filename with `.md` extension)

## How It Works

The converter performs the following steps in order:

1. **Extract Text**: Reads all pages from the PDF
2. **Remove Page Delimiters**: Strips `---` lines and `<!-- Page N -->` comments
3. **Remove Footers**: Removes lines like "StorNext File System 103"
4. **Remove Running Headers**: Strips document headers and per-command headers
5. **Extract TOC and Man Pages**: Separates table of contents from actual man page content
6. **Build TOC Map**: Creates a lookup table of command names and sections
7. **Add Command Headings**: Inserts `##` headings before each man page
8. **Add Section Headings**: Converts uppercase section labels to `###` headings
9. **Fix Missing Headings**: Ensures every NAME section has a preceding command heading
10. **Remove Redundant Headers**: Removes duplicate header lines like `AC CESS_JSON() A CCESS_JSON()`
11. **Cleanup Ligatures**: Replaces PDF ligatures with ASCII equivalents
12. **Cleanup Uppercase Spacing**: Collapses spaces within uppercase words

## Output Format

The output markdown file contains:

1. **Table of Contents**: All commands listed with their section numbers
2. **Man Pages**: Each command's documentation with:
   - Command heading: `## command_name (section)`
   - Section headings: `### NAME`, `### SYNOPSIS`, `### DESCRIPTION`, etc.
   - Full man page content

## Example Output

```markdown
Table of Contents
StorNext Filesystem Commands
mount_cvfs (8) 98
...

## mount_cvfs (8)

### NAME
mount_cvfs - Mount StorNext file systems

### SYNOPSIS
mount_cvfs [options] filesystem mountpoint

### DESCRIPTION
...
```

## Edge Cases Handled

- PDF ligatures (ﬁ, ﬂ, ﬀ, etc.)
- Split uppercase words (`UPD AT ING` → `UPDATING`)
- Missing command headings before NAME sections
- Various dash/hyphen characters in command names
- Spacing issues in section labels (`NA ME` → `NAME`)
- Non-breaking spaces and special Unicode characters
- Redundant header lines that appear between headings

## License

This utility is provided as-is for converting PDF man pages to markdown format.
