# Small Cash Invoice

## Purpose

Provides the operational outpatient invoicing workflow used to create and manage patient invoices, add billable services, calculate patient and payer amounts, apply pricing and discount rules, collect payment information, and initiate related clinical and financial processes.

## Complexity

**Complex**

This Form represents a highly integrated operational workflow with multiple interacting data blocks, extensive trigger-based business logic, pricing and insurance calculations, approval handling, package processing, cashier-shift controls, visit creation, service-request integration, reporting, payment processing, and downstream transaction updates.

A significant portion of the business behavior is implemented directly inside Oracle Forms triggers and program units.

## Main Functionality

* Creates and maintains outpatient invoices
* Selects and validates patients
* Determines cash or credit/insurance billing behavior
* Determines the applicable price plan and price list
* Associates invoices with doctors and clinics
* Adds individual billable services
* Retrieves service prices, discounts, VAT rates, and service metadata
* Calculates patient and company/payer shares
* Applies insurance class and deductible rules
* Supports cash-card discounts
* Supports discount offers and packages
* Imports previously requested services into the invoice
* Handles services requiring approval
* Supports multiple payment methods
* Calculates invoice totals, discounts, VAT, collected amounts, and remaining amounts
* Enforces cashier-shift requirements when configured
* Creates or updates related patient visit information
* Adds patients to applicable doctor/waiting workflows
* Maintains service-location records for downstream departments
* Creates package-consumption records
* Creates related store/inventory transactions
* Records invoice audit information
* Supports invoice printing and other patient-facing output
* Supports sending invoice and barcode/report links through the application's messaging mechanism
* Provides navigation to related payment and service-request functionality

## Technical Summary

| Component      | Count |
| -------------- | ----: |
| Blocks         |     5 |
| Items          |   202 |
| Triggers       |    95 |
| Program Units  |    30 |
| LOVs           |    15 |
| Relations      |     2 |
| DB Packages    |     1 |
| Report Objects |     1 |

The Form contains the following blocks:

* `T_INV` - primary invoice-header database block
* `D_INV` - invoice service/detail database block
* `T_INV_TRANS_M` - related store/inventory transaction block based on `TRANS_M`
* `TOOL` - non-database utility and control block
* `TITLE` - non-database presentation block

The combination of **202 items, 95 triggers, and 30 program units** reflects the large amount of workflow and business logic embedded directly in the legacy Form.

## Main Database Objects

The Form interacts with a large number of database objects. Significant dependencies include the following.

### Primary Transaction Objects

* `T_INV`
* `D_INV`
* `TRANS_M`

`T_INV` stores invoice-level information.

`D_INV` stores the individual services and financial details associated with the invoice.

`TRANS_M` is used by the related transaction block for store/inventory transactions associated with an invoice.

### Patient and Visit Objects

* `PATIENT`
* `V_PAT_DATA`
* `PAT_VISIT_M`
* `DOC_DATES`
* `DOC_SEQ`

These objects support patient retrieval, doctor/clinic assignment, visit creation, and waiting/reservation sequence handling.

### Service and Pricing Objects

* `SERVICES`
* `SERVICECAT`
* `PRICE_PLAN_M`
* `PRICE_LIST_MASTER`
* `OFFERS`
* `OFFERS_DTL`

These objects are used to determine available services, prices, discounts, offer pricing, package behavior, and applicable price lists.

### Insurance and Payer Objects

* `COMPANYS`
* `DISC_CLASSES`
* `COMPANY_CAT`
* `PAY_TYPES`
* `CASH_CARD_DISC`
* `CASH_CARD_DISCDTL`

These objects participate in payer selection, insurance classes, patient/company cost sharing, deductibles, discounts, and payment handling.

### Service Request and Package Objects

* `PAT_SERV_REQ`
* `V_SERVICES_REQ`
* `PACKAGE_DTL`
* `PACKAGE_CONS_M`
* `PACKAGE_CONS`

These objects support importing requested services, approval-related behavior, package definitions, and package consumption.

### Downstream Service Location Objects

* `T_INV_LOCA`
* `D_INV_LOCA`

These objects are maintained when invoiced services need to be routed or tracked by service location.

### Operational and Supporting Objects

* `CASHIER_SHIFT`
* `HMISFOX_AUDIT`
* `PREF`
* `V_USER_PREV`
* `INVOICES_TYPE`
* `CURRENCIES`
* `PC_PRINT_DEF`
* `TRANS_DTL`
* `ITEMS`

This list identifies significant dependencies visible in the Form and is not intended to be an exhaustive dependency tree.

## Key Business Logic

The Form contains substantial embedded business logic covering several functional areas.

### Invoice Creation

When an invoice is created, the Form:

* Generates an invoice number using the shared `GET_NEXT_INVOICE_NO` function
* Verifies that the generated number is not already present
* Initializes invoice date, time, information center, and user context
* Determines whether the patient is new or existing
* Applies invoice-type behavior
* Associates the invoice with the current cashier shift when shift control is enabled

