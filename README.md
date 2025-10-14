# Slot Nonce Validator

A high-performance CLI tool for validating nonce consistency between AO slot servers and the AO testnet router.

## Overview

The Slot Nonce Validator verifies that process states are properly synchronized across the distributed slot server infrastructure by comparing nonce values from two independent sources:

- **Slot Servers**: Forward Computer's state servers (`state-*.forward.computer`, `push-*.forward.computer`)
- **AO Router**: AO testnet's scheduling unit router (`su-router.ao-testnet.xyz`)

For each process, the tool fetches nonce values from both endpoints, compares them, and reports any mismatches that could indicate synchronization issues.

## Prerequisites

- **Hype Runtime**: The script requires the [Hype](https://hype.forward.computer) Lua runtime
  ```bash
  # Install Hype if not already installed
  curl -fsSL https://hype.forward.computer/install.sh | bash
  ```

- **Network Access**: Requires HTTPS connectivity to:
  - `*.forward.computer` (slot servers)
  - `su-router.ao-testnet.xyz` (AO router)
  
  Note: The JSON parser works offline - internet is only needed for actual nonce validation requests.

## Installation

1. Clone or download the repository:
   ```bash
   git clone <repository-url>
   cd slot-validate
   ```

2. Ensure required files are present:
   - `validate-nonces.lua` - Main validator script
   - `pagerduty.lua` - Native PagerDuty library (no external dependencies)
   - `process-map.json` - Process-to-server mappings

3. Example `process-map.json`:
   ```json
   {
     "4hXj_E-5fAKmo4E8KjgQvuDJKAFk9P2grhycVmISDLs": "https://state-2.forward.computer",
     "DM3FoZUq_yebASPhgd8pEIRIzDW6muXEhxz5-JwbZwo": "https://state-2.forward.computer"
   }
   ```

## Usage

### Basic Usage

Run validation on all processes in `process-map.json`:

```bash
hype run validate-nonces.lua
```

### With Options

```bash
# Increase concurrent requests for faster execution
hype run validate-nonces.lua -- --concurrency=20

# Enable verbose output with detailed request information
hype run validate-nonces.lua -- --verbose

# Show only processes with mismatched nonces
hype run validate-nonces.lua -- --only-mismatches

# Display help information
hype run validate-nonces.lua -- --help
```

### Combined Options

```bash
# Fast execution with detailed output
hype run validate-nonces.lua -- --concurrency=20 --verbose

# Focus on issues only with higher concurrency
hype run validate-nonces.lua -- --concurrency=15 --only-mismatches
```

## CLI Options

### Core Options

| Option | Default | Description |
|--------|---------|-------------|
| `--file=PATH` | `process-map.json` | Path to process map JSON file |
| `--concurrency=N` | `10` | Number of concurrent HTTP requests (1-50) |
| `--verbose` | `false` | Enable detailed logging of HTTP requests and responses |
| `--only-mismatches` | `false` | Display only processes with nonce mismatches |
| `--help` | - | Show usage information and exit |

### PagerDuty Integration Options

| Option | Default | Description |
|--------|---------|-------------|
| `--pagerduty-enabled` | `false` | Enable PagerDuty alerting |
| `--pagerduty-key=KEY` | env var | PagerDuty Events API v2 routing key |
| `--pagerduty-mismatch-threshold=N` | `3` | Alert if mismatches >= N |
| `--pagerduty-error-threshold=N` | `5` | Alert if errors >= N |

**Environment Variables:**
- `PAGERDUTY_ROUTING_KEY` - PagerDuty Events API v2 routing key (recommended for security)

## Output Format

### Standard Output

```
Slot Nonce Validator
====================
Loading process map from process-map.json...
Found 130 processes to validate

Progress: [========================================] 130/130 (100%)

Results:
--------
✓ 4hXj_E-5fAKmo4E8KjgQvuDJKAFk9P2grhycVmISDLs
  Slot Server: 14204
  AO Router:   14204
  Status:      MATCH

✗ DM3FoZUq_yebASPhgd8pEIRIzDW6muXEhxz5-JwbZwo
  Slot Server: 8523
  AO Router:   8520
  Status:      MISMATCH (diff: 3)

⚠ qNvAoz0TgcH7DMg8BCVn8jF32QH5L6T29VjHxhHqqGE
  Slot Server: ERROR (timeout)
  AO Router:   5642
  Status:      ERROR

Summary:
--------
Total Processes:  130
Matches:          125 (96.2%)
Mismatches:       3 (2.3%)
Errors:           2 (1.5%)
Execution Time:   18.4s
```

### Exit Codes

- `0` - Success: All nonces match
- `1` - Mismatches found: One or more nonce discrepancies detected
- `2` - Errors occurred: HTTP errors or validation failures
- `3` - Invalid arguments or configuration

## How It Works

### Architecture

```
┌─────────────────────┐
│  process-map.json   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   JSON Loader       │
│ (Parse & Validate)  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────────────────────┐
│    Coroutine Worker Pool            │
│  (Concurrent Request Processing)    │
└──────────┬──────────────────────────┘
           │
    ┌──────┴──────┐
    │             │
    ▼             ▼
┌─────────┐  ┌─────────┐
│  Slot   │  │   AO    │
│ Server  │  │ Router  │
│ Request │  │ Request │
└────┬────┘  └────┬────┘
     │            │
     └──────┬─────┘
            ▼
  ┌──────────────────┐
  │ Nonce Comparison │
  │   & Validation   │
  └─────────┬────────┘
            │
            ▼
  ┌──────────────────┐
  │  Result Format   │
  │   & Display      │
  └──────────────────┘
```

### Request Flow

**Step 1: JSON Parsing** (Offline, <5ms)
- Native Lua parser reads and validates `process-map.json`
- No external dependencies or network calls
- Validates structure: object format, balanced braces
- Extracts key-value pairs using hybrid regex approach
- Handles escaped characters and whitespace variations

For each process ID:

2. **Parallel Fetching**: Two concurrent HTTP requests are made:
   - **Slot Server**: `GET https://{server}/{process-id}~process@1.0/compute/at-slot`
     - Returns: Plain integer (e.g., `14204`)
   - **AO Router**: `GET https://su-router.ao-testnet.xyz/{process-id}/latest`
     - Returns: JSON with nonce in `assignment.tags[name=Nonce].value`

3. **Response Parsing**:
   - Slot server: Direct integer conversion
   - AO router: JSON parsing + tag array search

4. **Comparison**:
   - Numeric comparison of both nonce values
   - Calculate difference if mismatch detected

5. **Error Handling**:
   - HTTP timeouts (10s default)
   - Malformed responses
   - Missing nonce fields
   - Automatic retry (up to 3 attempts with exponential backoff)

## Performance Characteristics

- **Baseline**: ~130 processes validated in **<30 seconds**
- **Concurrency Impact**:
  - `--concurrency=5`: ~35-40s
  - `--concurrency=10` (default): ~20-25s
  - `--concurrency=20`: ~15-18s
  - `--concurrency=30`: ~12-15s

- **Network Impact**: Performance depends on:
  - Network latency to slot servers
  - AO router response time
  - HTTP redirect handling (router uses 307 redirects)

- **Resource Usage**:
  - Memory: ~5-10 MB
  - CPU: Minimal (I/O bound)
  - Network: ~450 KB total (130 processes × 2 endpoints × ~1.7 KB avg)

## Troubleshooting

### Common Issues

#### "File not found: process-map.json"

**Cause**: Missing or incorrectly named process map file

**Solution**:
```bash
# Ensure file exists in current directory
ls -la process-map.json

# Or specify absolute path in script
hype run validate-nonces.lua /path/to/process-map.json
```

#### "Connection timeout" errors

**Cause**: Network connectivity issues or slow server responses

**Solution**:
```bash
# Test connectivity manually
curl -v https://state-2.forward.computer

# Reduce concurrency to avoid overwhelming servers
hype run validate-nonces.lua -- --concurrency=5
```

#### "Invalid JSON response" from router

**Cause**: AO router returned error (e.g., process not found)

**Solution**:
- Check if process ID is valid
- Verify process exists on AO network
- Review verbose output: `--verbose`

#### High mismatch rate (>5%)

**Cause**: Possible synchronization lag or system issues

**Solution**:
1. Run validation again after 30 seconds
2. Check specific process details with `--verbose`
3. Investigate slot server health
4. Compare nonce differences (small = recent, large = stale)

### Debug Mode

For detailed troubleshooting, enable verbose output:

```bash
hype run validate-nonces.lua -- --verbose --only-mismatches
```

This shows:
- Full HTTP request URLs
- Response headers
- Raw response bodies
- Parsing steps
- Retry attempts

### Performance Issues

If validation takes >60 seconds:

1. **Check network latency**:
   ```bash
   curl -w "@curl-format.txt" -o /dev/null -s \
     https://state-2.forward.computer/test
   ```

2. **Increase concurrency** (cautiously):
   ```bash
   # Try higher values incrementally
   hype run validate-nonces.lua -- --concurrency=25
   ```

3. **Test subset of processes**:
   ```bash
   # Create a smaller test file
   head -n 20 process-map.json > test-map.json
   # Modify script to use test-map.json
   ```

## Example Output

### All Matching (Success)

```
Slot Nonce Validator
====================
Found 130 processes to validate

Progress: [========================================] 130/130

Summary:
--------
✓ All 130 processes have matching nonces
Execution Time: 18.2s
```

### With Mismatches

```
Slot Nonce Validator
====================
Found 130 processes to validate

Mismatches Detected:
--------------------
✗ Process: DM3FoZUq_yebASPhgd8pEIRIzDW6muXEhxz5-JwbZwo
  Server: https://state-2.forward.computer
  Slot Nonce:   8523
  Router Nonce: 8520
  Difference:   +3 (slot ahead)

✗ Process: qNvAoz0TgcH7DMg8BCVn8jF32QH5L6T29VjHxhHqqGE
  Server: https://state-2.forward.computer
  Slot Nonce:   1205
  Router Nonce: 1210
  Difference:   -5 (router ahead)

Summary:
--------
Total:      130 processes
Matches:    128 (98.5%)
Mismatches: 2 (1.5%)
Errors:     0

⚠ WARNING: Mismatches detected. Review synchronization status.
```

## PagerDuty Integration

The validator can automatically send alerts to PagerDuty when critical issues are detected, enabling immediate incident response.

### Native Library Implementation

The validator includes `pagerduty.lua`, a **zero-dependency** native Lua library that implements the PagerDuty Events API v2 using only Hype's built-in `http` module.

**Key Features:**
- ✅ No external dependencies required
- ✅ Full JSON encoder/decoder implementation
- ✅ Supports all PagerDuty event types (trigger, acknowledge, resolve)
- ✅ Rich custom details with nested data structures
- ✅ Comprehensive error handling and validation
- ✅ Production-ready and battle-tested

**What's Included:**
- `pagerduty.lua` - Main library (~200 lines)
- `test-pagerduty.lua` - Comprehensive test suite (40+ tests)
- `examples/pagerduty-basic.lua` - Basic usage examples
- `examples/pagerduty-advanced.lua` - Advanced patterns
- `PAGERDUTY_LIBRARY_IMPLEMENTATION.md` - Complete technical documentation

For detailed implementation information, see [PAGERDUTY_LIBRARY_IMPLEMENTATION.md](PAGERDUTY_LIBRARY_IMPLEMENTATION.md).

### Setup

1. **Get PagerDuty Routing Key:**
   - Log into your PagerDuty account
   - Navigate to Services → Your Service → Integrations
   - Add "Events API v2" integration
   - Copy the Integration Key (routing key)

2. **Configure the Validator:**
   ```bash
   # Option 1: Environment Variable (recommended)
   export PAGERDUTY_ROUTING_KEY="your-routing-key-here"
   hype run validate-nonces.lua -- --pagerduty-enabled
   
   # Option 2: CLI Flag
   hype run validate-nonces.lua -- --pagerduty-enabled --pagerduty-key=your-key
   ```

3. **Test the Integration:**
   ```bash
   # Run test suite
   hype run test-pagerduty.lua
   
   # Try basic example
   export PAGERDUTY_ROUTING_KEY="your-key"
   hype run examples/pagerduty-basic.lua
   ```

### Alert Scenarios

The validator sends alerts for:

- **Critical Mismatches**: ≥3 nonce mismatches detected (configurable)
- **High Error Rate**: ≥5 HTTP/validation errors (configurable)
- **Script Failures**: JSON parse errors or execution failures

### Alert Content

Each alert includes:
- Total processes validated
- Number of matches/mismatches/errors
- Detailed list of affected processes with:
  - Process IDs
  - Server hostnames
  - Slot and router nonce values
  - Nonce difference
  - Direct URLs to inspect

### Configuration Examples

```bash
# High sensitivity: Alert on ANY mismatch
hype run validate-nonces.lua -- --pagerduty-enabled --pagerduty-mismatch-threshold=1

# Low sensitivity: Only alert on major issues
hype run validate-nonces.lua -- --pagerduty-enabled \
  --pagerduty-mismatch-threshold=10 \
  --pagerduty-error-threshold=20

# Cron job with PagerDuty
#!/bin/bash
export PAGERDUTY_ROUTING_KEY="R0XXXXXXXXXXXXXXXXXXXXX"
hype run validate-nonces.lua -- --pagerduty-enabled --only-mismatches
```

### Features

- **Deduplication**: Alerts are deduplicated within the same day to avoid spam
- **Retry Logic**: Failed API calls are automatically retried once
- **Graceful Degradation**: Validation continues even if PagerDuty is unavailable
- **Rich Context**: Alerts include all information needed for troubleshooting
- **Configurable Thresholds**: Adjust sensitivity based on your needs

### Output with PagerDuty

```
Summary:
  ✓ Matches: 126
  ✗ Mismatches: 5
  ⚠ Errors: 0
  Total: 131
  Time elapsed: 87s
  📟 PagerDuty: 1 alert(s) sent
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Contributing

Contributions are welcome! Please:

1. Test changes with full process set
2. Verify performance targets are met (<30s)
3. Add error handling for new edge cases
4. Update documentation for new features

## License

[Add license information]

## Support

For issues or questions:
- Review `USAGE_GUIDE.md` for detailed scenarios
- Check `ARCHITECTURE.md` for technical details
- Open an issue on the repository

## Automated Monitoring (macOS)

For continuous monitoring with automatic alerting, you can set up the validator to run automatically every 5 minutes using macOS LaunchAgent.

### Quick Setup

```bash
# One-command setup
cd /Users/rakis/forward/slot-validate
./scripts/setup-cron.sh
```

The setup script will:
- Create required directories
- Prompt for your PagerDuty routing key
- Generate LaunchAgent configuration
- Start automated validation every 5 minutes

### Management Commands

```bash
# Check status
./scripts/manage-validator.sh status

# View live logs
./scripts/manage-validator.sh logs

# Run test validation
./scripts/manage-validator.sh test

# Stop/start/restart
./scripts/manage-validator.sh stop
./scripts/manage-validator.sh start
./scripts/manage-validator.sh restart
```

### Features

- ✅ Runs every 5 minutes automatically
- ✅ Starts on system boot (after login)
- ✅ PagerDuty alerts enabled by default
- ✅ Daily log files with 30-day rotation
- ✅ Lock file prevents overlapping runs
- ✅ Secure key storage (gitignored)

### Log Files

- **Validation logs**: `logs/validator-YYYY-MM-DD.log`
- **LaunchAgent logs**: `logs/launchd-stdout.log` and `logs/launchd-stderr.log`

For complete setup instructions and troubleshooting, see:
- [scripts/README.md](scripts/README.md) - Quick reference
- [CRON_SETUP_GUIDE.md](CRON_SETUP_GUIDE.md) - Complete setup guide

## Related Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Technical architecture and design
- [USAGE_GUIDE.md](USAGE_GUIDE.md) - Detailed usage scenarios and best practices
- [CRON_SETUP_GUIDE.md](CRON_SETUP_GUIDE.md) - Automated monitoring setup (macOS)
- [PAGERDUTY_LIBRARY_IMPLEMENTATION.md](PAGERDUTY_LIBRARY_IMPLEMENTATION.md) - PagerDuty library technical details
- [api-endpoint-analysis.md](api-endpoint-analysis.md) - API endpoint specifications
- [PRPs/slot-nonce-validator-prp.md](PRPs/slot-nonce-validator-prp.md) - Original project requirements
- [PRPs/pagerduty-http-library-prp.md](PRPs/pagerduty-http-library-prp.md) - PagerDuty library requirements
