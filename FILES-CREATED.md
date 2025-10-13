# Files Created

## Summary
Created test and example files for the Slot Nonce Validator project.

## Files

### 1. test-process-map.json (425 bytes)
Small test dataset with 5 processes for quick testing:
- 4hXj_E-5fAKmo4E8KjgQvuDJKAFk9P2grhycVmISDLs → state-2.forward.computer
- DM3FoZUq_yebASPhgd8pEIRIzDW6muXEhxz5-JwbZwo → state-2.forward.computer
- 4MYqWdc4_TcvVU0zoNMzuIZkUnazrSf0d-FsVjEPtSU → push-5.forward.computer
- 3XBGLrygs11K63F_7mldWz4veNx6Llg6hI2yZs8LKHo → push-1.forward.computer
- SNy4m-DrqxWl01YqGM4sxI8qCni-58re8uuJLvZPypY → push-3.forward.computer

### 2. examples/basic-usage.sh (1.0 KB) ✓ Executable
Shell script demonstrating basic usage:
- Running with test data (--file flag)
- Running with full dataset
- Filtering to show only mismatches

### 3. examples/advanced-usage.sh (2.7 KB) ✓ Executable
Advanced usage examples:
- Different concurrency levels (5, 10, 20)
- Verbose mode output
- Filtering mismatches
- Combining multiple flags
- Performance timing comparisons

### 4. test-runner.lua (6.5 KB)
Comprehensive test suite with 12 tests:
- JSON file loading
- JSON parsing via HTTP
- HTTP GET requests
- HTTP error handling
- Retry logic simulation
- Router nonce extraction
- URL construction
- String trimming
- Process ID formatting
- Result status categorization
- Coroutine creation
- Table operations

### 5. .gitignore (52 bytes)
Git ignore rules:
```
*.log
results/
.DS_Store
node_modules/
*.tmp
*.temp
```

### 6. TEST-README.md (5.2 KB)
Comprehensive documentation:
- Test file descriptions
- Example script usage
- Quick start guide
- Common test scenarios
- Expected output examples
- Troubleshooting guide
- File structure overview

### 7. validate-nonces.lua (Updated)
Added --file parameter support:
- Default: process-map.json
- Can specify custom file: --file=test-process-map.json
- Updated help text
- Updated config structure

## Usage Examples

### Run Tests
```bash
hype run test-runner.lua
```

### Quick Test with Small Dataset
```bash
hype run validate-nonces.lua -- --file=test-process-map.json
```

### Run Basic Examples
```bash
./examples/basic-usage.sh
```

### Run Advanced Examples
```bash
./examples/advanced-usage.sh
```

### Performance Comparison
```bash
time hype run validate-nonces.lua -- --file=test-process-map.json --concurrency=1
time hype run validate-nonces.lua -- --file=test-process-map.json --concurrency=20
```

## All Files Verified ✓
- test-process-map.json ✓
- examples/basic-usage.sh ✓ (executable)
- examples/advanced-usage.sh ✓ (executable)
- test-runner.lua ✓
- .gitignore ✓
- TEST-README.md ✓
- validate-nonces.lua ✓ (updated with --file support)
