#!/bin/bash
set -e

PROJECT_DIR="/Users/rakis/forward/slot-validate"
LOG_DIR="$PROJECT_DIR/logs"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
LOG_FILE="$LOG_DIR/validator-$DATE.log"
LOCK_FILE="$LOG_DIR/validator.lock"

if [ -f "$LOCK_FILE" ]; then
  echo "[$TIMESTAMP] Previous run still in progress, skipping..." >> "$LOG_FILE"
  exit 0
fi

touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

if [ -f "$PROJECT_DIR/config/.pagerduty_key" ]; then
  export PAGERDUTY_ROUTING_KEY=$(cat "$PROJECT_DIR/config/.pagerduty_key")
else
  echo "[$TIMESTAMP] ERROR: PagerDuty key not found" >> "$LOG_FILE"
  exit 1
fi

echo "" >> "$LOG_FILE"
echo "[$TIMESTAMP] ========== Starting validation ==========" >> "$LOG_FILE"

cd "$PROJECT_DIR"
set +e
/Users/rakis/.local/bin/hype run validate-nonces.lua -- \
  --pagerduty-enabled \
  --only-mismatches \
  --pagerduty-mismatch-threshold=10 \
  >> "$LOG_FILE" 2>&1

EXIT_CODE=$?
set -e

echo "[$TIMESTAMP] Validation complete (exit code: $EXIT_CODE)" >> "$LOG_FILE"
echo "[$TIMESTAMP] =========================================" >> "$LOG_FILE"

find "$LOG_DIR" -name "validator-*.log" -mtime +30 -delete 2>/dev/null || true

exit $EXIT_CODE
