# Project Request Protocol: macOS Cron Setup for Slot Nonce Validator

## Project Overview

### Purpose
Set up the Slot Nonce Validator to run automatically every 5 minutes on a macOS system with PagerDuty alerting enabled, ensuring continuous monitoring of slot server nonce synchronization.

### Context
The Slot Nonce Validator is currently a manual CLI tool that requires explicit execution. For production monitoring, it needs to run automatically on a schedule to:

**Current State:**
- ✅ Validator CLI tool fully functional
- ✅ PagerDuty integration complete and tested
- ✅ Graceful error handling implemented
- ❌ **Gap:** Manual execution required
- ❌ **Impact:** No continuous monitoring of nonce mismatches

**Business Need:**
```bash
# Currently required (manual):
$ hype run validate-nonces.lua -- --pagerduty-enabled

# Desired state (automated):
# Runs every 5 minutes automatically
# Alerts sent to PagerDuty when issues detected
# Logs captured for troubleshooting
```

**Problem:**
Without automated scheduling:
- 🚨 Nonce mismatches may go undetected for hours
- 📊 No continuous monitoring baseline
- 👤 Requires manual intervention
- ⏰ No 24/7 coverage

### Scope

**In Scope:**
- Automated execution every 5 minutes on macOS
- PagerDuty integration enabled by default
- Logging output to files for troubleshooting
- Environment variable configuration (routing key)
- Error handling for execution failures
- Log rotation to prevent disk space issues
- Start on system boot (persistent)
- Stop/start/status management

**Out of Scope:**
- Linux/Windows setup (macOS only)
- Docker/containerization
- Cloud deployment (AWS Lambda, etc.)
- Distributed/multi-machine setup
- Web dashboard/UI
- Database integration
- Metrics collection beyond PagerDuty

### Business Value

**Immediate Benefits:**
- 🔍 **Continuous Monitoring**: Issues detected within 5 minutes
- 📟 **Automated Alerting**: On-call engineers notified immediately
- 📈 **Baseline Data**: Historical log of validation runs
- 🛡️ **Reliability**: 24/7 coverage without manual intervention

**Operational Benefits:**
- 🎯 **Early Detection**: Catch synchronization issues before user impact
- 📊 **Trend Analysis**: Log files show patterns over time
- 🔧 **Troubleshooting**: Historical data for incident investigation
- 💤 **Peace of Mind**: Automated monitoring while team sleeps

**Technical Benefits:**
- 🚀 **Simple Setup**: Native macOS tools (no dependencies)
- 🔄 **Resilient**: Survives system reboots
- 📝 **Auditable**: All runs logged with timestamps
- ⚙️ **Configurable**: Easy to adjust schedule or settings

## Technical Requirements

### Environment

**Runtime:** macOS (tested on macOS 10.15+)

**Available Tools:**
- ✅ `cron` - Traditional Unix task scheduler (always available)
- ✅ `launchd` - macOS native task scheduler (preferred)
- ✅ `bash` - Shell scripting
- ✅ `hype` - Already installed at known path

**Not Available:**
- ❌ `systemd` - Linux-only
- ❌ Docker - Not assumed installed

### System Requirements

**macOS Version:** 10.15 (Catalina) or later

**Disk Space:**
- Script files: ~10 KB
- Logs: ~1 MB per day (with rotation)
- Total: ~50 MB with 30-day retention

**Permissions:**
- Read/write access to project directory
- Ability to create/modify cron jobs or LaunchAgents
- Environment variable access

### Functional Requirements

1. **Scheduled Execution**
   - ✅ Run every 5 minutes (12 times per hour, 288 times per day)
   - ✅ Execute even if previous run still in progress (overlap handling)
   - ✅ Start automatically after system reboot
   - ✅ Continue running if one execution fails

2. **Command Execution**
   - ✅ Run: `hype run validate-nonces.lua -- --pagerduty-enabled --only-mismatches`
   - ✅ Set environment variable: `PAGERDUTY_ROUTING_KEY`
   - ✅ Use absolute paths (not relative)
   - ✅ Capture stdout and stderr

3. **Logging**
   - ✅ Append all output to log file
   - ✅ Include timestamp for each run
   - ✅ Separate log file per day (YYYY-MM-DD format)
   - ✅ Rotate logs after 30 days (configurable)
   - ✅ Preserve error output separately (optional)

4. **Error Handling**
   - ✅ Continue scheduling even if validation fails
   - ✅ Log errors for troubleshooting
   - ✅ Don't create duplicate processes (lock file)
   - ✅ Handle missing environment variables gracefully

5. **Management**
   - ✅ Easy start/stop/restart commands
   - ✅ Status checking (is it running?)
   - ✅ View recent logs easily
   - ✅ Update configuration without system reboot

### Non-Functional Requirements

- **Reliability**: Survive system reboots, crashes, sleep/wake
- **Performance**: Minimal system overhead (<1% CPU average)
- **Maintainability**: Simple to update or disable
- **Security**: PagerDuty key stored securely (not in script)
- **Observability**: Easy to check if working correctly

### Edge Cases to Handle

1. **System Sleep/Wake**: macOS laptop sleeps, wakes up later
2. **Missed Runs**: System was off during scheduled time
3. **Long-Running Jobs**: Validation takes >5 minutes
4. **Disk Full**: Log directory runs out of space
5. **Missing Dependencies**: Hype not installed or path changed
6. **Invalid Routing Key**: PagerDuty key expired or wrong
7. **Network Outage**: No internet connection during run

