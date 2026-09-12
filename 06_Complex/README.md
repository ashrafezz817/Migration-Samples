# Patient

## Purpose

Provides patient registration and patient-master maintenance for the Healthcare Information System, including demographic information, identification, contact information, insurance and payer data, eligibility/retrieval workflows, patient validation, and navigation to related clinical and administrative processes.

## Complexity

**Complex**

Although the Form contains only two blocks, it is a large event-driven patient-management workflow with 170 items and 119 triggers.

Its complexity comes primarily from the amount of business behavior embedded directly in field-level and Form-level events rather than from master-detail structure.

The Form combines:

* Patient registration
* Identity validation
* Demographic validation
* Insurance and payer configuration
* Eligibility and patient-retrieval integration
* Mobile-validation workflow
* Arabic/English presentation logic
* Patient document/report generation
* Messaging
* Cross-Form navigation
* Legacy file-based integration
* Security and user-specific behavior

## Main Functionality

* Creates and maintains patient records
* Supports automatic and manual patient-number workflows
* Maintains patient medical-record/file information
* Records national ID/Iqama, passport, and other identification information
* Validates Saudi and non-Saudi identity information
* Maintains Arabic and English patient names
* Maintains gender, nationality, birth date, and marital status
* Calculates and validates patient age
* Maintains address, postal-code, telephone, mobile, and email information
* Maintains next-of-kin and relationship information
* Maintains employer and occupation information
* Associates patients with companies, insurers, TPAs, and insurance classes
* Maintains policy, member, card, and insurance information
* Validates insurance-card and contract information
* Supports patient eligibility checks
* Supports patient-data retrieval using identity and payer information
* Displays previously returned eligibility information
* Supports manual eligibility workflows
* Provides mobile-validation / OTP user-interface functionality
* Displays active packages, un-invoiced requested services, and valid revisits
* Displays patient financial totals
* Supports patient hold/resume behavior
* Supports patient search by several identifiers
* Generates patient-related reports and print output
* Sends patient-facing messages
* Provides navigation to admissions, reservations, consent, eligibility, retrieval, and other related workflows
* Supports Arabic and English UI behavior

## Technical Summary

| Component      | Count |
| -------------- | ----: |
| Blocks         |     2 |
| Items          |   170 |
| Triggers       |   119 |
| Program Units  |    20 |
| LOVs           |    10 |
| Relations      |     0 |
| DB Packages    |     2 |
| Report Objects |     0 |

The Form contains:

* `PATIENT` - primary database block
* `STK_V_TOOL` - non-database utility, action, and navigation block

The `PATIENT` block contains 117 items.

The `STK_V_TOOL` block contains 53 items.

The 119 Forms triggers are distributed across item, block, and Form scope:

* 97 item-level triggers
* 13 block-level triggers
* 9 Form-level triggers

The Form contains 20 Program Unit objects representing 18 distinct program-unit names because legacy duplicate definitions of `CHK_VOL` and `CHK_SEC` remain in the XML.

## Main Database Objects

The Form interacts with a broad set of patient, insurance, configuration, and operational objects.

Significant dependencies include the following.

### Primary Patient Object

* `PATIENT`

`PATIENT` is the primary database table maintained by the Form.

It stores the core patient demographic, identity, contact, insurance, and operational information.

### Identity and Demographic Objects

* `NATIONALITY`
* `POSTAL_CODE`
* `RELATIVE`
* `RELAG`
* `OCCUPATION_TYPES`

These objects support nationality, address, relationship, next-of-kin, and occupation information.

### Insurance and Payer Objects

* `COMPANYS`
* `DISC_CLASSES`
* `CASH_CARD_DISC`

These objects support payer/company information, sub-company relationships, insurance classes, discount-card information, and patient financial coverage.

### Clinical and Operational Objects

* `DOCTORS`
* `CLINICS`
* `T_INV`
* `D_INV`
* `PACKAGE_CONS_M`
* `SERVICES`

These objects are used to display or determine patient-related clinical, package, visit, and financial information.

### Eligibility and Retrieval Objects

The Form contains current and legacy functionality associated with insurance eligibility and patient retrieval, including references to objects such as:

* `W_RESPONSE_ELIGBILITY`

and shared eligibility/retrieval procedures.

