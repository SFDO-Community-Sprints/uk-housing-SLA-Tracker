# AHA Easy Milestones — Installation

Quick copy-paste commands to get AHA Easy Milestones deployed to a Salesforce org.

---

## Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) installed
- Git installed
- Access to the target org with permission to deploy Apex and LWC

Verify your CLI:
```bash
sf --version
```

---

## Standard installation (existing org)

### 1. Clone the repository

```bash
git clone https://github.com/SFDO-Community-Sprints/uk-housing-easy-SLA.git
cd uk-housing-easy-SLA
```

### 2. Authenticate to your target org

```bash
sf org login web --alias my-org
```

Replace `my-org` with an alias of your choice.

### 3. Deploy

```bash
sf project deploy start --target-org my-org
```

Expected output: `Status: Succeeded` with 0 errors. Deploys 6 Apex classes, 1 LWC component, and 5 Custom Metadata Types.

### 4. Run the test suite

```bash
sf apex run test --target-org my-org --result-format human --wait 10
```

All 18 test methods across 3 test classes should pass. Do not proceed if any tests fail.

### 5. Open the org

```bash
sf org open --target-org my-org
```

---

## Next steps after deployment

**Before creating any live processes**, configure Business Hours so that milestone clocks skip weekends and public holidays. Without this the clock runs 24/7 with no warning.

1. **Configure Business Hours** — Setup > Business Hours > New. Set working days, hours, and timezone. Then go to Setup > Holidays and create your public/bank holidays, then associate them with the Business Hours record.

2. **Create your first Process** — Setup > Custom Metadata Types > AHA Easy Milestones Process > Manage Records > New.

3. **Add the component to a record page** — in Lightning App Builder, search for **AHA Easy Milestones** and drag it onto your record page.

See [README.md](README.md) for full configuration documentation.

---

## Scratch org (development / testing)

```bash
# Create a scratch org (7-day duration) from your Dev Hub
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --target-dev-hub <your-dev-hub-alias> \
  --alias aha-easy-milestones-scratch \
  --duration-days 7 \
  --set-default

# Deploy source
sf project deploy start --target-org aha-easy-milestones-scratch

# Run tests
sf apex run test \
  --target-org aha-easy-milestones-scratch \
  --result-format human \
  --wait 10

# Open the org
sf org open --target-org aha-easy-milestones-scratch
```
