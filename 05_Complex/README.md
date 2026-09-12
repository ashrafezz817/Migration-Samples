# Small Cash Invoice

## Purpose

Provides the operational outpatient invoicing workflow used to create and manage patient invoices, add billable services, calculate patient and payer amounts, apply pricing and discount rules, collect payment information, and initiate related clinical and financial processes.

## Complexity

**Complex**

This Form represents a highly integrated operational workflow with multiple interacting data blocks, extensive trigger-based business logic, pricing and insurance calculations, approval handling, package processing, cashier-shift controls, visit creation, service-request integration, reporting, payment processing, and downstream transaction updates.

A significant portion of the business behavior is implemented directly inside Oracle Forms triggers and program units.

## Main Functionality

- Creates and maintains outpatient invoices
- Selects and validates patients
- Determines cash or credit/insurance billing behavior
- Determines the applicable price plan and price list
- Associates invoices with doctors and clinics
- Adds individual billable services
- Retrieves service prices, discounts, VAT rates, and service metadata
- Calculates patient and company/payer shares
- Applies insurance class and deductible rules
- Supports cash-card discounts
- Supports discount offers and packages
- Imports previously requested services into the invoice
- Handles services requiring approval
- Supports multiple payment methods
- Calculates invoice totals, discounts, VAT, collected amounts, and remaining amounts
- Enforces cashier-shift requirements when configured
- Creates or updates related patient visit information
- Adds patients to applicable doctor/waiting workflows
- Maintains service-location records for downstream departments
- Creates package-consumption records
- Creates related store/inventory transactions
- Records invoice audit information
- Supports invoice printing and other patient-facing output
- Supports sending invoice and barcode/report links through the application's messaging mechanism
- Provides navigation to related payment and service-request functionality

## Technical Summary

| Component | Count |
| --- | ---: |
| Blocks | 5 |
| Items | 202 |
| Triggers | 95 |
| Program Units | 30 |
| LOVs | 15 |
| Relations | 2 |
| DB Packages | 1 |
| Report Objects | 1 |

These counts describe the legacy Oracle Forms module only. The migrated APEX reference implementation and its related backend components are documented separately under `APEX_Reference/`.

The Form contains the following blocks:

- `T_INV` - primary invoice-header database block
- `D_INV` - invoice service/detail database block
- `T_INV_TRANS_M` - related store/inventory transaction block based on `TRANS_M`
- `TOOL` - non-database utility and control block
- `TITLE` - non-database presentation block

The combination of **202 items, 95 triggers, and 30 program units** reflects the large amount of workflow and business logic embedded directly in the legacy Form.

## Main Database Objects

The Form interacts with a large number of database objects. Significant dependencies include the following.

### Primary Transaction Objects

- `T_INV`
- `D_INV`
- `TRANS_M`

`T_INV` stores invoice-level information.

`D_INV` stores the individual services and financial details associated with the invoice.

`TRANS_M` is used by the related transaction block for store/inventory transactions associated with an invoice.

### Patient and Visit Objects

- `PATIENT`
- `V_PAT_DATA`
- `PAT_VISIT_M`
- `DOC_DATES`
- `DOC_SEQ`

These objects support patient retrieval, doctor/clinic assignment, visit creation, and waiting/reservation sequence handling.

### Service and Pricing Objects

- `SERVICES`
- `SERVICECAT`
- `PRICE_PLAN_M`
- `PRICE_LIST_MASTER`
- `OFFERS`
- `OFFERS_DTL`

These objects support service availability, pricing, discounts, offer pricing, package behavior, and applicable price lists.

### Insurance and Payer Objects

- `COMPANYS`
- `DISC_CLASSES`
- `COMPANY_CAT`
- `PAY_TYPES`
- `CASH_CARD_DISC`
- `CASH_CARD_DISCDTL`

These objects participate in payer selection, insurance classes, patient/company cost sharing, deductibles, discounts, and payment handling.

### Service Request and Package Objects

- `PAT_SERV_REQ`
- `V_SERVICES_REQ`
- `PACKAGE_DTL`
- `PACKAGE_CONS_M`
- `PACKAGE_CONS`

These objects support importing requested services, approval-related behavior, package definitions, and package consumption.

### Downstream Service Location Objects

- `T_INV_LOCA`
- `D_INV_LOCA`

These objects are maintained when invoiced services need to be routed or tracked by service location.

### Operational and Supporting Objects

- `CASHIER_SHIFT`
- `HMISFOX_AUDIT`
- `PREF`
- `V_USER_PREV`
- `INVOICES_TYPE`
- `CURRENCIES`
- `PC_PRINT_DEF`
- `TRANS_DTL`
- `ITEMS`