The exact backend dependency tree for these integration procedures should be assessed separately because substantial processing is implemented outside the Form.

### Configuration and Security Objects

* `PREF`
* `USERS_TABLE`
* `SYSTEMS`

These objects control application preferences, user capabilities, localization, and Form behavior.

### Legacy Integration Objects

The Form also references configuration used by a legacy DHS/MSV file-based integration, including:

* `PROVIDER_CONFIG`

along with payer, clinic, doctor, and nationality data used to construct outbound messages.

This list identifies significant dependencies visible in the Form and is not intended to be an exhaustive database dependency tree.

## Key Business Logic

The Form contains a large amount of embedded business logic covering patient identity, demographics, insurance, eligibility, and application workflow.

### Patient Identification

The Form supports several patient-identification mechanisms including:

* Medical record / patient number
* ID / Iqama
* Passport
* Border number
* Mobile number

Patient searches can be performed using different identifiers depending on the workflow.

Duplicate patient and duplicate ID checks are performed during validation.

### ID / Iqama Validation

For resident patients, the Form applies validation such as:

* Required identity information
* ID/Iqama length
* Nationality consistency with the leading digit of the ID
* Duplicate identity detection

Saudi-national and non-Saudi validation rules are handled differently.

### Birth Date and Age Validation

The Form validates birth dates and prevents invalid or future dates.

It calculates patient age and contains specialized handling for newborn patients.

Hijri-related birth-date handling is also present in the Form.

### Patient Number / File Generation

The legacy Form supports both automatic and manual patient-number behavior according to application configuration.

During insertion, patient file numbering includes legacy logic based on the current maximum `PATIENT_FILE` value plus one.

This mechanism requires review during migration because `MAX(...) + 1` numbering is not safe under concurrent web usage.

### Patient Data Validation

Before saving, the Form validates a broad range of patient information.

Examples include:

* Birth date
* Mobile/telephone information
* Identity or passport information
* English patient name
* Nationality
* Payer/company
* Insurance data when applicable

Additional checks are performed depending on patient and coverage type.

### Insurance Validation

For insured patients, the Form validates information such as:

* Company
* Sub-company
* Insurance class
* Membership/card number
* Policy number
* Card expiry date
* Insurance-class status
* Payer contract status
* Company status

The applicable validation differs according to company/payer type.

### Eligibility

The Form includes workflows for checking patient insurance eligibility.

Current integration logic includes calls such as:

* `MAIN_CALL_ELIGBILITY`
* `MAIN_CALL_ELIGBILIT_CASE_2`

The combined eligibility/retrieval flow derives payer information using the configured `NPHIES_PAYER_ID`.

Eligibility results can subsequently be displayed through related Forms.

### Patient Retrieval

Patient retrieval uses identity, birth-date, visit-type, and payer information.

The Form references shared retrieval functionality such as:

* `W_RETAVIL_PATIENT`

and then opens the related retrieval workflow when data is returned successfully.

### Mobile Validation / OTP

The Form contains a dedicated OTP view and fields related to mobile verification, including:

* OTP value
* OTP date
* Verification status

### Patient Packages and Requested Services

When an existing patient is queried, the Form checks for:

* Active packages
* Un-invoiced requested services
* Valid revisits

Relevant actions are dynamically displayed when such records exist.

### Patient Financial Summary

The Form calculates patient-level financial totals from invoice data, including:

* Total invoiced amount
* Total payment
* Outstanding/due amount

### Localization

The Form dynamically changes:

* Form direction
* Window direction
* Canvas direction
* Item prompts
* Button labels
* Item alignment
* Hints and tooltips

according to the active Arabic or English language.

A significant amount of this UI behavior is implemented through the `DO_INTERFACE` program unit and related prompt-handling logic.

## Forms Characteristics

* Two Forms blocks
* 170 items
* 119 triggers
* 20 Program Unit objects
* 10 LOVs
* Very high item-level trigger density
* Extensive embedded PL/SQL validation
* Patient-registration workflow
* Identity and duplicate-patient checks
* Insurance and payer validation
* Eligibility integration
* Patient retrieval integration
* Dynamic database-backed lists
* Mobile-validation / OTP UI
* Patient package and requested-service checks
* Cross-Form navigation
* Oracle Reports / JSP integration
* Database file-I/O integration
* Messaging integration
* Global-variable usage
* Form-parameter usage
* Arabic/English localization
* Shared Forms Object Library dependencies
* No Forms master-detail relations