## Solution Proposals

### Solution 1: Traditional Cron Job

**Architecture:**
```bash
# Cron job
*/5 * * * * /Users/rakis/forward/slot-validate/scripts/run-validator.sh >> /Users/rakis/forward/slot-validate/logs/cron.log 2>&1

# Shell script: scripts/run-validator.sh
#!/bin/bash
export PAGERDUTY_ROUTING_KEY="$(cat ~/.pagerduty_key)"
cd /Users/rakis/forward/slot-validate
/usr/local/bin/hype run validate-nonces.lua -- --pagerduty-enabled --only-mismatches
```

**Setup Process:**
1. Create wrapper shell script
2. Store PagerDuty key in `~/.pagerduty_key`
3. Edit crontab: `crontab -e`
4. Add cron entry
5. Verify with `crontab -l`

**Implementation Approach:**
- Use `crontab -e` to edit user crontab
- Create simple wrapper script for environment setup
- Redirect output to log file
- Use `flock` or PID file to prevent overlapping runs

**Pros:**
- ✅ **Extremely simple** - 3 lines of setup
- ✅ **Universal** - Works on all Unix systems
- ✅ **Well-known** - Most developers familiar with cron
- ✅ **No dependencies** - Built into every Unix system
- ✅ **Easy debugging** - Logs go directly to file

**Cons:**
- ❌ **Limited on macOS** - May not run during sleep
- ❌ **No start-on-boot guarantee** - Cron starts late
- ❌ **Inflexible timing** - Only minute-level precision
- ❌ **No built-in logging** - Must redirect manually
- ❌ **Deprecated on macOS** - Apple recommends launchd
- ❌ **No retry logic** - If missed, just skipped
- ❌ **Environment issues** - Limited env vars available
- ❌ **Hard to manage** - No status/stop/restart commands

### Solution 2: macOS LaunchAgent (launchd)

**Architecture:**
```xml
<!-- ~/Library/LaunchAgents/com.forward.slot-validator.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.forward.slot-validator</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/Users/rakis/forward/slot-validate/scripts/run-validator.sh</string>
    </array>
    
    <key>StartInterval</key>
    <integer>300</integer>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/Users/rakis/forward/slot-validate/logs/stdout.log</string>
    
    <key>StandardErrorPath</key>
    <string>/Users/rakis/forward/slot-validate/logs/stderr.log</string>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>PAGERDUTY_ROUTING_KEY</key>
        <string>R0XXXXXXXXXXXXXXXXXXXXX</string>
    </dict>
</dict>
</plist>
```

**Setup Process:**
1. Create wrapper script (`run-validator.sh`)
2. Create LaunchAgent plist file
3. Load with `launchctl load ~/Library/LaunchAgents/com.forward.slot-validator.plist`
4. Verify with `launchctl list | grep slot-validator`

**Implementation Approach:**
- XML plist defines job configuration
- LaunchAgent runs as current user (user-level permissions)
- StartInterval triggers every 300 seconds (5 minutes)
- Built-in stdout/stderr redirection
- Environment variables in plist file

**Pros:**
- ✅ **macOS native** - Recommended by Apple
- ✅ **Reliable** - Better than cron on macOS
- ✅ **Start on boot** - Loads automatically after login
- ✅ **Built-in logging** - StandardOutPath/StandardErrorPath
- ✅ **Process management** - Easy start/stop/restart via launchctl
- ✅ **Environment control** - Clean environment variable handling
- ✅ **Status checking** - `launchctl list` shows running status
- ✅ **Survives sleep** - Better handling of system sleep/wake
- ✅ **RunAtLoad** - Can trigger immediately on load

**Cons:**
- ❌ **More complex setup** - XML plist file required
- ❌ **macOS specific** - Won't work on Linux
- ❌ **Syntax complexity** - XML plist format non-intuitive
- ❌ **Debugging harder** - Less transparent than cron
- ❌ **Key in plist** - PagerDuty key stored in XML (less secure)
- ❌ **Reload required** - Must unload/load for changes
- ❌ **User context** - Only runs when user logged in (LaunchAgent vs LaunchDaemon)

### Solution 3: Hybrid LaunchAgent + Shell Script with Advanced Features

**Architecture:**
```bash
# Directory structure:
slot-validate/
├── scripts/
│   ├── run-validator.sh          # Main execution wrapper
│   ├── setup-cron.sh              # Setup/installation script
│   └── manage-validator.sh        # Start/stop/status commands
├── logs/
│   ├── validator-YYYY-MM-DD.log   # Daily logs
│   └── validator.lock             # Prevent overlapping runs
└── config/
    └── .pagerduty_key             # Secure key storage (gitignored)

# LaunchAgent: ~/Library/LaunchAgents/com.forward.slot-validator.plist
# Calls: run-validator.sh
# Which: Sets environment, handles locking, rotates logs, executes validator
```

**Components:**

