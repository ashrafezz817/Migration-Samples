# APEX Reference - Patient Management

## Purpose

This directory contains the migrated Oracle APEX implementation corresponding to the legacy Patient sample.

The implementation is provided as a **reference for the expected migration approach and quality level**. It is not intended to require future Forms to be reproduced using the exact same page structure or technical design.

During migration, legacy Forms functionality may be simplified, redesigned, split across multiple APEX pages, moved into reusable database APIs, replaced with native APEX functionality, or excluded from the target scope where appropriate.

For this sample, the large legacy Patient Form was separated into a patient search and action page plus a focused patient-demographics page. Patient creation and update rules were moved into a reusable server-side package.

## Migration Mapping

```text
Legacy Patient Form
        |
        +--> Page 17 - Patients
        |       |
        |       +--> patient search
        |       +--> patient actions and navigation
        |
        +--> Page 19 - Patient Demographics
                |
                +--> create / edit / view workflow
                |
                +--> PATIENT_MGMT_PKG

Related eligibility, retrieval, billing, visit and other patient workflows
remain separate application modules and are not all included in this sample.
```

The migration is not a one-to-one recreation of the original 170-item, trigger-heavy Oracle Forms screen.

The patient-search responsibility and the patient-maintenance responsibility are separated while shared business rules are centralized in the backend.

## Page 17 - Patients

Page 17 is the patient search and action workspace.

Rather than loading the entire patient population when the page opens, the page begins with a search state and returns patient records only after the user supplies search criteria.

Search options include:

- General search text
- MRN
- National ID / Iqama
- Personal or work phone
- Insurance member ID
- Patient name in English
- Patient name in Arabic

The report is based on `V_PATIENT_SEARCH`.

Patient-name searching uses Oracle Text `CONTAINS` searches, while exact identifiers and phone values use targeted comparisons.

The page includes an explicit empty state before search, a search-in-progress state, and a no-results state.

### Patient Actions

Search results provide permission-controlled actions for workflows such as:

- View patient demographics
- Retrieve insurance information where applicable
- Create a new-visit invoice
- Create a patient invoice
- Create a service-request invoice

Patient creation is also started from Page 17 and opens Page 19 in create mode.

These links demonstrate that patient management is treated as an application hub rather than forcing every related workflow into one page.

## Page 19 - Patient Demographics

Page 19 is the main patient registration and demographic-maintenance page.

It supports three explicit operating modes:

- `CREATE`
- `EDIT`
- `VIEW`

Page mode is derived on the server and access is protected using the centralized permission model.

Relevant permissions include:

- `PATIENT_DEMOG_VIEW`
- `PATIENT_CREATE`
- `PATIENT_UPDATE`

The page organizes patient information into focused sections rather than reproducing the original Forms item layout.

The maintained information includes areas such as:

- Residency status
- MRN
- National ID / Iqama
- Passport and Border Number
- External referral status and validity
- English and Arabic legal names
- Date of birth
- Gender
- Nationality
- Marital status
- Religion
- Occupation
- Personal mobile and work phone
- Address and postal code
- Email
- Emergency contact
- Next-of-kin information
- Coverage type
- Direct-contract company
- Insurance provider, policy and class information
- Subscriber and membership information
- Newborn and parent-patient information
- Audit information

## Functionality Not Included in the Target Migration

The current Page 19 export is still an in-progress application page and contains some residual functionality that is **not part of the intended Patient migration scope**.

### Discount Cards

Discount Card-related items may still appear in the Page 19 export and current APEX interface. Their presence should **not** be interpreted as a requirement to migrate or reproduce the legacy Discount Card functionality.

Discount Cards are intentionally excluded from the target Patient migration and should not be included when assessing the required Patient functionality or estimating the migration effort for this sample.

## Patient Creation and Update

Page 19 does not rely on native Automatic Row Processing for its final patient save.

The page builds a `PATIENT_MGMT_PKG.T_PATIENT_REC` record and delegates persistence to:

- `PATIENT_MGMT_PKG.CREATE_PATIENT`
- `PATIENT_MGMT_PKG.UPDATE_PATIENT`

The package returns the persisted patient number, generated patient names, object version number, last-update date and updating user back to the page.

This keeps the final business rules and persistence logic outside the browser and outside individual APEX page processes.

## MRN Generation

The migrated implementation supports both automatic and manual MRN generation according to application configuration.

