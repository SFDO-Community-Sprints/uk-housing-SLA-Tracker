# UK Housing SLA Tracker

A configuration-driven SLA Milestone tracking solution for Salesforce, built with Custom Metadata Types (CMDTs) and a Lightning Web Component (LWC). The tracker enables teams to define, display, and manage SLA milestones against any Salesforce object record — without code changes.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Installation](#installation)
  - [Prerequisites](#prerequisites)
  - [Deploying the Components](#deploying-the-components)
  - [Adding the LWC to a Record Page](#adding-the-lwc-to-a-record-page)
- [Custom Metadata Types Reference](#custom-metadata-types-reference)
- [Creating and Configuring SLA Processes](#creating-and-configuring-sla-processes)
  - [Step 1 — Create an SLA Process](#step-1--create-an-sla-process)
  - [Step 2 — Define Entry and Exit Criteria](#step-2--define-entry-and-exit-criteria)
  - [Step 3 — Create SLA Process Milestones](#step-3--create-sla-process-milestones)
  - [Step 4 — Add Milestone Validations (Optional)](#step-4--add-milestone-validations-optional)
  - [Step 5 — Configure Exit Field Updates](#step-5--configure-exit-field-updates)
- [Criteria and Validation JSON Reference](#criteria-and-validation-json-reference)
  - [Criteria JSON (Entry/Exit)](#criteria-json-entryexit)
  - [Validation Rule JSON](#validation-rule-json)
- [Maintaining SLA Milestones](#maintaining-sla-milestones)
  - [Activating and Deactivating Records](#activating-and-deactivating-records)
  - [Adjusting Time Targets](#adjusting-time-targets)
  - [Business Hours](#business-hours)
  - [Milestone Resets and Extensions](#milestone-resets-and-extensions)
- [LWC Configuration Properties](#lwc-configuration-properties)
- [Worked Examples](#worked-examples)
  - [Example 1: Case Working SLA](#example-1-case-working-sla)
  - [Example 2: SLA with Custom Start/End Fields and Extensions](#example-2-sla-with-custom-startend-fields-and-extensions)
- [Troubleshooting](#troubleshooting)

---

## Overview

The SLA Tracker is a metadata-driven framework that avoids hardcoded logic. All SLA behaviour — which records are in scope, what milestones must be reached, when the clock starts, and what happens on completion — is controlled through Custom Metadata records that administrators can update without a code deployment.

The component renders on any Lightning Record Page and shows:
- Active milestones with a live countdown or overdue timer
- Milestone status indicators (Active, Completed, Overdue, Pending)
- A "Mark Completed" action (where enabled) that runs configurable field updates on the record

---

## Architecture

The solution is composed of the following parts:

| Layer | Component | Purpose |
|---|---|---|
| **LWC** | `slaTrackerPanel` | Displays milestones and handles user interaction |
| **Apex Controller** | `SlaMilestoneController` | Exposes `@AuraEnabled` methods to the LWC |
| **Apex Service** | `SlaMilestoneService` | All business logic: process matching, milestone building, completions |
| **Apex DTOs** | `SlaMilestoneDtos` | Data transfer objects passed between Apex and the LWC |
| **CMDT** | `SLA_Process__mdt` | Defines an SLA Process for a target Salesforce object |
| **CMDT** | `SLA_Entry_Exit_Criteria__mdt` | JSON-based field conditions that control when a process is active |
| **CMDT** | `SLA_Process_Milestone__mdt` | Individual milestones within a process, with time targets |
| **CMDT** | `SLA_Milestone_Validation__mdt` | Field validation rules that must pass before manual completion |
| **CMDT** | `SLA_Exit_Field_Update__mdt` | Field updates applied to the record when a milestone is completed or the process exits |

---

## Installation

### Prerequisites

Before deploying, ensure you have:

- Salesforce CLI (`sf` or `sfdx`) installed and authenticated to your target org
- API version 63.0 or later
- Appropriate permissions to deploy Apex classes and LWC components
- Access to Setup > Custom Metadata Types to create and edit CMDT records

### Deploying the Components

1. Clone or download the repository to your local machine.

2. Authenticate to your Salesforce org:
   ```bash
   sf org login web --alias my-org
   ```

3. Deploy all components from the project root:
   ```bash
   sf project deploy start --source-dir . --target-org my-org
   ```

   The following files will be deployed:

   | File | Type |
   |---|---|
   | `SlaMilestoneController.apxc` | Apex Class |
   | `SlaMilestoneService.cls` | Apex Class |
   | `SlaMilestoneDtos.apxc` | Apex Class |
   | `SlaMilestoneControllerTest.apxc` | Apex Test Class |
   | `SlaMilestoneDtosTest.apxc` | Apex Test Class |
   | `SlaMilestoneServiceTest.apxc` | Apex Test Class |
   | `slaTrackerPanel` (html/js/css/meta) | Lightning Web Component |

4. Run the Apex tests to confirm a successful deployment:
   ```bash
   sf apex run test --target-org my-org --result-format human --wait 10
   ```
   All tests should pass before proceeding.

5. Optionally, load the sample CMDT records from the provided CSV files. These can be imported via **Setup > Custom Metadata Types > [Type Name] > Manage Records > Import**. The files are:
   - `SLA_Process__mdt.csv`
   - `SLA_Entry_Exit_Criteria__mdt.csv`
   - `SLA_Process_Milestone__mdt.csv`
   - `SLA_Milestone_Validation__mdt.csv`
   - `SLA_Exit_Field_Update__mdt.csv`

### Adding the LWC to a Record Page

The `slaTrackerPanel` component is configured to be available on:
- `lightning__RecordPage` — scoped to **Case** and **WorkOrder** by default
- `lightning__AppPage` and `lightning__HomePage` (without object scoping)

To add it to a page:

1. Navigate to the relevant record (e.g., a Case record).
2. Click the **Setup** gear icon → **Edit Page** to open Lightning App Builder.
3. In the component panel, search for **SLA Milestone Panel**.
4. Drag the component onto the page at the desired position.
5. Configure the component properties in the right-hand panel (see [LWC Configuration Properties](#lwc-configuration-properties)).
6. Click **Save** and then **Activate** the page.

> **Extending to other objects:** To support additional objects beyond Case and WorkOrder, update the `<objects>` section in `slaTrackerPanel.js-meta.xml` and redeploy, then add a corresponding `SLA_Process__mdt` record targeting that object's API name.

---

## Custom Metadata Types Reference

### SLA_Process__mdt — SLA Process

The top-level record that links an SLA configuration to a Salesforce object.

| Field | API Name | Description |
|---|---|---|
| Label | `MasterLabel` | Display name of the process |
| Developer Name | `DeveloperName` | Unique API identifier |
| Target Object API Name | `Target_Object_API_Name__c` | API name of the Salesforce object (e.g., `Case`, `WorkOrder`) |
| Description | `Description__c` | Optional notes on the process |
| Active | `Active__c` | Must be `true` for the process to be evaluated |
| Business Hours ID | `Business_Hours_Id__c` | Salesforce Business Hours record ID; applies to all milestones in this process unless overridden |

---

### SLA_Entry_Exit_Criteria__mdt — Entry/Exit Criteria

Defines the field conditions that determine whether a record enters or exits an SLA Process.

| Field | API Name | Description |
|---|---|---|
| Label | `MasterLabel` | Display name |
| Developer Name | `DeveloperName` | Unique API identifier |
| SLA Process | `SLA_Process__c` | Lookup to `SLA_Process__mdt` |
| Criteria Context | `Criteria_Context__c` | Either `ENTRY` or `EXIT` |
| Criteria JSON | `Criteria_JSON__c` | JSON rule evaluated against record fields (see [Criteria JSON Reference](#criteria-json-entryexit)) |
| Sequence | `Sequence__c` | Evaluation order; lower numbers are evaluated first |
| Description | `Description__c` | Optional notes |
| Active | `Active__c` | Must be `true` to be evaluated |

---

### SLA_Process_Milestone__mdt — SLA Process Milestone

Defines an individual milestone step within a process.

| Field | API Name | Description |
|---|---|---|
| Label | `MasterLabel` | Display name shown in the panel |
| Developer Name | `DeveloperName` | Unique API identifier |
| SLA Process | `SLA_Process__c` | Lookup to the parent `SLA_Process__mdt` |
| Time Trigger (Minutes) | `Time_Trigger_Minutes__c` | Time allowed for this milestone, in minutes |
| Start Field API Name | `Start_Field_API_Name__c` | Field on the record used as the clock start; falls back to `CreatedDate` if blank |
| Reset Enabled | `Reset_Enabled__c` | If `true`, the milestone clock can be reset by a field value |
| Reset Field API Name | `Reset_Field_API_Name__c` | Field whose populated value restarts the milestone clock |
| Extension Enabled | `Extension_Enabled__c` | If `true`, extra time can be added from a numeric field |
| Extension Field API Name | `Extension_Field_API_Name__c` | Numeric field on the record representing extension days (1 day = 480 minutes) |
| Manual Completion Enabled | `Manual_Completion_Enabled__c` | If `true`, users can click "Mark Completed" on the panel |
| Business Hours ID Override | `Business_Hours_Id_Override__c` | Overrides the process-level Business Hours ID for this milestone only |
| Sequence | `Sequence__c` | Display order within the process |
| Description | `Description__c` | Optional description shown in the panel below the milestone label |
| Active | `Active__c` | Must be `true` to appear |

---

### SLA_Milestone_Validation__mdt — Milestone Validation

Defines field conditions that must be satisfied before a user can manually complete a milestone.

| Field | API Name | Description |
|---|---|---|
| Label | `MasterLabel` | Display name |
| Developer Name | `DeveloperName` | Unique API identifier |
| SLA Process Milestone | `SLA_Process_Milestone__c` | Lookup to the parent `SLA_Process_Milestone__mdt` |
| Field API Name | `Field_API_Name__c` | The record field to validate |
| Validation Rule JSON | `Validation_Rule_JSON__c` | JSON rule defining the validation (see [Validation Rule JSON](#validation-rule-json)) |
| Error Message | `Error_Message__c` | Custom message shown to the user if the validation fails |
| Sequence | `Sequence__c` | Evaluation order |
| Description | `Description__c` | Internal notes |
| Active | `Active__c` | Must be `true` to be evaluated |

---

### SLA_Exit_Field_Update__mdt — Exit Field Update

Defines field writes applied to the record when a milestone is manually completed (`MILESTONE_COMPLETE`) or when the process reaches its exit criteria (`PROCESS_EXIT`).

| Field | API Name | Description |
|---|---|---|
| Label | `MasterLabel` | Display name |
| Developer Name | `DeveloperName` | Unique API identifier |
| SLA Process | `SLA_Process__c` | Lookup to `SLA_Process__mdt` |
| SLA Process Milestone | `SLA_Process_Milestone__c` | Lookup to the relevant `SLA_Process_Milestone__mdt` |
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

> **How completion is detected:** The service considers a milestone complete only when every `MILESTONE_COMPLETE` exit update for that milestone matches the current field value on the record. This means Exit Field Updates serve double duty — they both _write_ on completion and _signal_ completeness on subsequent loads.

---

## Creating and Configuring SLA Processes

### Step 1 — Create an SLA Process

1. Go to **Setup > Custom Metadata Types**.
2. Find **SLA Process** and click **Manage Records**.
3. Click **New** and fill in:
   - **Label** and **Developer Name** (auto-filled from Label)
   - **Target Object API Name**: the exact API name of the Salesforce object (e.g., `Case`)
   - **Active**: check this box
   - **Business Hours ID**: optional; paste the 15 or 18-character ID of a Business Hours record if milestones should use business time

4. Save the record.

---

### Step 2 — Define Entry and Exit Criteria

Entry criteria determine when a record "enters" the SLA (i.e., the process becomes active for that record). Exit criteria determine when the process is considered complete.

1. Go to **SLA Entry Exit Criteria** in Custom Metadata Types and click **Manage Records > New**.
2. Set **SLA Process** to the process created in Step 1.
3. Set **Criteria Context** to `ENTRY` or `EXIT`.
4. Write the **Criteria JSON** defining the field conditions (see [Criteria JSON Reference](#criteria-json-entryexit)).
5. Set **Sequence** (lower = evaluated first; the first matching criteria record wins).
6. Check **Active**.

> **No entry criteria defined:** If no `ENTRY` criteria records exist for a process, the process is considered to match all records for that object.
>
> **No exit criteria defined:** If no `EXIT` criteria records exist, the process never auto-exits (useful when milestones alone define closure).

---

### Step 3 — Create SLA Process Milestones

Each milestone represents one step in the SLA with a time target.

1. Go to **SLA Process Milestone** and click **Manage Records > New**.
2. Set **SLA Process** to link it to the parent process.
3. Fill in the required fields:
   - **Label**: the name displayed in the panel (e.g., "Initial Response")
   - **Time Trigger (Minutes)**: the total allowed time in minutes (e.g., `480` for 8 hours)
   - **Start Field API Name**: the field that starts the clock (leave blank to use `CreatedDate`)
   - **Sequence**: controls display order (e.g., `1`, `2`, `3`)
4. Configure optional features:
   - Enable **Manual Completion** if users should be able to mark it done from the panel
   - Enable **Reset** and provide a **Reset Field API Name** if the clock should restart when that field is populated
   - Enable **Extension** and provide an **Extension Field API Name** (a numeric field in days) if extra time can be granted
5. Check **Active** and save.

> Create one record per milestone. All milestones for an active, matched process are displayed together in sequence order.

---

### Step 4 — Add Milestone Validations (Optional)

Validations prevent users from marking a milestone complete until certain conditions are met.

1. Go to **SLA Milestone Validation** and click **Manage Records > New**.
2. Set **SLA Process Milestone** to the target milestone.
3. Enter the **Field API Name** on the record to validate.
4. Enter the **Validation Rule JSON** (see [Validation Rule JSON](#validation-rule-json)).
5. Optionally provide a friendly **Error Message** shown to the user on failure.
6. Set **Sequence** and check **Active**.

Multiple validations can be added to a single milestone; all must pass for completion to proceed.

---

### Step 5 — Configure Exit Field Updates

Exit Field Updates write values to the record when a milestone is completed (or the process exits). They are also the mechanism by which the service detects whether a milestone is already complete.

1. Go to **SLA Exit Field Update** and click **Manage Records > New**.
2. Set:
   - **SLA Process** (required)
   - **SLA Process Milestone**: the milestone this update belongs to
   - **Update Context**: `MILESTONE_COMPLETE` (triggered when a user marks the milestone done) or `PROCESS_EXIT` (triggered when exit criteria are met)
3. Fill in **Field API Name**, **Update Type**, and (if applicable) **Update Value**.
4. Set **Sequence** and check **Active**.

---

## Criteria and Validation JSON Reference

### Criteria JSON (Entry/Exit)

The `Criteria_JSON__c` field accepts JSON evaluated against the record's field values. A single condition, AND/OR groups, and nested logic are all supported.

**Single condition:**
```json
{
  "field": "Status",
  "operator": "EQUALS",
  "value": "Working"
}
```

**Check a field is populated (REQUIRED):**
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

The `Validation_Rule_JSON__c` field on `SLA_Milestone_Validation__mdt` uses the same operators, but in a simpler single-rule format:

```json
{ "type": "TRUE" }
```

```json
{ "type": "REQUIRED" }
```

```json
{ "type": "EQUALS", "value": "Approved" }
```

```json
{ "type": "NOT_EQUALS", "value": "Cancelled" }
```

The `type` key maps to the same operator names as the criteria JSON. The `field` is provided separately in the `Field_API_Name__c` metadata field rather than inside the JSON itself.

---

## Maintaining SLA Milestones

### Activating and Deactivating Records

Every CMDT record has an **Active** checkbox. Unchecking it instantly removes that record from evaluation without deletion. This is the recommended approach for:
- Temporarily suspending a process during system maintenance
- Disabling a milestone that no longer applies
- Toggling a validation rule on or off for a period

No deployment is required — metadata changes take effect immediately.

---

### Adjusting Time Targets

To change the time allowed for a milestone:

1. Navigate to **SLA Process Milestone** in Custom Metadata Types.
2. Open the relevant milestone record.
3. Update **Time Trigger (Minutes)**.
4. Save.

The change applies to all records where the milestone has not yet been completed. Existing completed milestones are unaffected (completion is determined by the field values on the record, not by re-evaluating the time target).

---

### Business Hours

Business Hours constrain when the SLA clock is running and affect both the deadline calculation and the live countdown display.

- **Process-level:** Set `Business_Hours_Id__c` on `SLA_Process__mdt`. All milestones in the process inherit this.
- **Milestone-level override:** Set `Business_Hours_Id_Override__c` on `SLA_Process_Milestone__mdt` to use different hours for a specific milestone.

To find a Business Hours record ID:
1. Go to **Setup > Business Hours**.
2. Open the desired record.
3. Copy the 18-character ID from the browser URL.

Leave the field blank to use calendar time (24/7) instead.

---

### Milestone Resets and Extensions

**Resets** allow the milestone clock to restart from a later point in time — useful where a process step may be paused and restarted (e.g., awaiting a customer response).

- Enable **Reset Enabled** on the milestone.
- Populate **Reset Field API Name** with a `Datetime` field on the object.
- When that field is populated and its value is later than the original start time, the clock restarts from that date.

**Extensions** allow authorised users to add extra time to a milestone's target — useful for agreed exceptions.

- Enable **Extension Enabled** on the milestone.
- Populate **Extension Field API Name** with a numeric field on the object representing the number of additional business days.
- The service converts days to minutes at a rate of 480 minutes per business day.

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

### Example 1: Case Working SLA

**Scenario:** Track a 5-day (7,200 minute) milestone for Cases in `Working` status. Close the case automatically when the milestone is completed.

**SLA Process (`SLA_Process__mdt`):**
- Label: `Case Working SLA`
- Target Object API Name: `Case`
- Active: `true`

**Entry Criteria (`SLA_Entry_Exit_Criteria__mdt`):**
- SLA Process: `Case Working SLA`
- Criteria Context: `ENTRY`
- Criteria JSON:
  ```json
  { "field": "Status", "operator": "EQUALS", "value": "Working" }
  ```

**Milestone (`SLA_Process_Milestone__mdt`):**
- Label: `Complete in Five Days`
- SLA Process: `Case Working SLA`
- Time Trigger (Minutes): `7200`
- Start Field API Name: `CreatedDate`
- Manual Completion Enabled: `true`
- Sequence: `1`

**Exit Field Update (`SLA_Exit_Field_Update__mdt`):**
- SLA Process Milestone: `Complete in Five Days`
- Update Context: `MILESTONE_COMPLETE`
- Field API Name: `Status`
- Update Type: `STATIC`
- Update Value: `Closed`

When a user clicks Mark Completed, the Case `Status` is set to `Closed`. On subsequent page loads, the service detects that `Status` equals `Closed` and shows the milestone as Completed.

---

### Example 2: SLA with Custom Start/End Fields and Extensions

**Scenario:** Track a milestone based on a custom `SLA_Test_Start__c` field, allow resets via `SLA_Test_Reset__c`, allow extensions via `SLA_Test_Extension_Days__c`, require a checkbox before completion, and stamp `SLA_Test_End__c` on completion.

**Entry Criteria:**
```json
{ "field": "SLA_Test_Start__c", "operator": "REQUIRED" }
```

**Milestone configuration:**
- Time Trigger (Minutes): `2400` (40 hours)
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

On completion, the current datetime is stamped into `SLA_Test_End__c`. On subsequent loads, the service checks whether `SLA_Test_End__c` is populated and, if so, displays the milestone as Completed.

---

## Troubleshooting

**The panel shows "No active SLA Process configuration found for this record."**
- Confirm at least one `SLA_Process__mdt` record exists with `Active = true` and `Target_Object_API_Name__c` matching the object exactly (case-sensitive).

**The panel shows "There are no current active SLA's against this record."**
- Entry criteria are defined but the record does not match. Check the `Criteria_JSON__c` on the Entry criteria records and verify the field values on the record match the expected conditions.

**The panel shows "The record meets SLA exit criteria."**
- Exit criteria are satisfied. If this is unexpected, review the Exit criteria `Criteria_JSON__c` for the process.

**A milestone shows "Awaiting start" indefinitely.**
- The `Start_Field_API_Name__c` is blank or the referenced field on the record is empty. Either populate the field or leave `Start_Field_API_Name__c` blank to fall back to `CreatedDate`.

**"Mark Completed" is not visible on a milestone.**
- `Manual_Completion_Enabled__c` must be `true` on the milestone.
- The milestone must not already be in a Completed status.

**A validation error appears when clicking Mark Completed.**
- A `SLA_Milestone_Validation__mdt` record linked to the milestone is failing. Check the `Error_Message__c` for guidance. Resolve the field condition on the record and try again.

**Business hours are not being applied.**
- Verify the Business Hours record ID is correct (18 characters). Go to **Setup > Business Hours**, open the record, and copy the ID from the URL. Confirm the Business Hours record is active and covers the expected timezone and days.

**Fields referenced in CMDT are not loading on the record.**
- The service dynamically queries only fields referenced across all active CMDT records. If you add a new field reference to CMDT, verify the field's API name is spelled correctly and exists on the target object.