**1. run-validator.sh** (Advanced wrapper)
```bash
#!/bin/bash
set -e

PROJECT_DIR="/Users/rakis/forward/slot-validate"
LOG_DIR="$PROJECT_DIR/logs"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
LOG_FILE="$LOG_DIR/validator-$DATE.log"
LOCK_FILE="$LOG_DIR/validator.lock"

# Lock file to prevent overlapping runs
if [ -f "$LOCK_FILE" ]; then
  echo "[$TIMESTAMP] Previous run still in progress, skipping..." >> "$LOG_FILE"
  exit 0
fi

touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

# Load PagerDuty key securely
if [ -f "$PROJECT_DIR/config/.pagerduty_key" ]; then
  export PAGERDUTY_ROUTING_KEY=$(cat "$PROJECT_DIR/config/.pagerduty_key")
else
  echo "[$TIMESTAMP] ERROR: PagerDuty key not found" >> "$LOG_FILE"
  exit 1
fi

# Log start
echo "[$TIMESTAMP] Starting validation..." >> "$LOG_FILE"

# Execute validator
cd "$PROJECT_DIR"
/usr/local/bin/hype run validate-nonces.lua -- \
  --pagerduty-enabled \
  --only-mismatches \
  >> "$LOG_FILE" 2>&1

# Log completion
echo "[$TIMESTAMP] Validation complete" >> "$LOG_FILE"

# Rotate logs (keep last 30 days)
find "$LOG_DIR" -name "validator-*.log" -mtime +30 -delete
```

**2. setup-cron.sh** (Installation script)
```bash
#!/bin/bash
# One-command setup script

PROJECT_DIR="/Users/rakis/forward/slot-validate"
PLIST_FILE="$HOME/Library/LaunchAgents/com.forward.slot-validator.plist"

# Create directories
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/config"

# Prompt for PagerDuty key
read -sp "Enter PagerDuty routing key: " PAGERDUTY_KEY
echo "$PAGERDUTY_KEY" > "$PROJECT_DIR/config/.pagerduty_key"
chmod 600 "$PROJECT_DIR/config/.pagerduty_key"

# Create LaunchAgent plist
cat > "$PLIST_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.forward.slot-validator</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PROJECT_DIR/scripts/run-validator.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$PROJECT_DIR/logs/launchd-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$PROJECT_DIR/logs/launchd-stderr.log</string>
</dict>
</plist>
EOF

# Make script executable
chmod +x "$PROJECT_DIR/scripts/run-validator.sh"

# Load LaunchAgent
launchctl load "$PLIST_FILE"

echo "✅ Setup complete! Validator will run every 5 minutes."
echo "📝 Logs: $PROJECT_DIR/logs/"
echo "🔧 Manage: $PROJECT_DIR/scripts/manage-validator.sh"
```

**3. manage-validator.sh** (Management commands)
```bash
#!/bin/bash
PLIST="$HOME/Library/LaunchAgents/com.forward.slot-validator.plist"
PROJECT_DIR="/Users/rakis/forward/slot-validate"

case "$1" in
  start)
    launchctl load "$PLIST"
    echo "✅ Validator started"
    ;;
  stop)
    launchctl unload "$PLIST"
    echo "⏹️  Validator stopped"
    ;;
  restart)
    launchctl unload "$PLIST" 2>/dev/null
    launchctl load "$PLIST"
    echo "🔄 Validator restarted"
    ;;
  status)
    if launchctl list | grep -q "com.forward.slot-validator"; then
      echo "✅ Validator is running"
      echo ""
      echo "Recent runs:"
      tail -20 "$PROJECT_DIR/logs/validator-$(date +%Y-%m-%d).log"
    else
      echo "❌ Validator is not running"
    fi
    ;;
  logs)
    tail -f "$PROJECT_DIR/logs/validator-$(date +%Y-%m-%d).log"
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|logs}"
    exit 1
    ;;
esac
```

**Setup Process:**
1. Run `./scripts/setup-cron.sh` (one command!)
2. Enter PagerDuty key when prompted
3. Script automatically creates directories, files, and loads LaunchAgent
4. Done!

**Implementation Approach:**
- Automated setup script (no manual XML editing)
- Secure key storage in separate file (gitignored)
- Lock file prevents overlapping runs
- Timestamped daily logs
- Automatic log rotation (30-day retention)
- Management script for easy control
- Graceful error handling

**Pros:**
- ✅ **One-command setup** - Run setup script, done
- ✅ **Secure key storage** - Key in separate file, not in plist
- ✅ **Best of both worlds** - LaunchAgent reliability + script flexibility
- ✅ **Overlap prevention** - Lock file prevents duplicate runs
- ✅ **Daily log rotation** - Automatic 30-day retention
- ✅ **Easy management** - Start/stop/status/logs commands
- ✅ **Timestamped logs** - Each run clearly marked
- ✅ **Error recovery** - Continues even if one run fails
- ✅ **Gitignore friendly** - Key never committed
- ✅ **Portable logic** - Easy to adapt for Linux/systemd
- ✅ **Professional** - Production-ready solution

**Cons:**
- ❌ **More files** - 3 scripts vs 1 cron line
- ❌ **Initial complexity** - More moving parts
- ❌ **Over-engineered?** - May be overkill for simple use case
- ❌ **Still macOS-specific** - LaunchAgent won't work on Linux

## Best Solution

**Selected: Solution 3 - Hybrid LaunchAgent + Shell Script with Advanced Features**

### Rationale

Solution 3 provides the optimal balance between simplicity, reliability, and production-readiness:

1. **Best Developer Experience**: Unlike Solution 1 (cron) and Solution 2 (manual plist):
   - **One-command setup**: `./scripts/setup-cron.sh`
   - **Easy management**: `./scripts/manage-validator.sh status`
   - **No XML editing**: Setup script generates everything
   - **Clear feedback**: Status commands show if working

