# Testing and Examples Guide

This directory contains test files and usage examples for the Slot Nonce Validator.

## Test Files

### test-process-map.json
A minimal test dataset containing 5 processes for quick validation testing. Use this file to:
- Test the validator without processing the full dataset
- Debug issues with specific processes
- Quickly verify functionality after changes

**Usage:**
```bash
hype run validate-nonces.lua -- --file=test-process-map.json
```

### test-runner.lua
Automated test suite that validates core functionality:
- JSON file loading
- HTTP request handling
- Retry logic
- Response parsing
- Output formatting
- Coroutine management

**Usage:**
```bash
hype run test-runner.lua
```

**Expected output:**
- Individual test results with pass/fail status
- Summary of total tests passed/failed
- Exit code 0 on success, 1 on failure

## Example Scripts

### examples/basic-usage.sh
Demonstrates fundamental usage patterns:

1. **Test with small dataset** - Validates 5 processes from test file
2. **Full dataset validation** - Processes all entries in process-map.json
3. **Filter mismatches only** - Shows only processes with nonce differences

**Usage:**
```bash
chmod +x examples/basic-usage.sh
./examples/basic-usage.sh
```

### examples/advanced-usage.sh
Shows advanced features and performance tuning:

1. **Concurrency testing** - Compares different concurrency levels (5, 10, 20)
2. **Verbose mode** - Detailed output with server information
3. **Filtered output** - Show only mismatches
4. **Combined flags** - Multiple options together
5. **Performance benchmarks** - Timing comparisons between concurrency levels

**Usage:**
```bash
chmod +x examples/advanced-usage.sh
./examples/advanced-usage.sh
```

## Quick Start

1. **Run basic tests:**
   ```bash
   hype run test-runner.lua
   ```

2. **Test with sample data:**
   ```bash
   hype run validate-nonces.lua -- --file=test-process-map.json
   ```

3. **Try example scripts:**
   ```bash
   ./examples/basic-usage.sh
   ```

## Common Test Scenarios

### Scenario 1: Quick Validation
```bash
hype run validate-nonces.lua -- --file=test-process-map.json --only-mismatches
```

### Scenario 2: Verbose Testing
```bash
hype run validate-nonces.lua -- --file=test-process-map.json --verbose
```

### Scenario 3: Performance Testing
```bash
time hype run validate-nonces.lua -- --file=test-process-map.json --concurrency=1
time hype run validate-nonces.lua -- --file=test-process-map.json --concurrency=20
```

### Scenario 4: Full Validation
```bash
hype run validate-nonces.lua -- --verbose --concurrency=15
```

## Expected Results

### Successful Test Run (test-runner.lua)
```
[TEST] JSON file loading... ✓ PASS
[TEST] JSON parsing via HTTP... ✓ PASS
[TEST] HTTP GET request... ✓ PASS
...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
═══════════════════ Test Results ══════════════════
✓ Passed: 12
✗ Failed: 0
Total: 12
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

All tests passed!
```

### Successful Validation Run
```
Loading process map...
Validating 5 processes with concurrency 10...

✓ 4hXj_E-5fA... (nonce: 12345)
✓ DM3FoZUq_y... (nonce: 12346)
✗ 4MYqWdc4_T...
  Slot:   12347
  Router: 12348

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary:
  ✓ Matches: 4
  ✗ Mismatches: 1
  ⚠ Errors: 0
  Total: 5
  Time elapsed: 3s
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Troubleshooting

### Tests Fail
1. Ensure Hype runtime is installed and accessible
2. Verify internet connectivity (tests make HTTP requests)
3. Check that test-process-map.json exists and is valid

### Validation Errors
- **File not found**: Verify the --file parameter points to a valid JSON file
- **HTTP errors**: Check network connectivity and endpoint availability
- **Parsing errors**: Ensure JSON files are properly formatted

### Performance Issues
- Reduce concurrency if experiencing timeout errors
- Increase concurrency for faster processing (up to 20-30 recommended)
- Use --only-mismatches to reduce output volume

## File Structure

```
slot-validate/
├── validate-nonces.lua          # Main validator script
├── process-map.json             # Full process dataset
├── test-process-map.json        # Small test dataset (5 processes)
├── test-runner.lua              # Test suite
├── TEST-README.md               # This file
├── examples/
│   ├── basic-usage.sh          # Basic usage examples
│   └── advanced-usage.sh       # Advanced usage examples
└── .gitignore                   # Git ignore rules
```

## Contributing Tests

When adding new features to validate-nonces.lua:

1. Add corresponding tests to test-runner.lua
2. Update example scripts if new flags are added
3. Document new test scenarios in this README
4. Ensure all tests pass before committing changes