Page 19 reads the current MRN generation mode from `FND_APP_SETTINGS_PKG`.

When the mode is `AUTO`, the backend generates the patient number using `PATIENT_MRN_SEQ`.

When the mode is `MANUAL`, a patient number must be supplied by the user.

This replaces legacy concurrency-sensitive numbering behavior with a database sequence for automatic generation.

## Identity and Demographic Validation

The final patient save is protected by server-side validation in `PATIENT_MGMT_PKG`.

Validation includes areas such as:

- Required residency status
- Required National ID / Iqama for applicable residents
- National ID / Iqama format
- Saudi nationality consistency with National ID values
- Border Number requirements and format
- Duplicate National ID / Iqama detection
- Duplicate Border Number detection
- Required English first and family names
- Gender validation
- Occupation validation
- Marital-status validation
- Religion validation
- Date-of-birth validation
- Personal mobile requirement
- Newborn parent-patient requirements
- Insurance-card date consistency

Page-level validations provide immediate user feedback, while the backend remains the final authority before persistence.

## Coverage Model

Patient coverage is represented explicitly using the current application coverage model:

- `CASH`
- `DIRECT_CONTRACT`
- `INSURANCE`

### Cash

For Cash patients, the configured cash company is resolved through `INS_COMP_UTIL` and insurance-specific values are cleared.

### Direct Contract

For Direct Contract patients, the backend validates that the selected company is an active direct-contract company and removes insurance-only fields.

### Insurance

For insured patients, the backend validates and derives information such as:

- Policy / policy holder
- Insurance provider
- Related provider / group
- Insurance class
- Policy validity
- Subscriber relationship

The package verifies that the selected policy and class are currently valid before saving the patient.

## Newborn Handling

The migrated workflow retains explicit newborn handling.

A newborn patient must reference a parent patient. The backend validates the relationship and derives the appropriate residency context from the parent where required.

The parent MRN cannot be the same as the new patient's MRN.

## Personal Mobile Sharing

The application can limit how many patient records may share the same personal mobile number.

`PATIENT_MGMT_PKG` reads the configured maximum from `FND_APP_SETTINGS_PKG` and uses `PATIENT_MOBILE_LOCK_BUCKET` to serialize competing validations for the same mobile value.

This is important in a web application because two sessions can attempt to create or update patient records concurrently.

The check is therefore implemented as a transaction-safe backend rule rather than only a client-side count.

## Mobile Verification

Page 19 includes a mobile OTP verification workflow.

The page uses `PATIENT_OTP` to verify the saved personal mobile number.

Verification is tied to the persisted mobile value. If the patient's personal mobile changes, `PATIENT_MGMT_PKG` resets the stored OTP verification state during update.

When OTP verification updates the patient row, Page 19 refreshes the current `OBJECT_VERSION_NUMBER` so a later patient update does not produce a false optimistic-lock conflict.

## Name Transliteration

Page 19 provides English-to-Arabic and Arabic-to-English transliteration suggestions for patient legal-name components.

Suggestions are requested asynchronously through an APEX callback that uses `PATIENT_UTIL`.

The client cancels obsolete requests and ignores stale responses when the source value changes before an earlier lookup completes.

When a patient is created or the English/Arabic name pair changes, `PATIENT_MGMT_PKG` submits the final name pairs back to `PATIENT_UTIL` for transliteration learning.

Failures in this auxiliary learning process are isolated from the main patient save and recorded in `APP_AUDIT_LOG`.

## Optimistic Locking

Patient updates use `PATIENT.OBJECT_VERSION_NUMBER`.

`PATIENT_MGMT_PKG.UPDATE_PATIENT` updates the row only when the submitted object version matches the current database version.

If another user or process has already changed the patient, the update is rejected and the user is required to refresh before trying again.

This replaces the implicit single-user assumptions common in desktop Forms workflows with an explicit web-concurrency contract.

## Backend Reference

The backend directory contains:

### `PATIENT_MGMT_PKG.sql`

This package owns patient creation and update for Page 19.

Its public API is intentionally small:

- `CREATE_PATIENT`
- `UPDATE_PATIENT`

Unlike the billing backend in Sample 5, this package does not contain a large unrelated public surface that needs to be removed for the migration sample.

The private helpers in the package directly support those two save operations, including:

- Input normalization
- Automatic MRN generation
- Identity validation
- Demographic validation
- Birth-date validation
- Coverage validation and derivation
- Newborn handling
- Duplicate identity handling
- Personal-mobile sharing limits
- Name-transliteration learning
- Optimistic locking
- OTP reset when the saved personal mobile changes

For that reason, the package is retained as the relevant Patient-management backend rather than being reduced to a thin wrapper that would hide the actual business rules.

## Related Workflows

The legacy Patient Form also acted as a launch point for many other application functions.

The APEX implementation keeps those concerns as separate workflows rather than embedding all functionality in the demographics page.

Examples include:

- Insurance eligibility and retrieval
- Manual eligibility
- Eligibility result viewing
- Patient history
- New visits
- Patient invoicing
- Service-request invoicing
- Hold/resume workflows
- Other clinical and administrative actions

Some of these destinations are linked from Pages 17 and 19 but their page exports and backend implementations are outside this sample.

This is intentional. The reference demonstrates the migrated Patient-management responsibility without duplicating other application modules that are maintained separately.

## Key Modernization Changes

The migrated implementation differs substantially from the legacy Oracle Forms architecture.

Key changes include:

- Patient search was separated from patient demographic maintenance.
- Page 17 uses a search-first workflow instead of loading the full patient dataset automatically.
- Page 19 uses explicit Create, Edit and View modes.
- Patient creation and update rules are centralized in `PATIENT_MGMT_PKG`.
- Automatic MRN generation uses a database sequence.
- Duplicate identity validation is enforced on the server.
- Coverage rules are centralized and normalized before persistence.
- Personal-mobile sharing limits include concurrency protection.
- Updates use optimistic locking through `OBJECT_VERSION_NUMBER`.
- Mobile verification is tied to the persisted mobile value.
- English/Arabic transliteration is implemented as a reusable service instead of Forms-specific field logic.
- Permissions use centralized application authorization.
- Related billing, eligibility and clinical workflows are separate application modules rather than responsibilities of one patient-maintenance screen.
- Discount Card functionality is intentionally excluded from the target Patient migration even if residual controls are visible in the current Page 19 export.
- Forms-specific window, canvas, object-library and item-manipulation patterns are not reproduced unnecessarily.

The objective is to preserve required patient-management behavior while creating clearer domain and workflow boundaries.

## Shared Dependencies

This reference relies on wider HMIS application infrastructure that is not fully included in the sample.

Important dependencies include:

- `PATIENT`
- `V_PATIENT_SEARCH`
- `PATIENT_MRN_SEQ`
- `PATIENT_MOBILE_LOCK_BUCKET`
- `COMPANYS`
- `DISC_CLASSES`
- `OCCUPATION_TYPES`
- `RELAG`
- `APP_AUDIT_LOG`
- `FND_APP_SETTINGS_PKG`
- `FND_APP_SECURITY`
- `INS_COMP_UTIL`
- `FND_SMS_UTIL`
- `PATIENT_UTIL`
- `PATIENT_OTP`
- Shared APEX LOVs and application session context

Pages 17 and 19 also navigate to other application workflows whose implementations are outside this directory.

The reference is therefore **not a standalone deployable patient-management subsystem**.

## Reference Scope

The implementation is intended to demonstrate how a large, event-driven Oracle Forms patient module can be modernized without reproducing its original 170-item architecture one-to-one.

The required business behavior should be preserved while allowing responsibilities to be separated into:

- Search and patient discovery
- Patient demographic maintenance
- Reusable backend validation and persistence
- Eligibility and insurance workflows
- Billing workflows
- Other clinical and administrative modules

Residual functionality still visible in the current APEX export should not automatically be interpreted as target-scope functionality. The explicit scope decisions documented in this README take precedence for this migration sample.

A future migration does not need to reproduce these exact page numbers or technical components. The important requirement is to preserve the required business behavior and an equivalent level of integrity, maintainability, concurrency safety, security, and usability.

## Files

- `hmisfox_page_17.apx` - Oracle APEX Page 17, Patients search and action workspace
- `hmisfox_page_19.apx` - Oracle APEX Page 19, Patient Demographics
- `backend/PATIENT_MGMT_PKG.sql` - patient creation and update backend
- `screenshots/screenshot-p17.png` - Patients search results
- `screenshots/screenshot-p17-empty-state.png` - initial Patients search state
- `screenshots/screenshot-p19.png` - Patient Demographics page