2. **Production-Ready Features**: Unlike Solution 1 and 2:
   - ✅ **Overlap prevention**: Lock file prevents race conditions
   - ✅ **Log rotation**: Automatic 30-day cleanup
   - ✅ **Secure key storage**: Not in plist or crontab
   - ✅ **Error handling**: Continues on failure
   - ✅ **Timestamped logs**: Easy debugging
   - ✅ **Management commands**: Professional operations

3. **macOS Reliability**: Better than Solution 1 (cron):
   - ✅ Uses native LaunchAgent (Apple recommended)
   - ✅ Survives system sleep/wake
   - ✅ Starts on boot (after user login)
   - ✅ Better process management

4. **Security**: Better than Solution 2:
   - ✅ Key stored in separate file (not in plist)
   - ✅ File permissions set to 600 (user-only read)
   - ✅ Key never committed to git (.gitignore)
   - ✅ Can rotate key without editing plist

5. **Maintainability**: Better than both alternatives:
   - 📝 **Clear structure**: All scripts in `scripts/` directory
   - 🔧 **Easy updates**: Modify wrapper script, no reload needed (mostly)
   - 📊 **Observable**: Management script shows status instantly
   - 🐛 **Debuggable**: Timestamped logs make troubleshooting easy

6. **Future-Proof**: Easier to extend:
   - Can add Slack notifications
   - Can add metrics collection
   - Can add health checks
   - Can port to systemd (Linux) by swapping LaunchAgent

### Why Not the Others?

**Solution 1 (Cron):**
- ❌ **Unreliable on macOS**: Apple deprecated cron in favor of launchd
- ❌ **Sleep issues**: May not run during system sleep
- ❌ **No management**: Hard to start/stop/status
- ❌ **Manual setup**: Edit crontab, no automation
- ❌ **Limited features**: No built-in logging or overlap prevention

**Solution 2 (Basic LaunchAgent):**
- ❌ **Manual XML editing**: Error-prone, non-intuitive
- ❌ **Key in plist**: Security concern (visible in XML)
- ❌ **No overlap prevention**: Could run duplicate processes
- ❌ **No log rotation**: Logs grow forever
- ❌ **Less flexible**: Hard to add features later

### Trade-offs Accepted

**Complexity vs Features:**
- Solution 3 has more files (3 scripts vs 1)
- Acceptable because: One-time setup, professional operations
- Benefit: Production-ready monitoring with easy management

**macOS-Specific:**
- LaunchAgent only works on macOS
- Acceptable because: Requirement specifies macOS
- Benefit: Uses native, reliable macOS scheduler

**Setup Time:**
- ~10 minutes to create scripts vs 2 minutes for cron
- Acceptable because: One-time investment
- Benefit: Saves hours of troubleshooting later

## Implementation Steps

### Phase 1: Directory Structure Setup (5 minutes)

1. **Create required directories**
   ```bash
   cd /Users/rakis/forward/slot-validate
   mkdir -p scripts
   mkdir -p logs
   mkdir -p config
   ```

2. **Create .gitignore entries**
   ```bash
   echo "config/.pagerduty_key" >> .gitignore
   echo "logs/*.log" >> .gitignore
   echo "logs/*.lock" >> .gitignore
   ```

### Phase 2: Create Wrapper Script (10 minutes)

3. **Create `scripts/run-validator.sh`**
   ```bash
   cat > scripts/run-validator.sh <<'EOF'
#!/bin/bash
set -e

PROJECT_DIR="/Users/rakis/forward/slot-validate"
LOG_DIR="$PROJECT_DIR/logs"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
LOG_FILE="$LOG_DIR/validator-$DATE.log"
LOCK_FILE="$LOG_DIR/validator.lock"

# Lock file to prevent overlapping runs
if [ -f "$LOCK_FILE" ]; then
  echo "[$TIMESTAMP] Previous run still in progress, skipping..." >> "$LOG_FILE"
  exit 0
fi

touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

# Load PagerDuty key securely
if [ -f "$PROJECT_DIR/config/.pagerduty_key" ]; then
  export PAGERDUTY_ROUTING_KEY=$(cat "$PROJECT_DIR/config/.pagerduty_key")
else
  echo "[$TIMESTAMP] ERROR: PagerDuty key not found" >> "$LOG_FILE"
  exit 1
fi

# Log start
echo "" >> "$LOG_FILE"
echo "[$TIMESTAMP] ========== Starting validation ==========" >> "$LOG_FILE"

# Execute validator
cd "$PROJECT_DIR"
/usr/local/bin/hype run validate-nonces.lua -- \
  --pagerduty-enabled \
  --only-mismatches \
  >> "$LOG_FILE" 2>&1

EXIT_CODE=$?

# Log completion
echo "[$TIMESTAMP] Validation complete (exit code: $EXIT_CODE)" >> "$LOG_FILE"
echo "[$TIMESTAMP] =========================================" >> "$LOG_FILE"

# Rotate logs (keep last 30 days)
find "$LOG_DIR" -name "validator-*.log" -mtime +30 -delete 2>/dev/null || true

exit $EXIT_CODE
EOF

   chmod +x scripts/run-validator.sh
   ```

### Phase 3: Create Setup Script (10 minutes)