## Program Units

The form contains 20 Program Unit objects:

* `MESSAG`
* `CHG_PRMPT2`
* `CHK_VOL`
* `CHK_VOL`
* `CHK_SEC`
* `HIDE_AN_ITEM`
* `CHK_SEC`
* `ENCODE`
* `START_SCAN`
* `SNED_MSV_MSG`
* `VALID_OR_NOT`
* `CANCEL_TIMER`
* `XST`
* `TYPESHOW`
* `FILE_IS_OK`
* `DO_INTERFACE`
* `MOVE_ITEM`
* `CHK_LIC_SEC`
* `FINAL_CHECK`
* `COLLECT_NAME`

`CHK_VOL` and `CHK_SEC` each have duplicate XML Program Unit definitions, so the structural count is 20 even though there are 18 distinct names.

Some of these units represent business rules while others provide shared Forms UI, security, localization, or legacy integration functionality.

## Dependencies

### Database Packages

Two active explicit Oracle database package dependencies were identified.

#### `UTL_FILE`

Used by the legacy DHS/MSV integration to:

* Create outbound files
* Write patient and payer message records
* Check response files
* Close and manage integration files

The Form uses Oracle directory objects such as `DHS_MSVREQUEST`.

This file-based integration requires architectural review during migration rather than direct reproduction inside an APEX page.

#### `UTL_URL`

Used when constructing and escaping Oracle Reports URLs before opening them in the browser.

Forms built-ins such as `WEB.SHOW_DOCUMENT` are not counted as database package dependencies.

### Database Functions / Procedures

The Form references a substantial amount of shared standalone database functionality.

Examples include:

* `MAIN_CALL_ELIGBILITY`
* `MAIN_CALL_ELIGBILIT_CASE_2`
* `W_RETAVIL_PATIENT`
* `SEND_MESSAG`
* `DAY_TO_DAYES`

Additional shared functions and procedures are referenced throughout the Form.

These are not included in the `DB Packages` count because they are standalone database routines rather than package-qualified calls.

The backend implementation of these routines should be assessed as part of the migration dependency analysis.

## LOVs

The Form defines 10 LOV objects:

* `INFO`
* `MOBILE`
* `ID`
* `LOV757`
* `DISC_CARD`
* `THE_CLASS`
* `DOC1`
* `NAT`
* `COMPANY1_2`
* `SUB_COMPANY`

These LOVs support patient registration and search functionality including:

* Information center
* Patient lookup
* Mobile lookup
* Identity lookup
* Nationality
* Doctor
* Company/payer
* Sub-company
* Insurance class
* Discount card

In addition to these Forms LOV objects, several list items are populated dynamically at runtime using database queries.

Examples include:

* Relationship lists
* Relative lists
* Occupation types

These runtime lists should be considered separate dependencies when designing the target APEX page.

## Other Forms

The Patient Form participates in a large number of cross-Form workflows.

Significant examples include:

### Eligibility / Retrieval

* `ELLIGABILITY`
* `elligability_manul`
* `RETRIVAL`

These Forms support eligibility result display, manual eligibility processing, and patient retrieval.

### Consent

* `MEDICAL_CONSENT`

Used for patient medical-consent functionality.

### Admission

* `ADDM`

Used to continue from the patient record into admission processing.

### Reservation

* `DOC_DATESTW`

Used for doctor reservation/scheduling functionality.

Additional cross-Form navigation exists throughout the module.

These workflows should generally become normal APEX page navigation or integrated application flows rather than direct equivalents of `OPEN_FORM`, `FIND_FORM`, and `GO_FORM`.

## Reports and External Output

### Forms Report Objects

The XML contains **no actual `<Report>` objects**, so the technical-summary `Report Objects` count is `0`.

### Active Report / JSP Dependencies

Despite having no structural Report objects, the Form contains report-server dependencies.

#### `PAT_DATA.jsp`

Used to generate patient-data / patient-file output.

#### `PAT_CARD.jsp`

Used to generate patient-card output.

#### `consent.jsp`

A consent-report URL is generated during patient processing and stored in the patient consent command field.