This is a significant-object summary rather than an exhaustive dependency tree.

## Key Business Logic

The Form contains substantial embedded business logic covering several functional areas.

### Invoice Creation

When an invoice is created, the Form:

- Generates an invoice number using the shared `GET_NEXT_INVOICE_NO` function
- Verifies that the generated number is not already present
- Initializes invoice date, time, information center, and user context
- Determines whether the patient is new or existing
- Applies invoice-type behavior
- Associates the invoice with the current cashier shift when shift control is enabled

The current invoice-number implementation already uses a shared number-generation function. An older `MAX(INV_NO) + 1` implementation remains only as commented legacy code.

### Cashier Shift Control

When shift control is enabled, invoice creation checks whether the current user has exactly one active cashier shift.

The Form contains logic allowing invoice-administrator users to bypass some of these restrictions.

### Patient and Payer Resolution

Patient validation retrieves patient and payer information and determines:

- Company/payer
- Sub-company
- Insurance class
- Price plan
- Price list
- VAT applicability
- Policy information
- Approval limits
- Maximum deductible
- Cash versus credit behavior

The applicable pricing configuration can vary based on information center, company, insurance class, and other patient attributes.

### Service Entry and Pricing

Invoice services are maintained through the `D_INV` block.

Service-entry logic includes:

- Service selection
- Category selection
- Price retrieval
- Discount retrieval
- Quantity
- VAT
- Patient share
- Company share
- Fixed payment amounts
- Percentage payment amounts
- Approval requirements
- Insurance-specific calculations

Program units including `SMALL_CALC`, `DO_DISC`, `CHK_ADV_CLASS`, `OKA`, and `ROUND_FOR_CASH` participate in financial calculations and validation.

### Insurance and Deductible Logic

Insurance calculations vary according to:

- Payer/company
- Insurance class
- Service type
- Clinic type
- Deductible configuration
- Fixed-share configuration
- Percentage-share configuration

Specialized rules also exist for particular clinic categories and advanced insurance-class configurations.

### Requested Service Import

The Form can import services from existing patient service requests.

The import workflow:

- Retrieves pending requested services
- Checks approval status
- Prevents or warns about rejected services
- Determines whether approval is required
- Copies service, quantity, price, discount, and request information into the invoice
- Links the resulting invoice detail row back to the service request

### Offers and Packages

Cash invoices may use configured offers.

The Form can:

- Select an active offer
- Retrieve its services from `OFFERS_DTL`
- Add those services to the invoice
- Apply offer quantities and prices
- Recalculate the invoice

Package services can also result in creation or maintenance of package-consumption records in `PACKAGE_CONS_M` and `PACKAGE_CONS`.

### Visit and Queue Integration

When applicable, invoice creation participates in operational patient flow by:

- Creating a `PAT_VISIT_M` visit
- Associating the visit with the patient, doctor, clinic, invoice, and information center
- Allocating or updating doctor sequence information
- Supporting waiting/reservation-related behavior

### Service Location Processing

When invoiced services are associated with downstream service locations, the Form creates or updates:

- `T_INV_LOCA`
- `D_INV_LOCA`

Package services may generate location records for multiple component services.

### Store / Inventory Transactions

The Form contains functionality to generate related store transactions from invoiced services.

This processing creates records in:

- `TRANS_M`
- `TRANS_DTL`

and maps billable services to inventory items and quantities where applicable.

### Audit

Invoice creation and update actions write audit information to:

- `HMISFOX_AUDIT`

### Payment Handling

The Form supports payment information including:

- Primary and secondary payment methods
- Collected cash
- Paid amounts
- Remaining amount
- Refund/change calculation

A separate payment workflow can also be opened for an existing invoice.

## Forms Characteristics

- Five Forms blocks
- 202 items
- 95 triggers
- 30 program units
- 15 LOVs
- Two master-detail relationships
- Extensive item, block, and Form-level trigger logic
- Large amounts of embedded PL/SQL
- Complex financial calculations
- Insurance and payer-specific business rules
- Cashier-shift integration
- Patient visit integration
- Service-request import
- Package processing
- Store/inventory transaction generation
- Approval workflow logic
- Dynamic LOV and record-group behavior
- Global-variable and Form-parameter usage
- Cross-Form navigation
- Oracle Reports integration
- External URL generation
- Messaging integration
- Arabic/English interface behavior
- Shared Forms Object Library dependencies

## Master-Detail Relationships

The Form defines two Oracle Forms relationships.

### `T_INV_D_INV`

Links invoice details to the invoice header using:

`D_INV.INV_NO = T_INV.INV_NO`