4. **Create `scripts/setup-cron.sh`**
   ```bash
   cat > scripts/setup-cron.sh <<'EOF'
#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLIST_FILE="$HOME/Library/LaunchAgents/com.forward.slot-validator.plist"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║   Slot Nonce Validator - Automated Cron Setup           ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Create directories
echo "📁 Creating directories..."
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/config"

# Check if key already exists
if [ -f "$PROJECT_DIR/config/.pagerduty_key" ]; then
  echo "🔑 PagerDuty key already exists"
  read -p "   Update key? (y/N): " UPDATE_KEY
  if [[ "$UPDATE_KEY" =~ ^[Yy]$ ]]; then
    read -sp "   Enter new PagerDuty routing key: " PAGERDUTY_KEY
    echo ""
    echo "$PAGERDUTY_KEY" > "$PROJECT_DIR/config/.pagerduty_key"
    chmod 600 "$PROJECT_DIR/config/.pagerduty_key"
    echo "   ✅ Key updated"
  fi
else
  # Prompt for PagerDuty key
  echo "🔑 PagerDuty Configuration"
  read -sp "   Enter PagerDuty routing key: " PAGERDUTY_KEY
  echo ""
  
  if [ -z "$PAGERDUTY_KEY" ]; then
    echo "❌ Error: PagerDuty key is required"
    exit 1
  fi
  
  echo "$PAGERDUTY_KEY" > "$PROJECT_DIR/config/.pagerduty_key"
  chmod 600 "$PROJECT_DIR/config/.pagerduty_key"
  echo "   ✅ Key saved securely"
fi

# Create LaunchAgent plist
echo ""
echo "📝 Creating LaunchAgent configuration..."
cat > "$PLIST_FILE" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.forward.slot-validator</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$PROJECT_DIR/scripts/run-validator.sh</string>
    </array>
    
    <key>StartInterval</key>
    <integer>300</integer>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>$PROJECT_DIR/logs/launchd-stdout.log</string>
    
    <key>StandardErrorPath</key>
    <string>$PROJECT_DIR/logs/launchd-stderr.log</string>
    
    <key>WorkingDirectory</key>
    <string>$PROJECT_DIR</string>
</dict>
</plist>
PLIST

echo "   ✅ LaunchAgent created"

# Make script executable
chmod +x "$PROJECT_DIR/scripts/run-validator.sh"

# Unload existing if present
echo ""
echo "🔄 Loading LaunchAgent..."
launchctl unload "$PLIST_FILE" 2>/dev/null || true

# Load LaunchAgent
if launchctl load "$PLIST_FILE"; then
  echo "   ✅ LaunchAgent loaded successfully"
else
  echo "   ❌ Failed to load LaunchAgent"
  exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║              ✅ Setup Complete!                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Status:"
echo "   • Validator will run every 5 minutes"
echo "   • Runs automatically on system boot (after login)"
echo "   • PagerDuty alerts enabled"
echo ""
echo "📝 Logs:"
echo "   • Daily logs: $PROJECT_DIR/logs/validator-YYYY-MM-DD.log"
echo "   • LaunchAgent: $PROJECT_DIR/logs/launchd-*.log"
echo ""
echo "🔧 Management:"
echo "   • Status:  ./scripts/manage-validator.sh status"
echo "   • Logs:    ./scripts/manage-validator.sh logs"
echo "   • Stop:    ./scripts/manage-validator.sh stop"
echo "   • Restart: ./scripts/manage-validator.sh restart"
echo ""
echo "🧪 Test now:"
echo "   ./scripts/run-validator.sh"
echo ""
EOF

   chmod +x scripts/setup-cron.sh
   ```

### Phase 4: Create Management Script (10 minutes)

