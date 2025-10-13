# Slot Nonce Validator - Usage Guide

A comprehensive guide to using the Slot Nonce Validator effectively for various validation scenarios.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Understanding the Output](#understanding-the-output)
3. [Common Scenarios](#common-scenarios)
4. [Performance Tuning](#performance-tuning)
5. [Debugging and Troubleshooting](#debugging-and-troubleshooting)
6. [Best Practices](#best-practices)
7. [FAQ](#faq)

---

## Getting Started

### First-Time Setup

1. **Verify Prerequisites**:
   ```bash
   # Check if Hype is installed
   hype --version
   
   # If not installed
   curl -fsSL https://hype.forward.computer/install.sh | bash
   ```

2. **Verify Process Map**:
   ```bash
   # Check if process-map.json exists
   ls -la process-map.json
   
   # Verify JSON structure
   cat process-map.json | head -n 10
   ```

3. **Test Run with Defaults**:
   ```bash
   hype run validate-nonces.lua
   ```

### Your First Validation

When you run the validator for the first time, you'll see:

```bash
$ hype run validate-nonces.lua

Slot Nonce Validator
====================
Loading process map from process-map.json...
Found 130 processes to validate

Progress: [========================================] 130/130 (100%)

Summary:
--------
Total Processes:  130
Matches:          128 (98.5%)
Mismatches:       2 (1.5%)
Errors:           0 (0%)
Execution Time:   22.3s
```

**What this means**:
- ✅ **98.5% match rate**: Excellent synchronization
- ⚠️ **2 mismatches**: Minor discrepancies to investigate
- ✅ **0 errors**: All endpoints reachable

---

## Understanding the Output

### Progress Indicator

```
Progress: [====================                    ] 65/130 (50%)
```

- **Bar**: Visual representation of completion
- **Numbers**: Completed / Total processes
- **Percentage**: Overall progress

### Result Details

#### Successful Match

```
✓ 4hXj_E-5fAKmo4E8KjgQvuDJKAFk9P2grhycVmISDLs
  Slot Server: 14204
  AO Router:   14204
  Status:      MATCH
```

**Interpretation**: 
- Both endpoints report the same nonce (14204)
- Process is perfectly synchronized
- No action required

---

#### Nonce Mismatch

```
✗ DM3FoZUq_yebASPhgd8pEIRIzDW6muXEhxz5-JwbZwo
  Server:      https://state-2.forward.computer
  Slot Nonce:  8523
  Router Nonce: 8520
  Difference:  +3 (slot ahead)
  Status:      MISMATCH
```

**Interpretation**:
- Slot server is 3 nonces ahead of router
- **Possible causes**:
  - Recent activity not yet propagated to router
  - Synchronization delay (normal if < 10)
  - Network partition (if difference is large)

**Action**:
- If difference < 5: Wait 30 seconds and re-validate
- If difference > 10: Investigate synchronization system
- If persistent: Check slot server logs

---

#### Error State

```
⚠ qNvAoz0TgcH7DMg8BCVn8jF32QH5L6T29VjHxhHqqGE
  Server:      https://state-2.forward.computer
  Slot Nonce:  ERROR (timeout after 3 retries)
  Router Nonce: 5642
  Status:      ERROR
```

**Interpretation**:
- Slot server request failed after 3 retry attempts
- Router responded successfully
- **Possible causes**:
  - Server temporarily down
  - Network connectivity issue
  - Process not on this server
  - Server overloaded

**Action**:
- Re-run validation after 1-2 minutes
- Check server health manually
- Verify process exists on this server

---

### Summary Statistics

```
Summary:
--------
Total Processes:  130
Matches:          125 (96.2%)
Mismatches:       3 (2.3%)
Errors:           2 (1.5%)
Execution Time:   18.4s
```

#### Interpreting the Numbers

| Match Rate | Status | Interpretation |
|------------|--------|----------------|
| 100% | 🟢 Excellent | Perfect synchronization |
| 95-99% | 🟢 Good | Minor transient issues |
| 90-95% | 🟡 Fair | Some synchronization lag |
| 85-90% | 🟠 Poor | Significant sync problems |
| < 85% | 🔴 Critical | System-wide issues |

#### Error Rate Guidelines

| Error Rate | Status | Action Required |
|------------|--------|-----------------|
| 0% | ✅ Perfect | No action |
| 1-5% | ⚠️ Normal | Monitor, may be transient |
| 5-10% | ⚠️ Elevated | Investigate network/servers |
| > 10% | 🚨 Critical | Immediate investigation |

---

## Common Scenarios

### Scenario 1: First-Time Validation

**Goal**: Establish baseline nonce consistency

**Steps**:
```bash
# 1. Run with verbose output to see what's happening
hype run validate-nonces.lua -- --verbose

# 2. Save results for comparison
hype run validate-nonces.lua > validation-baseline.txt

# 3. Review mismatches
hype run validate-nonces.lua -- --only-mismatches
```

**Expected Results**:
- 95%+ match rate indicates healthy system
- < 5% errors is normal for distributed system
- Note any recurring problem servers

---

### Scenario 2: Investigating Mismatches

**Goal**: Understand why nonces don't match

**Steps**:

1. **Identify Mismatches**:
   ```bash
   hype run validate-nonces.lua -- --only-mismatches --verbose
   ```

2. **Analyze Patterns**:
   ```bash
   # Check if mismatches are on specific servers
   hype run validate-nonces.lua -- --only-mismatches | grep "Server:"
   ```

3. **Manual Verification**:
   ```bash
   # Replace with actual process ID and server
   PROCESS="4hXj_E-5fAKmo4E8KjgQvuDJKAFk9P2grhycVmISDLs"
   SERVER="https://state-2.forward.computer"
   
   # Check slot server
   curl -s "$SERVER/${PROCESS}~process@1.0/compute/at-slot"
   
   # Check router
   curl -L -s "https://su-router.ao-testnet.xyz/${PROCESS}/latest" | \
     jq -r '.assignment.tags[] | select(.name == "Nonce") | .value'
   ```

4. **Wait and Revalidate**:
   ```bash
   # Wait 30 seconds for synchronization
   sleep 30
   hype run validate-nonces.lua -- --only-mismatches
   ```

**Decision Tree**:
```
Mismatch Detected
    │
    ├─▶ Difference < 5?
    │   └─▶ YES: Wait 30s and retry
    │       └─▶ Still mismatch?
    │           ├─▶ NO: Resolved (sync lag)
    │           └─▶ YES: Continue investigation
    │
    └─▶ Difference > 10?
        └─▶ YES: Check server logs
            └─▶ Multiple processes affected?
                ├─▶ YES: System-wide sync issue
                └─▶ NO: Process-specific problem
```

---

### Scenario 3: Performance Tuning

**Goal**: Optimize validation speed for large process sets

**Baseline Performance**:
```bash
# Test default concurrency (10)
time hype run validate-nonces.lua
# Note: ~20-25 seconds for 130 processes
```

**Tuning Steps**:

1. **Test Higher Concurrency**:
   ```bash
   # Try 15 concurrent requests
   time hype run validate-nonces.lua -- --concurrency=15
   
   # Try 20 concurrent requests
   time hype run validate-nonces.lua -- --concurrency=20
   
   # Try 30 concurrent requests
   time hype run validate-nonces.lua -- --concurrency=30
   ```

2. **Find Optimal Value**:
   ```bash
   # Test range and compare times
   for c in 10 15 20 25 30; do
     echo "Testing concurrency=$c"
     time hype run validate-nonces.lua -- --concurrency=$c
   done
   ```

3. **Monitor Error Rate**:
   - If errors increase with higher concurrency, reduce value
   - Sweet spot: Fastest time with 0-2% error rate

**Performance Table** (130 processes):

| Concurrency | Time | Error Rate | Recommendation |
|-------------|------|------------|----------------|
| 5 | 40s | 0% | Too slow |
| 10 | 22s | 0-1% | ✅ Default (safe) |
| 15 | 17s | 0-1% | ✅ Good balance |
| 20 | 14s | 1-2% | ✅ Fast |
| 30 | 12s | 2-3% | ⚠️ Risky |
| 40 | 11s | 5%+ | ❌ Too aggressive |

**Recommendation**: Start with default (10), increase gradually to 20 if needed.

---

### Scenario 4: Continuous Monitoring

**Goal**: Regular validation as part of monitoring workflow

**Setup Cron Job**:
```bash
# Edit crontab
crontab -e

# Run every 15 minutes
*/15 * * * * cd /path/to/slot-validate && hype run validate-nonces.lua >> /var/log/nonce-validation.log 2>&1

# Or run hourly at minute 0
0 * * * * cd /path/to/slot-validate && hype run validate-nonces.lua --only-mismatches >> /var/log/nonce-mismatches.log 2>&1
```

**Setup Systemd Timer**:
```bash
# /etc/systemd/system/nonce-validator.service
[Unit]
Description=Slot Nonce Validator
After=network.target

[Service]
Type=oneshot
WorkingDirectory=/path/to/slot-validate
ExecStart=/usr/local/bin/hype run validate-nonces.lua --only-mismatches
StandardOutput=append:/var/log/nonce-validation.log
StandardError=append:/var/log/nonce-validation.log

[Install]
WantedBy=multi-user.target
```

```bash
# /etc/systemd/system/nonce-validator.timer
[Unit]
Description=Run Nonce Validator Every 15 Minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=15min

[Install]
WantedBy=timers.target
```

```bash
# Enable and start
sudo systemctl enable nonce-validator.timer
sudo systemctl start nonce-validator.timer

# Check status
sudo systemctl status nonce-validator.timer
```

**Alert on Failures**:
```bash
#!/bin/bash
# validate-with-alert.sh

cd /path/to/slot-validate
hype run validate-nonces.lua --only-mismatches > /tmp/validation.txt

# Check exit code
if [ $? -ne 0 ]; then
    # Send alert (example: email)
    cat /tmp/validation.txt | mail -s "Nonce Validation Failed" admin@example.com
    
    # Or post to Slack
    curl -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\"Nonce validation detected mismatches\"}" \
      YOUR_SLACK_WEBHOOK_URL
fi
```

---

### Scenario 5: Debugging Connection Issues

**Goal**: Diagnose and resolve network/connectivity problems

**Steps**:

1. **Test Basic Connectivity**:
   ```bash
   # Test slot server
   curl -v https://state-2.forward.computer
   
   # Test router
   curl -v https://su-router.ao-testnet.xyz
   ```

2. **Check DNS Resolution**:
   ```bash
   # Resolve slot servers
   nslookup state-2.forward.computer
   nslookup push-5.forward.computer
   
   # Resolve router
   nslookup su-router.ao-testnet.xyz
   ```

3. **Test SSL/TLS**:
   ```bash
   # Check certificate
   openssl s_client -connect state-2.forward.computer:443 -servername state-2.forward.computer
   ```

4. **Run with Verbose Mode**:
   ```bash
   hype run validate-nonces.lua -- --verbose --concurrency=5
   ```

5. **Reduce Concurrency**:
   ```bash
   # Slower but more reliable
   hype run validate-nonces.lua -- --concurrency=3
   ```

**Common Issues and Solutions**:

| Error | Cause | Solution |
|-------|-------|----------|
| "Connection timeout" | Network latency | Reduce concurrency to 5 |
| "SSL certificate error" | Certificate validation | Update system certificates |
| "DNS resolution failed" | DNS server issue | Use `8.8.8.8` or `1.1.1.1` |
| "Too many open files" | File descriptor limit | Increase ulimit: `ulimit -n 4096` |

---

## Performance Tuning

### Understanding Bottlenecks

**Network Latency**:
```bash
# Measure round-trip time to servers
ping -c 5 state-2.forward.computer
```

**Server Response Time**:
```bash
# Measure actual request time
curl -w "@curl-format.txt" -o /dev/null -s \
  "https://state-2.forward.computer/test"

# curl-format.txt contents:
time_namelookup:  %{time_namelookup}s
time_connect:     %{time_connect}s
time_appconnect:  %{time_appconnect}s
time_pretransfer: %{time_pretransfer}s
time_starttransfer: %{time_starttransfer}s
time_total:       %{time_total}s
```

### Optimization Strategies

#### 1. Optimal Concurrency

**Formula**:
```
optimal = ceil(total_processes / target_seconds / avg_request_time)
```

**Example**:
- 130 processes
- Target: 15 seconds
- Avg request time: 0.2 seconds per request
- Optimal: `130 / 15 / 0.2 = 43` (cap at 30 for safety)

**Testing**:
```bash
# Binary search for optimal value
# Start with 10
hype run validate-nonces.lua -- --concurrency=10

# If fast and no errors, try 20
hype run validate-nonces.lua -- --concurrency=20

# If still good, try 30
hype run validate-nonces.lua -- --concurrency=30
```

#### 2. Network Optimization

**Use Local DNS Cache**:
```bash
# Install dnsmasq for DNS caching
sudo apt-get install dnsmasq  # Ubuntu/Debian
sudo systemctl enable dnsmasq
sudo systemctl start dnsmasq
```

**Optimize TCP Settings**:
```bash
# Increase connection tracking
sudo sysctl -w net.netfilter.nf_conntrack_max=131072

# Increase local port range
sudo sysctl -w net.ipv4.ip_local_port_range="1024 65535"

# Enable TCP fast open
sudo sysctl -w net.ipv4.tcp_fastopen=3
```

#### 3. System Resources

**Increase File Descriptors**:
```bash
# Temporary (current session)
ulimit -n 4096

# Permanent (add to /etc/security/limits.conf)
* soft nofile 4096
* hard nofile 8192
```

---

## Best Practices

### 1. Regular Validation Schedule

**Recommendation**: Run validation:
- **Every 15 minutes**: For critical production systems
- **Hourly**: For normal monitoring
- **Daily**: For periodic checks

### 2. Baseline Establishment

Always establish a baseline during low-activity periods:
```bash
# Run 3 times and compare
hype run validate-nonces.lua > baseline-1.txt
sleep 60
hype run validate-nonces.lua > baseline-2.txt
sleep 60
hype run validate-nonces.lua > baseline-3.txt

# Compare results
diff baseline-1.txt baseline-2.txt
```

### 3. Alert Thresholds

**Recommended Thresholds**:
- **Warning**: Mismatch rate > 5%
- **Critical**: Mismatch rate > 10%
- **Emergency**: Error rate > 20%

### 4. Logging Strategy

**Structured Logging**:
```bash
# Create log directory
mkdir -p /var/log/nonce-validator

# Run with timestamped output
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
hype run validate-nonces.lua > \
  /var/log/nonce-validator/validation-${TIMESTAMP}.log 2>&1
```

**Log Rotation**:
```bash
# /etc/logrotate.d/nonce-validator
/var/log/nonce-validator/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
}
```

### 5. Pre-Deployment Validation

Before deploying changes to slot servers:
```bash
# 1. Run baseline validation
hype run validate-nonces.lua > pre-deploy-baseline.txt

# 2. Deploy changes

# 3. Wait for propagation (5 minutes)
sleep 300

# 4. Run post-deployment validation
hype run validate-nonces.lua > post-deploy-validation.txt

# 5. Compare
diff pre-deploy-baseline.txt post-deploy-validation.txt
```

---

## FAQ

### General Questions

**Q: How long should validation take?**

A: For 130 processes with default settings (concurrency=10), expect 20-25 seconds. With concurrency=20, expect 15-18 seconds.

---

**Q: What's a "good" match rate?**

A: 
- 100%: Perfect (ideal)
- 95-99%: Excellent (normal for distributed systems)
- 90-95%: Acceptable (minor sync lag)
- < 90%: Investigate (potential issues)

---

**Q: Should I be concerned about small nonce differences?**

A: 
- Difference < 5: Normal, likely sync lag (wait 30s and retry)
- Difference 5-10: Monitor (may indicate slow sync)
- Difference > 10: Investigate (potential sync failure)

---

**Q: Can I run multiple validations in parallel?**

A: Not recommended. Run sequentially to avoid overwhelming servers and skewing results.

---

### Troubleshooting Questions

**Q: Why am I seeing connection timeouts?**

A:
1. Check network connectivity: `ping state-2.forward.computer`
2. Reduce concurrency: `--concurrency=5`
3. Check server status manually
4. Verify firewall rules

---

**Q: Why do mismatches persist after waiting?**

A: Possible causes:
- Synchronization system issue
- Process stopped receiving updates
- Server-router communication broken
- Check server logs and process status

---

**Q: What causes "Invalid JSON response" errors?**

A:
- Process doesn't exist on AO network
- Router returned error message instead of data
- Network corruption (rare)
- Use `--verbose` to see actual response

---

**Q: How do I validate a subset of processes?**

A: Create a smaller process map file:
```bash
# Extract first 10 processes
head -n 12 process-map.json > test-map.json
# (2 for {}, 10 for processes)

# Modify script to use test-map.json or:
cat test-map.json | hype run validate-nonces.lua
```

---

### Performance Questions

**Q: Why is validation slower than expected?**

A:
1. Check network latency: High latency increases total time
2. Server response times: Overloaded servers respond slowly
3. Concurrency too low: Increase `--concurrency`
4. System resources: Check CPU, memory, network bandwidth

---

**Q: What's the maximum safe concurrency level?**

A: Depends on:
- Network capacity: Higher bandwidth = higher concurrency
- Server capacity: Don't overwhelm slot servers
- Process count: More processes = can use more concurrency

**Safe values**:
- Conservative: 10
- Balanced: 15-20
- Aggressive: 25-30
- Maximum: 40-50 (not recommended)

---

**Q: Does verbose mode slow down validation?**

A: Minimal impact. Verbose mode adds logging but doesn't affect HTTP request parallelism. Expect < 5% slowdown.

---

### Advanced Questions

**Q: Can I customize timeout values?**

A: Currently, timeouts are hardcoded to 10 seconds. You can modify the script:
```lua
-- In HTTP request functions, change:
timeout = 10000  -- milliseconds
-- To:
timeout = 20000  -- 20 seconds
```

---

**Q: How do I integrate with monitoring systems?**

A: Use exit codes:
```bash
# Check exit code
hype run validate-nonces.lua
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "SUCCESS: All nonces match"
elif [ $EXIT_CODE -eq 1 ]; then
    echo "WARNING: Mismatches detected"
    # Send alert
elif [ $EXIT_CODE -eq 2 ]; then
    echo "ERROR: Validation errors occurred"
    # Send alert
fi
```

---

**Q: Can I validate processes from different networks?**

A: Yes, but modify `process-map.json` to include processes from any AO-compatible network. Router URL may need to be configurable.

---

**Q: How do I validate a single process?**

A: Create a minimal process map:
```bash
echo '{
  "4hXj_E-5fAKmo4E8KjgQvuDJKAFk9P2grhycVmISDLs": "https://state-2.forward.computer"
}' > single-process.json

# Modify script to use single-process.json
```

---

## Next Steps

1. **Read Architecture Documentation**: [ARCHITECTURE.md](ARCHITECTURE.md)
2. **Review API Details**: [api-endpoint-analysis.md](api-endpoint-analysis.md)
3. **Check Project Plan**: [PRPs/slot-nonce-validator-prp.md](PRPs/slot-nonce-validator-prp.md)

---

## Getting Help

If you encounter issues not covered in this guide:

1. Run with `--verbose` flag for detailed output
2. Check system logs for network errors
3. Verify server health manually with curl
4. Review [ARCHITECTURE.md](ARCHITECTURE.md) for technical details
5. Open an issue on the repository with:
   - Command run
   - Full output
   - System information (OS, Hype version)
   - Network details (if relevant)