A newer consent workflow also opens the `MEDICAL_CONSENT` Form, while older direct consent-report logic remains in the XML.

### Legacy Report Object Reference

The Form contains legacy code that calls:

`FIND_REPORT_OBJECT('REPORT568')`

and uses `RUN_REPORT_OBJECT` / `REPORT_OBJECT_STATUS`.

However, there is no corresponding `<Report Name="REPORT568">` object in the current XML.

This should therefore be treated as a legacy report dependency/reference rather than as a structural Forms Report object.

## Legacy DHS / MSV Integration

The `SNED_MSV_MSG` Program Unit contains a legacy file-based integration workflow.

It constructs structured patient/payer messages and writes them using `UTL_FILE`.

The message includes information from:

* Patient demographics
* Insurance/payer data
* Provider configuration
* Nationality
* Clinic
* Doctor
* Policy/member information

Additional response-file handling is present in the Form, although some timer/response-processing sections are currently commented out.

During migration, this integration should be confirmed as either:

* Still required and needing a supported server-side integration architecture, or
* Legacy behavior that can be retired

before effort is allocated to reproducing it.

## Shared Forms Libraries

The Form references shared Oracle Forms Object Libraries including:

* `BUSINESSXP.olb`
* `HMISTEXT.olb`
* `HMISCANVAS.olb`
* `HMISBUTTON.olb`

These libraries provide common visual, control, alert, button, and application behavior used throughout the legacy Forms application.

## Migration Considerations

This Form should not be migrated as a literal 170-field Oracle APEX page.

The existing Form combines multiple responsibilities that can be separated into clearer APEX workflows while retaining the required business behavior.

Key considerations include:

* Patient registration and patient search should be separated where this improves usability and maintainability.
* Core patient validation should be centralized in database APIs or reusable backend validation services rather than distributed across dozens of APEX Dynamic Actions and page processes.
* Patient-number and patient-file generation should use concurrency-safe database mechanisms rather than `MAX(...) + 1`.
* Duplicate ID/Iqama, passport, mobile, and patient checks should be backed by appropriate database constraints or transaction-safe backend validation where possible.
* Saudi ID/Iqama and nationality consistency rules should be documented explicitly and regression-tested.
* Birth-date, age, newborn, and Hijri/Gregorian rules should be preserved through reusable validation logic.
* Insurance/company/class validation should be centralized rather than reproduced independently in client-side page events.
* Eligibility and retrieval integrations should be treated as backend services with clear request, response, timeout, and error-handling contracts.
* The NPHIES-related eligibility/retrieval flow should be assessed together with its shared database procedures and integration infrastructure rather than considering only the Forms trigger that invokes it.
* Mobile verification should be reviewed against the intended current workflow because the Form contains OTP UI but its older OTP procedure calls are currently commented out.
* The legacy `UTL_FILE` DHS/MSV integration should not automatically be reproduced. Its current business requirement and replacement architecture should first be confirmed.
* Direct Oracle Reports `rwservlet` URL generation should be replaced by the target reporting architecture.
* Report credentials and infrastructure details should not be exposed through browser-visible URLs.
* Cross-Form workflows such as eligibility, retrieval, admissions, reservations, and consent should become integrated APEX navigation flows.
* Arabic and English presentation should use standard APEX globalization, translation, and RTL/LTR capabilities rather than reproducing Forms item-by-item property manipulation.
* Security should use the target application's centralized permission model rather than Forms block and item manipulation.
* Shared Forms visual utilities, window-positioning code, and item-movement logic generally do not require direct migration.
* Legacy globals and module parameters should be replaced with controlled APEX session state, application context, or configuration settings.
* Extensive `WHEN OTHERS THEN NULL` exception handling should be reviewed because it can hide data and integration failures.
* Commented legacy integrations and historical branches should be separated from active functionality before estimating migration effort.
* Patient registration should be regression-tested using representative Saudi, resident, visitor, insured, uninsured, newborn, duplicate-identity, eligibility, retrieval, and update scenarios.
* The target design should preserve required business rules without reproducing obsolete Forms-specific behavior.

## Files

* `Patient.fmb` — Original Oracle Forms module
* `Patient.xml` — XML export for source inspection and analysis
* `screenshot.png` — Screenshot of the current Oracle Forms user interface