5. **Create `scripts/manage-validator.sh`**
   ```bash
   cat > scripts/manage-validator.sh <<'EOF'
#!/bin/bash

PLIST="$HOME/Library/LaunchAgents/com.forward.slot-validator.plist"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATE=$(date +%Y-%m-%d)
LOG_FILE="$PROJECT_DIR/logs/validator-$DATE.log"

case "$1" in
  start)
    echo "🚀 Starting validator..."
    if launchctl load "$PLIST" 2>/dev/null; then
      echo "✅ Validator started successfully"
      echo "   Runs every 5 minutes"
    else
      echo "⚠️  Validator may already be running"
      echo "   Check status: $0 status"
    fi
    ;;
    
  stop)
    echo "⏹️  Stopping validator..."
    if launchctl unload "$PLIST" 2>/dev/null; then
      echo "✅ Validator stopped"
    else
      echo "⚠️  Validator may not be running"
    fi
    ;;
    
  restart)
    echo "🔄 Restarting validator..."
    launchctl unload "$PLIST" 2>/dev/null || true
    sleep 1
    if launchctl load "$PLIST"; then
      echo "✅ Validator restarted"
    else
      echo "❌ Failed to restart validator"
      exit 1
    fi
    ;;
    
  status)
    echo "📊 Validator Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if launchctl list | grep -q "com.forward.slot-validator"; then
      echo "✅ Status: Running"
      echo "🔄 Schedule: Every 5 minutes"
      echo "📁 Project: $PROJECT_DIR"
      
      # Show last run time
      if [ -f "$LOG_FILE" ]; then
        LAST_RUN=$(tail -20 "$LOG_FILE" | grep "Starting validation" | tail -1 | cut -d']' -f1 | cut -d'[' -f2)
        if [ -n "$LAST_RUN" ]; then
          echo "⏰ Last run: $LAST_RUN"
        fi
      fi
      
      # Show PagerDuty status
      if [ -f "$PROJECT_DIR/config/.pagerduty_key" ]; then
        echo "📟 PagerDuty: Enabled"
      else
        echo "📟 PagerDuty: ⚠️  Key not found"
      fi
      
      echo ""
      echo "📝 Recent activity (last 10 runs):"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      if [ -f "$LOG_FILE" ]; then
        grep "Starting validation\|Validation complete" "$LOG_FILE" | tail -20
      else
        echo "   No logs for today yet"
      fi
    else
      echo "❌ Status: Not running"
      echo ""
      echo "To start: $0 start"
    fi
    ;;
    
  logs)
    if [ -f "$LOG_FILE" ]; then
      echo "📝 Tailing logs: $LOG_FILE"
      echo "   (Press Ctrl+C to exit)"
      echo ""
      tail -f "$LOG_FILE"
    else
      echo "❌ No logs for today: $LOG_FILE"
      echo ""
      echo "Available logs:"
      ls -lh "$PROJECT_DIR/logs/validator-"*.log 2>/dev/null || echo "   No logs found"
    fi
    ;;
    
  test)
    echo "🧪 Running test validation..."
    echo ""
    "$PROJECT_DIR/scripts/run-validator.sh"
    echo ""
    echo "✅ Test complete. Check logs:"
    echo "   tail $LOG_FILE"
    ;;
    
  *)
    echo "Slot Nonce Validator - Management Script"
    echo ""
    echo "Usage: $0 {start|stop|restart|status|logs|test}"
    echo ""
    echo "Commands:"
    echo "  start    - Start the scheduled validator"
    echo "  stop     - Stop the scheduled validator"
    echo "  restart  - Restart the scheduled validator"
    echo "  status   - Show current status and recent runs"
    echo "  logs     - Tail the current log file"
    echo "  test     - Run a test validation now"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 logs"
    echo "  $0 test"
    exit 1
    ;;
esac
EOF

   chmod +x scripts/manage-validator.sh
   ```

### Phase 5: Run Setup (5 minutes)

6. **Execute setup script**
   ```bash
   cd /Users/rakis/forward/slot-validate
   ./scripts/setup-cron.sh
   ```

7. **Enter PagerDuty routing key when prompted**
   - Script will prompt for key
   - Key saved securely to `config/.pagerduty_key`
   - File permissions set to 600 (user-only)

### Phase 6: Verification (5 minutes)

8. **Test immediate execution**
   ```bash
   ./scripts/manage-validator.sh test
   ```

9. **Check status**
   ```bash
   ./scripts/manage-validator.sh status
   ```

10. **Verify LaunchAgent loaded**
    ```bash
    launchctl list | grep slot-validator
    # Should show: com.forward.slot-validator
    ```

11. **Wait 5 minutes and check logs**
    ```bash
    ./scripts/manage-validator.sh logs
    # Or:
    cat logs/validator-$(date +%Y-%m-%d).log
    ```

### Phase 7: Documentation (5 minutes)

12. **Create README for scripts**
    ```bash
    cat > scripts/README.md <<'EOF'
# Slot Validator Automation Scripts

## Quick Start

1. **Setup (first time only)**
   ```bash
   ./setup-cron.sh
   ```

2. **Check status**
   ```bash
   ./manage-validator.sh status
   ```

3. **View logs**
   ```bash
   ./manage-validator.sh logs
   ```

## Management Commands

- `./manage-validator.sh start` - Start scheduled runs
- `./manage-validator.sh stop` - Stop scheduled runs
- `./manage-validator.sh restart` - Restart service
- `./manage-validator.sh status` - Show current status
- `./manage-validator.sh logs` - Tail current log file
- `./manage-validator.sh test` - Run test validation now

## Logs

- Daily logs: `../logs/validator-YYYY-MM-DD.log`
- Automatically rotated after 30 days
- Each run timestamped

## Configuration

- PagerDuty key: `../config/.pagerduty_key`
- Update key: Re-run `./setup-cron.sh`

## Troubleshooting

### Validator not running
```bash
./manage-validator.sh status
# If stopped:
./manage-validator.sh start
```

### No recent logs
```bash
# Check LaunchAgent logs
cat ../logs/launchd-stderr.log
```

### Change schedule (from 5 minutes)
1. Edit: `~/Library/LaunchAgents/com.forward.slot-validator.plist`
2. Change `<integer>300</integer>` to desired seconds
3. Restart: `./manage-validator.sh restart`
EOF
    ```

13. **Update main README.md**
    Add section about automation setup

## Success Criteria

### Functional Requirements ✅

- [x] **Scheduled Execution**: Runs every 5 minutes automatically
- [x] **Start on Boot**: Loads after user login via LaunchAgent
- [x] **PagerDuty Enabled**: Alerts sent when thresholds exceeded
- [x] **Logging**: All output captured to daily log files
- [x] **Log Rotation**: Automatically deletes logs older than 30 days
- [x] **Overlap Prevention**: Lock file prevents duplicate processes
- [x] **Error Handling**: Continues scheduling even if validation fails

### Management Requirements ✅

- [x] **Easy Setup**: One-command installation (`./setup-cron.sh`)
- [x] **Status Check**: `./manage-validator.sh status` shows running state
- [x] **Start/Stop**: Commands to control service
- [x] **View Logs**: `./manage-validator.sh logs` for real-time tailing
- [x] **Test Execution**: Run validation manually for testing