The current invoice-number implementation already uses a shared number-generation function; an older `MAX(INV_NO) + 1` implementation remains only as commented legacy code.

### Cashier Shift Control

When shift control is enabled, invoice creation checks whether the current user has exactly one active cashier shift.

The Form contains logic allowing invoice-administrator users to bypass some of these restrictions.

### Patient and Payer Resolution

Patient validation retrieves patient and payer information and determines:

* Company/payer
* Sub-company
* Insurance class
* Price plan
* Price list
* VAT applicability
* Policy information
* Approval limits
* Maximum deductible
* Cash versus credit behavior

The applicable pricing configuration can vary based on information center, company, insurance class, and other patient attributes.

### Service Entry and Pricing

Invoice services are maintained through the `D_INV` block.

Service-entry logic includes:

* Service selection
* Category selection
* Price retrieval
* Discount retrieval
* Quantity
* VAT
* Patient share
* Company share
* Fixed payment amounts
* Percentage payment amounts
* Approval requirements
* Insurance-specific calculations

Several program units, including `SMALL_CALC`, `DO_DISC`, `CHK_ADV_CLASS`, `OKA`, and `ROUND_FOR_CASH`, participate in financial calculations and validation.

### Insurance and Deductible Logic

Insurance calculations vary according to:

* Payer/company
* Insurance class
* Service type
* Clinic type
* Deductible configuration
* Fixed-share configuration
* Percentage-share configuration

Specialized rules also exist for particular clinic categories and advanced insurance-class configurations.

### Requested Service Import

The Form can import services from existing patient service requests.

The import workflow:

* Retrieves pending requested services
* Checks approval status
* Prevents or warns about rejected services
* Determines whether approval is required
* Copies service, quantity, price, discount, and request information into the invoice
* Links the resulting invoice detail row back to the service request

### Offers and Packages

Cash invoices may use configured offers.

The Form can:

* Select an active offer
* Retrieve its services from `OFFERS_DTL`
* Add those services to the invoice
* Apply offer quantities and prices
* Recalculate the invoice

Package services can also result in creation or maintenance of package-consumption records in `PACKAGE_CONS_M` and `PACKAGE_CONS`.

### Visit and Queue Integration

When applicable, invoice creation participates in operational patient flow by:

* Creating a `PAT_VISIT_M` visit
* Associating the visit with the patient, doctor, clinic, invoice, and information center
* Allocating or updating doctor sequence information
* Supporting waiting/reservation-related behavior

### Service Location Processing

When invoiced services are associated with downstream service locations, the Form creates or updates:

* `T_INV_LOCA`
* `D_INV_LOCA`

Package services may generate location records for multiple component services.

### Store / Inventory Transactions

The Form contains functionality to generate related store transactions from invoiced services.

This processing creates records in:

* `TRANS_M`
* `TRANS_DTL`

and maps billable services to inventory items and quantities where applicable.

### Audit

Invoice creation and update actions write audit information to:

* `HMISFOX_AUDIT`

### Payment Handling

The Form supports payment information including:

* Primary and secondary payment methods
* Collected cash
* Paid amounts
* Remaining amount
* Refund/change calculation

A separate payment workflow can also be opened for an existing invoice.

## Forms Characteristics

* Five Forms blocks
* 202 items
* 95 triggers
* 30 program units
* 15 LOVs
* Two master-detail relationships
* Extensive item, block, and Form-level trigger logic
* Large amounts of embedded PL/SQL
* Complex financial calculations
* Insurance and payer-specific business rules
* Cashier-shift integration
* Patient visit integration
* Service-request import
* Package processing
* Store/inventory transaction generation
* Approval workflow logic
* Dynamic LOV and record-group behavior
* Global-variable and Form-parameter usage
* Cross-Form navigation
* Oracle Reports integration
* External URL generation
* Messaging integration
* Arabic/English interface behavior
* Shared Forms Object Library dependencies

## Dependencies

### Database Packages

The Form contains one identified active Oracle database package dependency:

* `UTL_URL` — used to escape generated report URLs before opening or transmitting them

Forms built-ins such as `WEB.SHOW_DOCUMENT` and WebUtil functionality are not counted as Oracle database package dependencies.

### Database Functions / Procedures

The Form references numerous shared standalone database functions and procedures.

Examples include:

* `GET_NEXT_INVOICE_NO`
* `GET_PRICE_PLAN`
* `GET_PAYID_VALUE`
* `GET_HTFN2`
* `GET_U_PREV20`
* `FIND_PROMPT`
* `SEND_MESSAG`

Additional standalone database dependencies may exist within the Form and shared application infrastructure.

These dependencies are not included in the `DB Packages` count because they are not package-qualified calls.

### LOVs

The Form defines 15 LOVs:

* `APPROVED_SERV`
* `RESERV_NO`
* `CAT`
* `COMPANY1_2`
* `THE_CLASS`
* `SUB_COMPANY`
* `DOC1`
* `DOC`
* `CLINICS`
* `PATIENT`
* `PATIENT_TRANS`
* `SERVICES`
* `OFFERS`
* `PAY_TYPE1`
* `PAY_TYPE2`

