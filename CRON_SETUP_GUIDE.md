# macOS Automated Monitoring Setup Guide

Complete guide for setting up automated Slot Nonce Validator execution on macOS using LaunchAgent.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Verification](#verification)
- [Management](#management)
- [Troubleshooting](#troubleshooting)
- [Configuration](#configuration)
- [Uninstallation](#uninstallation)

## Overview

This setup enables the Slot Nonce Validator to run automatically every 5 minutes on macOS with:

- ✅ Automated execution every 5 minutes
- ✅ PagerDuty alerting on critical issues
- ✅ Daily log files with automatic rotation (30-day retention)
- ✅ Overlap prevention (lock file mechanism)
- ✅ Secure PagerDuty key storage
- ✅ Start on system boot (after user login)
- ✅ Easy management interface

### Architecture

```
┌─────────────────────────────────────────────────┐
│  macOS LaunchAgent (com.forward.slot-validator) │
│  Runs: run-validator.sh every 300 seconds       │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│  run-validator.sh                                │
│  • Checks lock file (prevents overlaps)         │
│  • Loads PagerDuty key from config              │
│  • Executes: hype run validate-nonces.lua       │
│  • Logs output to daily file                    │
│  • Rotates logs older than 30 days              │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│  validate-nonces.lua                             │
│  • Validates 130+ process nonces                │
│  • Sends PagerDuty alerts if issues detected    │
│  • Returns exit code for monitoring             │
└─────────────────────────────────────────────────┘
```

## Prerequisites

### System Requirements

- **macOS Version**: 10.15 (Catalina) or later
- **Disk Space**: ~50 MB (scripts + logs with 30-day retention)
- **Hype Runtime**: Already installed at `/usr/local/bin/hype`

### Permissions

- Read/write access to project directory
- Ability to create/modify LaunchAgents in `~/Library/LaunchAgents/`
- Environment variable access

### Before You Begin

1. **Verify Hype is installed:**
   ```bash
   which hype
   # Expected: /usr/local/bin/hype
   ```

2. **Test validator manually:**
   ```bash
   cd /Users/rakis/forward/slot-validate
   hype run validate-nonces.lua
   # Should complete successfully
   ```

3. **Get PagerDuty routing key:**
   - Log into PagerDuty
   - Navigate to Services → Your Service → Integrations
   - Add "Events API v2" integration
   - Copy the Integration Key

## Installation

### One-Command Setup

```bash
cd /Users/rakis/forward/slot-validate
./scripts/setup-cron.sh
```

**What it does:**

1. Creates required directories (`logs/`, `config/`)
2. Prompts for PagerDuty routing key
3. Saves key securely to `config/.pagerduty_key` (chmod 600)
4. Generates LaunchAgent plist: `~/Library/LaunchAgents/com.forward.slot-validator.plist`
5. Loads the LaunchAgent into macOS
6. Makes all scripts executable

### Interactive Setup Process

```
╔══════════════════════════════════════════════════════════╗
║   Slot Nonce Validator - Automated Cron Setup           ║
╚══════════════════════════════════════════════════════════╝

📁 Creating directories...
🔑 PagerDuty Configuration
   Enter PagerDuty routing key: [hidden input]
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
```

### Manual Verification

After setup, verify installation:

```bash
# 1. Check LaunchAgent is loaded
launchctl list | grep slot-validator
# Expected: Shows com.forward.slot-validator with PID

# 2. Verify files created
ls -la scripts/
# Expected: run-validator.sh, setup-cron.sh, manage-validator.sh (all executable)

ls -la config/
# Expected: .pagerduty_key with permissions -rw-------

ls -la ~/Library/LaunchAgents/com.forward.slot-validator.plist
# Expected: File exists
```

## Verification

### Immediate Test

Run a test validation to ensure everything works:

```bash
./scripts/manage-validator.sh test
```

Expected output:
```
🧪 Running test validation...

[2025-10-13 14:30:22] ========== Starting validation ==========
Slot Nonce Validator
Found 130 processes to validate
...
[2025-10-13 14:30:40] Validation complete (exit code: 0)

✅ Test complete. Check logs:
   tail logs/validator-2025-10-13.log
```

### Check Status

```bash
./scripts/manage-validator.sh status
```

Expected output:
```
📊 Validator Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Status: Running
🔄 Schedule: Every 5 minutes
📁 Project: /Users/rakis/forward/slot-validate
⏰ Last run: 2025-10-13 14:30:22
📟 PagerDuty: Enabled

📝 Recent activity (last 10 runs):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[2025-10-13 14:30:22] ========== Starting validation ==========
[2025-10-13 14:30:40] Validation complete (exit code: 0)
```

### Wait for Scheduled Runs

After 5-10 minutes, check that automated runs are occurring:

```bash
# View today's log file
cat logs/validator-$(date +%Y-%m-%d).log

# Expected: Multiple validation runs logged
```

### Verify PagerDuty Integration

If mismatches occur (≥3 by default), check PagerDuty dashboard for alerts.

## Management

### Status Check

Show current status and recent run history:

```bash
./scripts/manage-validator.sh status
```

### View Logs

Tail the current log file in real-time:

```bash
./scripts/manage-validator.sh logs
```

Press `Ctrl+C` to exit.

### Stop Service

```bash
./scripts/manage-validator.sh stop
```

### Start Service

```bash
./scripts/manage-validator.sh start
```

### Restart Service

```bash
./scripts/manage-validator.sh restart
```

Useful after configuration changes.

### Run Test Validation

Execute validator immediately without waiting for schedule:

```bash
./scripts/manage-validator.sh test
```

### Available Commands Summary

| Command | Description |
|---------|-------------|
| `status` | Show running status and recent activity |
| `logs` | Tail current log file (live view) |
| `test` | Run immediate test validation |
| `start` | Start scheduled validator |
| `stop` | Stop scheduled validator |
| `restart` | Restart scheduled validator |

## Troubleshooting

### Issue: LaunchAgent Not Running

**Symptoms:**
```bash
$ ./scripts/manage-validator.sh status
❌ Status: Not running
```

**Solutions:**

1. **Check LaunchAgent logs:**
   ```bash
   cat logs/launchd-stderr.log
   ```

2. **Try loading manually:**
   ```bash
   launchctl load ~/Library/LaunchAgents/com.forward.slot-validator.plist
   ```

3. **Verify plist syntax:**
   ```bash
   plutil ~/Library/LaunchAgents/com.forward.slot-validator.plist
   # Should output: OK
   ```

4. **Check file permissions:**
   ```bash
   ls -la scripts/run-validator.sh
   # Should be: -rwxr-xr-x (executable)
   ```

### Issue: PagerDuty Key Not Found

**Symptoms:**
```
ERROR: PagerDuty key not found
```

**Solutions:**

1. **Check if key file exists:**
   ```bash
   ls -la config/.pagerduty_key
   ```

2. **Re-run setup to add/update key:**
   ```bash
   ./scripts/setup-cron.sh
   # Choose 'y' when prompted to update key
   ```

3. **Manually create key file:**
   ```bash
   echo "YOUR_ROUTING_KEY_HERE" > config/.pagerduty_key
   chmod 600 config/.pagerduty_key
   ```

### Issue: Hype Not Found

**Symptoms:**
```
/usr/local/bin/hype: No such file or directory
```

**Solutions:**

1. **Find hype location:**
   ```bash
   which hype
   # Example output: /opt/homebrew/bin/hype
   ```

2. **Update run-validator.sh with correct path:**
   ```bash
   nano scripts/run-validator.sh
   # Change line: /usr/local/bin/hype
   # To actual path from step 1
   ```

3. **Restart validator:**
   ```bash
   ./scripts/manage-validator.sh restart
   ```

### Issue: Lock File Stuck

**Symptoms:**
```
Previous run still in progress, skipping...
```

**Solutions:**

1. **Check if validator actually running:**
   ```bash
   ps aux | grep validate-nonces
   ```

2. **If not running, remove lock file:**
   ```bash
   rm logs/validator.lock
   ```

3. **Test immediately:**
   ```bash
   ./scripts/manage-validator.sh test
   ```

### Issue: Logs Not Rotating

**Symptoms:**
- Logs directory growing too large

**Solutions:**

1. **Manually clean old logs:**
   ```bash
   find logs/ -name "validator-*.log" -mtime +30 -delete
   ```

2. **Verify rotation logic in script:**
   ```bash
   grep "find.*mtime" scripts/run-validator.sh
   # Should show: find "$LOG_DIR" -name "validator-*.log" -mtime +30 -delete
   ```

### Issue: High CPU Usage

**Symptoms:**
- System slow during validation runs

**Solutions:**

1. **Check validator concurrency:**
   ```bash
   # Default is 10 concurrent requests
   # To reduce, edit run-validator.sh:
   nano scripts/run-validator.sh
   # Add: --concurrency=5 to hype command
   ```

2. **Increase schedule interval:**
   ```bash
   # Edit LaunchAgent plist
   nano ~/Library/LaunchAgents/com.forward.slot-validator.plist
   # Change: <integer>300</integer> to <integer>600</integer> (10 minutes)
   
   # Restart
   ./scripts/manage-validator.sh restart
   ```

## Configuration

### Change PagerDuty Key

**Option 1: Re-run setup**
```bash
./scripts/setup-cron.sh
# Choose 'y' when prompted to update key
```

**Option 2: Manually edit**
```bash
echo "NEW_KEY_HERE" > config/.pagerduty_key
chmod 600 config/.pagerduty_key
# No restart needed - takes effect next run
```

### Change Schedule

Edit the LaunchAgent plist to change execution frequency:

```bash
nano ~/Library/LaunchAgents/com.forward.slot-validator.plist
```

Find and modify:
```xml
<key>StartInterval</key>
<integer>300</integer>  <!-- Change this value (in seconds) -->
```

Common intervals:
- Every 5 minutes: `300`
- Every 10 minutes: `600`
- Every 15 minutes: `900`
- Every 30 minutes: `1800`
- Every hour: `3600`

After editing, restart:
```bash
./scripts/manage-validator.sh restart
```

### Change Alert Thresholds

Edit `run-validator.sh` to adjust PagerDuty alert sensitivity:

```bash
nano scripts/run-validator.sh
```

Modify the hype command line:
```bash
/usr/local/bin/hype run validate-nonces.lua -- \
  --pagerduty-enabled \
  --only-mismatches \
  --pagerduty-mismatch-threshold=5 \    # Alert if ≥5 mismatches (default: 3)
  --pagerduty-error-threshold=10 \      # Alert if ≥10 errors (default: 5)
```

No restart needed - changes take effect on next scheduled run.

### Change Log Retention

Edit `run-validator.sh` to modify log retention period:

```bash
nano scripts/run-validator.sh
```

Find and modify:
```bash
find "$LOG_DIR" -name "validator-*.log" -mtime +30 -delete
#                                                 ^^
#                                         Change this number (days)
```

Common retention periods:
- 7 days: `-mtime +7`
- 14 days: `-mtime +14`
- 30 days: `-mtime +30` (default)
- 90 days: `-mtime +90`

### Change Validator Options

Edit `run-validator.sh` to modify validator behavior:

```bash
nano scripts/run-validator.sh
```

Available options to add/modify:
```bash
/usr/local/bin/hype run validate-nonces.lua -- \
  --pagerduty-enabled \
  --only-mismatches \
  --concurrency=20 \              # Faster execution (default: 10)
  --verbose \                     # Detailed logging
  --file=custom-map.json          # Different process map
```

## Uninstallation

To completely remove the automated validator:

### Step 1: Stop and Unload LaunchAgent

```bash
./scripts/manage-validator.sh stop
```

Or manually:
```bash
launchctl unload ~/Library/LaunchAgents/com.forward.slot-validator.plist
```

### Step 2: Remove LaunchAgent File

```bash
rm ~/Library/LaunchAgents/com.forward.slot-validator.plist
```

### Step 3: Remove Configuration (Optional)

Keep logs and scripts but remove sensitive key:
```bash
rm config/.pagerduty_key
```

### Step 4: Remove All Automation Files (Optional)

Complete removal:
```bash
cd /Users/rakis/forward/slot-validate
rm -rf scripts/ logs/ config/
```

**Note:** This preserves the main validator (`validate-nonces.lua`) so you can still run it manually.

## Advanced Usage

### Run Multiple Instances

You can run multiple validators with different configurations:

1. **Create a second project directory:**
   ```bash
   cp -r /Users/rakis/forward/slot-validate /Users/rakis/forward/slot-validate-prod
   ```

2. **Modify the second setup:**
   - Update `PROJECT_DIR` in all scripts to new path
   - Use different LaunchAgent label: `com.forward.slot-validator-prod`
   - Use different schedule (e.g., every 10 minutes offset by 5 minutes)

3. **Load both LaunchAgents:**
   ```bash
   # Original runs at :00, :05, :10, etc.
   # New one runs at :02:30, :07:30, :12:30, etc. (offset)
   ```

### Custom Process Maps

To validate different process sets:

1. **Create custom map:**
   ```bash
   cp process-map.json production-map.json
   # Edit production-map.json with different processes
   ```

2. **Update run-validator.sh:**
   ```bash
   nano scripts/run-validator.sh
   # Add: --file=production-map.json
   ```

3. **Restart:**
   ```bash
   ./scripts/manage-validator.sh restart
   ```

### Integration with External Monitoring

Export metrics for external systems:

```bash
# Add to run-validator.sh after validation
if [ $EXIT_CODE -eq 0 ]; then
  echo "validator.status:0|g" | nc -u -w1 statsd-host 8125
else
  echo "validator.status:1|g" | nc -u -w1 statsd-host 8125
fi
```

### Email Notifications

Add email alerts in addition to PagerDuty:

```bash
# Add to run-validator.sh after validation
if [ $EXIT_CODE -ne 0 ]; then
  echo "Validation failed. Check logs at $LOG_FILE" | \
    mail -s "Slot Validator Alert" ops@example.com
fi
```

## Performance Characteristics

### Resource Usage

- **CPU**: <1% average, 5-10% during validation (15-30 seconds)
- **Memory**: ~50 MB during validation
- **Disk**: ~1 MB per day with 30-day retention ≈ 30 MB total
- **Network**: ~450 KB per validation run

### Execution Frequency

- **Default**: Every 5 minutes = 288 runs/day
- **Duration**: 15-30 seconds per run (depends on network)
- **Overlap**: Prevented by lock file mechanism

### Log Growth

| Period | Log Size |
|--------|----------|
| Daily | ~1 MB (288 runs × ~3.5 KB/run) |
| Weekly | ~7 MB |
| Monthly | ~30 MB |
| With 30-day rotation | Max ~30 MB |

## Maintenance

### Regular Checks

**Weekly:**
```bash
# Quick status check
./scripts/manage-validator.sh status

# Review PagerDuty incidents (if any)
# Visit PagerDuty dashboard
```

**Monthly:**
```bash
# Verify log rotation working
ls -lh logs/validator-*.log | wc -l
# Should show ~30-35 files (30 days + current month)

# Check disk usage
du -sh logs/
# Should be ~30 MB

# Review PagerDuty alert history
```

**As Needed:**
- Update PagerDuty key (if rotated)
- Adjust thresholds based on false positive rate
- Modify schedule if load too high

### Backup Configuration

Recommended to backup:

```bash
# Backup PagerDuty key (encrypted)
tar czf validator-config-backup.tar.gz config/.pagerduty_key

# Backup custom scripts (if modified)
tar czf validator-scripts-backup.tar.gz scripts/

# Store securely (encrypted, off-site)
```

### Updating Scripts

To update scripts while preserving configuration:

1. **Stop validator:**
   ```bash
   ./scripts/manage-validator.sh stop
   ```

2. **Update scripts:**
   ```bash
   # Pull latest from git or edit manually
   ```

3. **Test manually:**
   ```bash
   ./scripts/manage-validator.sh test
   ```

4. **Restart:**
   ```bash
   ./scripts/manage-validator.sh start
   ```

## FAQ

### Q: Will it run when my Mac is asleep?

**A:** No, LaunchAgent jobs don't run during system sleep. However:
- Jobs execute immediately upon wake
- No runs are "lost" - next scheduled run occurs on time
- For 24/7 monitoring, keep Mac awake or use cloud/server deployment

### Q: Will it run after reboot?

**A:** Yes, the LaunchAgent loads automatically after user login using the `RunAtLoad` setting.

### Q: Can I run it on Linux?

**A:** The current setup is macOS-specific (LaunchAgent). For Linux:
- Use `systemd` timer instead of LaunchAgent
- Replace plist with systemd service/timer unit files
- Rest of the scripts work unchanged

### Q: How do I know if it's working?

**A:** Multiple ways:
```bash
# 1. Check status
./scripts/manage-validator.sh status

# 2. View logs
cat logs/validator-$(date +%Y-%m-%d).log

# 3. Check LaunchAgent
launchctl list | grep slot-validator

# 4. Monitor PagerDuty (if issues detected)
```

### Q: Can I change which processes are validated?

**A:** Yes, edit `process-map.json` with your desired processes. Changes take effect on next run.

### Q: What happens if validation takes longer than 5 minutes?

**A:** The lock file mechanism prevents overlapping runs. If a run is still in progress when the next schedule triggers, it logs "Previous run still in progress, skipping..." and waits for the next schedule.

### Q: How do I test PagerDuty integration?

**A:** Multiple approaches:

```bash
# 1. Run standalone PagerDuty test
export PAGERDUTY_ROUTING_KEY="your-key"
hype run test-pagerduty.lua

# 2. Trigger alert with low threshold
# Edit run-validator.sh temporarily:
# --pagerduty-mismatch-threshold=1
./scripts/manage-validator.sh test

# 3. Check PagerDuty dashboard for incidents
```

### Q: Can I get notifications somewhere other than PagerDuty?

**A:** Yes, edit `run-validator.sh` to add:
- Email notifications (via `mail` command)
- Slack webhooks (via `curl`)
- SMS (via Twilio API)
- Custom webhooks

Example:
```bash
# Add after validation in run-validator.sh
if [ $EXIT_CODE -ne 0 ]; then
  curl -X POST https://hooks.slack.com/your-webhook \
    -d '{"text":"Validator alert: check logs"}'
fi
```

## Support

For issues or questions:

1. **Check this guide's Troubleshooting section**
2. **Review logs:**
   ```bash
   cat logs/validator-$(date +%Y-%m-%d).log
   cat logs/launchd-stderr.log
   ```
3. **Test manually:**
   ```bash
   ./scripts/manage-validator.sh test
   ```
4. **Open issue on repository** with:
   - Output of `./scripts/manage-validator.sh status`
   - Relevant log excerpts
   - macOS version
   - Any error messages

## Related Documentation

- [README.md](README.md) - Main validator documentation
- [scripts/README.md](scripts/README.md) - Quick script reference
- [USAGE_GUIDE.md](USAGE_GUIDE.md) - Validator usage scenarios
- [PRPs/cron-setup-macos-prp.md](PRPs/cron-setup-macos-prp.md) - Original requirements

---

**Last Updated:** October 13, 2025  
**Version:** 1.0  
**Target Platform:** macOS 10.15+
