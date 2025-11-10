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
      
      if [ -f "$LOG_FILE" ]; then
        LAST_RUN=$(tail -20 "$LOG_FILE" | grep "Starting validation" | tail -1 | cut -d']' -f1 | cut -d'[' -f2)
        if [ -n "$LAST_RUN" ]; then
          echo "⏰ Last run: $LAST_RUN"
        fi
      fi
      
      if [ -f "$PROJECT_DIR/config/.pagerduty_key" ]; then
        echo "📟 PagerDuty: Enabled"
      else
        echo "📟 PagerDuty: ⚠️  Key not found"
      fi
      
      echo ""
      echo "📊 Last Summary:"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      if [ -f "$LOG_FILE" ]; then
        # Extract last summary (matches, mismatches, errors, total, time, pagerduty)
        tail -200 "$LOG_FILE" | grep -A 6 "Summary:" | tail -7 | sed 's/\[34m//g; s/\[32m//g; s/\[31m//g; s/\[33m//g; s/\[0m//g'
        echo ""
        echo "📝 Recent activity (last 5 runs):"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        grep "Starting validation\|Validation complete" "$LOG_FILE" | tail -10
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