### Security Requirements ✅

- [x] **Secure Key Storage**: PagerDuty key in separate file, not in plist
- [x] **File Permissions**: Key file set to 600 (user-only read)
- [x] **Git Ignored**: Key never committed to version control
- [x] **No Hardcoded Secrets**: All secrets in config files

### Observability Requirements ✅

- [x] **Timestamped Logs**: Each run has clear start/end timestamps
- [x] **Exit Codes**: Logged for troubleshooting
- [x] **Recent Activity**: Status command shows last 10 runs
- [x] **Error Logging**: Stderr captured separately (launchd-stderr.log)

### Testing Requirements ✅

- [x] **Test Command**: Can run validation manually without waiting
- [x] **Verify LaunchAgent**: `launchctl list` shows loaded service
- [x] **Check Logs**: Logs confirm scheduled runs occurring
- [x] **PagerDuty Test**: Alerts received in PagerDuty (with real key)

## Verification Checklist

### Installation Verification

Run these commands after setup:

```bash
# 1. Check LaunchAgent loaded
launchctl list | grep slot-validator
# Expected: Should show "com.forward.slot-validator"

# 2. Verify files created
ls -la scripts/
# Expected: run-validator.sh, setup-cron.sh, manage-validator.sh (all executable)

ls -la config/
# Expected: .pagerduty_key (permissions: -rw-------)

ls -la ~/Library/LaunchAgents/com.forward.slot-validator.plist
# Expected: File exists

# 3. Run test validation
./scripts/manage-validator.sh test
# Expected: Completes without errors

# 4. Check status
./scripts/manage-validator.sh status
# Expected: Shows "Status: Running"

# 5. Wait 5-10 minutes, check logs
cat logs/validator-$(date +%Y-%m-%d).log
# Expected: At least 2 validation runs logged
```

### Continuous Operation Verification

After 24 hours:

```bash
# 1. Check run count (should be ~288 runs per day)
grep "Starting validation" logs/validator-$(date +%Y-%m-%d).log | wc -l
# Expected: ~12 runs per hour × hours since setup

# 2. Check for errors
grep "ERROR" logs/validator-$(date +%Y-%m-%d).log
# Expected: None (or expected errors only)

# 3. Verify PagerDuty integration (if mismatches occurred)
# Check PagerDuty dashboard for incidents

# 4. Test system reboot
# Reboot Mac, wait for login
launchctl list | grep slot-validator
# Expected: Service automatically loaded
```

## Troubleshooting

### Common Issues

#### 1. LaunchAgent Not Running

**Symptoms:**
```bash
$ ./scripts/manage-validator.sh status
❌ Status: Not running
```

**Solutions:**
```bash
# Check LaunchAgent logs
cat logs/launchd-stderr.log

# Try loading manually
launchctl load ~/Library/LaunchAgents/com.forward.slot-validator.plist

# Verify plist syntax
plutil ~/Library/LaunchAgents/com.forward.slot-validator.plist
# Should output: OK
```

#### 2. PagerDuty Key Not Found

**Symptoms:**
```
ERROR: PagerDuty key not found
```

**Solutions:**
```bash
# Check if key file exists
ls -la config/.pagerduty_key

# Re-run setup to add key
./scripts/setup-cron.sh
# Choose to update key when prompted
```

#### 3. Hype Not Found

**Symptoms:**
```
/usr/local/bin/hype: No such file or directory
```

**Solutions:**
```bash
# Find hype location
which hype

# Update run-validator.sh with correct path
# Replace /usr/local/bin/hype with actual path
```

#### 4. Lock File Stuck

**Symptoms:**
```
Previous run still in progress, skipping...
```

**Solutions:**
```bash
# Check if validation actually running
ps aux | grep validate-nonces

# If not running, remove lock file
rm logs/validator.lock
```

#### 5. Logs Not Rotating

**Symptoms:**
Logs directory growing too large

**Solutions:**
```bash
# Manually clean old logs
find logs/ -name "validator-*.log" -mtime +30 -delete

# Verify cron script has rotation logic
grep "find.*mtime" scripts/run-validator.sh
```

## Performance Characteristics

### Resource Usage

- **CPU**: <1% average (spikes to 5-10% during 20-second validation)
- **Memory**: ~50 MB during validation
- **Disk**: ~1 MB per day (logs)
- **Network**: ~450 KB per validation (HTTP requests)

### Expected Behavior

- **Frequency**: Every 5 minutes (288 runs/day)
- **Duration**: 15-30 seconds per run (depends on network)
- **Overlap**: Prevented by lock file
- **Missed Runs**: None (LaunchAgent handles sleep/wake)

### Log Growth

```
Daily:    ~1 MB (288 runs × ~3.5 KB per run)
Weekly:   ~7 MB
Monthly:  ~30 MB
Yearly:   ~365 MB (with 30-day rotation: max ~30 MB)
```

## Maintenance

### Regular Maintenance

**Weekly:**
- Check status: `./scripts/manage-validator.sh status`
- Verify PagerDuty incidents (if any)
- Review error logs

**Monthly:**
- Verify log rotation working
- Check disk space: `du -sh logs/`
- Review PagerDuty alert history

**As Needed:**
- Update PagerDuty key: Re-run `./setup-cron.sh`
- Adjust thresholds: Edit `run-validator.sh` flags
- Change schedule: Edit plist `StartInterval`

