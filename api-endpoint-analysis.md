# API Endpoint Analysis Report

## Test Process
- **Process ID**: 4hXj_E-5fAKmo4E8KjgQvuDJKAFk9P2grhycVmISDLs
- **Slot Server**: https://state-2.forward.computer
- **Test Date**: 2025-10-12

---

## Endpoint 1: Slot Server Endpoint

### URL Format
```
https://state-2.forward.computer/{PROCESS_ID}~process@1.0/compute/at-slot
```

### Test URL
```
https://state-2.forward.computer/4hXj_E-5fAKmo4E8KjgQvuDJKAFk9P2grhycVmISDLs~process@1.0/compute/at-slot
```

### Response
**HTTP Status**: 200

**Content-Type**: text/plain

**Response Body**: Plain integer value
```
14204
```

### Analysis
- Returns a **single integer** representing the current slot/nonce number
- Simple, lightweight response (5 bytes)
- Direct GET request, no parameters required
- Returns the latest nonce value for the process

---

## Endpoint 2: Router Endpoint (SU Router)

### URL Format
```
https://su-router.ao-testnet.xyz/{PROCESS_ID}/latest
```

### Test URL
```
https://su-router.ao-testnet.xyz/4hXj_E-5fAKmo4E8KjgQvuDJKAFk9P2grhycVmISDLs/latest
```

### Behavior
1. **Initial Response**: HTTP 307 (Temporary Redirect)
   - Redirects to: `https://su201.ao-testnet.xyz/{PROCESS_ID}/latest`
   - Must follow redirect to get actual data

2. **Final Response** (after following redirect): HTTP 200

### Full JSON Response Structure

```json
{
  "message": {
    "id": "l-qcqLJY6CxT3hQnib4aBlt1o2jg6weYavMvC3GnyUU",
    "owner": {
      "address": "fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY",
      "key": "<long RSA key>"
    },
    "data": "<process-specific data>",
    "tags": [
      {"name": "Reference", "value": "1096"},
      {"name": "Action", "value": "Mint"},
      {"name": "Inflow-Type", "value": "FlpToken"},
      {"name": "Yield-Cycle-Nonce", "value": "169984"},
      {"name": "Data-Protocol", "value": "ao"},
      {"name": "Type", "value": "Message"},
      {"name": "Variant", "value": "ao.TN.1"},
      {"name": "From-Process", "value": "H1I09hGlSlqrvlQid4zBp-lleynE8bNo2Ep1u8xq0fQ"},
      {"name": "From-Module", "value": "oWF6Ijx2f3LsqXmGlMeNk7feMVIw6p8m9WbCXsRtEvM"},
      {"name": "Pushed-For", "value": "Y0eCtvu5l0VcpAFFmEE_O14LLYRd4zn3VBbgLAHGQiA"}
    ],
    "signature": "<signature>",
    "anchor": "00000000000000000000000000001096",
    "target": "4hXj_E-5fAKmo4E8KjgQvuDJKAFk9P2grhycVmISDLs"
  },
  "assignment": {
    "id": "1Eg4PeiCZ-H0YTb8uKjbV72udaBWEhnNzKsEM5q9PEg",
    "owner": {
      "address": "fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY",
      "key": "<long RSA key>"
    },
    "tags": [
      {"name": "Process", "value": "4hXj_E-5fAKmo4E8KjgQvuDJKAFk9P2grhycVmISDLs"},
      {"name": "Epoch", "value": "0"},
      {"name": "Nonce", "value": "14204"},
      {"name": "Hash-Chain", "value": "-W0NJGXV4Z_Ulrw8TnjOQjulmmutVx4dRYZgKH4RV7o"},
      {"name": "Block-Height", "value": "000001772658"},
      {"name": "Timestamp", "value": "1760288502319"},
      {"name": "Data-Protocol", "value": "ao"},
      {"name": "Type", "value": "Assignment"},
      {"name": "Variant", "value": "ao.TN.1"},
      {"name": "Message", "value": "l-qcqLJY6CxT3hQnib4aBlt1o2jg6weYavMvC3GnyUU"}
    ],
    "signature": "<signature>",
    "anchor": null,
    "target": ""
  }
}
```

---

## Nonce Field Locations

