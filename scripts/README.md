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

## Script Details

### run-validator.sh
Main wrapper script that:
- Prevents overlapping runs with lock file
- Loads PagerDuty key from secure config
- Executes validator with proper flags
- Logs all output with timestamps
- Rotates logs older than 30 days

### setup-cron.sh
One-time setup script that:
- Creates required directories
- Prompts for PagerDuty routing key
- Generates LaunchAgent plist configuration
- Loads the LaunchAgent into macOS
- Makes all scripts executable

### manage-validator.sh
Management interface that provides:
- Start/stop/restart commands
- Status checking with recent run history
- Log tailing for troubleshooting
- Test command for manual execution

## Architecture

```
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

~/Library/LaunchAgents/
└── com.forward.slot-validator.plist  # macOS LaunchAgent config
```

## Security Notes

- PagerDuty key stored in separate file with 600 permissions
- Key file is gitignored and never committed
- Lock file prevents race conditions
- All scripts validate prerequisites before executing