This is the primary invoice header/detail relationship.

### `T_INV_T_INV_TRANS_M`

Links related store/inventory transactions back to the invoice using:

`T_INV_TRANS_M.IMP_FROM_T_INV_NO = T_INV.INV_NO`

The legacy Form contains Forms-generated coordination logic for querying, clearing, and validating these relationships.

## Legacy Dependencies

### Database Packages

The Form has one active Oracle database package dependency:

- `UTL_URL` - used to escape generated report URLs before opening or transmitting them

Forms built-ins such as `WEB.SHOW_DOCUMENT` and WebUtil functionality are not counted as Oracle database package dependencies.

### Database Functions / Procedures

The Form calls shared standalone database functions and procedures including:

- `GET_NEXT_INVOICE_NO`
- `GET_PRICE_PLAN`
- `GET_PAYID_VALUE`
- `GET_HTFN2`
- `GET_U_PREV20`
- `FIND_PROMPT`
- `SEND_MESSAG`

These dependencies are not included in the `DB Packages` count because they are not package-qualified calls.

### LOVs

The Form defines 15 LOVs:

- `APPROVED_SERV`
- `RESERV_NO`
- `CAT`
- `COMPANY1_2`
- `THE_CLASS`
- `SUB_COMPANY`
- `DOC1`
- `DOC`
- `CLINICS`
- `PATIENT`
- `PATIENT_TRANS`
- `SERVICES`
- `OFFERS`
- `PAY_TYPE1`
- `PAY_TYPE2`

These LOVs cover major workflow entities including patients, doctors, clinics, service categories, services, companies, insurance classes, offers, approved services, reservations, and payment methods.

The `SERVICES` LOV returns the selected service together with related pricing, discount, category, approval, SFDA-code, and VAT information used by invoice calculations.

### Other Forms

The Form contains active navigation to other Oracle Forms modules.

#### `INVOICE_PAYMENT`

Opened for the selected invoice and receives the current invoice number.

#### `phy_req_note`

Opened for a selected invoice-detail row to maintain or review related request notes.

#### `translate`

Opened to support legacy Form translation/localization maintenance.

### Reports / External Integrations

The Form contains one Oracle Forms Report object:

- `XX`

The object points to a legacy `nat.rdf` file path.

The active invoice workflow also references several Oracle Reports/JSP outputs, including:

- `inv_small_cash.jsp` - normal invoice output
- `inv_form2.jsp` - detailed invoice output
- `PAT_CARD_INV.jsp` - patient/invoice card or barcode output
- `iqama_check.jsp` - patient/Iqama-related output

The invoice print selection can dynamically choose between normal and detailed invoice formats.

The legacy implementation constructs Oracle Reports `rwservlet` URLs using runtime report-server configuration and opens them through Forms web functionality.

Some output flows can also send generated report links to the patient through the application's `SEND_MESSAG` mechanism.

### Shared Forms Libraries

The Form references shared Oracle Forms Object Libraries including:

- `BUSINESSXP.olb`
- `HMISTEXT.olb`
- `HMISCANVAS.olb`
- `HMISBUTTON.olb`

These libraries provide common visual, control, alert, button, and application behavior used by the legacy Forms application.

## APEX Reference Implementation

This sample has already been migrated to Oracle APEX and the completed implementation is included under `APEX_Reference/`.

The legacy Small Cash Invoice Form became:

- Page 48 - **Patient Invoice**
- Three Page 48 JavaScript files for client interaction, grid behavior, and preview synchronization
- `BIL_INVOICE_API` migration reference extract for Page 48 orchestration
- `BIL_IMPORT` for service-request, new-visit, and package import
- `BIL_INVOICE_ENGINE` for authoritative invoice calculation and persistence
- Backend architecture documentation
- Screenshots covering manual creation, request/new-visit workflows, and existing invoice view mode

The implementation does not reproduce the five legacy Forms blocks, 202 items, 95 triggers, and 30 program units one-to-one. The workflow was redesigned as a single APEX invoice workspace with an Interactive Grid and reusable server-side billing components.

### Page 48 Workflow

Page 48 supports:

- Manual invoice creation
- Invoice creation from existing service requests
- New-visit invoice creation
- Existing invoice view mode
- Cash and credit billing context
- Patient, clinic, doctor, payer, and invoice context
- Service-line entry and editing
- Package insertion and expansion
- Bundled Offer insertion and expansion
- Controlled discounts and price overrides
- Payment entry
- Final invoice creation
- Invoice printing
- Invoice messaging

The page changes its available controls according to the current mode and source workflow rather than relying on Forms windows and trigger sequencing.

### Authoritative Server-Side Calculation

