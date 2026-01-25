# Setting OUTPUT_DIR System-Wide on macOS

To set the `OUTPUT_DIR` environment variable for **all terminals and shells** on macOS, you have several options:

## Option 1: System-Wide Profile Files (Recommended)

Create/edit system-wide profile files that all shells will source:

### For bash/sh:
```bash
sudo sh -c 'echo "export OUTPUT_DIR=." >> /etc/profile'
```

### For zsh:
```bash
sudo sh -c 'echo "export OUTPUT_DIR=." >> /etc/zshenv'
```

**Note:** `/etc/zshenv` is sourced by all zsh shells (login and non-login), making it the most reliable for zsh.

### For fish (if you use it):
```bash
sudo sh -c 'echo "set -gx OUTPUT_DIR ." >> /etc/fish/config.fish'
```

## Option 2: User-Specific but Cross-Shell

Create files in your home directory that each shell sources:

### For bash:
```bash
echo 'export OUTPUT_DIR=.' >> ~/.bash_profile
echo 'export OUTPUT_DIR=.' >> ~/.bashrc  # For non-login shells
```

### For zsh:
```bash
echo 'export OUTPUT_DIR=.' >> ~/.zshenv  # Sourced by all zsh shells
```

### For sh:
```bash
echo 'export OUTPUT_DIR=.' >> ~/.profile
```

## Option 3: LaunchAgent (Most System-Wide)

Create a LaunchAgent plist file that sets the environment variable for all processes:

```bash
cat > ~/Library/LaunchAgents/com.marker.outputdir.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.marker.outputdir</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/launchctl</string>
        <string>setenv</string>
        <string>OUTPUT_DIR</string>
        <string>.</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# Load it
launchctl load ~/Library/LaunchAgents/com.marker.outputdir.plist
```

**Note:** This method sets it for GUI applications too, but may not work for all terminal emulators.

## Option 4: Quick Setup Script

Run this script to set it up for the most common shells:

```bash
#!/bin/bash

# System-wide (requires sudo)
echo "Setting up system-wide configuration..."
sudo sh -c 'echo "export OUTPUT_DIR=." >> /etc/profile'
sudo sh -c 'echo "export OUTPUT_DIR=." >> /etc/zshenv'

# User-specific
echo 'export OUTPUT_DIR=.' >> ~/.bash_profile
echo 'export OUTPUT_DIR=.' >> ~/.bashrc
echo 'export OUTPUT_DIR=.' >> ~/.zshenv
echo 'export OUTPUT_DIR=.' >> ~/.profile

echo "Done! Please restart your terminal or run: source ~/.zshenv"
```

## Verification

After setting up, verify in a new terminal:

```bash
echo $OUTPUT_DIR
# Should output: .
```

## Recommended Approach

For macOS, I recommend **Option 1** (system-wide files):
- `/etc/profile` for bash/sh
- `/etc/zshenv` for zsh

This ensures it works for all users and all shell types. If you only want it for your user account, use **Option 2** instead.

## Troubleshooting

If it doesn't work after setting up:

1. **Check which shell you're using:**
   ```bash
   echo $SHELL
   ```

2. **Manually source the file:**
   ```bash
   source /etc/zshenv  # for zsh
   source /etc/profile  # for bash
   ```

3. **Check if the variable is set:**
   ```bash
   env | grep OUTPUT_DIR
   ```

4. **Restart your terminal** - environment variables set in profile files only take effect in new shell sessions.
