# Marker Configuration Guide: Setting Default Output Directory

Marker uses `pydantic_settings` which allows configuration via environment variables or a `.env` file.

## Option 1: Environment Variable (Recommended)

Set the `OUTPUT_DIR` environment variable to use the current working directory:

### For a single session:
```bash
export OUTPUT_DIR=.
marker /path/to/pdf/folder
```

### For your shell profile (persistent):
Add to your `~/.zshrc` (since you're using zsh):
```bash
export OUTPUT_DIR=.
```

Then reload:
```bash
source ~/.zshrc
```

## Option 2: Create a `.env` file

Marker looks for a `local.env` file. You can create one in your project directory:

```bash
# In your project root or home directory
echo "OUTPUT_DIR=." > local.env
```

Or create it in a specific location:
```bash
cd "/Users/pepe/Library/CloudStorage/GoogleDrive-jose@nobul.tech/My Drive/Customers/marlins"
echo "OUTPUT_DIR=." > local.env
```

## Option 3: Shell Alias/Wrapper Script

Create a wrapper script that always sets the output directory:

```bash
# Create a marker wrapper
cat > ~/bin/marker-cwd << 'EOF'
#!/bin/bash
export OUTPUT_DIR="${OUTPUT_DIR:-.}"
exec marker "$@"
EOF

chmod +x ~/bin/marker-cwd
```

Then use `marker-cwd` instead of `marker`.

## Option 4: Modify Marker Settings (Not Recommended)

You could modify the Marker installation directly, but this will be overwritten on updates:

```python
# Edit: /Users/pepe/.pyenv/versions/3.13.5/lib/python3.13/site-packages/marker/settings.py
# Change line 13 from:
OUTPUT_DIR: str = os.path.join(BASE_DIR, "conversion_results")
# To:
OUTPUT_DIR: str = "."
```

**Note:** This will be lost when you update Marker.

## Important Notes

1. **Marker creates subdirectories**: Marker creates a subdirectory for each PDF file. So if you have `file.pdf`, it will create `./file/file.md` (not `./file.md` directly).

2. **Relative vs Absolute**: Using `.` means the current working directory when you run the command, not the directory where the PDF is located.

3. **Best Practice**: I recommend **Option 1** (environment variable in your shell profile) as it's persistent and doesn't require modifying Marker's code.

## Testing

After setting up, test it:
```bash
cd /path/to/your/pdf/directory
export OUTPUT_DIR=.
marker /path/to/pdf/folder
# Output should be in the current directory
```
