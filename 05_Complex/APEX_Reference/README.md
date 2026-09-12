# APEX Reference - Patient Invoice

## Purpose

This directory contains the migrated Oracle APEX implementation corresponding to the legacy Small Cash Invoice sample.

The implementation is provided as a **reference for the expected migration approach and quality level**. It is not intended to require future Forms to be reproduced using the exact same page structure or technical design.

During migration, legacy Forms functionality may be simplified, redesigned, consolidated, split across multiple APEX components, moved into reusable database APIs, or replaced with native APEX functionality where appropriate.

For this sample, the original Forms invoice workflow was redesigned as a single APEX Patient Invoice workspace supported by client-side interaction logic and a substantial server-side billing architecture.

## Migration Mapping

```text
Legacy Small Cash Invoice Form
            |
            v
Page 48 - Patient Invoice
            |
            +--> JavaScript interaction and grid behavior
            |
            +--> BIL_INVOICE_API
                    |
                    +--> BIL_IMPORT
                    |
                    +--> BIL_INVOICE_ENGINE
                    |
                    +--> shared payment, queue, stock, print and messaging services
```

The migration is not a one-to-one recreation of the Oracle Forms blocks, triggers, windows, and program units.

Instead, Page 48 acts as the user-facing workflow while authoritative billing rules are executed on the server.

## Page 48 - Patient Invoice

Page 48 is the main migrated invoice workspace.

It supports multiple operating contexts within one page rather than requiring separate Forms-style windows or duplicated invoice logic.

The page supports:

- Manual invoice creation
- Invoice creation from existing service requests
- New-visit invoice creation
- Existing invoice view mode
- Cash and credit billing context
- Patient, clinic, doctor, payer, and invoice context
- Service-line entry and editing
- Package insertion and expansion
- Bundled Offer insertion and expansion
- Discounts and controlled price overrides where permitted
- Automatic server-side recalculation of invoice totals
- Payment entry
- Final invoice creation
- Invoice printing
- Invoice messaging

The page changes its available controls and behavior according to the current mode and source workflow.

## Invoice Services Grid

Invoice services are maintained through an APEX Interactive Grid rather than the multiple Oracle Forms data blocks used by the legacy module.

The grid represents both user-editable values and calculated billing values, including areas such as:

- Service
- Quantity
- Unit price
- Discount
- Net amount
- Patient share
- Company share
- VAT
- Approval information
- Package membership
- Bundled Offer membership

Calculated financial columns are returned by the backend and are not treated as browser-authoritative values.

The grid also carries technical evidence required to validate package and Bundled Offer structures during server-side preview and final invoice creation.

## Authoritative Preview

One of the major modernization changes is the invoice preview model.

Page 48 sends the complete editable invoice state to the backend for calculation. The server recalculates all lines together using the same billing rules used by final invoice creation.

The authoritative preview calculates values such as:

- Gross amount
- Plan discount
- Manual discount
- Net amount
- Patient share
- Company share
- Patient VAT
- Company VAT
- Cash amount due
- Payment amounts
- Remaining amount
- Payment status

The browser displays the results but does not become the source of truth for the financial calculation.

Before final creation, the invoice is calculated again from the submitted line data so invoice persistence does not depend on a previously displayed browser preview.

## Request and New-Visit Import

The legacy invoice workflow contains significant logic for creating invoice lines from upstream clinical and reception activity.

The migrated implementation handles these sources through `BIL_IMPORT` and the Page 48 import-preview workflow.

### Service Requests

Selected service requests can be converted into invoice lines while preserving relevant request information such as:

- Request row identity
- Approval requirement and status
- Approval reference
- Approval validity
- Claim information
- Tooth and surface information where applicable

Request selections are session-scoped so one user's selected request lines do not leak into another APEX session.

Requested packages are expanded into their complete package structure before invoice calculation.

### New Visits

For new-visit invoicing, the backend resolves the appropriate consultation or review service using the selected doctor, clinic, payer context, and current price list.

If the resolved visit service is itself a package, the package is expanded before the invoice preview is built.

The imported source is therefore treated as input to the billing engine, not as trusted final invoice pricing.

## Packages

Packages are represented using an explicit parent-and-component contract rather than relying on implicit Forms cursor behavior.

The package parent identifies the package occurrence and acts as the authoritative quantity multiplier.

Component quantities are derived from:

```text
Package setup quantity x Parent quantity
```

The backend retains package evidence including:

- Package service
- Package instance
- Parent/component role
- Component order
- Parent relationship
- Package pricing method
- Package definition token

The package definition token allows the backend to detect when package configuration has changed between selection and final invoice creation.

Package pricing and discount behavior remains controlled by the server-side billing engine.

## Bundled Offers

Bundled Offers are supported directly from the invoice workspace.

The user-facing grid displays the bundle components while the logical zero-value parent row is hidden from the user interface.

Before authoritative preview and final invoice creation, `BIL_INVOICE_API` reconstructs the complete bundle occurrence and validates the submitted evidence against the current Bundled Offer definition.

Validation includes areas such as:

- Offer identity
- Offer occurrence identity
- Component identity
- Component quantity
- Offer price
- Parent relationship
- Header and detail object-version evidence
- Active offer/component state

This provides a simpler grid experience while preserving server-side integrity.

## Final Invoice Creation

Final invoice creation is coordinated through `BIL_INVOICE_API.CREATE_FULL_INVOICE`.