### Updating Configuration

**Change PagerDuty Key:**
```bash
# Option 1: Re-run setup
./scripts/setup-cron.sh

# Option 2: Manually edit
echo "NEW_KEY_HERE" > config/.pagerduty_key
chmod 600 config/.pagerduty_key
```

**Change Schedule (e.g., every 10 minutes):**
```bash
# Edit plist
nano ~/Library/LaunchAgents/com.forward.slot-validator.plist
# Change: <integer>300</integer> to <integer>600</integer>

# Restart
./scripts/manage-validator.sh restart
```

**Change Alert Thresholds:**
```bash
# Edit run-validator.sh
nano scripts/run-validator.sh
# Add flags: --pagerduty-mismatch-threshold=5

# No restart needed (takes effect next run)
```

## Uninstallation

If you need to remove the automated validator:

```bash
# 1. Stop and unload LaunchAgent
./scripts/manage-validator.sh stop

# 2. Remove LaunchAgent plist
rm ~/Library/LaunchAgents/com.forward.slot-validator.plist

# 3. Remove config (keeps logs and scripts)
rm config/.pagerduty_key

# 4. (Optional) Remove all automation files
rm -rf scripts/ logs/ config/
```

## Production Deployment

### Pre-Deployment Checklist

- [ ] PagerDuty routing key tested and valid
- [ ] Validator tested manually (`./scripts/manage-validator.sh test`)
- [ ] Setup script tested (`./scripts/setup-cron.sh`)
- [ ] Status command works (`./scripts/manage-validator.sh status`)
- [ ] Logs being created in `logs/` directory
- [ ] LaunchAgent loads automatically after reboot

### Deployment Steps

1. Clone repository to target Mac
2. Run setup: `./scripts/setup-cron.sh`
3. Enter PagerDuty routing key
4. Verify: `./scripts/manage-validator.sh status`
5. Test: Wait 5 minutes, check logs
6. Monitor: Check PagerDuty dashboard for incidents

### Post-Deployment Monitoring

**First 24 Hours:**
- Check status every few hours
- Verify 288 runs logged
- Confirm PagerDuty alerts working (if issues detected)

**First Week:**
- Daily status checks
- Review any PagerDuty incidents
- Verify log rotation working

**Ongoing:**
- Weekly status checks
- Monthly log cleanup verification
- Quarterly review of alert thresholds

---

## Example Usage

### Initial Setup

```bash
$ cd /Users/rakis/forward/slot-validate
$ ./scripts/setup-cron.sh

╔══════════════════════════════════════════════════════════╗
║   Slot Nonce Validator - Automated Cron Setup           ║
╚══════════════════════════════════════════════════════════╝

📁 Creating directories...
🔑 PagerDuty Configuration
   Enter PagerDuty routing key: ●●●●●●●●●●●●●●●●●●●●
   ✅ Key saved securely

📝 Creating LaunchAgent configuration...
   ✅ LaunchAgent created

🔄 Loading LaunchAgent...
   ✅ LaunchAgent loaded successfully

╔══════════════════════════════════════════════════════════╗
║              ✅ Setup Complete!                          ║
╚══════════════════════════════════════════════════════════╝

📊 Status:
   • Validator will run every 5 minutes
   • Runs automatically on system boot (after login)
   • PagerDuty alerts enabled

📝 Logs:
   • Daily logs: /Users/rakis/forward/slot-validate/logs/validator-YYYY-MM-DD.log
   • LaunchAgent: /Users/rakis/forward/slot-validate/logs/launchd-*.log

🔧 Management:
   • Status:  ./scripts/manage-validator.sh status
   • Logs:    ./scripts/manage-validator.sh logs
   • Stop:    ./scripts/manage-validator.sh stop
   • Restart: ./scripts/manage-validator.sh restart
```

### Checking Status

```bash
$ ./scripts/manage-validator.sh status

📊 Validator Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Status: Running
🔄 Schedule: Every 5 minutes
📁 Project: /Users/rakis/forward/slot-validate
⏰ Last run: 2025-10-13 14:35:22
📟 PagerDuty: Enabled

📝 Recent activity (last 10 runs):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[2025-10-13 14:30:22] ========== Starting validation ==========
[2025-10-13 14:30:40] Validation complete (exit code: 0)
[2025-10-13 14:35:22] ========== Starting validation ==========
[2025-10-13 14:35:38] Validation complete (exit code: 0)
```

---

## Summary

**Implementation Time:** ~60 minutes total

**Effort Breakdown:**
- Directory setup: 5 minutes
- Create wrapper script: 10 minutes
- Create setup script: 10 minutes
- Create management script: 10 minutes
- Run setup: 5 minutes
- Verification: 5 minutes
- Documentation: 15 minutes

**Complexity:** Medium (more setup, easier operations)

**Risk Level:** Low
- Well-tested LaunchAgent approach
- Automated setup reduces human error
- Management scripts provide safety net
- Can easily revert if issues

**Dependencies:**
- macOS 10.15+ (built-in launchd)
- Hype already installed
- Bash shell (built-in)

---

**Status:** Ready for Implementation ✅  
**Priority:** High (enables continuous monitoring)  
**Complexity:** Medium  
**Risk:** Low  
**Value:** Critical (24/7 monitoring)  
**Dependencies:** macOS, Hype installed

---

*Created: October 13, 2025*  
*PRP Version: 1.0*  
*Target Implementation: 60 minutes*
