# AHA Easy Milestones

A configuration-driven milestone tracking framework for Salesforce, built with Custom Metadata Types (CMDTs) and a Lightning Web Component (LWC). The framework enables teams to define, display, and manage time-based milestones against any Salesforce object record — without code changes.

---

##  Contributions
Huge thank you to **Mark Jones [Believe Housing]** for donating the solution to AHA. Further refinements and contributions welcome. If you discover any issues please let us know.

## Next Steps
- Markdown for installation / deployment using AI
- Templates for Easy Milestones, e.g. Awaab & Complaints
  
## Table of Contents

- [Overview](#overview)
- [How this differs from native Entitlement Milestones](#how-this-differs-from-native-entitlement-milestones)
- [Architecture](#architecture)
- [Business Hours and Holiday Setup](#business-hours-and-holiday-setup)
- [Installation](#installation)
  - [Prerequisites](#prerequisites)
  - [Deploying the Components](#deploying-the-components)
  - [Adding the LWC to a Record Page](#adding-the-lwc-to-a-record-page)
- [Custom Metadata Types Reference](#custom-metadata-types-reference)
- [Creating and Configuring Milestone Processes](#creating-and-configuring-milestone-processes)
  - [Step 1 — Create a Process](#step-1--create-a-process)
  - [Step 2 — Define Entry and Exit Criteria](#step-2--define-entry-and-exit-criteria)
  - [Step 3 — Create Process Milestones](#step-3--create-process-milestones)
  - [Step 4 — Add Milestone Validations (Optional)](#step-4--add-milestone-validations-optional)
  - [Step 5 — Configure Exit Field Updates](#step-5--configure-exit-field-updates)
- [Criteria and Validation JSON Reference](#criteria-and-validation-json-reference)
  - [Criteria JSON (Entry/Exit)](#criteria-json-entryexit)
  - [Validation Rule JSON](#validation-rule-json)
- [Maintaining Milestones](#maintaining-milestones)
  - [Activating and Deactivating Records](#activating-and-deactivating-records)
  - [Adjusting Time Targets](#adjusting-time-targets)
  - [Business Hours](#business-hours)
  - [Milestone Resets and Extensions](#milestone-resets-and-extensions)
- [LWC Configuration Properties](#lwc-configuration-properties)
- [Worked Examples](#worked-examples)
  - [Example 1: Case Working Milestone](#example-1-case-working-milestone)
  - [Example 2: Milestone with Custom Start/End Fields and Extensions](#example-2-milestone-with-custom-startend-fields-and-extensions)
- [Troubleshooting](#troubleshooting)

---

## Overview

AHA Easy Milestones is a metadata-driven framework that avoids hardcoded logic. All behaviour — which records are in scope, what milestones must be reached, when the clock starts, and what happens on completion — is controlled through Custom Metadata records that administrators can update without a code deployment.

The component renders on any Lightning Record Page and shows:
- Active milestones with a live countdown or overdue timer
- Milestone status indicators (Active, Completed, Overdue, Pending)
- A "Mark Completed" action (where enabled) that runs configurable field updates on the record

---

## How this differs from native Entitlement Milestones

Salesforce includes a native milestone capability as part of the Entitlements feature. AHA Easy Milestones is a different approach designed for teams that need milestone tracking beyond what native Entitlements supports, or without the associated licence requirements.

| Capability | Native Entitlement Milestones | AHA Easy Milestones |
|---|---|---|
| **Objects supported** | Case only | Any Salesforce object |
| **Licence requirement** | Requires Service Cloud / Entitlements licence | No additional licence required |
| **Configuration** | Entitlement Processes in Setup — requires admin knowledge of the Entitlements model | Custom Metadata records — no deployment needed for config changes |
| **Live countdown** | Not available out of the box | Built into the LWC, ticking in real time |
| **Weekend / holiday awareness** | Always enforced via Business Hours — required field | Available when a Business Hours ID is configured; falls back to 24/7 calendar time if not (see [Business Hours and Holiday Setup](#business-hours-and-holiday-setup)) |
| **Completion validation gates** | Not natively supported | Configurable field validation rules per milestone |
| **Field updates on completion** | Via Process Builder / Flow | Configured directly in CMDT records |
| **Reset / extension mechanisms** | Not available | Built in — field-driven clock resets and day extensions |
| **Escalation / notifications** | Native escalation actions built in | Not included — implement separately via Flow if needed |

### Weekend and holiday behaviour

Both native Entitlement Milestones and this framework use the same Salesforce platform methods — `BusinessHours.add()`, `BusinessHours.diff()`, and `BusinessHours.isWithin()` — when a Business Hours record is configured. This means deadline calculations and the live countdown both skip non-working periods automatically, including weekends and bank holidays associated with the Business Hours record.

A concrete example: a 5-day (2,400 minute at 8 hours/day) milestone starting on a Thursday at 3pm will have its deadline rolled forward through the weekend to the following Thursday. The live countdown will also freeze on Saturday and Sunday, resuming on Monday morning — exactly as native Entitlement Milestones behave.

The important distinction is the fallback. If no Business Hours ID is provided to this framework, the clock runs on pure calendar arithmetic — 24/7, including weekends and public holidays — with no warning that this is the case. Native Entitlement Milestones do not have this fallback; Business Hours is always required. **Admins installing this framework should configure Business Hours before creating any live processes.** See [Business Hours and Holiday Setup](#business-hours-and-holiday-setup).

---

## Architecture

| Layer | Component | Purpose |
|---|---|---|
| **LWC** | `ahaEasyMilestones` | Displays milestones and handles user interaction |
| **Apex Controller** | `AhaEasyMilestonesController` | Exposes `@AuraEnabled` methods to the LWC |
| **Apex Service** | `AhaEasyMilestonesService` | All business logic: process matching, milestone building, completions |
| **Apex DTOs** | `AhaEasyMilestonesDtos` | Data transfer objects passed between Apex and the LWC |
| **CMDT** | `AHA_EasyMilestones_Process__mdt` | Defines a milestone process for a target Salesforce object |
| **CMDT** | `AHA_EasyMilestones_Entry_Exit_Criteria__mdt` | JSON-based field conditions that control when a process is active |
| **CMDT** | `AHA_EasyMilestones_Process_Milestone__mdt` | Individual milestones within a process, with time targets |
| **CMDT** | `AHA_EasyMilestones_Milestone_Validation__mdt` | Field validation rules that must pass before manual completion |
| **CMDT** | `AHA_EasyMilestones_Exit_Field_Update__mdt` | Field updates applied to the record when a milestone is completed or the process exits |

---

## Business Hours and Holiday Setup

> **Configure this before going live.** Without a Business Hours ID, the framework uses 24/7 calendar time. A 5-day milestone starting on a Thursday will land on Tuesday — counting straight through the weekend — with no indication that working hours are not being applied.

### Step 1 — Create a Business Hours record

1. Go to **Setup > Business Hours**.
2. Click **New**.
3. Give it a meaningful name (e.g., `UK Standard Working Hours`).
4. Set the working days and hours (e.g., Monday–Friday, 09:00–17:00).
5. Set the **Time Zone** to match your team's location.
6. Click **Save**.

### Step 2 — Create Holiday records

Holidays are managed separately and then associated with a Business Hours record.

1. Go to **Setup > Holidays**.
2. Click **New** for each public or bank holiday.
3. Set the **Name**, **Date**, and whether it is a recurring annual holiday.
4. Save each record.

### Step 3 — Associate Holidays with Business Hours

1. Return to **Setup > Business Hours** and open your record.
2. In the **Holidays** related list, click **Add Holidays**.
3. Select the holidays to associate and save.

Associated holidays are automatically excluded from all deadline calculations and live countdown timers — the clock will not tick during those days.

### Step 4 — Find the Business Hours ID

1. Go to **Setup > Business Hours** and open your record.
2. Copy the 18-character ID from the browser URL.

### Step 5 — Apply the ID to your Process

Paste the 18-character ID into the **Business Hours ID** field on your `AHA_EasyMilestones_Process__mdt` record. To apply different hours to a specific milestone, paste the ID into **Business Hours ID Override** on the relevant `AHA_EasyMilestones_Process_Milestone__mdt` record instead — this overrides the process-level setting for that milestone only.

---

## Installation

For a quick copy-paste installation script, see [INSTALL.md](INSTALL.md).

### Prerequisites

- Salesforce CLI (`sf`) installed and authenticated
- API version 63.0 or later
- Permission to deploy Apex and LWC to the target org
- Access to Setup > Custom Metadata Types

### Deploying the Components

1. Clone the repository:
   ```bash
   git clone https://github.com/SFDO-Community-Sprints/uk-housing-easy-SLA.git
   cd uk-housing-easy-SLA
   ```

2. Authenticate to your target org:
   ```bash
   sf org login web --alias my-org
   ```

3. Deploy all components:
   ```bash
   sf project deploy start --target-org my-org
   ```

   The following components are deployed:

   | Component | Type |
   |---|---|
   | `AhaEasyMilestonesController` | Apex Class |
   | `AhaEasyMilestonesService` | Apex Class |
   | `AhaEasyMilestonesDtos` | Apex Class |
   | `AhaEasyMilestonesControllerTest` | Apex Test Class |
   | `AhaEasyMilestonesDtosTest` | Apex Test Class |
   | `AhaEasyMilestonesServiceTest` | Apex Test Class |
   | `ahaEasyMilestones` | Lightning Web Component |
   | `AHA_EasyMilestones_Process__mdt` | Custom Metadata Type |
   | `AHA_EasyMilestones_Entry_Exit_Criteria__mdt` | Custom Metadata Type |
   | `AHA_EasyMilestones_Process_Milestone__mdt` | Custom Metadata Type |
   | `AHA_EasyMilestones_Milestone_Validation__mdt` | Custom Metadata Type |
   | `AHA_EasyMilestones_Exit_Field_Update__mdt` | Custom Metadata Type |

4. Run the Apex tests to confirm a clean deployment:
   ```bash
   sf apex run test --target-org my-org --result-format human --wait 10
   ```
   All tests should pass before proceeding.

### Adding the LWC to a Record Page

The `ahaEasyMilestones` component is available on:
- `lightning__RecordPage` — scoped to **Case** and **WorkOrder** by default
- `lightning__AppPage` and `lightning__HomePage` (without object scoping)

To add it to a page:

1. Navigate to the relevant record (e.g., a Case record).
2. Click the **Setup** gear icon → **Edit Page** to open Lightning App Builder.
3. In the component panel, search for **AHA Easy Milestones**.
4. Drag the component onto the page at the desired position.
5. Configure the component properties in the right-hand panel (see [LWC Configuration Properties](#lwc-configuration-properties)).
6. Click **Save** and then **Activate** the page.

> **Extending to other objects:** To support additional objects beyond Case and WorkOrder, update the `<objects>` section in `force-app/main/default/lwc/ahaEasyMilestones/ahaEasyMilestones.js-meta.xml` and redeploy. Then add a corresponding `AHA_EasyMilestones_Process__mdt` record targeting that object's API name.

---

## Custom Metadata Types Reference

### AHA_EasyMilestones_Process__mdt — Process

The top-level record that links a milestone configuration to a Salesforce object.

| Field | API Name | Description |
|---|---|---|
| Label | `MasterLabel` | Display name of the process |
| Developer Name | `DeveloperName` | Unique API identifier |
| Target Object API Name | `Target_Object_API_Name__c` | API name of the Salesforce object (e.g., `Case`, `WorkOrder`) |
| Description | `Description__c` | Optional notes on the process |
| Active | `Active__c` | Must be `true` for the process to be evaluated |
| Business Hours ID | `Business_Hours_Id__c` | 18-character Salesforce Business Hours record ID. Applies to all milestones unless overridden. Leave blank to use 24/7 calendar time (not recommended for production) |

---

### AHA_EasyMilestones_Entry_Exit_Criteria__mdt — Entry/Exit Criteria

Defines the field conditions that determine whether a record enters or exits a process.

| Field | API Name | Description |
|---|---|---|
| Label | `MasterLabel` | Display name |
| Developer Name | `DeveloperName` | Unique API identifier |
| Process | `Process__c` | Lookup to `AHA_EasyMilestones_Process__mdt` |
| Criteria Context | `Criteria_Context__c` | Either `ENTRY` or `EXIT` |
| Criteria JSON | `Criteria_JSON__c` | JSON rule evaluated against record fields (see [Criteria JSON Reference](#criteria-json-entryexit)) |
| Sequence | `Sequence__c` | Evaluation order; lower numbers evaluated first |
| Description | `Description__c` | Optional notes |
| Active | `Active__c` | Must be `true` to be evaluated |

---

### AHA_EasyMilestones_Process_Milestone__mdt — Process Milestone

Defines an individual milestone step within a process.

| Field | API Name | Description |
|---|---|---|
| Label | `MasterLabel` | Display name shown in the panel |
| Developer Name | `DeveloperName` | Unique API identifier |
| Process | `Process__c` | Lookup to the parent `AHA_EasyMilestones_Process__mdt` |
| Time Trigger (Minutes) | `Time_Trigger_Minutes__c` | Time allowed for this milestone, in minutes |
| Start Field API Name | `Start_Field_API_Name__c` | Field on the record used as the clock start; falls back to `CreatedDate` if blank |
| Reset Enabled | `Reset_Enabled__c` | If `true`, the milestone clock can be reset by a field value |
| Reset Field API Name | `Reset_Field_API_Name__c` | Field whose populated value restarts the milestone clock |
| Extension Enabled | `Extension_Enabled__c` | If `true`, extra time can be added from a numeric field |
| Extension Field API Name | `Extension_Field_API_Name__c` | Numeric field representing extension days (1 day = 480 minutes) |
| Manual Completion Enabled | `Manual_Completion_Enabled__c` | If `true`, users can click "Mark Completed" on the panel |
| Business Hours ID Override | `Business_Hours_Id_Override__c` | Overrides the process-level Business Hours ID for this milestone only |
| Sequence | `Sequence__c` | Display order within the process |
| Description | `Description__c` | Optional description shown below the milestone label |
| Active | `Active__c` | Must be `true` to appear |

---

### AHA_EasyMilestones_Milestone_Validation__mdt — Milestone Validation

Defines field conditions that must be satisfied before a user can manually complete a milestone.

| Field | API Name | Description |
|---|---|---|
| Label | `MasterLabel` | Display name |
| Developer Name | `DeveloperName` | Unique API identifier |
| Process Milestone | `Process_Milestone__c` | Lookup to the parent `AHA_EasyMilestones_Process_Milestone__mdt` |
| Field API Name | `Field_API_Name__c` | The record field to validate |
| Validation Rule JSON | `Validation_Rule_JSON__c` | JSON rule defining the validation (see [Validation Rule JSON](#validation-rule-json)) |
| Error Message | `Error_Message__c` | Custom message shown to the user if validation fails |
| Sequence | `Sequence__c` | Evaluation order |
| Description | `Description__c` | Internal notes |
| Active | `Active__c` | Must be `true` to be evaluated |

---

### AHA_EasyMilestones_Exit_Field_Update__mdt — Exit Field Update

Defines field writes applied to the record when a milestone is manually completed (`MILESTONE_COMPLETE`) or when the process reaches its exit criteria (`PROCESS_EXIT`).

| Field | API Name | Description |
|---|---|---|
| Label | `MasterLabel` | Display name |
| Developer Name | `DeveloperName` | Unique API identifier |
| Process | `Process__c` | Lookup to `AHA_EasyMilestones_Process__mdt` |
| Process Milestone | `Process_Milestone__c` | Lookup to the relevant `AHA_EasyMilestones_Process_Milestone__mdt` |
| Update Context | `Update_Context__c` | Either `MILESTONE_COMPLETE` or `PROCESS_EXIT` |
| Field API Name | `Field_API_Name__c` | The record field to update |
| Update Type | `Update_Type__c` | The type of update: `NOW`, `TRUE`, `FALSE`, `NULL`, `STATIC`, or `COPY_FIELD` |
| Update Value | `Update_Value__c` | Used with `STATIC` (literal value) and `COPY_FIELD` (source field API name) |
| Sequence | `Sequence__c` | Execution order |
| Description | `Description__c` | Internal notes |
| Active | `Active__c` | Must be `true` to be applied |

**Update Type values:**

| Update Type | Behaviour |
|---|---|
| `NOW` | Sets the field to the current `Datetime` |
| `TRUE` | Sets a Boolean field to `true` |
| `FALSE` | Sets a Boolean field to `false` |
| `NULL` | Clears the field value |
| `STATIC` | Sets the field to the literal value in `Update_Value__c` |
| `COPY_FIELD` | Copies the value from the field named in `Update_Value__c` |

> **How completion is detected:** The service considers a milestone complete only when every `MILESTONE_COMPLETE` exit update for that milestone matches the current field value on the record. Exit Field Updates therefore serve double duty — they both _write_ on completion and _signal_ completeness on subsequent page loads.

---

## Creating and Configuring Milestone Processes

### Step 1 — Create a Process

1. Go to **Setup > Custom Metadata Types**.
2. Find **AHA Easy Milestones Process** and click **Manage Records**.
3. Click **New** and fill in:
   - **Label** and **Developer Name** (auto-filled from Label)
   - **Target Object API Name**: the exact API name of the Salesforce object (e.g., `Case`)
   - **Active**: check this box
   - **Business Hours ID**: paste the 18-character ID of a Business Hours record so that milestones respect working hours and holidays (see [Business Hours and Holiday Setup](#business-hours-and-holiday-setup))
4. Save the record.

---

### Step 2 — Define Entry and Exit Criteria

Entry criteria determine when a record enters the process. Exit criteria determine when the process is considered complete.

1. Go to **AHA Easy Milestones Entry Exit Criteria** and click **Manage Records > New**.
2. Set **Process** to the process created in Step 1.
3. Set **Criteria Context** to `ENTRY` or `EXIT`.
4. Write the **Criteria JSON** (see [Criteria JSON Reference](#criteria-json-entryexit)).
5. Set **Sequence** (lower = evaluated first; the first matching criteria record wins).
6. Check **Active**.

> **No entry criteria defined:** If no `ENTRY` criteria records exist for a process, the process matches all records for that object.
>
> **No exit criteria defined:** If no `EXIT` criteria records exist, the process never auto-exits.

---

### Step 3 — Create Process Milestones

Each milestone represents one step with a time target.

1. Go to **AHA Easy Milestones Process Milestone** and click **Manage Records > New**.
2. Set **Process** to link it to the parent process.
3. Fill in the required fields:
   - **Label**: the name displayed in the panel (e.g., `Initial Response`)
   - **Time Trigger (Minutes)**: the total allowed time (e.g., `2400` for 5 working days at 8 hours/day)
   - **Start Field API Name**: the field that starts the clock (leave blank to use `CreatedDate`)
   - **Sequence**: controls display order
4. Configure optional features:
   - Enable **Manual Completion** if users should be able to mark it done from the panel
   - Enable **Reset** and provide a **Reset Field API Name** if the clock should restart when that field is populated
   - Enable **Extension** and provide an **Extension Field API Name** (numeric, in days) if extra time can be granted
5. Check **Active** and save.

---

### Step 4 — Add Milestone Validations (Optional)

Validations prevent users from marking a milestone complete until certain conditions are met.

1. Go to **AHA Easy Milestones Milestone Validation** and click **Manage Records > New**.
2. Set **Process Milestone** to the target milestone.
3. Enter the **Field API Name** to validate.
4. Enter the **Validation Rule JSON** (see [Validation Rule JSON](#validation-rule-json)).
5. Optionally provide a friendly **Error Message**.
6. Set **Sequence** and check **Active**.

Multiple validations can be added to a single milestone; all must pass for completion to proceed.

---

### Step 5 — Configure Exit Field Updates

Exit Field Updates write values to the record when a milestone is completed (or the process exits). They also act as the completion signal — the service checks these field values on every load to determine whether a milestone is already complete.

1. Go to **AHA Easy Milestones Exit Field Update** and click **Manage Records > New**.
2. Set:
   - **Process** (required)
   - **Process Milestone**: the milestone this update belongs to
   - **Update Context**: `MILESTONE_COMPLETE` or `PROCESS_EXIT`
3. Fill in **Field API Name**, **Update Type**, and (if applicable) **Update Value**.
4. Set **Sequence** and check **Active**.

---

## Criteria and Validation JSON Reference

### Criteria JSON (Entry/Exit)

The `Criteria_JSON__c` field accepts JSON evaluated against the record's field values. Single conditions, AND/OR groups, and nested logic are all supported.

**Single condition:**
```json
{
  "field": "Status",
  "operator": "EQUALS",
  "value": "Working"
}
```

**Check a field is populated:**
```json
{
  "field": "SLA_Test_Start__c",
  "operator": "REQUIRED"
}
```

**AND group:**
```json
{
  "logic": "AND",
  "conditions": [
    { "field": "Status", "operator": "EQUALS", "value": "Working" },
    { "field": "Priority", "operator": "EQUALS", "value": "High" }
  ]
}
```

**OR group:**
```json
{
  "logic": "OR",
  "conditions": [
    { "field": "Status", "operator": "EQUALS", "value": "New" },
    { "field": "Status", "operator": "EQUALS", "value": "Working" }
  ]
}
```

**Supported operators:**

| Operator | Behaviour |
|---|---|
| `EQUALS` | Field value matches the given value |
| `NOT_EQUALS` | Field value does not match |
| `REQUIRED` | Field is not blank or null |
| `TRUE` | Boolean field is `true` |
| `FALSE` | Boolean field is `false` |
| `GREATER_THAN` | Numeric field is greater than value |
| `LESS_THAN` | Numeric field is less than value |

---

### Validation Rule JSON

Single-rule format used in `Validation_Rule_JSON__c`. The field being validated is provided separately in `Field_API_Name__c` — not inside the JSON.

```json
{ "type": "REQUIRED" }
```

```json
{ "type": "TRUE" }
```

```json
{ "type": "EQUALS", "value": "Approved" }
```

```json
{ "type": "NOT_EQUALS", "value": "Cancelled" }
```

The `type` key maps to the same operator names as the criteria JSON.

---

## Maintaining Milestones

### Activating and Deactivating Records

Every CMDT record has an **Active** checkbox. Unchecking it instantly removes it from evaluation without deletion. No deployment is required — changes take effect immediately. This is the recommended approach for temporarily suspending a process, disabling a milestone, or toggling a validation rule.

---

### Adjusting Time Targets

1. Go to **AHA Easy Milestones Process Milestone** in Custom Metadata Types.
2. Open the relevant milestone record.
3. Update **Time Trigger (Minutes)**.
4. Save.

Changes apply to all records where the milestone has not yet been completed. Completed milestones are unaffected — completion is determined by the current field values on the record, not by re-evaluating the time target.

---

### Business Hours

Business Hours determine when the milestone clock runs and directly affect deadline calculation, remaining time, and the live countdown.

- **Process-level:** Set `Business_Hours_Id__c` on `AHA_EasyMilestones_Process__mdt`. All milestones in the process inherit this.
- **Milestone-level override:** Set `Business_Hours_Id_Override__c` on `AHA_EasyMilestones_Process_Milestone__mdt` to apply different hours to a specific milestone.

When a Business Hours ID is configured, the framework calls `BusinessHours.add()` to calculate target deadlines and `BusinessHours.diff()` to measure remaining time. Non-working periods — weekends and any holidays associated with the Business Hours record — are automatically excluded from both calculations. A 5-day milestone starting on a Thursday afternoon will have its deadline rolled to the following week, with the weekend skipped entirely. The live countdown freezes during non-working periods via `BusinessHours.isWithin()`.

> **If no Business Hours ID is set:** the framework falls back to `startDateTime.addMinutes(totalMinutes)` — pure calendar arithmetic, running 24/7 including weekends and public holidays. There is no warning when this fallback is active. See [Business Hours and Holiday Setup](#business-hours-and-holiday-setup).

---

### Milestone Resets and Extensions

**Resets** restart the milestone clock from a later datetime — useful where a step may be paused and restarted (e.g., awaiting a customer response).

- Enable **Reset Enabled** on the milestone.
- Set **Reset Field API Name** to a `Datetime` field on the object.
- When that field is populated with a value later than the original start time, the clock restarts from that date.

**Extensions** add extra time to a milestone's target — useful for agreed exceptions.

- Enable **Extension Enabled** on the milestone.
- Set **Extension Field API Name** to a numeric field representing additional business days.
- The service converts days to minutes at 480 minutes per business day.

---

## LWC Configuration Properties

These properties are set in Lightning App Builder when placing the component on a page:

| Property | Label | Default | Description |
|---|---|---|---|
| `cardTitle` | Card Title | `SLA Milestones` | Text shown in the panel header |
| `cardIconName` | SLDS Icon Name | `standard:entitlement_policy` | SLDS icon identifier for the header |
| `iconBackgroundColor` | Icon Background Color | `#2e844a` | Hex colour for the icon background |
| `iconColor` | Icon Color | `#ffffff` | Hex colour for the icon itself |
| `completionActionStyle` | Completion Action Style | `link` | `link` or `button` — controls the appearance of the Mark Completed action |

---

## Worked Examples

### Example 1: Case Working Milestone

**Scenario:** Track a 5-day (2,400 minute at 8 hours/day) milestone for Cases in `Working` status, respecting UK working hours. Close the case when the milestone is completed.

**Process (`AHA_EasyMilestones_Process__mdt`):**
- Label: `Case Working Milestone`
- Target Object API Name: `Case`
- Active: `true`
- Business Hours ID: `<your 18-character Business Hours record ID>`

**Entry Criteria (`AHA_EasyMilestones_Entry_Exit_Criteria__mdt`):**
- Process: `Case Working Milestone`
- Criteria Context: `ENTRY`
- Criteria JSON:
  ```json
  { "field": "Status", "operator": "EQUALS", "value": "Working" }
  ```

**Milestone (`AHA_EasyMilestones_Process_Milestone__mdt`):**
- Label: `Complete in Five Days`
- Process: `Case Working Milestone`
- Time Trigger (Minutes): `2400`
- Start Field API Name: *(blank — uses `CreatedDate`)*
- Manual Completion Enabled: `true`
- Sequence: `1`

**Exit Field Update (`AHA_EasyMilestones_Exit_Field_Update__mdt`):**
- Process Milestone: `Complete in Five Days`
- Update Context: `MILESTONE_COMPLETE`
- Field API Name: `Status`
- Update Type: `STATIC`
- Update Value: `Closed`

When a user clicks Mark Completed, the Case `Status` is set to `Closed`. On subsequent page loads the service detects `Status = Closed` and shows the milestone as Completed.

---

### Example 2: Milestone with Custom Start/End Fields and Extensions

**Scenario:** Track a milestone based on a custom `SLA_Test_Start__c` field, allow resets via `SLA_Test_Reset__c`, allow extensions via `SLA_Test_Extension_Days__c`, require a checkbox before completion, and stamp a completion datetime into `SLA_Test_End__c`.

**Entry Criteria:**
```json
{ "field": "SLA_Test_Start__c", "operator": "REQUIRED" }
```

**Milestone configuration:**
- Time Trigger (Minutes): `2400` (5 working days)
- Start Field API Name: `SLA_Test_Start__c`
- Reset Enabled: `true`, Reset Field API Name: `SLA_Test_Reset__c`
- Extension Enabled: `true`, Extension Field API Name: `SLA_Test_Extension_Days__c`
- Manual Completion Enabled: `true`

**Milestone Validation:**
- Field API Name: `SLA_Ready_to_Complete__c`
- Validation Rule JSON: `{ "type": "TRUE" }`
- Error Message: `Tick SLA Ready to Complete before marking this milestone complete.`

**Exit Field Update:**
- Field API Name: `SLA_Test_End__c`
- Update Type: `NOW`

On completion, the current datetime is stamped into `SLA_Test_End__c`. On subsequent loads the service checks whether `SLA_Test_End__c` is populated and displays the milestone as Completed.

---

## Troubleshooting

**The panel shows "No active SLA Process configuration found for this record."**
- Confirm at least one `AHA_EasyMilestones_Process__mdt` record exists with `Active = true` and `Target_Object_API_Name__c` matching the object exactly (case-sensitive).

**The panel shows "There are no current active SLA's against this record."**
- Entry criteria are defined but the record does not match. Check `Criteria_JSON__c` on the Entry criteria records and verify field values on the record match the expected conditions.

**The panel shows "The record meets SLA exit criteria."**
- Exit criteria are satisfied. If unexpected, review the Exit criteria `Criteria_JSON__c` for the process.

**A milestone shows "Awaiting start" indefinitely.**
- `Start_Field_API_Name__c` is blank or the referenced field on the record is empty. Either populate the field or clear `Start_Field_API_Name__c` to fall back to `CreatedDate`.

**"Mark Completed" is not visible on a milestone.**
- `Manual_Completion_Enabled__c` must be `true` on the milestone.
- The milestone must not already be in a Completed status.

**A validation error appears when clicking Mark Completed.**
- An `AHA_EasyMilestones_Milestone_Validation__mdt` record linked to the milestone is failing. Check the `Error_Message__c` for guidance, resolve the field condition on the record, and try again.

**The milestone clock is counting through weekends / public holidays.**
- No Business Hours ID is set. The framework falls back to 24/7 calendar time when no ID is configured. Paste an 18-character Business Hours record ID into `Business_Hours_Id__c` on the Process record (see [Business Hours and Holiday Setup](#business-hours-and-holiday-setup)).
- If a Business Hours ID is set but holidays are not being excluded, confirm the relevant Holiday records have been associated with the Business Hours record in Setup.

**Business hours appear to be configured but deadlines still seem wrong.**
- Verify the ID is 18 characters. Go to **Setup > Business Hours**, open the record, and copy the full ID from the URL.
- Confirm the Business Hours record is **Active** and covers the correct timezone.

**Fields referenced in CMDT are not loading on the record.**
- The service dynamically queries only fields referenced across all active CMDT records. Verify the field's API name is spelled correctly and exists on the target object.