The workflow recalculates and persists the invoice through `BIL_INVOICE_ENGINE` and can then coordinate downstream operations including:

- Payment posting
- Doctor queue posting
- Stock posting
- Print URL generation
- Invoice messaging

The creation flow also supports a request identifier used to protect against accidental duplicate invoice creation when a browser or network action is repeated.

The detailed implementations of payment, queue, stock, reporting, and messaging are shared application services and are not included in this sample.

## Backend Reference

The backend directory contains three migration reference files:

### `BIL_INVOICE_API.sql`

The Page 48 orchestration layer.

It exposes only the operations required to demonstrate the Patient Invoice workflow, including Bundled Offers, package loading, authoritative preview, import preview, final creation, printing, and messaging.

### `BIL_IMPORT.sql`

The source-import layer used for service requests, new visits, and package expansion.

### `BIL_INVOICE_ENGINE.sql`

The authoritative calculation and persistence engine.

This is intentionally the largest backend file because it contains the core financial and validation logic that represents a significant part of the migration effort.

See [`backend/README.md`](backend/README.md) for the detailed backend boundary and dependency explanation.

## JavaScript Architecture

Page 48 uses application JavaScript files rather than placing all client behavior directly inside the APEX page export.

The included files are:

### `page48-function-and-global-variable-declaration.js`

Contains shared Page 48 client functions and state used by the invoice workflow.

### `page48-invoice-preview.js`

Coordinates the editable invoice preview, request sequencing, calculated-value application, failure handling, stale-response protection, and preview-related UI state.

### `page48-invoice-services-init.js`

Initializes the Invoice Services grid and its page-specific behavior.

Client-side code is used for interaction, presentation, and synchronization. Financial authority remains with the backend.

## Reliability and Concurrency

The migrated implementation includes protections that are important for a transactional invoice page:

- Server-side validation before persistence
- Authoritative recalculation before creation
- Protection against stale asynchronous preview responses
- Cancellation or replacement of obsolete preview requests
- Prevention of actions while a relevant preview is still pending
- Package-definition validation
- Bundled Offer definition and object-version validation
- Duplicate-create request protection
- Controlled backend business-error propagation to the page

These protections are part of the migration quality expected for workflows where browser state and database state can change independently.

## Key Modernization Changes

The migrated implementation differs substantially from the legacy Oracle Forms architecture.

Key changes include:

- Multiple Forms blocks and trigger-driven interactions were consolidated into one APEX invoice workspace.
- Service maintenance moved to an Interactive Grid.
- Pricing and financial calculations were centralized in reusable backend components.
- Preview and final creation use the same authoritative server-side billing rules.
- Request selections are scoped to the current APEX application session and user.
- Package handling uses explicit parent/component contracts and definition evidence.
- Bundled Offers use explicit occurrence and version evidence.
- Browser-calculated values are not trusted for invoice persistence.
- Repeated create requests are protected from accidental duplicate invoice creation.
- Payment, queue, stock, printing, and messaging are coordinated through reusable domain services.
- Forms-specific navigation, window behavior, built-ins, and trigger sequencing were replaced with APEX page state, processes, dynamic interaction, and reusable APIs.
- Long client-side behavior was separated into application JavaScript files rather than being embedded entirely in the page export.

The objective is to preserve required billing behavior while avoiding unnecessary reproduction of Oracle Forms implementation patterns.

## Shared Dependencies

This reference relies on wider HMIS billing and application infrastructure that is not fully included in the sample.

Examples include:

- Patient-context resolution
- Service-context resolution
- Price rules
- Insurance and class-share rules
- Bundled Offer rules
- Payment posting
- Doctor queue posting
- Stock posting
- Reporting and print URL generation
- Messaging
- Application permissions and session context
- Cashier-shift rules and configuration where applicable

The sample also depends on the surrounding database schema, including invoice, service, pricing, package, offer, request, visit, doctor, and supporting configuration tables.

The reference is therefore **not a standalone deployable billing subsystem**.

## Reference Scope

The implementation is intended to demonstrate how a complex Oracle Forms transaction can be modernized without reproducing the original Forms architecture one-to-one.

The required business behavior should be preserved while allowing the implementation to use:

- Native APEX components
- Reusable server-side APIs
- Explicit domain boundaries
- Centralized financial rules
- Safer session handling
- Stronger transactional validation
- Modern asynchronous user interaction

A future migration does not need to reproduce this exact page layout, JavaScript structure, or package organization. The important requirement is to retain the required business behavior and an equivalent level of integrity, maintainability, and usability.

## Files

- `hmisfox_page_48.apx` - Oracle APEX Page 48, Patient Invoice
- `javascript/page48-function-and-global-variable-declaration.js` - shared Page 48 client functions and state
- `javascript/page48-invoice-preview.js` - invoice preview and synchronization logic
- `javascript/page48-invoice-services-init.js` - Invoice Services grid initialization
- `backend/BIL_INVOICE_API.sql` - Patient Invoice orchestration migration reference extract
- `backend/BIL_IMPORT.sql` - request, visit, and package import backend
- `backend/BIL_INVOICE_ENGINE.sql` - authoritative invoice calculation and persistence engine
- `backend/README.md` - backend architecture and reference-boundary documentation
- `screenshots/screenshot-p48-manual.png` - manual invoice workflow
- `screenshots/screenshot-p48-request-x-new-visit.png` - request and new-visit workflow reference
- `screenshots/screenshot-p48-view.png` - existing invoice view mode