### Slot Server Endpoint
- **Location**: Direct response (root level)
- **Path**: N/A (entire response is the nonce)
- **Type**: Plain integer
- **Value**: `14204`

### Router Endpoint
- **Location**: Inside assignment.tags array
- **Path**: `assignment.tags[?(@.name=="Nonce")].value`
- **Type**: String (inside JSON)
- **Value**: `"14204"`

### Extraction Examples

**jq (for Router endpoint)**:
```bash
curl -L -s "https://su-router.ao-testnet.xyz/{PROCESS_ID}/latest" | \
  jq -r '.assignment.tags[] | select(.name == "Nonce") | .value'
```

**Slot Server** (already plain text):
```bash
curl -s "https://{SLOT_SERVER}/{PROCESS_ID}~process@1.0/compute/at-slot"
```

---

## Nonce Value Consistency

✅ **Both endpoints return the same nonce value**: `14204`

The nonce values are **identical** across both endpoints, confirming they refer to the same state/slot number for the process.

---

## Additional Fields in Router Response

The router endpoint provides much richer information beyond just the nonce:

1. **Message Information**:
   - Message ID
   - Owner address and public key
   - Data payload
   - Message tags (including action type, references, etc.)
   - Cryptographic signature
   - Anchor and target

2. **Assignment Information**:
   - Assignment ID
   - Process ID
   - Epoch number
   - **Nonce** ← Our target field
   - Hash-chain value
   - Block height
   - Timestamp
   - Message reference
   - Cryptographic signature

3. **Useful Metadata**:
   - `Block-Height`: "000001772658"
   - `Timestamp`: "1760288502319" (Unix timestamp in milliseconds)
   - `Epoch`: "0"
   - `Hash-Chain`: Chain state identifier

---

## Error Handling Considerations

### Slot Server Endpoint

**Success Case**:
- HTTP 200
- Returns plain integer

**Potential Errors**:
- HTTP 000 or connection timeout: Server unreachable
- HTTP 403: Forbidden (if POST is attempted)
- Empty response: Process may not exist or server error

### Router Endpoint

**Success Case**:
- HTTP 307 → HTTP 200 (after redirect)
- Returns JSON with message and assignment

**Error Cases Observed**:

1. **Process Not Found**:
   ```json
   {"error":"NotFound(\"Process scheduler not found\")"}
   ```
   - HTTP Status: 400
   - Occurs when process ID doesn't exist in router

2. **Redirect Required**:
   - HTTP 307
   - Must follow `Location` header to actual SU server
   - Tools should use `-L` flag or equivalent to auto-follow

---

## Performance & Size Comparison

| Endpoint | Response Size | Complexity | Overhead |
|----------|--------------|------------|----------|
| Slot Server | ~5 bytes | Minimal | None |
| Router | ~3.5 KB | High | Significant |

**Recommendation**: 
- Use **Slot Server** endpoint for nonce-only validation (200x smaller response)
- Use **Router** endpoint when additional metadata is needed

---

## Implementation Recommendations

### For Nonce Validation Only
```bash
# Fastest, most efficient
nonce=$(curl -s "$SLOT_SERVER/$PROCESS_ID~process@1.0/compute/at-slot")
```

### For Full State Information
```bash
# Includes metadata, block height, timestamp, etc.
response=$(curl -L -s "$ROUTER/$PROCESS_ID/latest")
nonce=$(echo "$response" | jq -r '.assignment.tags[] | select(.name == "Nonce") | .value')
```

### Error Handling Pattern
```bash
response=$(curl -s -w "\n%{http_code}" "$URL")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [ "$http_code" != "200" ]; then
  # Handle error
fi
```

---

## Summary

1. **Slot Server returns**: Plain integer nonce directly
2. **Router returns**: Rich JSON structure with nonce in `assignment.tags`
3. **Values are consistent**: Both return the same nonce (14204)
4. **Router requires redirect**: Must follow HTTP 307 to actual SU server
5. **Efficiency**: Slot server is ~200x more efficient for nonce-only queries
6. **Error handling**: Router provides structured errors; slot server may timeout or return empty

**Both endpoints are suitable for validation**, but the slot server endpoint is preferred for performance when only the nonce value is needed.
