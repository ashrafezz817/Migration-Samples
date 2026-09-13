# Patient

## Purpose

Provides patient registration and patient-master maintenance, including identity, demographics, contact information, coverage data, validation, and navigation to related workflows.

## Complexity

**Complex**

The Form contains only two blocks, but it is highly event-driven with 170 items, 119 triggers, and 20 Program Unit objects. Much of the business behavior is embedded directly in item, block, and Form-level logic.

## Main Functionality

- Creates and maintains patient records
- Supports automatic and manual patient-number workflows
- Maintains National ID / Iqama, passport, and Border Number
- Maintains English and Arabic patient names
- Maintains demographics, address, phones, email, emergency contact, and next of kin
- Maintains payer, policy, class, member, and insurance information
- Validates identity and coverage data
- Supports eligibility and patient-retrieval workflows
- Provides mobile-verification / OTP functionality
- Links to related visit, billing, history, eligibility, and administrative workflows
- Supports reports, messaging, and bilingual operation

## Technical Summary

| Component | Count |
| --- | ---: |
| Blocks | 2 |
| Items | 170 |
| Triggers | 119 |
| Program Units | 20 |
| LOVs | 10 |
| Relations | 0 |
| DB Packages | 2 |
| Report Objects | 0 |

These counts describe the legacy Oracle Forms module only. The migrated APEX reference implementation and backend component are documented separately under `APEX_Reference/`.

The Form contains:

- `PATIENT` - primary database block
- `STK_V_TOOL` - non-database utility, action, and navigation block

## Main Database Objects

### Primary Patient Object

- `PATIENT`

### Identity and Demographic Objects

- `NATIONALITY`
- `POSTAL_CODE`
- `RELATIVE`
- `RELAG`
- `OCCUPATION_TYPES`

### Insurance and Payer Objects

- `COMPANYS`
- `DISC_CLASSES`
- `CASH_CARD_DISC`

### Clinical and Operational Objects

- `DOCTORS`
- `CLINICS`
- `T_INV`
- `D_INV`
- `PACKAGE_CONS_M`
- `SERVICES`

### Configuration and Integration Objects

- `PREF`
- `USERS_TABLE`
- `SYSTEMS`
- `PROVIDER_CONFIG`
- `W_RESPONSE_ELIGBILITY`

## Key Business Logic

The Form contains substantial logic for patient identity, duplicate checks, demographics, birth date and age, newborn handling, coverage and insurance validation, eligibility and retrieval, mobile verification, patient-number behavior, patient packages and requests, financial information, and bilingual UI behavior.

Identity rules include required National ID / Iqama handling for applicable residents, 10-digit validation, nationality consistency, duplicate identity checks, Border Number validation, and passport-related rules.

Insurance rules validate company, policy, class, membership/card data, validity dates, and payer status according to the selected coverage context.

The Form also invokes shared eligibility and retrieval routines such as `MAIN_CALL_ELIGBILITY`, `MAIN_CALL_ELIGBILIT_CASE_2`, and `W_RETAVIL_PATIENT`.

## Forms Characteristics

- Two Forms blocks
- 170 items
- 119 triggers
- 20 Program Unit objects
- 10 LOVs
- No master-detail relations
- Extensive embedded PL/SQL validation
- Insurance and payer logic
- Eligibility and retrieval integration
- Mobile-verification UI
- Cross-Form navigation
- Oracle Reports / JSP integration
- Database file-I/O integration
- Messaging integration
- Arabic/English localization
- Shared Forms Object Library dependencies

## Program Units

The Form contains 20 Program Unit objects:

- `MESSAG`
- `CHG_PRMPT2`
- `CHK_VOL`
- `CHK_VOL`
- `CHK_SEC`
- `HIDE_AN_ITEM`
- `CHK_SEC`
- `ENCODE`
- `START_SCAN`
- `SNED_MSV_MSG`
- `VALID_OR_NOT`
- `CANCEL_TIMER`
- `XST`
- `TYPESHOW`
- `FILE_IS_OK`
- `DO_INTERFACE`
- `MOVE_ITEM`
- `CHK_LIC_SEC`
- `FINAL_CHECK`
- `COLLECT_NAME`

`CHK_VOL` and `CHK_SEC` each have duplicate definitions, so the structural count is 20 even though there are 18 distinct names.

## Legacy Dependencies

### Database Packages

The Form has two active explicit Oracle database package dependencies:

- `UTL_FILE` - legacy DHS/MSV file-based integration
- `UTL_URL` - escaping generated Oracle Reports URLs

### Database Functions / Procedures

Examples of shared standalone routines include:

- `MAIN_CALL_ELIGBILITY`
- `MAIN_CALL_ELIGBILIT_CASE_2`
- `W_RETAVIL_PATIENT`
- `SEND_MESSAG`
- `DAY_TO_DAYES`

