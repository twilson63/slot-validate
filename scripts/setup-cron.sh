#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLIST_FILE="$HOME/Library/LaunchAgents/com.forward.slot-validator.plist"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║   Slot Nonce Validator - Automated Cron Setup           ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

echo "📁 Creating directories..."
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/config"

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

chmod +x "$PROJECT_DIR/scripts/run-validator.sh"

echo ""
echo "🔄 Loading LaunchAgent..."
launchctl unload "$PLIST_FILE" 2>/dev/null || true

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
