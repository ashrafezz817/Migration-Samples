# APEX Reference - Bundled Offers

## Purpose

This directory contains the migrated Oracle APEX implementation corresponding to the legacy `disc_packages` Oracle Form.

The implementation is provided as a **reference for the expected migration approach and quality level**. It is not intended to require future Forms to be reproduced using the exact same page structure or technical design.

During migration, legacy Forms functionality may be simplified, redesigned, split across multiple APEX pages, moved into reusable database APIs, or replaced with native APEX functionality where appropriate.

The required business behavior should be preserved while avoiding unnecessary reproduction of Forms-specific implementation patterns.

## Migration Mapping

The legacy discount-package maintenance Form was migrated to:

* **Oracle APEX Page 63 - Bundled Offers**
* **Oracle APEX Page 64 - Manage Bundled Offer**
* **`BIL_OFFERS_ADMIN`** - backend API used for bundled-offer header, pricing, and component operations

The original master-detail Forms screen was redesigned as a bundle-management workspace with a separate modal page for bundle-header maintenance.

Page 63 handles bundle discovery, overview, component maintenance, and financial presentation.

Page 64 handles bundle creation, header updates, and retirement.

The backend package centralizes transactional business rules that should not depend on APEX page state alone.

## APEX Pages

### Page 63 - Bundled Offers

Page 63 is the main management page for bundled offers.

The page provides:

* A searchable list of bundled offers
* Selection of a bundle for detailed review
* A bundle overview showing status, dates, pricing, totals, and savings
* An Interactive Grid for the services included in the selected bundle
* Add, update, and remove operations for bundle components
* Service pricing lookup when components are selected or changed
* Empty-state handling when no bundle is selected or no matching records are available
* Read-only behavior for retired bundled offers

Bundled offers are scoped to the current information center through `G_INFO_CENTER_ID` and are distinguished from other offer types using the bundled-offer type value.

The component grid works with `OFFERS_DTL` records associated with the selected `OFFERS` header.

Component operations are authorized separately from bundle-header operations through the application's authorization model.

### Bundle Component Processing

Page 63 delegates important component operations to `BIL_OFFERS_ADMIN`.

The page uses:

* `GET_BUNDLE_COMPONENT_PRICING`
* `ADD_BUNDLE_COMPONENT`
* `UPDATE_BUNDLE_COMPONENT`
* `REMOVE_BUNDLE_COMPONENT`

The pricing operation retrieves the original service price, original discount, and VAT rate using the bundle's current cash price-list context.

The add, update, and remove operations perform server-side validation and recalculate bundle totals after component changes.

### Page 64 - Manage Bundled Offer

Page 64 is implemented as a modal dialog for creating and maintaining the bundle header.

The page maintains:

* Bundle name
* Start date
* End date
* Validity days
* Description

The page supports three separate business actions:

* Create bundled offer
* Update bundled offer
* Retire bundled offer

These operations are controlled through application permissions including:

* `BILLING_BUNDLED_OFFERS_CREATE`
* `BILLING_BUNDLED_OFFERS_UPDATE`
* `BILLING_BUNDLED_OFFERS_RETIRE`

The page validates that the end date does not precede the start date and that validity days are a supported whole-number value.

Header operations are delegated to `BIL_OFFERS_ADMIN` rather than implemented as direct page DML.

## Backend API

### `BIL_OFFERS_ADMIN`

The backend file included in this sample is a **migration reference extract** containing only the package functionality required by Pages 63 and 64.

Additional production package functionality unrelated to bundled offers is intentionally not included.

The extract exposes the following bundled-offer operations:

#### Bundle Header

* `CREATE_BUNDLED_OFFER`
* `UPDATE_BUNDLED_OFFER`
* `RETIRE_BUNDLED_OFFER`

#### Bundle Components

* `GET_BUNDLE_COMPONENT_PRICING`
* `ADD_BUNDLE_COMPONENT`
* `UPDATE_BUNDLE_COMPONENT`
* `REMOVE_BUNDLE_COMPONENT`

The extract also contains the private validation, pricing, information-center, total-recalculation, and concurrency helpers required by those operations.

## Key Modernization Changes

### Forms Master-Detail Replaced with an APEX Management Workspace

The legacy Form used Forms master-detail blocks and a Forms relation to coordinate `OFFERS` and `OFFERS_DTL`.

The migrated implementation does not reproduce that architecture directly.

Instead:

* Page 63 presents the bundle list and selected bundle overview.
* The component detail records are maintained through an Interactive Grid.
* Page 64 handles bundle-header creation and maintenance in a modal dialog.
* Backend APIs coordinate transactional rules between the header and components.

This preserves the business relationship while using APEX interaction patterns that are easier to maintain and understand.