These routines are not included in the `DB Packages` count because they are not package-qualified calls.

### LOVs

The Form defines 10 LOV objects:

- `INFO`
- `MOBILE`
- `ID`
- `LOV757`
- `DISC_CARD`
- `THE_CLASS`
- `DOC1`
- `NAT`
- `COMPANY1_2`
- `SUB_COMPANY`

### Other Forms

Significant cross-Form workflows include:

- `ELLIGABILITY`
- `elligability_manul`
- `RETRIVAL`
- `MEDICAL_CONSENT`
- `ADDM`
- `DOC_DATESTW`

### Reports / External Integrations

There are no Forms Report objects.

Active JSP/report-server references include:

- `PAT_DATA.jsp`
- `PAT_CARD.jsp`
- `consent.jsp`

The legacy `SNED_MSV_MSG` workflow uses `UTL_FILE` for file-based integration. That integration is outside the included APEX reference scope.

### Shared Forms Libraries

- `BUSINESSXP.olb`
- `HMISTEXT.olb`
- `HMISCANVAS.olb`
- `HMISBUTTON.olb`

## APEX Reference Implementation

The Patient Form has been migrated into a separated Oracle APEX workflow rather than recreated as one large page.

The reference includes:

- Page 17 - Patients
- Page 19 - Patient Demographics
- `PATIENT_MGMT_PKG`
- P17, P17 empty-state, and P19 screenshots

The implementation is provided as a **reference for the expected migration approach and quality level**. It is not intended to require future Forms to be reproduced using the exact same page structure or technical design.

### Page 17 - Patients

Page 17 separates patient discovery from patient maintenance.

It uses a search-first workflow and supports search by general text, MRN, National ID / Iqama, phone, insurance member ID, and English or Arabic patient name.

Search results provide permission-controlled actions to related workflows such as patient demographics, insurance retrieval, new-visit invoicing, patient invoicing, and service-request invoicing.

### Page 19 - Patient Demographics

Page 19 contains patient registration and demographic maintenance using explicit `CREATE`, `EDIT`, and `VIEW` modes.

The page maintains identity, legal names, demographics, contact information, emergency contact, coverage, insurance/direct-contract data, newborn relationships, and audit information.

### Patient Backend

Page 19 saves through:

- `PATIENT_MGMT_PKG.CREATE_PATIENT`
- `PATIENT_MGMT_PKG.UPDATE_PATIENT`

The package centralizes:

- Input normalization
- Automatic and manual MRN handling
- Sequence-based automatic MRN generation using `PATIENT_MRN_SEQ`
- Identity and demographic validation
- Duplicate identity checks
- Coverage and insurance validation
- Newborn handling
- Personal-mobile sharing limits
- Concurrency protection for mobile-sharing checks
- Name-transliteration learning
- OTP reset when the saved mobile changes
- Optimistic locking using `OBJECT_VERSION_NUMBER`

The package public API is already limited to the two Page 19 save operations, so its supporting private implementation is retained as part of the reference.

### Mobile Verification and Transliteration

Page 19 includes mobile verification through `PATIENT_OTP`. Verification applies to the persisted mobile value, and changing that value resets the verification state.

The page also provides English-to-Arabic and Arabic-to-English name suggestions through `PATIENT_UTIL`, with stale asynchronous responses ignored by the browser.

### Separation of Legacy Responsibilities

The legacy Patient Form also acted as a launch point for billing, eligibility, clinical, reporting, and administrative workflows.

The APEX implementation keeps those concerns as separate application modules instead of embedding all of them in Page 19. This includes eligibility/retrieval, patient history, visits, invoicing, service requests, hold/resume, and other clinical or administrative actions.

### Key Modernization Changes

- Patient search separated from demographic maintenance
- Search-first patient discovery
- Explicit Create, Edit, and View modes
- Server-side patient creation and update rules
- Sequence-based automatic MRN generation
- Server-side duplicate identity checks
- Centralized coverage validation
- Transaction-safe mobile-sharing limits
- Optimistic locking through `OBJECT_VERSION_NUMBER`
- Mobile verification tied to the persisted mobile
- Reusable name transliteration support
- Centralized application permissions
- Related workflows separated into their own modules
- Forms-specific windows, canvases, Object Libraries, globals, and item-property manipulation not reproduced unnecessarily
- Legacy DHS/MSV file integration excluded from this reference

The required business behavior is preserved while avoiding unnecessary reproduction of Forms-specific implementation patterns.

See [`APEX_Reference/README.md`](APEX_Reference/README.md) for the detailed migrated implementation.

## Files

- `Patient.fmb` - Original Oracle Forms module
- `Patient.xml` - XML export of the Oracle Forms module
- `screenshot.png` - Screenshot of the current Oracle Forms user interface
- `APEX_Reference/` - Completed Oracle APEX reference implementation, backend package, screenshots, and migration notes
