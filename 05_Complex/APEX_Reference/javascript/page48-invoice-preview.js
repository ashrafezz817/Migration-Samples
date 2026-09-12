/* ============================================================================
 * Namespace: p48InvoicePreview
 * Purpose  : Calculate editable invoice lines through the authoritative Page 48
 *            backend preview contract.
 * Point 2  : Enforce backend-controlled manual-discount eligibility.
 * Point 3  : Protect package and bundled-offer fields without disabling the
 *            reusable Interactive Grid column editors.
 * Point 3C : Allow package-parent QTY as the authoritative occurrence
 *            multiplier; component quantities remain backend-derived.
 * Mixed-line fix: Preserve required SERVICEID/QTY values while users move among
 *                 package, bundle, standard-offer, and normal service rows.
 * Point 4  : Use only documented model.setValue calls; no direct record-array
 *            mutation or query-only fallback writes.
 * ========================================================================== */

window.p48InvoicePreview = (function(apex, $) {
    "use strict";

    var REGION_ID = "invoice_services";
    var PROCESS_NAME =
        "CALCULATE_EDITABLE_INVOICE_PREVIEW";
    var requiredModelColumns = [
        "SERVICEID",
        "SERVICEDESC",
        "QTY",

        "PRICE",
        "MY_PRICE",
        "MY_NET",
        "THE_PAY",
        "THE_COMP",

        "DISCOUNT_TYPE",
        "DISC",
        "MY_DISC",

        "PRICE_OVERRIDE",
        "USE_PRICE_OVERRIDE",

        "PLAN_DISCOUNT_PCT",
        "PLAN_DISCOUNT_AMOUNT",
        "DISCOUNT_SOURCE",
        "EFFECTIVE_DISCOUNT_PCT",
        "TOTAL_DISCOUNT_AMOUNT",

        "VAT_RATE",
        "VAT_VAL_PAT",
        "VAT_VAL_CO",

        "REQ_NEED_A",
        "REQ_A_STATUS",

        "PACKAGE_SERVICE_ID",
        "PACKAGE_INSTANCE_ID",
        "PACKAGE_LINE_ROLE",
        "PACKAGE_COMPONENT_ORDER",
        "PACKAGE_PARENT_LINE_ID",
        "PACKAGE_PRICING_METHOD",
        "PACKAGE_DEFINITION_TOKEN",

        "OFFER_ID",
        "OFFER_DTL_ID",
        "OFFER_TYPE",
        "OFFER_INSTANCE_ID",
        "OFFER_LINE_ROLE",
        "OFFER_PARENT_LINE_ID",
        "OFFER_PRICE_APPLIED",
        "OFFER_DIS_APPLIED",
        "OFFER_NAME_SNAPSHOT",
        "OFFER_OBJECT_VERSION_NUMBER",
        "OFFER_DTL_OBJECT_VERSION_NUMBER",

        "ALLOW_MANUAL_DISCOUNT",
        "ALLOW_PRICE_OVERRIDE"
    ];
    var configurationFailed = false;
    var requiredPageItems = [
        "P48_MODE",
        "P48_SOURCE_MODE",
        "P48_IMPORT_PKG_AUTO_LOADING",

        "P48_PATIENTNO",
        "P48_PAYTYPE",
        "P48_CLINICID",
        "P48_DOCID",
        "P48_CURR_CODE",

        "P48_FINALDISC",
        "P48_AMOUNT_1_AUTO",
        "P48_AMOUNT_1",
        "P48_AMOUNT_2",

        "P48_TOTAL_GROSS",
        "P48_TOTAL_DISCOUNT",
        "P48_TOTAL_NET",
        "P48_PAT_PAY",
        "P48_COMP_PAY",
        "P48_VAT_TOTAL_PAT",
        "P48_VAT_TOTAL_CO",
        "P48_AMOUNT_DUE",
        "P48_REMAINING_AMOUNT",
        "P48_PAYMENT_STATUS",

        "P48_INFO_CENTER_ID",
        "P48_DRAFT_ID"
    ];
    var delayMs = 250;
    var timer = null;
    var requestToken = 0;
    var activePreviewRequest = null;
    var previewBusy = false;
    var applying = false;
    var bulkLoading = false;
    var refreshPending = false;
    var initialized = false;
    var discountRuleApplying = false;
    var protectionRuleApplying = false;
    var missingEditorWarnings = {};
    var authoritativeLinesByClientId = {};
    /*
     * Track preview model subscriptions without attaching private properties
     * to APEX-owned model objects.
     */
    var supportsWeakSet =
        typeof WeakSet === "function";

    var subscribedModels =
        supportsWeakSet ?
        new WeakSet() : [];

    var subscribedModel = null;
    var subscribedModelViewId = null;
    var SOFT_LOCK_CLASS = "p48-ig-editor-readonly";
    var expectedVisibleEditors = {
        SERVICEID: true,
        QTY: true,
        DISCOUNT_TYPE: true,
        DISC: true,
        MY_DISC: true
    };

    /* ==========================================================================
     * Function: reportRequiredPageItemFailure
     * Purpose : Fail closed when a required Page 48 item cannot be accessed.
     * ======================================================================== */
    function reportRequiredPageItemFailure(
        name,
        operation,
        error
    ) {
        configurationFailed = true;

        apex.debug.error(
            "Page 48 preview could not " +
            operation +
            " required page item " +
            name +
            ".",
            error
        );

        if (
            typeof p48SetInvoiceCreateButtonsDisabled ===
            "function"
        ) {
            p48SetInvoiceCreateButtonsDisabled(
                true
            );
        }

        showPreviewError(
            "Invoice page configuration is incomplete. " +
            "Refresh the page or contact support."
        );
    }


    /* ==========================================================================
     * Function: requiredPageItem
     * Purpose : Resolve one required APEX page item.
     * ======================================================================== */
    function requiredPageItem(name) {
        var item;
        var error;

        try {
            item =
                apex.item(name);
        } catch (e) {
            reportRequiredPageItemFailure(
                name,
                "resolve",
                e
            );

            throw e;
        }

        if (
            !item ||
            !item.node
        ) {
            error =
                new Error(
                    "Required Page 48 item " +
                    name +
                    " is not available."
                );

            reportRequiredPageItemFailure(
                name,
                "resolve",
                error
            );

            throw error;
        }

        return item;
    }


    /* ==========================================================================
     * Function: itemValue
     * Purpose : Read one required Page 48 item without swallowing failures.
     * ======================================================================== */
    function itemValue(name) {
        var item =
            requiredPageItem(name);

        try {
            return item.getValue();
        } catch (e) {
            reportRequiredPageItemFailure(
                name,
                "read",
                e
            );

            throw e;
        }
    }


    /* ==========================================================================
     * Function: setItemValue
     * Purpose : Update one required Page 48 item without swallowing failures.
     * ======================================================================== */
    function setItemValue(
        name,
        value
    ) {
        var item =
            requiredPageItem(name);

        try {
            item.setValue(
                value === null ||
                value === undefined ?
                "" :
                value,
                null,
                true
            );
        } catch (e) {
            reportRequiredPageItemFailure(
                name,
                "update",
                e
            );

            throw e;
        }
    }

    /* ==========================================================================
     * Function: validateRequiredPageItems
     * Purpose : Verify all Page 48 preview item dependencies once at startup.
     * ======================================================================== */
    function validateRequiredPageItems() {
        var missing = [];

        requiredPageItems.forEach(
            function(name) {
                var item = null;

                try {
                    item =
                        apex.item(name);
                } catch (e) {
                    apex.debug.error(
                        "Page 48 could not resolve required page item " +
                        name +
                        ".",
                        e
                    );
                }

                if (
                    !item ||
                    !item.node
                ) {
                    missing.push(
                        name
                    );
                }
            }
        );

        if (!missing.length) {
            return true;
        }

        configurationFailed = true;

        apex.debug.error(
            "Page 48 preview configuration error. " +
            "Missing required page item(s): " +
            missing.join(", ")
        );

        if (
            typeof p48SetInvoiceCreateButtonsDisabled ===
            "function"
        ) {
            p48SetInvoiceCreateButtonsDisabled(
                true
            );
        }

        showPreviewError(
            "Invoice page configuration is incomplete. " +
            "Refresh the page or contact support."
        );

        return false;
    }

    /* ==========================================================================
     * Function: numberOrNull
     * Purpose : Parse a locale-aware numeric value.
     *           Blank values return null.
     *           Invalid values return NaN and are never converted to zero.
     * ======================================================================== */
    function numberOrNull(value) {
        var text;
        var result;

        if (
            value === null ||
            value === undefined
        ) {
            return null;
        }

        if (typeof value === "number") {
            return Number.isFinite(value) ?
                value :
                NaN;
        }

        text =
            String(value).trim();

        if (!text) {
            return null;
        }

        result =
            apex.locale.toNumber(
                text
            );

        return Number.isFinite(result) ?
            result :
            NaN;
    }

    /* ==========================================================================
     * Function: numberValue
     * Purpose : Default a genuinely empty numeric value to zero.
     *           Invalid numeric input remains invalid.
     * ======================================================================== */
    function numberValue(value) {
        var result =
            numberOrNull(value);

        return result === null ?
            0 :
            result;
    }

    /* ==========================================================================
     * Function: validNumberOrNull
     * Purpose : Parse an optional numeric value and reject malformed input.
     * ======================================================================== */
    function validNumberOrNull(
        value,
        label
    ) {
        var result =
            numberOrNull(value);

        if (
            result !== null &&
            !Number.isFinite(result)
        ) {
            throw new Error(
                label +
                " must be a valid number."
            );
        }

        return result;
    }

    /* ==========================================================================
     * Function: pageNumberOrZero
     * Purpose : Read a Page 48 Number Field through APEX's locale-aware native
     *           number interface. Empty means zero; invalid input is rejected.
     * ======================================================================== */
    function pageNumberOrZero(
        itemName,
        label
    ) {
        var item =
            apex.item(itemName);

        var result;

        if (
            !item ||
            !item.node
        ) {
            throw new Error(
                label +
                " field is not available."
            );
        }

        if (item.isEmpty()) {
            return 0;
        }

        if (
            typeof item.getNativeValue ===
            "function"
        ) {
            result =
                item.getNativeValue();
        } else {
            result =
                numberOrNull(
                    item.getValue()
                );
        }

        if (!Number.isFinite(result)) {
            throw new Error(
                label +
                " must be a valid number."
            );
        }

        if (result < 0) {
            throw new Error(
                label +
                " cannot be negative."
            );
        }

        return result;
    }

    /* ==========================================================================
     * Function: money
     * Purpose : Normalize monetary values to two decimal places.
     * ======================================================================== */
    function money(value) {
        return Math.round(
            numberValue(value) * 100
        ) / 100;
    }

    /* ==========================================================================
     * Function: setMoney
     * Purpose : Set a monetary page-item value.
     * ======================================================================== */
    function setMoney(name, value) {
        setItemValue(
            name,
            money(value)
        );
    }

    /* ==========================================================================
     * Function: gridView
     * Purpose : Return the Invoice Services Interactive Grid view.
     * ======================================================================== */
    function gridView() {
        var region;

        try {
            region =
                apex.region(REGION_ID);

            if (!region) {
                return null;
            }

            return region
                .widget()
                .interactiveGrid(
                    "getViews",
                    "grid"
                );
        } catch (e) {
            return null;
        }
    }

    /* ==========================================================================
     * Function: gridModel
     * Purpose : Return the Invoice Services Interactive Grid model.
     * ======================================================================== */
    function gridModel() {
        var view =
            gridView();

        return view && view.model ?
            view.model :
            null;
    }

    /* ==========================================================================
     * Function: rawValue
     * Purpose : Return the underlying IG value, including Popup LOV return value.
     * ======================================================================== */
    function rawValue(
        model,
        record,
        columnName
    ) {
        var value;

        try {
            value = model.getValue(
                record,
                columnName
            );
        } catch (e) {
            return null;
        }

        /*
         * Popup LOV columns can contain:
         *
         * {
         *   v: returnValue,
         *   d: displayValue
         * }
         */
        if (
            value &&
            typeof value === "object" &&
            Object.prototype.hasOwnProperty.call(
                value,
                "v"
            )
        ) {
            return value.v;
        }

        return value;
    }

    /* ==========================================================================
     * Function: recordId
     * Purpose : Safely obtain an IG record identifier.
     * ======================================================================== */
    function recordId(
        model,
        record
    ) {
        try {
            return model.getRecordId(
                record
            );
        } catch (e) {
            return null;
        }
    }

    /* ==========================================================================
     * Function: isDeleted
     * Purpose : Determine whether an IG record is marked for deletion.
     * ======================================================================== */
    function isDeleted(
        model,
        record
    ) {
        var id;
        var metadata;

        id = recordId(
            model,
            record
        );

        if (
            id === null ||
            id === undefined
        ) {
            return false;
        }

        try {
            metadata =
                model.getRecordMetadata(id);
        } catch (e) {
            metadata = null;
        }

        return !!(
            metadata &&
            metadata.deleted
        );
    }

    /* ==========================================================================
     * Function: columnExists
     * Purpose : Determine whether an IG model column exists.
     * ======================================================================== */
    function columnExists(
        model,
        columnName
    ) {
        var fieldKey;

        try {
            fieldKey =
                model.getFieldKey(
                    columnName
                );

            return (
                fieldKey !== null &&
                fieldKey !== undefined
            );
        } catch (e) {
            return false;
        }
    }

    var numericModelColumns = {
        QTY: true,
        PRICE: true,
        MY_PRICE: true,
        PRICE_OVERRIDE: true,

        DISC: true,
        MY_DISC: true,

        PLAN_DISCOUNT_PCT: true,
        PLAN_DISCOUNT_AMOUNT: true,
        EFFECTIVE_DISCOUNT_PCT: true,
        TOTAL_DISCOUNT_AMOUNT: true,

        MY_NET: true,
        THE_PAY: true,
        THE_COMP: true,

        VAT_RATE: true,
        VAT_VAL_PAT: true,
        VAT_VAL_CO: true,

        REQ_NEED_A: true,
        REQ_A_STATUS: true,

        PACKAGE_COMPONENT_ORDER: true,
        PACKAGE_PARENT_LINE_ID: true,

        OFFER_ID: true,
        OFFER_DTL_ID: true,
        OFFER_TYPE: true,
        OFFER_PARENT_LINE_ID: true,
        OFFER_PRICE_APPLIED: true,
        OFFER_DIS_APPLIED: true,
        OFFER_OBJECT_VERSION_NUMBER: true,
        OFFER_DTL_OBJECT_VERSION_NUMBER: true
    };

    /* ==========================================================================
     * Function: columnExists
     * Purpose : Determine whether an IG model column exists.
     * ======================================================================== */

    function validateRequiredModelColumns(model) {
        var missing = [];

        if (
            model._p48RequiredColumnsValidated
        ) {
            return true;
        }

        requiredModelColumns.forEach(
            function(columnName) {
                if (
                    !columnExists(
                        model,
                        columnName
                    )
                ) {
                    missing.push(
                        columnName
                    );
                }
            }
        );

        if (!missing.length) {
            model._p48RequiredColumnsValidated =
                true;

            return true;
        }

        configurationFailed = true;

        apex.debug.error(
            "Page 48 Invoice Services configuration error. " +
            "Missing required model column(s): " +
            missing.join(", ")
        );

        if (
            typeof p48SetInvoiceCreateButtonsDisabled ===
            "function"
        ) {
            p48SetInvoiceCreateButtonsDisabled(
                true
            );
        }

        showPreviewError(
            "Invoice Services is not configured correctly. " +
            "Refresh the page or contact support."
        );

        return false;
    }

    /* ==========================================================================
     * Function: valuesAreEqual
     * Purpose : Compare current and new model values consistently.
     * ======================================================================== */
    function valuesAreEqual(
        columnName,
        current,
        value
    ) {
        var currentNumber;
        var newNumber;

        /*
         * Database/APEX null values are represented in the model
         * as null, undefined, or an empty string.
         */
        if (
            (
                current === null ||
                current === undefined ||
                current === ""
            ) &&
            (
                value === null ||
                value === undefined ||
                value === ""
            )
        ) {
            return true;
        }

        /*
         * Numeric model fields compare numerically so equivalent
         * representations such as 1, "1", and "1.00" are equal.
         */
        if (numericModelColumns[columnName]) {
            currentNumber =
                numberOrNull(current);

            newNumber =
                numberOrNull(value);

            if (
                currentNumber === null ||
                newNumber === null ||
                !Number.isFinite(currentNumber) ||
                !Number.isFinite(newNumber)
            ) {
                return false;
            }

            return currentNumber === newNumber;
        }

        /*
         * Codes, IDs represented as strings, descriptions, tokens,
         * and other textual fields use exact normalized comparison.
         */
        return modelString(current) ===
            modelString(value);
    }

    /* ==========================================================================
     * Function: setModelValue
     * Purpose : Set a normal writable Interactive Grid model value.
     * ======================================================================== */
    function setModelValue(
        model,
        record,
        columnName,
        value
    ) {
        var current;
        var normalizedValue =
            modelString(value);

        if (
            !columnExists(
                model,
                columnName
            )
        ) {
            if (applying) {
                throw new Error(
                    "Required preview model column " +
                    columnName +
                    " is unavailable."
                );
            }

            return false;
        }

        current = rawValue(
            model,
            record,
            columnName
        );

        if (
            valuesAreEqual(
                columnName,
                current,
                normalizedValue
            )
        ) {
            return true;
        }

        try {
            model.setValue(
                record,
                columnName,
                normalizedValue
            );

            return true;
        } catch (e) {
            if (applying) {
                throw new Error(
                    "Preview could not apply model column " +
                    columnName +
                    ": " +
                    e.message
                );
            }

            apex.debug.warn(
                "Page 48 preview could not set " +
                columnName +
                ": " +
                e.message
            );

            return false;
        }
    }


    /* ==========================================================================
     * Function: modelString
     * Purpose : Convert an APEX model value to the string form expected by the
     *           APEX server while preserving null as an empty string.
     * ======================================================================== */
    function modelString(value) {
        return value === null ||
            value === undefined ?
            "" :
            String(value);
    }

    /* ==========================================================================
     * Function: setLovModelValue
     * Purpose : Set an IG Popup LOV value without losing its display label.
     * ======================================================================== */
    function setLovModelValue(
        model,
        record,
        columnName,
        value,
        displayValue
    ) {
        var current;
        var currentValue;
        var currentDisplay;
        var normalizedValue =
            modelString(value);
        var normalizedDisplay =
            modelString(displayValue || value);

        if (
            !columnExists(
                model,
                columnName
            )
        ) {
            if (applying) {
                throw new Error(
                    "Required preview LOV column " +
                    columnName +
                    " is unavailable."
                );
            }

            return false;
        }

        try {
            current = model.getValue(
                record,
                columnName
            );
        } catch (e) {
            current = null;
        }

        currentValue =
            current &&
            typeof current === "object" &&
            Object.prototype.hasOwnProperty.call(
                current,
                "v"
            ) ?
            modelString(current.v) :
            modelString(current);

        currentDisplay =
            current &&
            typeof current === "object" &&
            Object.prototype.hasOwnProperty.call(
                current,
                "d"
            ) ?
            modelString(current.d) :
            "";

        if (
            currentValue === normalizedValue &&
            (
                !currentDisplay ||
                currentDisplay === normalizedDisplay
            )
        ) {
            return true;
        }

        try {
            model.setValue(
                record,
                columnName,
                normalizedValue ? {
                    v: normalizedValue,
                    d: normalizedDisplay
                } :
                ""
            );

            return true;
        } catch (e) {
            if (applying) {
                throw new Error(
                    "Preview could not apply LOV column " +
                    columnName +
                    ": " +
                    e.message
                );
            }

            apex.debug.warn(
                "Page 48 preview could not set " +
                columnName +
                ": " +
                e.message
            );

            return false;
        }
    }

    /* ==========================================================================
     * Function: setFieldValidity
     * Purpose : Set or clear one IG field validation state safely.
     * ======================================================================== */
    function setFieldValidity(
        model,
        record,
        columnName,
        validity,
        message
    ) {
        var id =
            recordId(
                model,
                record
            );

        if (
            id === null ||
            id === undefined ||
            typeof model.setValidity !==
            "function"
        ) {
            return;
        }

        try {
            model.setValidity(
                validity,
                id,
                columnName,
                validity === "valid" ?
                undefined :
                message
            );
        } catch (e) {
            apex.debug.warn(
                "Page 48 could not update validation state for " +
                columnName +
                ": " +
                e.message
            );
        }
    }

    /* ==========================================================================
     * Function: focusGridCell
     * Purpose : Move focus to the first invalid IG field.
     * ======================================================================== */
    function focusGridCell(
        recordIdentifier,
        columnName
    ) {
        var view =
            gridView();

        if (
            !view ||
            !view.view$ ||
            recordIdentifier === null ||
            recordIdentifier === undefined
        ) {
            return;
        }

        window.setTimeout(
            function() {
                try {
                    view.view$.grid(
                        "gotoCell",
                        recordIdentifier,
                        columnName
                    );
                } catch (e) {
                    apex.debug.warn(
                        "Page 48 could not focus the invalid invoice line: " +
                        e.message
                    );
                }
            },
            0
        );
    }

    /* ==========================================================================
     * Function: upperValue
     * Purpose : Normalize a code value for comparisons.
     * ======================================================================== */
    function upperValue(value) {
        return String(
                value === null ||
                value === undefined ?
                "" :
                value
            )
            .trim()
            .toUpperCase();
    }

    /* ==========================================================================
     * Function: hasText
     * Purpose : Return true when a metadata value is present.
     * ======================================================================== */
    function hasText(value) {
        return String(
            value === null ||
            value === undefined ?
            "" :
            value
        ).trim() !== "";
    }

    /* ==========================================================================
     * Function: lineOrModelValue
     * Purpose : Prefer a fresh backend line value; otherwise read the IG model.
     * ======================================================================== */
    function lineOrModelValue(
        line,
        propertyName,
        model,
        record,
        columnName
    ) {
        if (
            line &&
            Object.prototype.hasOwnProperty.call(
                line,
                propertyName
            )
        ) {
            return line[propertyName];
        }

        return rawValue(
            model,
            record,
            columnName
        );
    }

    /* ==========================================================================
     * Function: rowContext
     * Purpose : Classify a row using backend evidence and fail-closed metadata.
     * ======================================================================== */
    function rowContext(
        model,
        record,
        line
    ) {
        var sourceType =
            upperValue(
                lineOrModelValue(
                    line,
                    "sourceType",
                    model,
                    record,
                    "SOURCE_TYPE"
                )
            );

        var offerType =
            numberOrNull(
                lineOrModelValue(
                    line,
                    "offerType",
                    model,
                    record,
                    "OFFER_TYPE"
                )
            );

        var offerInstanceId =
            lineOrModelValue(
                line,
                "offerInstanceId",
                model,
                record,
                "OFFER_INSTANCE_ID"
            );

        var offerLineRole =
            lineOrModelValue(
                line,
                "offerLineRole",
                model,
                record,
                "OFFER_LINE_ROLE"
            );

        var packageServiceId =
            lineOrModelValue(
                line,
                "packageServiceId",
                model,
                record,
                "PACKAGE_SERVICE_ID"
            );

        var packageInstanceId =
            lineOrModelValue(
                line,
                "packageInstanceId",
                model,
                record,
                "PACKAGE_INSTANCE_ID"
            );

        var packageLineRole =
            upperValue(
                lineOrModelValue(
                    line,
                    "packageLineRole",
                    model,
                    record,
                    "PACKAGE_LINE_ROLE"
                )
            );

        var packagePricingMethod =
            upperValue(
                lineOrModelValue(
                    line,
                    "packagePricingMethod",
                    model,
                    record,
                    "PACKAGE_PRICING_METHOD"
                )
            );

        var packageComponentOrder =
            lineOrModelValue(
                line,
                "packageComponentOrder",
                model,
                record,
                "PACKAGE_COMPONENT_ORDER"
            );

        var packageParentLineId =
            lineOrModelValue(
                line,
                "packageParentLineId",
                model,
                record,
                "PACKAGE_PARENT_LINE_ID"
            );

        var packageDefinitionToken =
            lineOrModelValue(
                line,
                "packageDefinitionToken",
                model,
                record,
                "PACKAGE_DEFINITION_TOKEN"
            );

        return {
            packageLineRole: packageLineRole,

            packagePricingMethod: packagePricingMethod,

            isBundleLine: (
                sourceType === "BUNDLE" ||
                offerType === 0 ||
                hasText(offerInstanceId) ||
                hasText(offerLineRole)
            ),

            isPackageLine: (
                sourceType === "PACKAGE" ||
                hasText(packageServiceId) ||
                hasText(packageInstanceId) ||
                hasText(packageLineRole) ||
                hasText(packagePricingMethod) ||
                hasText(packageComponentOrder) ||
                hasText(packageParentLineId) ||
                hasText(packageDefinitionToken)
            )
        };
    }

    /* ==========================================================================
     * Function: manualDiscountAllowedForRow
     * Purpose : Apply backend permission plus package and bundle fail-closed rules.
     * ======================================================================== */
    function manualDiscountAllowedForRow(
        model,
        record,
        line
    ) {
        var context =
            rowContext(
                model,
                record,
                line
            );

        var backendAllows =
            upperValue(
                lineOrModelValue(
                    line,
                    "allowManualDiscount",
                    model,
                    record,
                    "ALLOW_MANUAL_DISCOUNT"
                )
            ) === "Y";

        if (
            !backendAllows ||
            context.isBundleLine
        ) {
            return false;
        }

        if (!context.isPackageLine) {
            return true;
        }

        /*
         * Keep the agreed package-discount rule from Point 2:
         * only discountable COMPONENT_PRICE components may receive a manual
         * discount. Package parents, FIXED_PRICE rows, and FREE rows are locked.
         */
        return (
            context.packageLineRole ===
            "COMPONENT" &&
            context.packagePricingMethod ===
            "COMPONENT_PRICE"
        );
    }

    /* ==========================================================================
     * Function: lineFieldEditability
     * Purpose : Calculate service, quantity, and price-override permissions.
     * ======================================================================== */
    function lineFieldEditability(
        model,
        record,
        line
    ) {
        var context =
            rowContext(
                model,
                record,
                line
            );

        var backendAllowsPriceOverride =
            upperValue(
                lineOrModelValue(
                    line,
                    "allowPriceOverride",
                    model,
                    record,
                    "ALLOW_PRICE_OVERRIDE"
                )
            ) === "Y";

        var lockedOccurrence =
            context.isPackageLine ||
            context.isBundleLine;

        var isPackageParent = (
            context.isPackageLine &&
            context.packageLineRole === "PARENT"
        );

        /*
         * The backend now treats package-parent QTY as the authoritative package
         * occurrence multiplier and reconstructs component quantities. Fail closed
         * when package metadata is incomplete: only an explicit PARENT role may
         * edit QTY. Bundle quantities and package component quantities stay locked.
         */
        return {
            serviceEditable:
                !lockedOccurrence,

            quantityEditable: (
                !context.isBundleLine &&
                (
                    !context.isPackageLine ||
                    isPackageParent
                )
            ),

            priceOverrideEditable: (
                !lockedOccurrence &&
                backendAllowsPriceOverride
            )
        };
    }

    /* ==========================================================================
     * Function: gridColumnDefinition
     * Purpose : Resolve an Interactive Grid column definition by model property.
     * ======================================================================== */
    function gridColumnDefinition(columnName) {
        var view =
            gridView();

        var columns;
        var target =
            upperValue(columnName);

        var match = null;

        if (
            !view ||
            !view.view$
        ) {
            return null;
        }

        try {
            columns =
                view.view$.grid(
                    "getColumns"
                ) || [];
        } catch (e) {
            return null;
        }

        columns.some(function(column) {
            var names;
            var elementId;

            if (!column) {
                return false;
            }

            names = [
                column.property,
                column.columnName,
                column.name,
                column.id
            ];

            if (
                names.some(function(name) {
                    return (
                        hasText(name) &&
                        upperValue(name) === target
                    );
                })
            ) {
                match = column;
                return true;
            }

            /*
             * APEX-generated item IDs can include a region/model prefix. The suffix
             * fallback is used only when the documented property name is absent.
             */
            elementId =
                upperValue(
                    column.elementId
                );

            if (
                elementId === target ||
                elementId.slice(
                    -(target.length + 1)
                ) === "_" + target
            ) {
                match = column;
                return true;
            }

            return false;
        });

        return match;
    }

    /* ==========================================================================
     * Function: gridColumnItem
     * Purpose : Resolve the actual APEX column item used by the active IG row.
     * ======================================================================== */
    function gridColumnItem(columnName) {
        var definition =
            gridColumnDefinition(
                columnName
            );

        var candidates = [];
        var item;

        if (
            definition &&
            hasText(definition.elementId)
        ) {
            candidates.push(
                definition.elementId
            );
        }

        /*
         * Retain a simple-name fallback for APEX versions where the generated
         * element ID equals the model property.
         */
        candidates.push(columnName);

        candidates.some(function(itemName) {
            try {
                item =
                    apex.item(itemName);
            } catch (e) {
                item = null;
            }

            return !!(
                item &&
                item.node
            );
        });

        return (
                item &&
                item.node
            ) ?
            item :
            null;
    }

    /* ==========================================================================
     * Function: ensureSoftLockCss
     * Purpose : Add a small visual treatment for non-editable active IG editors.
     * ======================================================================== */
    function ensureSoftLockCss() {
        if (
            document.getElementById(
                "p48-ig-soft-lock-css"
            )
        ) {
            return;
        }

        $("<style>", {
            id: "p48-ig-soft-lock-css",
            text: "." + SOFT_LOCK_CLASS + " input," +
                "." + SOFT_LOCK_CLASS + " select," +
                "." + SOFT_LOCK_CLASS + " textarea{" +
                "background:var(--a-field-input-state-disabled-background-color,#f4f4f4)!important;" +
                "cursor:not-allowed!important;" +
                "}" +
                "." + SOFT_LOCK_CLASS + " button{" +
                "opacity:.55;cursor:not-allowed!important;" +
                "}"
        }).appendTo("head");
    }

    /* ==========================================================================
     * Function: editorWrapper
     * Purpose : Return the reusable IG column-item wrapper for one editor.
     * ======================================================================== */
    function editorWrapper(item) {
        var node$ =
            $(item.node);
        var wrapper$ =
            node$.closest(
                ".a-GV-columnItem"
            );

        return wrapper$.length ?
            wrapper$ :
            node$.parent();
    }

    /* ==========================================================================
     * Function: setGridColumnItemDisabled
     * Purpose : Apply a non-destructive soft read-only state to the active IG
     *           editor. Never call item.disable(): APEX reuses one column item
     *           between rows and disabled controls can lose required values.
     * ======================================================================== */
    function setGridColumnItemDisabled(
        columnName,
        disabled
    ) {
        var item =
            gridColumnItem(
                columnName
            );
        var node$;
        var wrapper$;

        if (!item) {
            if (
                expectedVisibleEditors[columnName] &&
                !missingEditorWarnings[columnName]
            ) {
                missingEditorWarnings[columnName] =
                    true;

                apex.debug.warn(
                    "Page 48 could not resolve the IG editor for " +
                    columnName +
                    "."
                );
            }

            return;
        }

        ensureSoftLockCss();

        node$ =
            $(item.node);
        wrapper$ =
            editorWrapper(item);

        try {
            /*
             * Undo any disabled state left by an older Page 48 JavaScript version.
             * The value remains in the model and the current editor can load it.
             */
            if (
                typeof item.isDisabled ===
                "function" &&
                item.isDisabled()
            ) {
                item.enable();
            }

            node$.prop(
                "disabled",
                false
            );

            node$.prop(
                "readOnly",
                !!disabled
            );

            if (disabled) {
                node$.attr(
                    "aria-readonly",
                    "true"
                );

                wrapper$
                    .addClass(
                        SOFT_LOCK_CLASS
                    )
                    .attr(
                        "data-p48-readonly",
                        "Y"
                    );

                wrapper$
                    .find(
                        "button,select"
                    )
                    .attr(
                        "aria-disabled",
                        "true"
                    );
            } else {
                node$.removeAttr(
                    "aria-readonly"
                );

                wrapper$
                    .removeClass(
                        SOFT_LOCK_CLASS
                    )
                    .removeAttr(
                        "data-p48-readonly"
                    );

                wrapper$
                    .find(
                        "button,select"
                    )
                    .removeAttr(
                        "aria-disabled"
                    );
            }
        } catch (e) {
            apex.debug.warn(
                "Page 48 could not update the IG editor for " +
                columnName +
                ": " +
                e.message
            );
        }
    }

    /* ==========================================================================
     * Function: blockSoftLockedEditorEvent
     * Purpose : Prevent user interaction with a soft-locked select/button while
     *           allowing APEX to initialize and submit its underlying value.
     * ======================================================================== */
    function blockSoftLockedEditorEvent(event) {
        var target$ =
            $(event.target);
        var wrapper$ =
            target$.closest(
                "." + SOFT_LOCK_CLASS
            );
        var key =
            event.key || "";

        if (
            !wrapper$.length ||
            !event.originalEvent
        ) {
            return;
        }

        if (
            event.type === "keydown" &&
            (
                key === "Tab" ||
                (
                    (event.ctrlKey || event.metaKey) && ["a", "c"].indexOf(
                        String(key).toLowerCase()
                    ) !== -1
                )
            )
        ) {
            return;
        }

        if (
            target$.is(
                "button,select"
            ) || [
                "beforeinput",
                "paste",
                "drop",
                "cut",
                "change",
                "input",
                "wheel",
                "keydown"
            ].indexOf(event.type) !== -1
        ) {
            event.preventDefault();
            event.stopImmediatePropagation();
            return false;
        }
    }

    /* ==========================================================================
     * Function: bindSoftLockGuards
     * Purpose : Bind one delegated guard for reusable IG column editors.
     * ======================================================================== */
    function bindSoftLockGuards() {
        var region$ =
            lineEditorEventTarget();

        if (
            !region$ ||
            !region$.length
        ) {
            return;
        }

        region$
            .off(
                ".p48SoftLockedEditors"
            )
            .on(
                "mousedown.p48SoftLockedEditors " +
                "click.p48SoftLockedEditors " +
                "dblclick.p48SoftLockedEditors " +
                "keydown.p48SoftLockedEditors " +
                "beforeinput.p48SoftLockedEditors " +
                "paste.p48SoftLockedEditors " +
                "drop.p48SoftLockedEditors " +
                "cut.p48SoftLockedEditors " +
                "change.p48SoftLockedEditors " +
                "input.p48SoftLockedEditors " +
                "wheel.p48SoftLockedEditors",
                "." + SOFT_LOCK_CLASS + " :input," +
                "." + SOFT_LOCK_CLASS + " button",
                blockSoftLockedEditorEvent
            );
    }

    /* ==========================================================================
     * Function: activeRecordMatches
     * Purpose : Confirm that editor controls currently belong to this row.
     * ======================================================================== */
    function activeRecordMatches(
        model,
        record
    ) {
        var view =
            gridView();

        var activeRecordId;
        var currentRecordId;

        if (
            !view ||
            !view.view$
        ) {
            return false;
        }

        try {
            activeRecordId =
                view.view$.grid(
                    "getActiveRecordId"
                );
        } catch (e) {
            return false;
        }

        currentRecordId =
            recordId(
                model,
                record
            );

        return (
            activeRecordId !== null &&
            activeRecordId !== undefined &&
            currentRecordId !== null &&
            currentRecordId !== undefined &&
            String(activeRecordId) ===
            String(currentRecordId)
        );
    }

    /* ==========================================================================
     * Function: updateLineEditorState
     * Purpose : Apply complete row-specific editability to the active IG editor.
     * ======================================================================== */
    function updateLineEditorState(
        model,
        record,
        line,
        force
    ) {
        var fieldRules;
        var manualAllowed;
        var method;

        if (
            !force &&
            !activeRecordMatches(
                model,
                record
            )
        ) {
            return;
        }

        fieldRules =
            lineFieldEditability(
                model,
                record,
                line
            );

        manualAllowed =
            manualDiscountAllowedForRow(
                model,
                record,
                line
            );

        method =
            upperValue(
                rawValue(
                    model,
                    record,
                    "DISCOUNT_TYPE"
                )
            );

        setGridColumnItemDisabled(
            "SERVICEID",
            !fieldRules.serviceEditable
        );

        setGridColumnItemDisabled(
            "QTY",
            !fieldRules.quantityEditable
        );

        setGridColumnItemDisabled(
            "PRICE_OVERRIDE",
            !fieldRules.priceOverrideEditable
        );

        setGridColumnItemDisabled(
            "USE_PRICE_OVERRIDE",
            !fieldRules.priceOverrideEditable
        );

        setGridColumnItemDisabled(
            "DISCOUNT_TYPE",
            !manualAllowed
        );

        setGridColumnItemDisabled(
            "DISC",
            !manualAllowed ||
            method !== "R"
        );

        setGridColumnItemDisabled(
            "MY_DISC",
            !manualAllowed ||
            method !== "V"
        );
    }

    /* ==========================================================================
     * Function: resetLineEditorState
     * Purpose : Prevent one row's editor state leaking into the next row.
     * ======================================================================== */
    function resetLineEditorState() {
        [
            "SERVICEID",
            "QTY",
            "PRICE_OVERRIDE",
            "USE_PRICE_OVERRIDE",
            "DISCOUNT_TYPE",
            "DISC",
            "MY_DISC"
        ].forEach(function(columnName) {
            setGridColumnItemDisabled(
                columnName,
                false
            );
        });
    }

    /* ==========================================================================
     * Function: applyManualDiscountRule
     * Purpose : Normalize method/value pairs before the preview is submitted.
     * ======================================================================== */
    function applyManualDiscountRule(
        model,
        record,
        line,
        forceEditorUpdate
    ) {
        var manualAllowed =
            manualDiscountAllowedForRow(
                model,
                record,
                line
            );

        var method =
            upperValue(
                rawValue(
                    model,
                    record,
                    "DISCOUNT_TYPE"
                )
            );

        var changed = false;

        if (
            !manualAllowed || ["N", "R", "V"].indexOf(
                method
            ) === -1
        ) {
            method = "N";
        }

        discountRuleApplying =
            true;

        try {
            if (
                !valuesAreEqual(
                    "DISCOUNT_TYPE",
                    rawValue(
                        model,
                        record,
                        "DISCOUNT_TYPE"
                    ),
                    method
                )
            ) {
                setModelValue(
                    model,
                    record,
                    "DISCOUNT_TYPE",
                    method
                );

                changed = true;
            }

            if (
                method !== "R" &&
                !valuesAreEqual(
                    "DISC",
                    rawValue(
                        model,
                        record,
                        "DISC"
                    ),
                    0
                )
            ) {
                setModelValue(
                    model,
                    record,
                    "DISC",
                    0
                );

                changed = true;
            }

            if (
                method !== "V" &&
                !valuesAreEqual(
                    "MY_DISC",
                    rawValue(
                        model,
                        record,
                        "MY_DISC"
                    ),
                    0
                )
            ) {
                setModelValue(
                    model,
                    record,
                    "MY_DISC",
                    0
                );

                changed = true;
            }
        } finally {
            discountRuleApplying =
                false;
        }

        updateLineEditorState(
            model,
            record,
            line,
            !!forceEditorUpdate
        );

        return changed;
    }

    /* ==========================================================================
     * Function: protectedFieldIsLocked
     * Purpose : Determine whether a changed field is protected for this row.
     * ======================================================================== */
    function protectedFieldIsLocked(
        model,
        record,
        fieldName
    ) {
        var rules =
            lineFieldEditability(
                model,
                record,
                null
            );

        if (fieldName === "SERVICEID") {
            return !rules.serviceEditable;
        }

        if (fieldName === "QTY") {
            return !rules.quantityEditable;
        }

        if (
            fieldName === "PRICE_OVERRIDE" ||
            fieldName === "USE_PRICE_OVERRIDE"
        ) {
            return !rules.priceOverrideEditable;
        }

        return false;
    }

    /* ==========================================================================
     * Function: revertProtectedModelChange
     * Purpose : Restore a protected value before any preview request is sent.
     * ======================================================================== */
    function revertProtectedModelChange(
        model,
        change
    ) {
        /*
         * Package and bundle importers populate protected fields programmatically
         * while bulk-loading mode is active. Never treat those trusted model writes
         * as user edits or they will be reverted to the inserted row defaults.
         */
        if (
            applying ||
            importIsLoading()
        ) {
            return false;
        }

        if (
            !change ||
            !change.record || [
                "SERVICEID",
                "QTY",
                "PRICE_OVERRIDE",
                "USE_PRICE_OVERRIDE"
            ].indexOf(change.field) === -1 ||
            !protectedFieldIsLocked(
                model,
                change.record,
                change.field
            )
        ) {
            return false;
        }

        protectionRuleApplying =
            true;

        try {
            model.setValue(
                change.record,
                change.field,
                change.oldValue
            );
        } finally {
            protectionRuleApplying =
                false;
        }

        updateLineEditorState(
            model,
            change.record,
            null,
            false
        );

        return true;
    }

    /* ==========================================================================
     * Function: lineEditorEventTarget
     * Purpose : Return the Interactive Grid widget that emits row-edit events.
     * ======================================================================== */
    function lineEditorEventTarget() {
        var region;
        var widget$;

        try {
            region =
                apex.region(REGION_ID);
        } catch (e) {
            region = null;
        }

        if (!region) {
            return null;
        }

        try {
            widget$ =
                region.widget();
        } catch (e) {
            widget$ = null;
        }

        if (
            widget$ &&
            widget$.length
        ) {
            return widget$;
        }

        if (
            region.element &&
            region.element.length
        ) {
            return region.element;
        }

        return $("#" + REGION_ID);
    }

    /* ==========================================================================
     * Function: bindLineEditorEvents
     * Purpose : Reapply row-specific editor state whenever the active row changes.
     * ======================================================================== */
    function bindLineEditorEvents() {
        var region$ =
            lineEditorEventTarget();

        if (
            !region$ ||
            !region$.length
        ) {
            apex.debug.warn(
                "Page 48 could not bind Invoice Lines edit events."
            );

            return;
        }

        region$
            .off(
                ".p48InvoiceLineEditability"
            )
            .on(
                "apexbeginrecordedit.p48InvoiceLineEditability",
                function(
                    event,
                    data
                ) {
                    var changed;

                    if (
                        !data ||
                        !data.model ||
                        !data.record
                    ) {
                        return;
                    }

                    /*
                     * insertNewRecord can cause record-edit events while package or
                     * bundle rows are still being populated. Wait until the importer
                     * finishes and the authoritative preview has applied the row data.
                     */
                    if (
                        applying ||
                        importIsLoading()
                    ) {
                        return;
                    }

                    changed =
                        applyManualDiscountRule(
                            data.model,
                            data.record,
                            null,
                            true
                        );

                    /*
                     * Reapply after the current event stack so Popup LOV and number-field
                     * item plug-ins have completed active-row initialization.
                     */
                    window.setTimeout(
                        function() {
                            updateLineEditorState(
                                data.model,
                                data.record,
                                null,
                                false
                            );
                        },
                        0
                    );

                    if (changed) {
                        schedule();
                    }
                }
            )
            .on(
                "apexendrecordedit.p48InvoiceLineEditability",
                function() {
                    resetLineEditorState();
                }
            );
    }

    /* ==========================================================================
     * Function: editablePreviewEnabled
     * Purpose : Determine whether the editable IG batch preview should run.
     * ======================================================================== */
    function editablePreviewEnabled() {
        var mode =
            String(
                itemValue("P48_MODE") ||
                "CREATE"
            ).toUpperCase();

        return (
            !itemValue(
                "P48_SOURCE_MODE"
            ) &&
            mode !== "VIEW"
        );
    }

    /* ==========================================================================
     * Function: importIsLoading
     * Purpose : Determine whether package or offer rows are being bulk loaded.
     * ======================================================================== */
    function importIsLoading() {
        return (
            bulkLoading ||
            itemValue(
                "P48_IMPORT_PKG_AUTO_LOADING"
            ) === "Y"
        );
    }

    /* ==========================================================================
     * Function: validateRequiredRowsForSubmit
     * Purpose : Stop final submit before APEX ARP when a visible row has lost a
     *           required Service or Quantity value. Clear stale field errors once
     *           the model value is valid again.
     * ======================================================================== */
    function validateRequiredRowsForSubmit() {
        var model =
            gridModel();
        var firstError = null;

        if (!model) {
            return {
                valid: false,
                message: "Invoice lines are not available. Refresh the page and try again."
            };
        }

        protectionRuleApplying = true;

        try {
            model.forEach(function(record) {
                var id;
                var context;
                var snapshot;
                var serviceId;
                var quantity;
                var offerType;
                var offerLineRole;
                var isBundleParent;

                if (
                    isDeleted(
                        model,
                        record
                    )
                ) {
                    return;
                }

                id = recordId(
                    model,
                    record
                );

                context = rowContext(
                    model,
                    record,
                    null
                );

                snapshot =
                    authoritativeLinesByClientId[
                        String(id)
                    ];

                serviceId = rawValue(
                    model,
                    record,
                    "SERVICEID"
                );

                quantity = numberOrNull(
                    rawValue(
                        model,
                        record,
                        "QTY"
                    )
                );

                /*
                 * Repair only fields that the user is not permitted to edit. This also
                 * repairs a row damaged by the previous item.disable implementation.
                 */
                if (
                    snapshot &&
                    context.isBundleLine
                ) {
                    if (!hasText(serviceId)) {
                        setLovModelValue(
                            model,
                            record,
                            "SERVICEID",
                            snapshot.serviceId,
                            modelString(snapshot.serviceId) +
                            (
                                hasText(snapshot.serviceDesc) ?
                                " - " + modelString(snapshot.serviceDesc) :
                                ""
                            )
                        );

                        serviceId = rawValue(
                            model,
                            record,
                            "SERVICEID"
                        );
                    }

                    if (
                        quantity === null ||
                        !Number.isFinite(quantity)
                    ) {
                        setModelValue(
                            model,
                            record,
                            "QTY",
                            modelString(snapshot.qty)
                        );

                        quantity = numberOrNull(
                            rawValue(
                                model,
                                record,
                                "QTY"
                            )
                        );
                    }
                }

                if (
                    snapshot &&
                    context.isPackageLine
                ) {
                    if (!hasText(serviceId)) {
                        setLovModelValue(
                            model,
                            record,
                            "SERVICEID",
                            snapshot.serviceId,
                            modelString(snapshot.serviceId) +
                            (
                                hasText(snapshot.serviceDesc) ?
                                " - " + modelString(snapshot.serviceDesc) :
                                ""
                            )
                        );

                        serviceId = rawValue(
                            model,
                            record,
                            "SERVICEID"
                        );
                    }

                    if (
                        context.packageLineRole ===
                        "COMPONENT" &&
                        (
                            quantity === null ||
                            !Number.isFinite(quantity)
                        )
                    ) {
                        setModelValue(
                            model,
                            record,
                            "QTY",
                            modelString(snapshot.qty)
                        );

                        quantity = numberOrNull(
                            rawValue(
                                model,
                                record,
                                "QTY"
                            )
                        );
                    }
                }

                offerType = numberOrNull(
                    rawValue(
                        model,
                        record,
                        "OFFER_TYPE"
                    )
                );

                offerLineRole = upperValue(
                    rawValue(
                        model,
                        record,
                        "OFFER_LINE_ROLE"
                    )
                );

                isBundleParent = (
                    offerType === 0 &&
                    offerLineRole === "PARENT"
                );

                if (
                    !isBundleParent &&
                    !hasText(serviceId)
                ) {
                    setFieldValidity(
                        model,
                        record,
                        "SERVICEID",
                        "error",
                        "Service is required except for bundled-offer parent rows."
                    );

                    if (!firstError) {
                        firstError = {
                            id: id,
                            columnName: "SERVICEID",
                            message: "Select a service or remove the incomplete invoice line."
                        };
                    }
                } else {
                    setFieldValidity(
                        model,
                        record,
                        "SERVICEID",
                        "valid"
                    );
                }
                if (
                    quantity === null ||
                    !Number.isFinite(quantity) ||
                    quantity <= 0 ||
                    !Number.isInteger(quantity)
                ) {
                    setFieldValidity(
                        model,
                        record,
                        "QTY",
                        "error",
                        "Quantity must be a positive whole number."
                    );

                    if (!firstError) {
                        firstError = {
                            id: id,
                            columnName: "QTY",
                            message: "Quantity must be a positive whole number."
                        };
                    }
                } else {
                    /*
                     * Keep required numeric model values in the string form expected by
                     * APEX before page submit.
                     */
                    if (
                        typeof rawValue(
                            model,
                            record,
                            "QTY"
                        ) !== "string"
                    ) {
                        setModelValue(
                            model,
                            record,
                            "QTY",
                            modelString(quantity)
                        );
                    }

                    setFieldValidity(
                        model,
                        record,
                        "QTY",
                        "valid"
                    );
                }

            });

        } finally {
            protectionRuleApplying = false;
        }

        if (firstError) {
            focusGridCell(
                firstError.id,
                firstError.columnName
            );

            return {
                valid: false,
                message: firstError.message
            };
        }

        return {
            valid: true
        };
    }

    /* ==========================================================================
     * Function: incompleteRowHasMeaningfulData
     * Purpose : Distinguish a pristine new IG row from an incomplete row that
     *           already contains user input or calculated/source evidence.
     * ======================================================================== */
    function incompleteRowHasMeaningfulData(
        model,
        record
    ) {
        var qty =
            numberOrNull(
                rawValue(
                    model,
                    record,
                    "QTY"
                )
            );

        var disc =
            numberOrNull(
                rawValue(
                    model,
                    record,
                    "DISC"
                )
            );

        var myDisc =
            numberOrNull(
                rawValue(
                    model,
                    record,
                    "MY_DISC"
                )
            );

        var discountType =
            upperValue(
                rawValue(
                    model,
                    record,
                    "DISCOUNT_TYPE"
                )
            );

        /*
         * Ignore normal defaults for a newly inserted row:
         *
         * QTY             = 1
         * DISCOUNT_TYPE   = N
         * DISC            = 0
         * MY_DISC         = 0
         */
        if (
            qty !== null &&
            (
                !Number.isFinite(qty) ||
                qty !== 1
            )
        ) {
            return true;
        }

        if (
            discountType &&
            discountType !== "N"
        ) {
            return true;
        }

        if (
            disc !== null &&
            (
                !Number.isFinite(disc) ||
                disc !== 0
            )
        ) {
            return true;
        }

        if (
            myDisc !== null &&
            (
                !Number.isFinite(myDisc) ||
                myDisc !== 0
            )
        ) {
            return true;
        }

        return [
            "PRICE_OVERRIDE",
            "USE_PRICE_OVERRIDE",
            "TEETH_NO",
            "TOOTH_SURFACE",
            "TEETH_NO2",
            "SERVICEDESC",
            "PRICE",
            "MY_PRICE",
            "MY_NET",
            "THE_PAY",
            "THE_COMP",
            "PAT_SERV_REQ_ROW_ID",
            "APPROV_REF_NO",
            "CLAIM_NO",
            "PACKAGE_SERVICE_ID",
            "PACKAGE_INSTANCE_ID",
            "OFFER_ID",
            "OFFER_DTL_ID",
            "OFFER_INSTANCE_ID"
        ].some(function(columnName) {
            var value =
                rawValue(
                    model,
                    record,
                    columnName
                );

            /*
             * USE_PRICE_OVERRIDE = N is another normal default.
             */
            if (
                columnName ===
                "USE_PRICE_OVERRIDE" &&
                upperValue(value) === "N"
            ) {
                return false;
            }

            return hasText(value);
        });
    }

    /* ==========================================================================
     * Function: collectLines
     * Purpose : Collect all non-deleted IG rows using the backend JSON contract.
     * ======================================================================== */
    function collectLines() {
        var model =
            gridModel();

        var rows = [];
        var position = 0;

        var priceOverride;
        var discountPercent;
        var discountAmount;

        if (!model) {
            return rows;
        }

        model.forEach(function(record) {
            var id;
            var serviceId;
            var sequenceNo;
            var lineId;
            var quantity;
            var offerType;
            var offerLineRole;
            var isBundleParent;

            position += 1;

            if (
                isDeleted(
                    model,
                    record
                )
            ) {
                return;
            }

            serviceId = rawValue(
                model,
                record,
                "SERVICEID"
            );

            offerType = numberOrNull(
                rawValue(
                    model,
                    record,
                    "OFFER_TYPE"
                )
            );

            offerLineRole = rawValue(
                model,
                record,
                "OFFER_LINE_ROLE"
            );

            isBundleParent = (
                offerType === 0 &&
                String(
                    offerLineRole || ""
                ).toUpperCase() === "PARENT"
            );

            if (
                !isBundleParent &&
                !hasText(serviceId)
            ) {
                if (
                    incompleteRowHasMeaningfulData(
                        model,
                        record
                    )
                ) {
                    id =
                        recordId(
                            model,
                            record
                        );

                    setFieldValidity(
                        model,
                        record,
                        "SERVICEID",
                        "error",
                        "Service is required."
                    );

                    focusGridCell(
                        id,
                        "SERVICEID"
                    );

                    throw new Error(
                        "Select a service or remove the incomplete invoice line."
                    );
                }

                /*
                 * A completely pristine newly inserted row contributes nothing
                 * financially and may remain temporarily while the user is editing.
                 */
                return;
            }

            id = recordId(
                model,
                record
            );

            if (
                id === null ||
                id === undefined
            ) {
                return;
            }

            sequenceNo = numberOrNull(
                rawValue(
                    model,
                    record,
                    "SEQ_NO"
                )
            );

            lineId = numberOrNull(
                rawValue(
                    model,
                    record,
                    "LINE_ID"
                )
            );

            /*
             * Preserve the exact quantity.
             *
             * Do not silently default a missing quantity to one.
             */
            quantity = numberOrNull(
                rawValue(
                    model,
                    record,
                    "QTY"
                )
            );

            if (
                quantity === null ||
                !Number.isFinite(quantity) ||
                quantity <= 0 ||
                !Number.isInteger(quantity)
            ) {
                setFieldValidity(
                    model,
                    record,
                    "QTY",
                    "error",
                    "Quantity must be a positive whole number."
                );

                throw new Error(
                    "Quantity must be a positive whole number."
                );
            }

            priceOverride =
                validNumberOrNull(
                    rawValue(
                        model,
                        record,
                        "PRICE_OVERRIDE"
                    ),
                    "Price Override"
                );

            discountPercent =
                validNumberOrNull(
                    rawValue(
                        model,
                        record,
                        "DISC"
                    ),
                    "Discount Percentage"
                );

            discountAmount =
                validNumberOrNull(
                    rawValue(
                        model,
                        record,
                        "MY_DISC"
                    ),
                    "Discount Amount"
                );

            setFieldValidity(
                model,
                record,
                "QTY",
                "valid"
            );

            rows.push({
                position: position,
                sequenceNo: sequenceNo,
                lineId: lineId,

                payload: {
                    clientId: String(id),

                    serviceId: serviceId,

                    qty: quantity,

                    priceOverride: priceOverride,

                    usePriceOverride: rawValue(
                        model,
                        record,
                        "USE_PRICE_OVERRIDE"
                    ) || "N",

                    /*
                     * Manual discount inputs only.
                     */
                    discountType: rawValue(
                        model,
                        record,
                        "DISCOUNT_TYPE"
                    ) || "N",

                    disc: discountPercent === null ?
                        0 : discountPercent,

                    myDisc: discountAmount,

                    teethNo: rawValue(
                        model,
                        record,
                        "TEETH_NO"
                    ),

                    toothSurface: rawValue(
                        model,
                        record,
                        "TOOTH_SURFACE"
                    ),

                    teethNo2: rawValue(
                        model,
                        record,
                        "TEETH_NO2"
                    ),

                    patServReqRowId: numberOrNull(
                        rawValue(
                            model,
                            record,
                            "PAT_SERV_REQ_ROW_ID"
                        )
                    ),

                    approvRefNo: rawValue(
                        model,
                        record,
                        "APPROV_REF_NO"
                    ),

                    claimNo: rawValue(
                        model,
                        record,
                        "CLAIM_NO"
                    ),

                    reqNeedA: numberOrNull(
                        rawValue(
                            model,
                            record,
                            "REQ_NEED_A"
                        )
                    ),

                    reqAStatus: numberOrNull(
                        rawValue(
                            model,
                            record,
                            "REQ_A_STATUS"
                        )
                    ),

                    packageServiceId: rawValue(
                        model,
                        record,
                        "PACKAGE_SERVICE_ID"
                    ),

                    packageInstanceId: rawValue(
                        model,
                        record,
                        "PACKAGE_INSTANCE_ID"
                    ),

                    packageLineRole: rawValue(
                        model,
                        record,
                        "PACKAGE_LINE_ROLE"
                    ),

                    packageComponentOrder: numberOrNull(
                        rawValue(
                            model,
                            record,
                            "PACKAGE_COMPONENT_ORDER"
                        )
                    ),

                    packageParentLineId: numberOrNull(
                        rawValue(
                            model,
                            record,
                            "PACKAGE_PARENT_LINE_ID"
                        )
                    ),

                    packagePricingMethod: rawValue(
                        model,
                        record,
                        "PACKAGE_PRICING_METHOD"
                    ),

                    packageDefinitionToken: rawValue(
                        model,
                        record,
                        "PACKAGE_DEFINITION_TOKEN"
                    ),

                    offerId: numberOrNull(
                        rawValue(
                            model,
                            record,
                            "OFFER_ID"
                        )
                    ),

                    offerDtlId: numberOrNull(
                        rawValue(
                            model,
                            record,
                            "OFFER_DTL_ID"
                        )
                    ),

                    offerType: numberOrNull(
                        rawValue(
                            model,
                            record,
                            "OFFER_TYPE"
                        )
                    ),

                    offerInstanceId: rawValue(
                        model,
                        record,
                        "OFFER_INSTANCE_ID"
                    ),

                    offerLineRole: rawValue(
                        model,
                        record,
                        "OFFER_LINE_ROLE"
                    ),

                    offerParentLineId: numberOrNull(
                        rawValue(
                            model,
                            record,
                            "OFFER_PARENT_LINE_ID"
                        )
                    ),

                    offerPriceApplied: numberOrNull(
                        rawValue(
                            model,
                            record,
                            "OFFER_PRICE_APPLIED"
                        )
                    ),

                    offerDisApplied: numberOrNull(
                        rawValue(
                            model,
                            record,
                            "OFFER_DIS_APPLIED"
                        )
                    ),

                    offerNameSnapshot: rawValue(
                        model,
                        record,
                        "OFFER_NAME_SNAPSHOT"
                    ),

                    offerObjectVersionNumber: numberOrNull(
                        rawValue(
                            model,
                            record,
                            "OFFER_OBJECT_VERSION_NUMBER"
                        )
                    ),

                    offerDtlObjectVersionNumber: numberOrNull(
                        rawValue(
                            model,
                            record,
                            "OFFER_DTL_OBJECT_VERSION_NUMBER"
                        )
                    )
                }
            });
        });

        /*
         * Match final invoice line ordering:
         *
         * 1. SEQ_NO
         * 2. LINE_ID
         * 3. Original model position
         */
        rows.sort(function(a, b) {
            var aSeq =
                a.sequenceNo === null ?
                Number.MAX_SAFE_INTEGER :
                a.sequenceNo;

            var bSeq =
                b.sequenceNo === null ?
                Number.MAX_SAFE_INTEGER :
                b.sequenceNo;

            var aLine;
            var bLine;

            if (aSeq !== bSeq) {
                return aSeq - bSeq;
            }

            aLine =
                a.lineId === null ?
                Number.MAX_SAFE_INTEGER :
                a.lineId;

            bLine =
                b.lineId === null ?
                Number.MAX_SAFE_INTEGER :
                b.lineId;

            if (aLine !== bLine) {
                return aLine - bLine;
            }

            return (
                a.position -
                b.position
            );
        });

        return rows.map(function(row) {
            return row.payload;
        });
    }

    /* ==========================================================================
     * Function: buildPayload
     * Purpose : Build the JSON payload expected by the preview callback.
     * ======================================================================== */
    function buildPayload(lines) {
        return {
            header: {
                patientno: itemValue(
                    "P48_PATIENTNO"
                ),

                paytype: numberOrNull(
                    itemValue(
                        "P48_PAYTYPE"
                    )
                ),

                clinicid: numberOrNull(
                    itemValue(
                        "P48_CLINICID"
                    )
                ),

                docid: numberOrNull(
                    itemValue(
                        "P48_DOCID"
                    )
                ),

                currCode: itemValue(
                    "P48_CURR_CODE"
                ),

                finalDisc: pageNumberOrZero(
                    "P48_FINALDISC",
                    "Final Discount"
                )
            },

            payment: {
                amount1Auto: itemValue(
                    "P48_AMOUNT_1_AUTO"
                ) || "Y",

                amount1: pageNumberOrZero(
                    "P48_AMOUNT_1",
                    "Amount 1"
                ),

                amount2: pageNumberOrZero(
                    "P48_AMOUNT_2",
                    "Amount 2"
                )
            },

            lines: lines
        };
    }

    /* ==========================================================================
     * Function: clearTotals
     * Purpose : Clear calculated totals when the grid contains no invoice lines.
     * ======================================================================== */
    function clearTotals() {
        setMoney(
            "P48_TOTAL_GROSS",
            0
        );

        setMoney(
            "P48_TOTAL_DISCOUNT",
            0
        );

        setMoney(
            "P48_TOTAL_NET",
            0
        );

        setMoney(
            "P48_PAT_PAY",
            0
        );

        setMoney(
            "P48_COMP_PAY",
            0
        );

        setMoney(
            "P48_VAT_TOTAL_PAT",
            0
        );

        setMoney(
            "P48_VAT_TOTAL_CO",
            0
        );

        setMoney(
            "P48_AMOUNT_DUE",
            0
        );

        setMoney(
            "P48_REMAINING_AMOUNT",
            0
        );

        if (
            (
                itemValue(
                    "P48_AMOUNT_1_AUTO"
                ) || "Y"
            ) === "Y"
        ) {
            setMoney(
                "P48_AMOUNT_1",
                0
            );
        }

        setItemValue(
            "P48_PAYMENT_STATUS",
            "No Invoice Lines"
        );
    }

    /* ==========================================================================
     * Function: applyTotals
     * Purpose : Apply authoritative invoice totals returned by the backend.
     * ======================================================================== */
    function applyTotals(totals) {

        setMoney(
            "P48_TOTAL_GROSS",
            totals.totalGross
        );

        setMoney(
            "P48_TOTAL_DISCOUNT",
            totals.totalDiscount
        );

        setMoney(
            "P48_TOTAL_NET",
            totals.totalNet
        );

        setMoney(
            "P48_PAT_PAY",
            totals.patientShare
        );

        setMoney(
            "P48_COMP_PAY",
            totals.providerShare
        );

        setMoney(
            "P48_VAT_TOTAL_PAT",
            totals.patientVat
        );

        setMoney(
            "P48_VAT_TOTAL_CO",
            totals.providerVat
        );

        setMoney(
            "P48_AMOUNT_DUE",
            totals.amountDue
        );

        /*
         * Amount 1 remains automatic only while P48_AMOUNT_1_AUTO is Y.
         */
        if (
            (
                itemValue(
                    "P48_AMOUNT_1_AUTO"
                ) || "Y"
            ) === "Y"
        ) {
            setMoney(
                "P48_AMOUNT_1",
                totals.amount1
            );
        }

        /*
         * Do not overwrite P48_AMOUNT_2.
         * It is entered manually by the user.
         */
        setMoney(
            "P48_REMAINING_AMOUNT",
            totals.remainingAmount
        );

        setItemValue(
            "P48_PAYMENT_STATUS",
            totals.paymentStatus ||
            "Unpaid"
        );
    }

    /* ==========================================================================
     * Function: applyLineEditability
     * Purpose : Apply backend-controlled row permissions without disabling
     *           submitted model fields.
     * ======================================================================== */
    function applyLineEditability(
        model,
        record,
        line
    ) {
        /*
         * This single rule performs both responsibilities:
         *
         * 1. Preserve the Point 2 manual-discount normalization.
         * 2. Lock package and bundle service, quantity, price override, and
         *    discount editors while keeping their model values submit-safe.
         */
        applyManualDiscountRule(
            model,
            record,
            line,
            false
        );
    }

    /* ==========================================================================
 * Currency response validation
 * ======================================================================== */
var CURRENCY_TOLERANCE =
    0.01;


/* ==========================================================================
 * Function: requireFiniteResponseNumber
 * Purpose : Require an actual finite JSON number from the preview backend.
 * ======================================================================== */
function requireFiniteResponseNumber(
    value,
    label
) {
    if (
        typeof value !== "number" ||
        !Number.isFinite(value)
    ) {
        throw new Error(
            label +
            " is missing or is not a finite number."
        );
    }

    return value;
}


/* ==========================================================================
 * Function: assertCurrencyEqual
 * Purpose : Compare two calculated monetary values within currency tolerance.
 * ======================================================================== */
function assertCurrencyEqual(
    label,
    actual,
    expected
) {
    if (
        Math.abs(
            actual -
            expected
        ) >
        CURRENCY_TOLERANCE
    ) {
        throw new Error(
            label +
            " does not reconcile with the returned invoice lines."
        );
    }
}

    /* ==========================================================================
     * Function: validatePreviewResponse
     * Purpose : Validate the successful backend preview contract before any result
     *           is applied to the Interactive Grid.
     * ======================================================================== */
    function validatePreviewResponse(
        data,
        requestLines,
        requestPayload
    ) {
        var expectedClientIds = {};
        var responseClientIds = {};

        var requiredTotals = [
            "totalGross",
            "totalDiscount",
            "totalNet",
            "patientShare",
            "providerShare",
            "patientVat",
            "providerVat",
            "amountDue",
            "amount1",
            "amount2",
            "remainingAmount",
            "paymentStatus"
        ];

        if (
            !data ||
            typeof data !== "object" ||
            data.success !== true
        ) {
            throw new Error(
                "Preview response is not a successful application response."
            );
        }

        if (!Array.isArray(data.lines)) {
            throw new Error(
                "Preview response is missing the lines array."
            );
        }

        if (
            !data.totals ||
            typeof data.totals !== "object" ||
            Array.isArray(data.totals)
        ) {
            throw new Error(
                "Preview response is missing totals."
            );
        }

        requiredTotals.forEach(function(name) {
            if (
                !Object.prototype.hasOwnProperty.call(
                    data.totals,
                    name
                )
            ) {
                throw new Error(
                    "Preview totals are missing " +
                    name +
                    "."
                );
            }
        });

        (requestLines || []).forEach(function(line) {
            var clientId =
                String(
                    line &&
                    line.clientId !== null &&
                    line.clientId !== undefined ?
                    line.clientId :
                    ""
                );

            if (!clientId) {
                throw new Error(
                    "A submitted preview line has no clientId."
                );
            }

            if (expectedClientIds[clientId]) {
                throw new Error(
                    "Duplicate submitted preview clientId: " +
                    clientId
                );
            }

            expectedClientIds[clientId] =
                true;
        });

        var lineGross = 0;
var lineDiscount = 0;
var lineNet = 0;
var linePatientShare = 0;
var lineProviderShare = 0;
var linePatientVat = 0;
var lineProviderVat = 0;

var totals =
    data.totals;

var finalDiscount;


/*
 * Validate every returned financial line value before using it
 * for reconciliation.
 */
data.lines.forEach(function(line) {
    lineGross +=
        requireFiniteResponseNumber(
            line.grossAmount,
            "Line gross amount"
        );

    lineDiscount +=
        requireFiniteResponseNumber(
            line.totalDiscountAmount,
            "Line discount amount"
        );

    lineNet +=
        requireFiniteResponseNumber(
            line.netAmount,
            "Line net amount"
        );

    linePatientShare +=
        requireFiniteResponseNumber(
            line.patientShare,
            "Line patient share"
        );

    lineProviderShare +=
        requireFiniteResponseNumber(
            line.providerShare,
            "Line provider share"
        );

    linePatientVat +=
        requireFiniteResponseNumber(
            line.patientVat,
            "Line patient VAT"
        );

    lineProviderVat +=
        requireFiniteResponseNumber(
            line.providerVat,
            "Line provider VAT"
        );
});


/*
 * Require actual finite JSON numbers.
 * Do not parse strings or default nulls to zero.
 */
[
    "totalGross",
    "totalDiscount",
    "totalNet",
    "patientShare",
    "providerShare",
    "patientVat",
    "providerVat",
    "amountDue",
    "amount1",
    "amount2",
    "remainingAmount"
].forEach(function(name) {
    requireFiniteResponseNumber(
        totals[name],
        "Preview total " + name
    );
});


if (
    typeof totals.paymentStatus !==
        "string" ||
    !totals.paymentStatus.trim()
) {
    throw new Error(
        "Preview payment status is missing."
    );
}


/*
 * Reconcile aggregate totals against the authoritative
 * returned line calculations.
 */
assertCurrencyEqual(
    "Total gross",
    totals.totalGross,
    lineGross
);

assertCurrencyEqual(
    "Total net",
    totals.totalNet,
    lineNet
);

assertCurrencyEqual(
    "Total discount",
    totals.totalDiscount,
    lineDiscount
);

/*
 * Additional invariant:
 *
 * Gross - discount = net.
 */
assertCurrencyEqual(
    "Gross/discount/net",
    totals.totalGross -
        totals.totalDiscount,
    totals.totalNet
);

assertCurrencyEqual(
    "Patient share",
    totals.patientShare,
    linePatientShare
);

assertCurrencyEqual(
    "Provider share",
    totals.providerShare,
    lineProviderShare
);

assertCurrencyEqual(
    "Patient VAT",
    totals.patientVat,
    linePatientVat
);

assertCurrencyEqual(
    "Provider VAT",
    totals.providerVat,
    lineProviderVat
);


/*
 * Page 48's current amount-due rule is:
 *
 * patient share
 * - invoice final discount
 * + patient VAT
 *
 * never below zero.
 */
finalDiscount =
    requireFiniteResponseNumber(
        requestPayload.header.finalDisc,
        "Submitted final discount"
    );

assertCurrencyEqual(
    "Amount due",
    totals.amountDue,
    Math.max(
        totals.patientShare -
        finalDiscount +
        totals.patientVat,
        0
    )
);

        data.lines.forEach(function(line) {
            var clientId;

            if (
                !line ||
                typeof line !== "object" ||
                !Object.prototype.hasOwnProperty.call(
                    line,
                    "clientId"
                ) ||
                line.clientId === null ||
                line.clientId === undefined ||
                String(line.clientId) === ""
            ) {
                throw new Error(
                    "A preview response line has no clientId."
                );
            }

            clientId =
                String(
                    line.clientId
                );

            if (!expectedClientIds[clientId]) {
                throw new Error(
                    "Preview returned an unexpected clientId: " +
                    clientId
                );
            }

            if (responseClientIds[clientId]) {
                throw new Error(
                    "Preview returned duplicate clientId: " +
                    clientId
                );
            }

            responseClientIds[clientId] =
                true;
        });

        Object.keys(
            expectedClientIds
        ).forEach(function(clientId) {
            if (!responseClientIds[clientId]) {
                throw new Error(
                    "Preview did not return clientId: " +
                    clientId
                );
            }
        });
    }

    /* ==========================================================================
     * Function: applyLines
     * Purpose : Map calculated backend lines back to their original IG records.
     * ======================================================================== */
    function applyLines(
        data,
        requestLines
    ) {
        var model =
            gridModel();

    var resultsByClientId = {};
    var expectedClientIds = {};
    var appliedClientIds = {};

    if (!model) {
        throw new Error(
            "Invoice Services model is unavailable while applying preview results."
        );
    }

    (requestLines || []).forEach(
        function(line) {
            expectedClientIds[
                String(line.clientId)
            ] = true;
        }
    );

        /*
         * The snapshot must represent only the most recently applied preview.
         * Do not retain deleted or replaced temporary record IDs.
         */
        authoritativeLinesByClientId = {};

        /*
         * Index backend lines by their browser-side IG record IDs.
         */
        (data.lines || []).forEach(
            function(line) {
                var clientId =
                    String(line.clientId);

                resultsByClientId[
                    clientId
                ] = line;

                authoritativeLinesByClientId[
                    clientId
                ] = line;
            }
        );

        applying = true;

        try {
            model.forEach(function(record) {
                var id;
                var line;

                if (
                    isDeleted(
                        model,
                        record
                    )
                ) {
                    return;
                }

                id = recordId(
                    model,
                    record
                );

                if (
                    !expectedClientIds[
                        String(id)
                ]
                ) {
                return;
                }

                if (
                    id === null ||
                    id === undefined
                ) {
                    return;
                }

                line =
                    resultsByClientId[
                        String(id)
                    ];

                if (!line) {
                    throw new Error(
                        "Preview result could not be mapped to invoice line " +
                        String(id) +
                        "."
                    );
                    }

                /*
                 * Authoritative service identity and display. This also repairs a
                 * protected row if an earlier browser editor state cleared its LOV.
                 */
                setLovModelValue(
                    model,
                    record,
                    "SERVICEID",
                    line.serviceId,
                    modelString(line.serviceId) +
                    (
                        hasText(line.serviceDesc) ?
                        " - " + modelString(line.serviceDesc) :
                        ""
                    )
                );

                setModelValue(
                    model,
                    record,
                    "SERVICEDESC",
                    modelString(line.serviceDesc)
                );

                /*
                 * Authoritative quantity.
                 *
                 * Package component quantities are reconstructed by the backend from
                 * PACKAGE_DTL.QTY * parent QTY. Keep the returned value as a string
                 * because APEX model save and item validation expect string values.
                 */
                setModelValue(
                    model,
                    record,
                    "QTY",
                    modelString(line.qty)
                );

                setFieldValidity(
                    model,
                    record,
                    "SERVICEID",
                    "valid"
                );

                setFieldValidity(
                    model,
                    record,
                    "QTY",
                    "valid"
                );

                /*
                 * Authoritative pricing.
                 */
                setModelValue(
                    model,
                    record,
                    "PRICE",
                    line.unitPrice
                );

                setModelValue(
                    model,
                    record,
                    "MY_PRICE",
                    line.grossAmount
                );

                /*
                 * System plan discount outputs.
                 */
                setModelValue(
                    model,
                    record,
                    "PLAN_DISCOUNT_PCT",
                    line.planDiscountPct
                );

                setModelValue(
                    model,
                    record,
                    "PLAN_DISCOUNT_AMOUNT",
                    line.planDiscountAmount
                );

                /*
                 * Effective combined discount outputs.
                 *
                 * Do not write these values into DISC or MY_DISC because those columns
                 * remain manual discount inputs.
                 */
                setModelValue(
                    model,
                    record,
                    "DISCOUNT_SOURCE",
                    line.discountSource
                );

                setModelValue(
                    model,
                    record,
                    "EFFECTIVE_DISCOUNT_PCT",
                    line.effectiveDiscountPct
                );

                setModelValue(
                    model,
                    record,
                    "TOTAL_DISCOUNT_AMOUNT",
                    line.totalDiscountAmount
                );

                /*
                 * Net, payer shares, and VAT.
                 */
                setModelValue(
                    model,
                    record,
                    "MY_NET",
                    line.netAmount
                );

                setModelValue(
                    model,
                    record,
                    "THE_PAY",
                    line.patientShare
                );

                setModelValue(
                    model,
                    record,
                    "THE_COMP",
                    line.providerShare
                );

                setModelValue(
                    model,
                    record,
                    "VAT_RATE",
                    line.vatRate
                );

                setModelValue(
                    model,
                    record,
                    "VAT_VAL_PAT",
                    line.patientVat
                );

                setModelValue(
                    model,
                    record,
                    "VAT_VAL_CO",
                    line.providerVat
                );

                /*
                 * Approval requirement outputs.
                 */
                setModelValue(
                    model,
                    record,
                    "REQ_NEED_A",
                    line.reqNeedA
                );

                setModelValue(
                    model,
                    record,
                    "REQ_A_STATUS",
                    line.reqAStatus
                );

                /*
                 * Persistent package metadata.
                 */
                setModelValue(
                    model,
                    record,
                    "PACKAGE_SERVICE_ID",
                    line.packageServiceId
                );

                setModelValue(
                    model,
                    record,
                    "PACKAGE_INSTANCE_ID",
                    line.packageInstanceId
                );

                setModelValue(
                    model,
                    record,
                    "PACKAGE_LINE_ROLE",
                    line.packageLineRole
                );

                setModelValue(
                    model,
                    record,
                    "PACKAGE_COMPONENT_ORDER",
                    line.packageComponentOrder
                );

                setModelValue(
                    model,
                    record,
                    "PACKAGE_DEFINITION_TOKEN",
                    line.packageDefinitionToken
                );

                /*
                 * Model-writable package rule outputs; custom DML ignores this alias.
                 */
                setModelValue(
                    model,
                    record,
                    "PACKAGE_PRICING_METHOD",
                    line.packagePricingMethod
                );

                /*
                 * Persistent offer evidence.
                 * These values must round-trip unchanged to final invoice creation.
                 */
                setModelValue(
                    model,
                    record,
                    "OFFER_ID",
                    line.offerId
                );

                setModelValue(
                    model,
                    record,
                    "OFFER_DTL_ID",
                    line.offerDtlId
                );

                setModelValue(
                    model,
                    record,
                    "OFFER_TYPE",
                    line.offerType
                );

                setModelValue(
                    model,
                    record,
                    "OFFER_INSTANCE_ID",
                    line.offerInstanceId
                );

                setModelValue(
                    model,
                    record,
                    "OFFER_LINE_ROLE",
                    line.offerLineRole
                );

                setModelValue(
                    model,
                    record,
                    "OFFER_PARENT_LINE_ID",
                    line.offerParentLineId
                );

                setModelValue(
                    model,
                    record,
                    "OFFER_PRICE_APPLIED",
                    line.offerPriceApplied
                );

                setModelValue(
                    model,
                    record,
                    "OFFER_DIS_APPLIED",
                    line.offerDisApplied
                );

                setModelValue(
                    model,
                    record,
                    "OFFER_NAME_SNAPSHOT",
                    line.offerNameSnapshot
                );

                setModelValue(
                    model,
                    record,
                    "OFFER_OBJECT_VERSION_NUMBER",
                    line.offerObjectVersionNumber
                );

                setModelValue(
                    model,
                    record,
                    "OFFER_DTL_OBJECT_VERSION_NUMBER",
                    line.offerDtlObjectVersionNumber
                );

                setModelValue(
                    model,
                    record,
                    "ALLOW_MANUAL_DISCOUNT",
                    line.allowManualDiscount ||
                    "N"
                );

                setModelValue(
                    model,
                    record,
                    "ALLOW_PRICE_OVERRIDE",
                    line.allowPriceOverride ||
                    "N"
                );

                applyLineEditability(
                    model,
                    record,
                    line
                );

                appliedClientIds[
                    String(id)
                ] = true;
            });

            Object.keys(
                expectedClientIds
            ).forEach(function(clientId) {
                if (
                    !appliedClientIds[
                        clientId
                    ]
                ) {
                    throw new Error(
                        "Preview result could not be applied to invoice line " +
                        clientId +
                        "."
                    );
                }
                });

            applyTotals(
                data.totals
            );
        } finally {
            applying = false;
        }

        /*
         * Process model changes that occurred while results were being applied.
         */
        if (refreshPending) {
            refreshPending = false;
            schedule();
        }
    }

    /* ==========================================================================
     * Function: showPreviewError
     * Purpose : Display a safe page-level preview calculation error.
     * ======================================================================== */
    function showPreviewError(message) {
        apex.message.clearErrors();

        apex.message.showErrors([{
            type: "error",
            location: "page",
            message: message ||
                "Invoice preview could not be calculated.",
            unsafe: false
        }]);
    }


    function resolvedPromise(value) {
        var deferred =
            $.Deferred();

        deferred.resolve(
            value || {
                success: true
            }
        );

        return deferred.promise();
    }

    /* ==========================================================================
     * Function: previewStatusElement
     * Purpose : Return the Page 48 accessible preview-status element.
     * ======================================================================== */
    function previewStatusElement() {
        var status$ =
            $("#p48_invoice_preview_status");

        if (!status$.length) {
            status$ =
                $("<div>", {
                    id: "p48_invoice_preview_status",
                    "class": "u-VisuallyHidden",
                    role: "status",
                    "aria-live": "polite",
                    "aria-atomic": "true"
                })
                .appendTo(document.body);
        }

        return status$;
    }


    /* ==========================================================================
     * Function: setPreviewBusy
     * Purpose : Apply the complete browser-side invoice preview busy state.
     *
     * Notes   :
     * - Invoice Lines and Totals expose aria-busy.
     * - Screen readers receive a polite calculation announcement.
     * - Create and import buttons cannot act on provisional totals.
     * - The IG actions module is notified so import/removal actions are disabled.
     * ======================================================================== */
    function setPreviewBusy(value) {
        var nextBusy = !!value;

        var changed =
            previewBusy !==
            nextBusy;

        var createDisabled;
        var importDisabled;

        previewBusy =
            nextBusy;

        $("#invoice_services,#invoice_totals")
            .attr(
                "aria-busy",
                previewBusy ?
                "true" :
                "false"
            );

        previewStatusElement()
            .text(
                previewBusy ?
                "Calculating invoice." :
                ""
            );

        /*
         * Create must remain disabled for any independent reason as well:
         * - preview calculation
         * - final invoice submission
         * - configuration failure
         */
        createDisabled = (
            previewBusy ||
            !!window.p48InvoiceSubmitting ||
            configurationFailed
        );

        $(
                "#btn_create_invoice," +
                "#btn_create_print_sms"
            )
            .prop(
                "disabled",
                createDisabled
            )
            .attr(
                "aria-disabled",
                createDisabled ?
                "true" :
                "false"
            );

        /*
         * Dialog import buttons must also be locked because the dialog may already
         * have been open when recalculation started.
         */
        importDisabled = (
            previewBusy ||
            !!window.p48InvoiceSubmitting
        );

        $(
                "#btn_import_package," +
                "#btn_import_offer"
            )
            .prop(
                "disabled",
                importDisabled
            )
            .attr(
                "aria-disabled",
                importDisabled ?
                "true" :
                "false"
            );

        /*
         * Notify the Interactive Grid actions module.
         */
        if (changed) {
            $(document).trigger(
                "p48invoicepreviewstatechange", [{
                    busy: previewBusy
                }]
            );
        }
    }

    function rejectedPromise(message) {
        var deferred =
            $.Deferred();

        deferred.reject({
            message: message
        });

        return deferred.promise();
    }

    /* ==========================================================================
     * Function: previewAjaxBusinessMessage
     * Purpose : Extract only an approved business message from a failed preview
     *           Ajax response. Never expose arbitrary responseText to the user.
     * ======================================================================== */
    function previewAjaxBusinessMessage(
        jqXHR
    ) {
        var data = null;

        if (
            jqXHR &&
            jqXHR.responseJSON &&
            typeof jqXHR.responseJSON ===
            "object"
        ) {
            data =
                jqXHR.responseJSON;
        }

        /*
         * Some failed responses may contain valid JSON without jQuery
         * populating responseJSON. Parse it, but never display raw responseText.
         */
        if (
            !data &&
            jqXHR &&
            typeof jqXHR.responseText ===
            "string" &&
            jqXHR.responseText.trim()
        ) {
            try {
                data =
                    JSON.parse(
                        jqXHR.responseText
                    );
            } catch (ignore) {
                data = null;
            }
        }

        /*
         * Only trust the documented Page 48 failure contract.
         */
        if (
            data &&
            data.success === false &&
            typeof data.message ===
            "string" &&
            data.message.trim()
        ) {
            return data.message.trim();
        }

        return "";
    }

    /* ==========================================================================
     * Function: abortActivePreviewRequest
     * Purpose : Cancel a preview request that has become obsolete.
     * ======================================================================== */
    function abortActivePreviewRequest() {
        if (
            activePreviewRequest &&
            typeof activePreviewRequest.abort ===
            "function"
        ) {
            try {
                activePreviewRequest.abort();
            } catch (e) {
                apex.debug.warn(
                    "Page 48 could not abort the obsolete invoice preview request.",
                    e
                );
            }
        }

        activePreviewRequest = null;
    }

    /* ==========================================================================
     * Function: requestPreview
     * Purpose : Run one authoritative preview operation.
     *
     * Contract:
     * - Resolve only after success === true and the response has been completely
     *   validated and applied.
     * - Reject business failures.
     * - Reject stale/obsolete responses.
     * - Reject response-contract and row-mapping failures.
     * - Reject transport failures.
     * ======================================================================== */
    function requestPreview() {
        var lines;
        var payload;
        var thisToken;

        var result =
            $.Deferred();

        var ajaxRequest;

        if (
            !editablePreviewEnabled()
        ) {
            return resolvedPromise({
                success: true
            });
        }

        setPreviewBusy(
            true
        );

        if (applying) {
            refreshPending = true;

            return rejectedPromise(
                "Invoice preview is still applying. Try again."
            );
        }

        if (
            importIsLoading()
        ) {
            refreshPending = true;

            return rejectedPromise(
                "Invoice lines are still loading. Try again."
            );
        }

        try {
            lines =
                collectLines();

            if (!lines.length) {
                requestToken += 1;

                authoritativeLinesByClientId = {};

                clearTotals();

                abortActivePreviewRequest();

                setPreviewBusy(
                    false
                );

                return resolvedPromise({
                    success: true
                });
            }

            payload =
                buildPayload(
                    lines
                );
        } catch (e) {
            requestToken += 1;

            abortActivePreviewRequest();

            setPreviewBusy(
                false
            );

            showPreviewError(
                e &&
                e.message ?
                e.message :
                "Correct the invalid invoice value before continuing."
            );

            return rejectedPromise(
                e &&
                e.message ?
                e.message :
                "Invalid invoice value."
            );
        }

        thisToken =
            ++requestToken;

        abortActivePreviewRequest();

        ajaxRequest =
            apex.server.process(
                PROCESS_NAME, {
                    x01: JSON.stringify(
                        payload
                    ),

                    pageItems: "#P48_INFO_CENTER_ID,#P48_DRAFT_ID"
                }, {
                    dataType: "json"
                }
            );

        /*
         * Keep the physical jqXHR so Point 61 can still abort obsolete
         * database/Ajax work.
         */
        activePreviewRequest =
            ajaxRequest;

        ajaxRequest
            .done(function(data) {
                var businessMessage;

                /*
                 * Stale transport success is still an application failure for
                 * the promise returned to the caller.
                 */
                if (
                    thisToken !==
                    requestToken
                ) {
                    result.reject({
                        message: "Invoice preview was superseded by a newer calculation.",
                        stale: true
                    });

                    return;
                }

                /*
                 * HTTP/Ajax success does not mean invoice-preview success.
                 */
                if (
                    !data ||
                    data.success !== true
                ) {
                    businessMessage =
                        (
                            data &&
                            typeof data.message ===
                            "string" &&
                            data.message.trim()
                        ) ?
                        data.message.trim() :
                        "Invoice preview could not be calculated.";

                    showPreviewError(
                        businessMessage
                    );

                    result.reject({
                        message: businessMessage,
                        applicationFailure: true
                    });

                    return;
                }

                try {
                    /*
                     * Validate the complete response contract and mapping before
                     * allowing final invoice creation to proceed.
                     */
                    validatePreviewResponse(
                        data,
                        lines,
                        payload
                    );

                    applyLines(
                        data,
                        lines
                    );
                } catch (e) {
                    apex.debug.error(
                        "Page 48 invoice preview response could not be applied.",
                        e
                    );

                    showPreviewError(
                        "Invoice preview returned incomplete or inconsistent results. " +
                        "Recalculate the invoice or contact support."
                    );

                    result.reject({
                        message: "Invoice preview returned incomplete or inconsistent results.",
                        applicationFailure: true
                    });

                    return;
                }

                /*
                 * This is the only successful resolution path:
                 * success === true + valid response + complete application.
                 */
                result.resolve(
                    data
                );
            })
            .fail(function(
                jqXHR,
                textStatus,
                errorThrown
            ) {
                var businessMessage;

                /*
                 * An obsolete response must reject the application promise.
                 * Do not display this as a user-facing error because replacement
                 * calculations during normal editing are expected.
                 */
                if (
                    thisToken !==
                    requestToken
                ) {
                    result.reject({
                        message: "Invoice preview was superseded by a newer calculation.",
                        stale: true
                    });

                    return;
                }

                /*
                 * A deliberate abort of the current request is not a successful
                 * preview either.
                 */
                if (
                    textStatus ===
                    "abort"
                ) {
                    result.reject({
                        message: "Invoice preview was cancelled.",
                        stale: true
                    });

                    return;
                }

                businessMessage =
                    previewAjaxBusinessMessage(
                        jqXHR
                    );

                apex.debug.error(
                    "Page 48 invoice preview Ajax request failed.", {
                        status: jqXHR ?
                            jqXHR.status : null,

                        textStatus: textStatus,

                        errorThrown: errorThrown
                    }
                );

                businessMessage =
                    businessMessage ||
                    "Invoice preview could not be calculated.";

                showPreviewError(
                    businessMessage
                );

                result.reject({
                    message: businessMessage
                });
            })
            .always(function() {
                /*
                 * Only the latest authoritative request may release Point 62's
                 * preview-busy state.
                 */
                if (
                    thisToken ===
                    requestToken
                ) {
                    activePreviewRequest =
                        null;

                    setPreviewBusy(
                        false
                    );
                }
            });

        return result.promise();
    }

    /* ==========================================================================
     * Function: schedule
     * Purpose : Debounce editable invoice recalculation requests.
     * ======================================================================== */
    function schedule(options) {
        options =
            options || {};

        if (configurationFailed) {
            return;
        }

        if (activePreviewRequest) {
            requestToken += 1;

            abortActivePreviewRequest();
        }
        /*
         * Final invoice creation owns the page now.
         * Do not schedule another background preview.
         */
        if (window.p48InvoiceSubmitting) {
            return;
        }

        if (
            !editablePreviewEnabled()
        ) {
            return;
        }

        setPreviewBusy(
            true
        );

        if (
            applying ||
            importIsLoading()
        ) {
            refreshPending = true;
            return;
        }

        window.clearTimeout(
            timer
        );

        timer =
            window.setTimeout(
                requestPreview,
                options.immediate ?
                0 :
                delayMs
            );
    }

    /* ==========================================================================
     * Function: subscribedModelIsTracked
     * Purpose : Determine whether this module already tracks a model subscription.
     * ======================================================================== */
    function subscribedModelIsTracked(model) {
        if (!model) {
            return false;
        }

        if (supportsWeakSet) {
            return subscribedModels.has(
                model
            );
        }

        return subscribedModels.indexOf(
            model
        ) !== -1;
    }


    /* ==========================================================================
     * Function: trackSubscribedModel
     * Purpose : Track a subscribed APEX model without modifying the model object.
     * ======================================================================== */
    function trackSubscribedModel(model) {
        if (
            !model ||
            subscribedModelIsTracked(model)
        ) {
            return;
        }

        if (supportsWeakSet) {
            subscribedModels.add(
                model
            );

            return;
        }

        subscribedModels.push(
            model
        );
    }


    /* ==========================================================================
     * Function: untrackSubscribedModel
     * Purpose : Remove a model from this module's subscription tracking.
     * ======================================================================== */
    function untrackSubscribedModel(model) {
        var index;

        if (!model) {
            return;
        }

        if (supportsWeakSet) {
            subscribedModels.delete(
                model
            );

            return;
        }

        index =
            subscribedModels.indexOf(
                model
            );

        if (index !== -1) {
            subscribedModels.splice(
                index,
                1
            );
        }
    }


    /* ==========================================================================
     * Function: unsubscribePreviewModel
     * Purpose : Remove the observer from the previous Invoice Services model.
     *
     * Notes   : model.subscribe() returns the viewId required by
     *           model.unSubscribe(viewId).
     * ======================================================================== */
    function unsubscribePreviewModel() {
        var model =
            subscribedModel;

        var viewId =
            subscribedModelViewId;

        if (!model) {
            return;
        }

        if (
            viewId !== null &&
            viewId !== undefined &&
            typeof model.unSubscribe ===
            "function"
        ) {
            try {
                model.unSubscribe(
                    viewId
                );
            } catch (e) {
                apex.debug.warn(
                    "Page 48 could not unsubscribe the previous Invoice Services preview model.",
                    e
                );
            }
        }

        untrackSubscribedModel(
            model
        );

        subscribedModel = null;
        subscribedModelViewId = null;
    }

    /* ==========================================================================
     * Function: subscribe
     * Purpose : Subscribe once to changes in the current Invoice Services model.
     *
     * Notes   :
     * - Never attach private state to an APEX-owned model.
     * - Retain the viewId returned by model.subscribe().
     * - Unsubscribe when the Interactive Grid replaces its model.
     * ======================================================================== */
    function subscribe() {
        var model =
            gridModel();

        var viewId;

        /*
         * A region refresh can replace the APEX model object.
         * Detach our observer from the previous model before subscribing
         * to its replacement.
         */
        if (
            subscribedModel &&
            subscribedModel !== model
        ) {
            unsubscribePreviewModel();
        }

        if (!model) {
            return;
        }

        if (
            !validateRequiredModelColumns(
                model
            )
        ) {
            return;
        }

        /*
         * Already subscribed to this exact model.
         */
        if (
            subscribedModel === model &&
            subscribedModelIsTracked(
                model
            ) &&
            subscribedModelViewId !== null &&
            subscribedModelViewId !== undefined
        ) {
            return;
        }

        try {
            viewId =
                model.subscribe({
                    onChange: function(
                        type,
                        change
                    ) {
                        if (
                            applying ||
                            discountRuleApplying ||
                            protectionRuleApplying
                        ) {
                            return;
                        }

                        /*
                         * Ignore programmatic row construction while an importer owns
                         * the model.
                         */
                        if (importIsLoading()) {
                            return;
                        }

                        if (
                            type === "set" &&
                            change &&
                            change.record &&
                            revertProtectedModelChange(
                                model,
                                change
                            )
                        ) {
                            return;
                        }

                        if (
                            type === "set" &&
                            change &&
                            change.record && [
                                "DISCOUNT_TYPE",
                                "DISC",
                                "MY_DISC"
                            ].indexOf(
                                change.field
                            ) !== -1
                        ) {
                            applyManualDiscountRule(
                                model,
                                change.record,
                                null,
                                false
                            );
                        }

                        if (
                            [
                                "set",
                                "delete",
                                "insert",
                                "copy",
                                "move",
                                "refresh"
                            ].indexOf(type) === -1
                        ) {
                            return;
                        }

                        schedule();
                    }
                });
        } catch (e) {
            apex.debug.error(
                "Page 48 could not subscribe to Invoice Services model changes.",
                e
            );

            configurationFailed =
                true;

            if (
                typeof p48SetInvoiceCreateButtonsDisabled ===
                "function"
            ) {
                p48SetInvoiceCreateButtonsDisabled(
                    true
                );
            }

            showPreviewError(
                "Invoice Services could not be initialized. " +
                "Refresh the page or contact support."
            );

            return;
        }

        /*
         * Retain both the model and the documented subscription identifier.
         */
        subscribedModel =
            model;

        subscribedModelViewId =
            viewId;

        trackSubscribedModel(
            model
        );
    }

    /* ==========================================================================
     * Function: waitForPreviewIdle
     * Purpose : Wait until package/bundle loading and preview application have
     *           completely finished before the exclusive final preview.
     * ======================================================================== */
    function waitForPreviewIdle() {
        var deferred =
            $.Deferred();

        function checkReady() {
            var loading;

            try {
                loading =
                    importIsLoading();
            } catch (e) {
                deferred.reject({
                    message: "Invoice state could not be verified before submission."
                });

                return;
            }

            if (
                !applying &&
                !loading
            ) {
                deferred.resolve();
                return;
            }

            window.setTimeout(
                checkReady,
                25
            );
        }

        checkReady();

        return deferred.promise();
    }


    /* ==========================================================================
     * Function: finishInvoiceEditing
     * Purpose : Commit the current Interactive Grid editor value into the model
     *           before collecting the authoritative final-preview payload.
     * ======================================================================== */
    function finishInvoiceEditing() {
        var deferred =
            $.Deferred();

        var view =
            gridView();

        if (
            !view ||
            !view.view$
        ) {
            deferred.reject({
                message: "Invoice lines are not available. Refresh the page and try again."
            });

            return deferred.promise();
        }

        try {
            view.view$
                .grid(
                    "finishEditing"
                )
                .done(function() {
                    deferred.resolve();
                })
                .fail(function() {
                    deferred.reject({
                        message: "The active invoice line could not be completed. Review the line and try again."
                    });
                });
        } catch (e) {
            apex.debug.error(
                "Page 48 could not finish Invoice Services editing before final preview.",
                e
            );

            deferred.reject({
                message: "The active invoice line could not be completed. Review the line and try again."
            });
        }

        return deferred.promise();
    }

    /* ==========================================================================
     * Function: init
     * Purpose : Initialize model subscription and the first invoice preview.
     * ======================================================================== */
    function init() {
        if (
            !validateRequiredPageItems()
        ) {
            return;
        }

        if (
            !editablePreviewEnabled()
        ) {
            return;
        }

        subscribe();

        if (configurationFailed) {
            return;
        }
        bindLineEditorEvents();
        bindSoftLockGuards();

        if (!initialized) {
            initialized = true;

            $("#" + REGION_ID)
                .off(
                    "apexafterrefresh.p48InvoicePreview"
                )
                .on(
                    "apexafterrefresh.p48InvoicePreview",
                    function() {
                        if (
                            !validateRequiredPageItems()
                        ) {
                            return;
                        }

                        subscribe();

                        if (configurationFailed) {
                            return;
                        }

                        bindLineEditorEvents();
                        bindSoftLockGuards();

                        schedule({
                            immediate: true
                        });
                    }
                );
        }

        schedule({
            immediate: true
        });
    }

    /* ==========================================================================
     * Public API
     * ======================================================================== */
    return {
        /*
         * Initialize the editable invoice preview.
         */
        init: init,

        /*
         * Schedule a preview recalculation.
         */
        refresh: function(options) {
            schedule(options);
        },

        refreshAndWait: function() {
            var deferred =
                $.Deferred();

            if (
                configurationFailed ||
                !validateRequiredPageItems()
            ) {
                return rejectedPromise(
                    "Invoice page configuration is incomplete. " +
                    "Refresh the page or contact support."
                );
            }

            /*
             * No ordinary debounced preview may compete with the final one.
             */
            window.clearTimeout(
                timer
            );

            timer = null;

            /*
             * Wait for any importer or synchronous result application to finish.
             */
            waitForPreviewIdle()
                .done(function() {

                    /*
                     * Then commit the active IG editor into the model.
                     */
                    finishInvoiceEditing()
                        .done(function() {
                            var validationResult;

                            /*
                             * finishEditing can cause model change events.
                             * Remove any debounce that may have been queued.
                             */
                            window.clearTimeout(
                                timer
                            );

                            timer = null;

                            /*
                             * Ensure an older preview cannot compete with this final
                             * authoritative calculation.
                             */
                            requestToken += 1;

                            abortActivePreviewRequest();

                            refreshPending = false;

                            validationResult =
                                validateRequiredRowsForSubmit();

                            if (!validationResult.valid) {
                                deferred.reject({
                                    message: validationResult.message
                                });

                                return;
                            }

                            /*
                             * One exclusive authoritative final preview.
                             */
                            requestPreview()
                                .done(function(data) {
                                    deferred.resolve(
                                        data
                                    );
                                })
                                .fail(function(error) {
                                    deferred.reject(
                                        error
                                    );
                                });
                        })
                        .fail(function(error) {
                            deferred.reject(
                                error
                            );
                        });
                })
                .fail(function(error) {
                    deferred.reject(
                        error
                    );
                });

            return deferred.promise();
        },

        /*
         * Enable or disable bulk-loading mode.
         *
         * When bulk loading ends, one complete preview is run by default.
         */
        setBulkLoading: function(
            value,
            refreshAfter
        ) {
            bulkLoading = !!value;

            if (
                !bulkLoading &&
                refreshAfter !== false
            ) {
                refreshPending = false;

                schedule({
                    immediate: true
                });
            }
        },

        /*
         * Enter exclusive final-submit mode.
         *
         * Cancel any scheduled preview and invalidate any preview
         * response that was already in flight before Create was clicked.
         */
        beginSubmit: function() {
            window.clearTimeout(
                timer
            );

            timer = null;

            /*
             * Any response carrying the previous token becomes stale and
             * will not be applied to the grid.
             */
            requestToken += 1;

            abortActivePreviewRequest();

            refreshPending = false;
        },

        /*
         * Leave final-submit mode after client-side validation or preview
         * failure. The caller clears window.p48InvoiceSubmitting first.
         */
        endSubmit: function() {
            refreshPending = false;

            schedule({
                immediate: true
            });
        },

        /*
         * Return whether backend output is currently being applied to the IG.
         */
        isApplying: function() {
            return applying;
        },
        /*
         * Return whether Invoice Lines/Totals currently contain provisional values.
         */
        isBusy: function() {
            return previewBusy;
        }

    };
})(
    apex,
    apex.jQuery
);