### Identifier Generation

The legacy Form generated identifiers using `MAX(...) + 1` patterns.

The migrated implementation relies on database-managed identifier generation when bundle headers and component rows are inserted.

Identifier allocation is therefore no longer calculated from the current maximum value in the APEX page.

### Pricing Centralized in the Backend

The legacy Form contained pricing lookup logic directly in Forms triggers and LOV behavior.

The migrated implementation resolves component pricing through `BIL_OFFERS_ADMIN`.

The backend validates the selected service against the bundle's cash price-list context and retrieves the applicable:

* Original unit price
* Original discount
* VAT rate

This keeps pricing rules on the server rather than trusting values supplied only by the browser.

### Server-Side Bundle Totals

Bundle totals are recalculated after component changes.

The backend derives the original total and bundled total from the active detail rows and updates the bundle header.

This prevents the saved financial totals from depending only on client-side calculations.

### Component Validation

The backend validates bundle component rules including:

* Service availability in the applicable pricing context
* Duplicate active services
* Required quantity
* Positive whole-number quantity limits
* Required bundle component price
* Nonnegative pricing
* Supported decimal precision
* Bundle price not exceeding the original unit price

These rules remain enforced even if the backend is called outside the Page 63 user interface.

### Optimistic Locking

The migrated implementation uses `OBJECT_VERSION_NUMBER` for concurrency control on both bundle headers and component rows.

Update and remove operations receive the expected object version and reject stale changes when another session has already modified the record.

This replaces reliance on the single-user interaction assumptions common in legacy Forms workflows.

### Retirement Instead of Destructive Deletion

Bundles and components use retirement or logical deletion behavior rather than relying only on destructive record deletion.

Retiring a bundle marks the bundle and its active components as deleted while preserving the records and retirement reason.

Page 63 can therefore distinguish active and retired states, and retired bundles are not editable through the normal component workflow.

### Information-Center Scoping

Bundle operations are scoped to the current application information center.

The backend validates the application context before managing a bundle, and the APEX queries also restrict records using `G_INFO_CENTER_ID`.

This prevents a bundle from another information center from being managed through the current session.

### Centralized Authorization

The migration replaces Forms operation-level security behavior with the target application's permission and authorization model.

Permissions are applied to bundle creation, update, retirement, and component maintenance rather than reproducing Forms block-property security logic.

### Improved User Experience

The migrated Page 63 provides a more task-focused interface than the original Forms master-detail screen.

Examples include:

* Searchable bundle selection
* Dedicated bundle overview
* Visible financial savings
* Interactive component maintenance
* Responsive presentation
* Explicit empty states
* Separate modal header maintenance
* Clear retired-state behavior

## Shared Dependencies

The reference implementation relies on application and database components outside this sample, including:

* `OFFERS`
* `OFFERS_DTL`
* `SERVICES`
* `PRICE_PLAN_M`
* `PRICE_PLAN_DTL`
* `PRICE_LIST_MASTER`
* `INSURANCE_NET_WORKS`
* `INS_COMP_UTIL`
* `FND_APP_SECURITY`
* `G_INFO_CENTER_ID` application context
* Shared APEX authorization schemes
* Shared application badge and empty-state styling

These components are part of the wider application architecture and are not necessarily included in this sample.

Therefore, the files in this directory should be treated as a **migration reference**, not as a standalone deployable application.

## Reference Scope

This implementation demonstrates the preferred modernization principle:

**Preserve the business workflow, but do not reproduce Oracle Forms architecture unnecessarily.**

A future migration does not need to use the same number of APEX pages, regions, grids, processes, or database APIs.

The appropriate design should depend on the functionality and complexity of the individual Form while following the same general objectives:

* Preserve required business behavior
* Move reusable and transactional business rules into appropriate backend APIs
* Keep pricing and financial validation on the server
* Use optimistic locking where concurrent maintenance is possible
* Enforce authorization through the target application's permission model
* Use native APEX capabilities where appropriate
* Replace unsafe legacy identifier-generation patterns
* Remove obsolete Forms-specific coordination logic
* Improve maintainability and user experience

## Files

* `hmisfox_page_63.apx` - Oracle APEX Page 63 export for the Bundled Offers management page
* `hmisfox_page_64.apx` - Oracle APEX Page 64 export for the Manage Bundled Offer modal dialog
* `backend/BIL_OFFERS_ADMIN.sql` - migration reference extract containing bundled-offer backend operations and required private helpers
* `screenshots/screenshot-p63.png` - Bundled Offers page with a selected bundle
* `screenshots/screenshot-p63-empty-state.png` - Bundled Offers empty-state example
* `screenshots/screenshot-p64.png` - Manage Bundled Offer modal dialog