These LOVs cover major workflow entities including:

* Patients
* Doctors
* Clinics
* Service categories
* Services
* Companies
* Insurance classes
* Offers
* Approved services
* Reservations
* Payment methods

The `SERVICES` LOV returns not only the selected service but also related pricing, discount, category, approval, SFDA-code, and VAT information used by invoice calculations.

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

## Other Forms

The Form contains active navigation to other Oracle Forms modules.

### `INVOICE_PAYMENT`

Opened for the selected invoice and receives the current invoice number.

### `phy_req_note`

Opened for a selected invoice-detail row to maintain or review related request notes.

### `translate`

Opened to support legacy Form translation/localization maintenance.

These workflows will need equivalent navigation or integrated functionality in the target APEX application.

## Reports and External Output

### Forms Report Object

The XML contains one Oracle Forms Report object:

* `XX`

The object points to a legacy `nat.rdf` file path.

Its relevance to the current invoicing workflow should be verified during migration because the active invoice-printing workflow primarily uses direct report-server URLs rather than this Report object.

### Active Report / JSP Dependencies

The Form contains active references to several Oracle Reports/JSP outputs, including:

* `inv_small_cash.jsp` — normal invoice output
* `inv_form2.jsp` — detailed invoice output
* `PAT_CARD_INV.jsp` — patient/invoice card or barcode output
* `iqama_check.jsp` — patient/Iqama-related output

The invoice print selection can dynamically choose between the normal and detailed invoice formats.

The legacy implementation constructs Oracle Reports `rwservlet` URLs using runtime report-server configuration and opens them through Forms web functionality.

Some output flows can also send generated report links to the patient through the application's `SEND_MESSAG` mechanism.

## Shared Forms Libraries

The Form references shared Oracle Forms Object Libraries including:

* `BUSINESSXP.olb`
* `HMISTEXT.olb`
* `HMISCANVAS.olb`
* `HMISBUTTON.olb`

These libraries provide common visual, control, alert, button, and application behavior used by the legacy Forms application.

## Migration Considerations

This Form should not be approached as a literal one-to-one conversion of a 202-item Oracle Forms screen.

The migration should preserve the required business workflow while separating the UI, transactional services, financial calculations, security, and integrations into maintainable components.

Key considerations include:

* Invoice creation, invoice details, pricing, VAT, discounts, insurance sharing, and payment calculations should be centralized in reusable server-side database APIs rather than distributed across APEX page processes and JavaScript.
* Creation of the invoice and its related visit, service-location, package, audit, and other required records should have clearly defined transactional boundaries.
* The existing `GET_NEXT_INVOICE_NO` mechanism should be reviewed for concurrency and uniqueness guarantees before being retained or replaced.
* Other legacy number-generation logic using `MAX(...) + 1` should be identified and replaced where concurrent use could produce duplicate values.
* The `T_INV` / `D_INV` relationship should use database referential integrity and a suitable APEX master-detail or transactional editing interface.
* Forms-generated coordination units such as `QUERY_MASTER_DETAILS`, `CLEAR_ALL_MASTER_DETAILS`, and `CHECK_PACKAGE_FAILURE` do not require direct equivalents in APEX.
* Cashier-shift requirements and administrator bypass rules should be enforced through centralized backend business rules and the target authorization model.
* Pricing rules must produce the same results for cash, direct-company, insurance, class-based, package, and offer scenarios.
* Patient share, payer share, deductibles, VAT, discounts, rounding, and split-payment calculations require dedicated regression testing against the legacy system.
* Approval-required and rejected service-request behavior must be preserved when requested services are imported.
* Offer and package behavior should use the same centralized package/pricing rules as the migrated Discount Packages functionality.
* Package-consumption and downstream service-location updates should not depend on client-side navigation or trigger order.
* Creation of `TRANS_M` / `TRANS_DTL` store transactions is a downstream business process and must be included explicitly in the migration scope.
* Direct Oracle Reports `rwservlet` URL construction should be replaced with the target reporting architecture.
* Report-server credentials or connection information should not be exposed through browser-visible URLs.
* Client-specific file paths and direct printer handling should be redesigned for the web environment.
* Legacy Forms globals and module parameters should be replaced by controlled APEX session context, application settings, or backend configuration.
* Authorization should use the target application's centralized permission model instead of dynamically changing Forms block/item properties.
* Legacy `WHEN OTHERS THEN NULL` exception handlers should be reviewed carefully because they can suppress business and technical errors.
* Commented, obsolete, and customer-specific branches should be identified before migration so unused legacy behavior is not unnecessarily reproduced.
* The large amount of trigger-based behavior should be decomposed into documented business services rather than transferred directly into page-level APEX logic.
* The migrated workflow should be regression-tested using representative cash, insured, discounted, package, approval-required, and multi-payment invoice scenarios.

## Files

* `Inv_Small_Cash.fmb` — Original Oracle Forms module
* `Inv_Small_Cash.xml` — XML export for source inspection and analysis
* `screenshot.png` — Screenshot of the current Oracle Forms user interface

