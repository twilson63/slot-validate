#!/bin/bash
set -e

PROJECT_DIR="/Users/rakis/forward/slot-validate"
LOG_DIR="$PROJECT_DIR/logs"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
LOG_FILE="$LOG_DIR/validator-$DATE.log"
LOCK_FILE="$LOG_DIR/validator.lock"

mkdir -p "$LOG_DIR"

if [ -f "$LOCK_FILE" ]; then
  echo "[$TIMESTAMP] Previous run still in progress, skipping..." >> "$LOG_FILE"
  exit 0
fi

touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

echo "" >> "$LOG_FILE"
echo "[$TIMESTAMP] ========== Starting validation ==========" >> "$LOG_FILE"

cd "$PROJECT_DIR"
set +e

# Run without PagerDuty for testing
"$PROJECT_DIR/hype-rs-build/target/release/hype" validate-nonces.lua -- \
  --only-mismatches \
  --file=test-process-map.json \
  --concurrency=10 \
  >> "$LOG_FILE" 2>&1

EXIT_CODE=$?
set -e

echo "[$TIMESTAMP] Validation complete (exit code: $EXIT_CODE)" >> "$LOG_FILE"
echo "[$TIMESTAMP] =========================================" >> "$LOG_FILE"

exit $EXIT_CODE