The migrated page does not treat browser-calculated financial values as authoritative.

The complete editable invoice is sent to `BIL_INVOICE_ENGINE` for server-side calculation. The backend returns calculated values including gross amount, discounts, net amount, patient share, company share, VAT, cash amount due, payment amounts, remaining amount, and payment status.

Before final creation, the server calculates the invoice again from the submitted lines. Preview and persistence therefore use the same authoritative billing rules.

### Request and New-Visit Import

`BIL_IMPORT` converts upstream reception and clinical activity into invoice input.

For service requests, the migrated workflow preserves request identity, approval status, approval references, claim information, and related clinical detail while using session-scoped request selection so one APEX session cannot reuse another user's selections.

For new visits, the backend resolves the consultation or review service from the selected doctor, clinic, payer context, and current price list before building the invoice preview.

Requested or visit services that are packages are expanded before authoritative calculation.

### Packages

Packages use an explicit parent/component contract.

The package parent carries the authoritative package quantity. Component quantities are derived from the package setup quantity multiplied by the parent quantity.

The backend also retains package identity, parent/component role, component order, parent relationship, pricing method, and a package-definition token so changed package configuration can be detected before final invoice creation.

### Bundled Offers

Bundled Offers use an explicit occurrence model rather than the legacy Forms offer-loading behavior.

Page 48 displays the offer components while the logical zero-value parent row remains hidden from the user. Before preview and final creation, `BIL_INVOICE_API` reconstructs the parent and validates the submitted component evidence against the current offer definition.

Validation includes offer identity, component identity, quantities, prices, parent relationship, active state, and object-version evidence.

### Final Invoice Creation

`BIL_INVOICE_API.CREATE_FULL_INVOICE` coordinates the final workflow after the submitted invoice has been validated and recalculated.

The flow can coordinate:

- Invoice persistence
- Payment posting
- Doctor queue posting
- Stock posting
- Print URL generation
- Invoice messaging
- Request-id protection against accidental duplicate invoice creation

Payment, queue, stock, reporting, messaging, and other shared billing-rule implementations remain reusable application services outside the sample backend boundary.

### JavaScript Structure

The Page 48 client behavior is separated into application JavaScript files rather than being embedded entirely inside the page export:

- `page48-function-and-global-variable-declaration.js`
- `page48-invoice-preview.js`
- `page48-invoice-services-init.js`

The JavaScript handles interaction, grid behavior, asynchronous preview coordination, calculated-value application, and page state. Financial authority remains with the backend.

### Reliability and Concurrency

The migrated workflow includes protections appropriate for a transactional invoice page, including:

- Server-side validation before persistence
- Authoritative recalculation before creation
- Stale-preview response protection
- Cancellation or replacement of obsolete preview requests
- Action gating while relevant preview work is pending
- Package-definition validation
- Bundled Offer version and definition validation
- Duplicate-create request protection
- Controlled propagation of backend business errors

### Backend Reference Scope

The three SQL files under `APEX_Reference/backend/` expose the backend complexity needed to understand the Patient Invoice migration without publishing unrelated billing functionality.

`BIL_INVOICE_API` is intentionally scoped to the Page 48 orchestration path. `BIL_IMPORT` contains the source-to-invoice conversion logic used by this workflow. `BIL_INVOICE_ENGINE` retains the substantial pricing, discount, payer-share, VAT, package, offer, validation, total, and persistence logic because those rules represent a major part of the actual migration effort.

Shared packages such as payment, queue, stock, print, messaging, patient-context, service-context, pricing, class-share, and offer-rule services remain dependencies rather than being copied into this sample.

The APEX reference is not a standalone deployable billing subsystem. It depends on the surrounding application schema, shared packages, application context, configuration, tables, sequences, triggers, permissions, and other infrastructure.

The implementation is provided as a **reference for the expected migration approach and quality level**. It is not intended to require future Forms to be reproduced using the exact same page layout, JavaScript structure, package boundaries, or technical design.

The required business behavior should be preserved while avoiding unnecessary reproduction of Oracle Forms implementation patterns.

See [`APEX_Reference/README.md`](APEX_Reference/README.md) for the detailed migrated implementation and [`APEX_Reference/backend/README.md`](APEX_Reference/backend/README.md) for the backend reference boundary.

## Files

- `Inv_Small_Cash.fmb` - Original Oracle Forms module
- `Inv_Small_Cash.xml` - XML export of the Oracle Forms module
- `screenshot.png` - Screenshot of the current Oracle Forms user interface
- `APEX_Reference/` - Completed Oracle APEX reference implementation, page export, JavaScript, backend reference extracts, screenshots, and migration notes
