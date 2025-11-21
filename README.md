# Slot Nonce Validator

High-performance CLI tool for validating nonce consistency between AO slot servers and the AO testnet router.

## Quick Start

```bash
# 1. Install Hype runtime
curl -fsSL https://raw.githubusercontent.com/twilson63/hype-rs/master/install.sh | sh

cd slot-validate
hype run validate-nonces.lua
```

## Usage

```bash
# Basic validation
hype run validate-nonces.lua

# Fast execution (20 concurrent requests)
hype run validate-nonces.lua -- --concurrency=20

# Show only mismatches
hype run validate-nonces.lua -- --only-mismatches

# With PagerDuty alerts
export PAGERDUTY_ROUTING_KEY="your-key"
hype run validate-nonces.lua -- --pagerduty-enabled
```

## CLI Options

| Option | Default | Description |
|--------|---------|-------------|
| `--file=PATH` | `process-map.json` | Process map JSON file |
| `--concurrency=N` | `10` | Concurrent requests (1-50) |
| `--verbose` | `false` | Detailed logging |
| `--only-mismatches` | `false` | Show only mismatches |
| `--pagerduty-enabled` | `false` | Enable PagerDuty alerts |
| `--pagerduty-key=KEY` | env var | PagerDuty routing key |

## Configuration

Create `process-map.json` with process-to-server mappings:

```json
{
  "4hXj_E-5fAKmo4E8KjgQvuDJKAFk9P2grhycVmISDLs": "https://state-2.forward.computer",
  "DM3FoZUq_yebASPhgd8pEIRIzDW6muXEhxz5-JwbZwo": "https://state-2.forward.computer"
}
```

## Automated Monitoring

```bash
# One-command setup for 5-minute interval validation
./scripts/setup-cron.sh

# Management
./scripts/manage-validator.sh status
./scripts/manage-validator.sh logs
./scripts/manage-validator.sh test
```

## Exit Codes

- `0` - All nonces match
- `1` - Mismatches detected
- `2` - Errors occurred
- `3` - Invalid configuration

## Documentation

- **[Architecture](docs/architecture.md)** - System design and data flow
- **[Usage Guide](docs/usage.md)** - Detailed usage scenarios
- **[API Reference](docs/api.md)** - Endpoint specifications
- **[Cron Setup](docs/cron-setup.md)** - Automated monitoring
- **[PagerDuty](docs/pagerduty.md)** - Alert integration
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues

## Project Structure

```
slot-validate/
├── validate-nonces.lua    # Main validation script
├── pagerduty.lua          # PagerDuty library
├── process-map.json       # Process mappings
├── scripts/               # Automation scripts
├── examples/              # Usage examples
├── docs/                  # Detailed documentation
```

## License

[Add license information]

## Support

See [Troubleshooting](docs/troubleshooting.md) or open an issue.
