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

## Installation

1. Clone or download the repository:
   ```bash
   git clone <repository-url>
   cd slot-validate
   ```

2. Ensure `process-map.json` is present with process-to-server mappings:
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

| Option | Default | Description |
|--------|---------|-------------|
| `--concurrency=N` | `10` | Number of concurrent HTTP requests (1-50) |
| `--verbose` | `false` | Enable detailed logging of HTTP requests and responses |
| `--only-mismatches` | `false` | Display only processes with nonce mismatches |
| `--help` | - | Show usage information and exit |

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

For each process ID:

1. **Parallel Fetching**: Two concurrent HTTP requests are made:
   - **Slot Server**: `GET https://{server}/{process-id}~process@1.0/compute/at-slot`
     - Returns: Plain integer (e.g., `14204`)
   - **AO Router**: `GET https://su-router.ao-testnet.xyz/{process-id}/latest`
     - Returns: JSON with nonce in `assignment.tags[name=Nonce].value`

2. **Response Parsing**:
   - Slot server: Direct integer conversion
   - AO router: JSON parsing + tag array search

3. **Comparison**:
   - Numeric comparison of both nonce values
   - Calculate difference if mismatch detected

4. **Error Handling**:
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

## Related Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Technical architecture and design
- [USAGE_GUIDE.md](USAGE_GUIDE.md) - Detailed usage scenarios and best practices
- [api-endpoint-analysis.md](api-endpoint-analysis.md) - API endpoint specifications
- [PRPs/slot-nonce-validator-prp.md](PRPs/slot-nonce-validator-prp.md) - Original project requirements
