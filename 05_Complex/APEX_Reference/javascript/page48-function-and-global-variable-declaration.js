/* ============================================================================
 * Function: p48NumberOrNull
 * Purpose : Parse a locale-aware numeric value.
 *           Blank values return null; malformed values are rejected.
 * ========================================================================== */
function p48NumberOrNull(
    value,
    label
) {
    var text;
    var n;
    var name =
        label || "Value";

    if (
        value === null ||
        value === undefined
    ) {
        return null;
    }

    if (typeof value === "number") {
        if (!Number.isFinite(value)) {
            throw new Error(
                name +
                " must be a valid number."
            );
        }

        return value;
    }

    text =
        String(value).trim();

    if (!text) {
        return null;
    }

    n =
        apex.locale.toNumber(
            text
        );

    if (!Number.isFinite(n)) {
        throw new Error(
            name +
            " must be a valid number."
        );
    }

    return n;
}


/* ============================================================================
 * Function: p48NumberValue
 * Purpose : Parse a locale-aware numeric value.
 *           Blank values return zero; malformed values are rejected.
 * ========================================================================== */
function p48NumberValue(
    value,
    label
) {
    var n =
        p48NumberOrNull(
            value,
            label
        );

    return n === null ?
        0 :
        n;
}

/* ============================================================================
 * Function: p48Money
 * Purpose : Normalize a numeric value to two decimal places.
 * ========================================================================== */
function p48Money(value) {
    return Math.round(p48NumberValue(value) * 100) / 100;
}

/* ============================================================================
 * Function: p48SetMoney
 * Purpose : Set a Page 48 item to a normalized two-decimal numeric value.
 * ========================================================================== */
function p48SetMoney(itemName, value) {
    apex.item(itemName).setValue(p48Money(value), null, true);
}

/* ============================================================================
 * Function: p48ApplyPaymentTotals
 * Purpose : Apply calculated invoice and payment totals to the Page 48 items.
 * ========================================================================== */
function p48ApplyPaymentTotals(totals) {
    p48SetMoney("P48_TOTAL_GROSS", totals.gross);
    p48SetMoney("P48_TOTAL_DISCOUNT", totals.discount);
    p48SetMoney("P48_TOTAL_NET", totals.net);
    p48SetMoney("P48_PAT_PAY", totals.patPay);
    p48SetMoney("P48_COMP_PAY", totals.compPay);
    p48SetMoney("P48_VAT_TOTAL_PAT", totals.vatPat);
    p48SetMoney("P48_VAT_TOTAL_CO", totals.vatCo);
    p48SetMoney("P48_AMOUNT_DUE", totals.amountDue);
    p48SetMoney("P48_REMAINING_AMOUNT", totals.remainingAmount);

    if (totals.amount1 !== null && totals.amount1 !== undefined) {
        p48SetMoney("P48_AMOUNT_1", totals.amount1);
    }

    apex.item("P48_PAYMENT_STATUS").setValue(
        totals.paymentStatus,
        null,
        true
    );
}

/* ============================================================================
 * Function: p48RefreshImportPaymentTotals
 * Purpose : Rebuild locked-source totals on the server and optionally refresh the import region.
 * ========================================================================== */
function p48RefreshImportPaymentTotals(options) {
    var refreshRegion = options && options.refreshRegion === true;

    apex.server.process(
        "BUILD_LOCKED_LINES_COLLECTION", {
            pageItems: "#P48_SOURCE_MODE,#P48_PATIENTNO,#P48_PAYTYPE," +
                "#P48_CLINICID,#P48_DOCID,#P48_SEED_SERVICEID,#P48_VISIT_UNIQUE," +
                "#P48_FINALDISC,#P48_AMOUNT_1,#P48_AMOUNT_2,#P48_AMOUNT_1_AUTO"
        }, {
            dataType: "json",
            success: function(data) {
                if (!data || data.success !== true) {
                    apex.message.clearErrors();
                    apex.message.showErrors([{
                        type: "error",
                        location: "page",
                        message: "Could not refresh invoice payment totals.",
                        unsafe: false
                    }]);
                    return;
                }

                if (data.totals) {
                    p48ApplyPaymentTotals({
                        gross: data.totals.gross,
                        discount: data.totals.discount,
                        net: data.totals.net,
                        patPay: data.totals.patPay,
                        compPay: data.totals.compPay,
                        vatPat: data.totals.vatPat,
                        vatCo: data.totals.vatCo,
                        amountDue: data.totals.amountDue,
                        amount1: data.totals.amount1,
                        amount2: data.totals.amount2,
                        remainingAmount: data.totals.remainingAmount,
                        paymentStatus: data.totals.paymentStatus
                    });
                }

                if (refreshRegion && apex.region("invoice_services_import")) {
                    apex.region("invoice_services_import").refresh();
                }
            },
            error: function(jqXHR, textStatus, errorThrown) {
                apex.message.clearErrors();
                apex.message.showErrors([{
                    type: "error",
                    location: "page",
                    message: errorThrown || textStatus || "Could not refresh invoice payment totals.",
                    unsafe: false
                }]);
            }
        }
    );
}

/* ============================================================================
 * Page 48 invoice submission guard
 * Prevents duplicate create attempts and releases automatically when an
 * APEX server-side validation/process error is returned through Ajax.
 * ========================================================================== */
window.p48InvoiceSubmitting = false;
window.p48InvoiceSubmitErrorObserver = null;
window.p48ReservedPrintWindow = null;


/* ============================================================================
 * Function: p48SetInvoiceCreateButtonsDisabled
 * ========================================================================== */
function p48SetInvoiceCreateButtonsDisabled(
    disabled
) {
    var buttons$ =
        apex.jQuery(
            "#btn_create_invoice," +
            "#btn_create_print_sms"
        );

    buttons$.prop(
        "disabled",
        !!disabled
    );

    if (disabled) {
        buttons$.attr(
            "aria-disabled",
            "true"
        );
    } else {
        buttons$.removeAttr(
            "aria-disabled"
        );
    }
}


/* ============================================================================
 * Function: p48StopInvoiceSubmitErrorWatch
 * ========================================================================== */
function p48StopInvoiceSubmitErrorWatch() {
    if (
        window.p48InvoiceSubmitErrorObserver
    ) {
        window.p48InvoiceSubmitErrorObserver
            .disconnect();

        window.p48InvoiceSubmitErrorObserver =
            null;
    }
}


/* ============================================================================
 * Function: p48CloseReservedPrintWindow
 * Purpose : Clean up the reserved print window after a failed create attempt.
 * ========================================================================== */
function p48CloseReservedPrintWindow() {
    sessionStorage.removeItem(
        "p48_print_pending"
    );

    try {
        if (
            window.p48ReservedPrintWindow &&
            !window.p48ReservedPrintWindow.closed
        ) {
            window.p48ReservedPrintWindow.close();
        }
    } catch (ignore) {
        /*
         * Ignore browser popup access issues.
         */
    }

    window.p48ReservedPrintWindow = null;
}


/* ============================================================================
 * Function: p48StartInvoiceSubmitErrorWatch
 * Purpose : Release the invoice-submit lock when APEX renders a server-side
 *           validation/process error.
 *
 * Notes   : The APEX notification container may not exist until an error is
 *           actually rendered, so observe document.body rather than the
 *           notification element itself.
 * ========================================================================== */
function p48StartInvoiceSubmitErrorWatch() {
    var root =
        document.body;

    function releaseIfErrorVisible() {
        var notification$ =
            apex.jQuery(
                "#t_Alert_Notification"
            );

        if (
            !window.p48InvoiceSubmitting
        ) {
            return;
        }

        if (
            notification$.length &&
            notification$.is(":visible") &&
            notification$
            .text()
            .trim()
        ) {
            p48ReleaseInvoiceSubmit();
        }
    }

    p48StopInvoiceSubmitErrorWatch();

    if (
        !root ||
        typeof MutationObserver !==
        "function"
    ) {
        return;
    }

    window.p48InvoiceSubmitErrorObserver =
        new MutationObserver(
            function() {
                window.setTimeout(
                    releaseIfErrorVisible,
                    0
                );
            }
        );

    window.p48InvoiceSubmitErrorObserver
        .observe(
            root, {
                childList: true,
                subtree: true,
                attributes: true,
                characterData: true,
                attributeFilter: [
                    "class",
                    "style",
                    "hidden",
                    "aria-hidden"
                ]
            }
        );
}


/* ============================================================================
 * Function: p48BeginInvoiceSubmit
 * Purpose : Acquire the single browser-side create lock.
 * ========================================================================== */
function p48BeginInvoiceSubmit() {
    if (window.p48InvoiceSubmitting) {
        return false;
    }

    /*
     * Remove errors from a previous attempt. Any current validation error will
     * be shown again by the final preview/client/server validation.
     */
    apex.message.clearErrors();

    window.p48InvoiceSubmitting = true;

    p48SetInvoiceCreateButtonsDisabled(
        true
    );

    /*
     * Start watching for server-side validation/process errors before
     * the final create path begins.
     */
    p48StartInvoiceSubmitErrorWatch();

    /*
     * Invalidate any old preview and prevent scheduled background previews.
     */
    if (
        window.p48InvoicePreview &&
        typeof window.p48InvoicePreview.beginSubmit ===
        "function"
    ) {
        window.p48InvoicePreview.beginSubmit();
    }

    return true;
}


/* ============================================================================
 * Function: p48ReleaseInvoiceSubmit
 * Purpose : Release the lock after any failed create attempt.
 * ========================================================================== */
function p48ReleaseInvoiceSubmit() {
    window.p48InvoiceSubmitting = false;

    p48StopInvoiceSubmitErrorWatch();

    p48SetInvoiceCreateButtonsDisabled(
        false
    );

    /*
     * Relevant only to Create, Print & SMS.
     */
    p48CloseReservedPrintWindow();

    if (
        window.p48InvoicePreview &&
        typeof window.p48InvoicePreview.endSubmit ===
        "function"
    ) {
        window.p48InvoicePreview.endSubmit();
    }
}

/* ============================================================================
 * Function: p48LoadPackageImportLinesIntoIg
 * Purpose : Load one complete package directly into the editable Invoice
 *           Services model, then run one authoritative batch preview.
 * ========================================================================== */
function p48LoadPackageImportLinesIntoIg(options) {
    "use strict";

    var region =
        apex.region("invoice_services");

    var ig$;
    var gridView;
    var model;

    var insertedRecords = [];
    var lastRecord = null;
    var nextSequence = 10;

    options = options || {};

    /* ==========================================================================
     * Function: showError
     * Purpose : Display a safe page-level package import error.
     * ======================================================================== */
    function showError(message) {
        apex.message.showErrors([{
            type: "error",
            location: "page",
            message: message ||
                "Package services could not be loaded.",
            unsafe: false
        }]);
    }

    if (
        window.p48InvoiceSubmitting ||
        (
            window.p48InvoicePreview &&
            typeof window.p48InvoicePreview.isBusy ===
            "function" &&
            window.p48InvoicePreview.isBusy()
        )
    ) {
        showError(
            "Invoice calculation is in progress. Complete the calculation before importing a package."
        );

        return;
    }

    /* ==========================================================================
     * Function: columnExists
     * Purpose : Determine whether an Interactive Grid model column exists.
     * ======================================================================== */
    function columnExists(columnName) {
        var fieldKey;

        try {
            fieldKey =
                model.getFieldKey(columnName);

            return (
                fieldKey !== null &&
                fieldKey !== undefined
            );
        } catch (e) {
            return false;
        }
    }

    /* ==========================================================================
     * Function: rawValue
     * Purpose : Read the underlying value from an IG model column.
     *
     * Notes   : Popup LOV values may be objects containing:
     *
     *             {
     *               v: returnValue,
     *               d: displayValue
     *             }
     * ======================================================================== */
    function rawValue(
        record,
        columnName
    ) {
        var value;

        try {
            value =
                model.getValue(
                    record,
                    columnName
                );
        } catch (e) {
            return null;
        }

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
     * Function: isDeleted
     * Purpose : Determine whether an IG model row is marked for deletion.
     * ======================================================================== */
    function isDeleted(record) {
        var recordId;
        var metadata;

        try {
            recordId =
                model.getRecordId(record);

            metadata =
                model.getRecordMetadata(
                    recordId
                );

            return !!(
                metadata &&
                metadata.deleted
            );
        } catch (e) {
            return false;
        }
    }

    /* ==========================================================================
     * Function: exactQuantity
     * Purpose : Convert and validate an exact package quantity.
     *
     * Notes   : Missing or invalid quantities are not defaulted to one.
     * ======================================================================== */
    function exactQuantity(
        value,
        serviceId
    ) {
        var quantity;

        if (
            value === null ||
            value === undefined ||
            value === ""
        ) {
            throw new Error(
                "Package service " +
                serviceId +
                " has no quantity."
            );
        }

        quantity =
            p48NumberOrNull(
                value,
                "Package service " +
                serviceId +
                " quantity"
            );

        if (
            quantity === null ||
            quantity <= 0 ||
            !Number.isInteger(quantity)
        ) {
            throw new Error(
                "Package service " +
                serviceId +
                " quantity must be a positive whole number."
            );
        }

        return modelString(quantity);
    }

    /* ==========================================================================
     * Function: modelString
     * Purpose : Convert a value to the string format expected by the APEX model
     *           and server submission.
     * ======================================================================== */
    function modelString(value) {
        if (
            value === null ||
            value === undefined
        ) {
            return "";
        }

        return String(value);
    }

    /* ==========================================================================
     * Function: setEditableValue
     * Purpose : Set a normal editable Interactive Grid column.
     *
     * Notes   : This is used only for columns that accept model.setValue.
     * ======================================================================== */
    function setEditableValue(
        record,
        columnName,
        value
    ) {
        if (!columnExists(columnName)) {
            throw new Error(
                "Required Invoice Services column " +
                columnName +
                " is missing."
            );
        }

        try {
            model.setValue(
                record,
                columnName,
                value
            );
        } catch (e) {
            throw new Error(
                "Could not set editable field " +
                columnName +
                ": " +
                e.message
            );
        }
    }

    /* ==========================================================================
     * Function: setProtectedValue
     * Purpose : Set a required writable Interactive Grid model column.
     *
     * Notes   : All writes must use model.setValue. If APEX rejects the value,
     *           treat it as a column configuration error and stop the import.
     * ======================================================================== */
    function setProtectedValue(
        record,
        columnName,
        value
    ) {
        if (!columnExists(columnName)) {
            throw new Error(
                "Required Invoice Services column " +
                columnName +
                " is missing."
            );
        }

        try {
            model.setValue(
                record,
                columnName,
                value
            );
        } catch (e) {
            throw new Error(
                "Invoice Services column " +
                columnName +
                " is not model-writable: " +
                e.message
            );
        }
    }

    /* ==========================================================================
     * Function: initializeInsertionPosition
     * Purpose : Find the final active row and calculate the next sequence number.
     * ======================================================================== */
    function initializeInsertionPosition() {
        var maximumSequence = 0;

        model.forEach(function(record) {
            var sequenceValue;

            if (isDeleted(record)) {
                return;
            }

            lastRecord =
                record;

            sequenceValue =
                p48NumberOrNull(
                    rawValue(
                        record,
                        "SEQ_NO"
                    ),
                    "Sequence number"
                );

            if (
                sequenceValue !== null &&
                sequenceValue > maximumSequence
            ) {
                maximumSequence =
                    sequenceValue;
            }
        });

        nextSequence =
            maximumSequence > 0 ?
            maximumSequence + 10 :
            10;
    }

    /* ==========================================================================
     * Function: rollbackInsertedRows
     * Purpose : Remove package rows inserted during a failed import attempt.
     * ======================================================================== */
    function rollbackInsertedRows() {
        if (!insertedRecords.length) {
            return;
        }

        try {
            model.deleteRecords(
                insertedRecords
            );
        } catch (e) {
            apex.debug.error(
                "Could not remove partially inserted package rows.",
                e
            );
        }
    }

    /* ==========================================================================
     * Function: finishLoading
     * Purpose : End package bulk-loading mode and optionally recalculate preview.
     * ======================================================================== */
    function finishLoading(
        message,
        refreshAfter
    ) {
        apex.item(
            "P48_IMPORT_PKG_AUTO_LOADING"
        ).setValue(
            "",
            null,
            true
        );

        window.p48InvoicePreview
            .setBulkLoading(
                false,
                refreshAfter === true
            );

        if (message) {
            apex.message.showPageSuccess(
                message
            );
        }
    }

    /* ==========================================================================
     * Function: insertPackageLine
     * Purpose : Insert one package parent or component into the IG model.
     * ======================================================================== */
    function insertPackageLine(line) {
        var recordId;
        var record;
        var serviceId;
        var serviceDisplay;
        var quantity;
        var discountPercent;
        var discountAmount;

        serviceId =
            line.serviceId === null ||
            line.serviceId === undefined ?
            "" :
            String(line.serviceId);

        if (!serviceId) {
            throw new Error(
                "Package import returned a line without a service."
            );
        }

        quantity =
            exactQuantity(
                line.qty,
                serviceId
            );

        discountPercent =
            p48NumberOrNull(
                line.disc,
                "Package discount percentage"
            );

        discountAmount =
            p48NumberOrNull(
                line.myDisc,
                "Package discount amount"
            );

        serviceDisplay =
            String(
                line.serviceDisplay ||
                serviceId
            );

        recordId =
            model.insertNewRecord(
                null,
                lastRecord
            );

        if (
            recordId === null ||
            recordId === undefined
        ) {
            throw new Error(
                "A package row could not be inserted."
            );
        }

        record =
            model.getRecord(recordId);

        if (!record) {
            throw new Error(
                "The inserted package row could not be found."
            );
        }

        insertedRecords.push(
            record
        );

        lastRecord =
            record;
        /*
         * Hidden persistent draft-line fields.
         */
        setProtectedValue(
            record,
            "SEQ_NO",
            modelString(nextSequence)
        );

        nextSequence += 10;

        setProtectedValue(
            record,
            "SOURCE_TYPE",
            modelString(
                line.sourceType ||
                "PACKAGE"
            )
        );

        setProtectedValue(
            record,
            "SOURCE_ID",
            modelString(
                line.sourceId === null ||
                line.sourceId === undefined ?
                line.packageServiceId :
                line.sourceId
            )
        );

        setEditableValue(
            record,
            "SERVICEID", {
                v: modelString(serviceId),
                d: modelString(serviceDisplay)
            }
        );

        if (
            columnExists(
                "SERVICEDESC"
            )
        ) {
            setProtectedValue(
                record,
                "SERVICEDESC",
                modelString(line.serviceDesc)
            );
        }

        /*
         * Exact package quantity as an APEX model string.
         */
        setEditableValue(
            record,
            "QTY",
            modelString(quantity)
        );

        /*
         * Manual discount inputs only.
         */
        setEditableValue(
            record,
            "DISCOUNT_TYPE",
            modelString(
                line.discountType ||
                "N"
            )
        );

        setEditableValue(
            record,
            "DISC",
            modelString(
                discountPercent === null ?
                0 :
                discountPercent
            )
        );

        setEditableValue(
            record,
            "MY_DISC",
            discountAmount === null ?
            "" :
            modelString(
                discountAmount
            )
        );

        /*
         * Package pricing is never a price override.
         */
        setProtectedValue(
            record,
            "PRICE_OVERRIDE",
            ""
        );

        setProtectedValue(
            record,
            "USE_PRICE_OVERRIDE",
            "N"
        );

        /*
         * Persistent package identity.
         */
        setProtectedValue(
            record,
            "PACKAGE_SERVICE_ID",
            modelString(
                line.packageServiceId
            )
        );

        setProtectedValue(
            record,
            "PACKAGE_INSTANCE_ID",
            modelString(
                line.packageInstanceId
            )
        );

        setProtectedValue(
            record,
            "PACKAGE_LINE_ROLE",
            modelString(
                line.packageLineRole
            )
        );

        setProtectedValue(
            record,
            "PACKAGE_COMPONENT_ORDER",
            modelString(
                line.packageComponentOrder
            )
        );

        setProtectedValue(
            record,
            "PACKAGE_PARENT_LINE_ID",
            line.packageParentLineId === null ||
            line.packageParentLineId === undefined ||
            line.packageParentLineId === "" ?
            "" :
            modelString(
                line.packageParentLineId
            )
        );

        setProtectedValue(
            record,
            "PACKAGE_DEFINITION_TOKEN",
            modelString(
                line.packageDefinitionToken
            )
        );

        /*
         * Runtime/query-only package fields.
         */
        setProtectedValue(
            record,
            "PACKAGE_PRICING_METHOD",
            modelString(
                line.packagePricingMethod
            )
        );

        setProtectedValue(
            record,
            "ALLOW_MANUAL_DISCOUNT",
            modelString(
                line.allowManualDiscount ||
                "N"
            )
        );

        setProtectedValue(
            record,
            "ALLOW_PRICE_OVERRIDE",
            modelString(
                line.allowPriceOverride ||
                "N"
            )
        );
    }

    /* ==========================================================================
     * Validate the Invoice Services region.
     * ======================================================================== */
    if (!region) {
        showError(
            "The Invoice Services grid is not available."
        );

        return;
    }

    ig$ =
        region.widget();

    gridView =
        ig$.interactiveGrid(
            "getViews",
            "grid"
        );

    if (
        !gridView ||
        !gridView.view$ ||
        !gridView.model
    ) {
        showError(
            "The Invoice Services grid is not available."
        );

        return;
    }

    model =
        gridView.model;

    /*
     * Complete any currently active cell editor before changing the model.
     */
    gridView.view$
        .grid("finishEditing")
        .done(function() {
            apex.server.process(
                    options.processName, {
                        pageItems: options.pageItems
                    }, {
                        dataType: "json"
                    }
                )
                .done(function(data) {
                    var lines;

                    if (
                        !data ||
                        data.success !== true
                    ) {
                        showError(
                            data &&
                            data.message ?
                            data.message :
                            (
                                options.errorMessage ||
                                "Package services could not be loaded."
                            )
                        );

                        return;
                    }

                    lines =
                        data.lines || [];

                    if (!lines.length) {
                        showError(
                            data.message ||
                            "The package contains no services."
                        );

                        return;
                    }

                    /*
                     * Importing the same package more than once is allowed.
                     * Each import receives a separate PACKAGE_INSTANCE_ID.
                     */
                    initializeInsertionPosition();

                    apex.item(
                        "P48_IMPORT_PKG_AUTO_LOADING"
                    ).setValue(
                        "Y",
                        null,
                        true
                    );

                    window.p48InvoicePreview
                        .setBulkLoading(
                            true,
                            false
                        );

                    try {
                        lines.forEach(
                            function(line) {
                                insertPackageLine(
                                    line
                                );
                            }
                        );

                        /*
                         * All package rows now exist. Run one authoritative batch preview.
                         */
                        finishLoading(
                            data.message ||
                            options.successMessage ||
                            "Package services added.",
                            true
                        );
                    } catch (e) {
                        rollbackInsertedRows();

                        finishLoading(
                            null,
                            true
                        );

                        apex.debug.error(
                            "Package import failed.",
                            e
                        );

                        showError(
                            e.message ||
                            "Package services could not be loaded."
                        );
                    }
                })
                .fail(function(
                    jqXHR,
                    textStatus,
                    errorThrown
                ) {
                    finishLoading(
                        null,
                        false
                    );

                    showError(
                        errorThrown ||
                        textStatus ||
                        options.errorMessage ||
                        "Package services could not be loaded."
                    );
                });
        })
        .fail(function() {
            showError(
                "Complete or correct the active invoice line before importing a package."
            );
        });
}
/* ============================================================================
 * Function: p48LoadBundledOfferLinesIntoIg
 * Purpose : Load bundled-offer component rows directly into the editable
 *           Invoice Services grid.
 * ========================================================================== */
function p48LoadBundledOfferLinesIntoIg(options) {
    "use strict";

    var region =
        apex.region("invoice_services");

    var ig$;
    var gridView;
    var model;

    var insertedRecords = [];
    var recordsToDelete = [];
    var lastRecord = null;
    var nextSequence = 10;
    var requestedBundleQty = null;

    options =
        options || {};

    function showError(message) {
        apex.message.clearErrors();

        apex.message.showErrors([{
            type: "error",
            location: "page",
            message: message ||
                "Bundled Offer could not be loaded.",
            unsafe: false
        }]);
    }

    if (
        window.p48InvoiceSubmitting ||
        (
            window.p48InvoicePreview &&
            typeof window.p48InvoicePreview.isBusy ===
            "function" &&
            window.p48InvoicePreview.isBusy()
        )
    ) {
        showError(
            "Invoice calculation is in progress. Complete the calculation before adding a bundled offer."
        );

        return;
    }

    function ajaxErrorMessage(
        jqXHR,
        textStatus,
        errorThrown,
        fallbackMessage
    ) {
        if (
            jqXHR &&
            jqXHR.responseJSON &&
            jqXHR.responseJSON.message
        ) {
            return jqXHR.responseJSON.message;
        }

        return (
            fallbackMessage ||
            "Bundled Offer could not be loaded."
        );
    }

    function columnExists(columnName) {
        var fieldKey;

        try {
            fieldKey =
                model.getFieldKey(columnName);

            return (
                fieldKey !== null &&
                fieldKey !== undefined
            );
        } catch (e) {
            return false;
        }
    }

    function modelString(value) {
        if (
            value === null ||
            value === undefined
        ) {
            return "";
        }

        return String(value);
    }

    function firstPresent() {
        var i;

        for (i = 0; i < arguments.length; i += 1) {
            if (
                arguments[i] !== null &&
                arguments[i] !== undefined &&
                arguments[i] !== ""
            ) {
                return arguments[i];
            }
        }

        return "";
    }

    function modelDbValue(value) {
        if (
            value === null ||
            value === undefined
        ) {
            return "";
        }

        return String(value);
    }

    function rawValue(
        record,
        columnName
    ) {
        var value;

        try {
            value =
                model.getValue(
                    record,
                    columnName
                );
        } catch (e) {
            return null;
        }

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

    function isDeleted(record) {
        var recordId;
        var metadata;

        try {
            recordId =
                model.getRecordId(record);

            metadata =
                model.getRecordMetadata(recordId);

            return !!(
                metadata &&
                metadata.deleted
            );
        } catch (e) {
            return false;
        }
    }

    function setValue(
        record,
        columnName,
        value
    ) {
        if (!columnExists(columnName)) {
            throw new Error(
                "Required Invoice Services column " +
                columnName +
                " is missing."
            );
        }

        try {
            model.setValue(
                record,
                columnName,
                value
            );
        } catch (e) {
            throw new Error(
                "Invoice Services column " +
                columnName +
                " is not model-writable: " +
                e.message
            );
        }
    }

    function exactQuantity(
        value,
        serviceId
    ) {
        var quantity;

        if (
            value === null ||
            value === undefined ||
            value === ""
        ) {
            throw new Error(
                "Bundled Offer service " +
                serviceId +
                " has no quantity."
            );
        }

        quantity =
            p48NumberOrNull(
                value,
                "Bundled Offer service " +
                serviceId +
                " quantity"
            );

        if (
            quantity === null ||
            quantity <= 0 ||
            !Number.isInteger(quantity)
        ) {
            throw new Error(
                "Bundled Offer service " +
                serviceId +
                " quantity must be a positive whole number."
            );
        }

        return quantity;
    }

    function initializeInsertionPosition() {
        var maximumSequence = 0;

        model.forEach(function(record) {
            var sequenceValue;

            if (isDeleted(record)) {
                return;
            }

            lastRecord =
                record;

            sequenceValue =
                p48NumberOrNull(
                    rawValue(
                        record,
                        "SEQ_NO"
                    ),
                    "Sequence number"
                );

            if (
                sequenceValue !== null &&
                sequenceValue > maximumSequence
            ) {
                maximumSequence =
                    sequenceValue;
            }
        });

        nextSequence =
            maximumSequence > 0 ?
            maximumSequence + 10 :
            10;
    }

    function collectExistingOfferRows(offerId) {
        recordsToDelete = [];

        model.forEach(function(record) {
            var rowOfferType;
            var rowOfferId;

            if (isDeleted(record)) {
                return;
            }

            rowOfferType =
                p48NumberOrNull(
                    rawValue(
                        record,
                        "OFFER_TYPE"
                    ),
                    "Offer type"
                );

            rowOfferId =
                String(
                    rawValue(
                        record,
                        "OFFER_ID"
                    ) || ""
                );

            if (
                rowOfferType === 0 &&
                rowOfferId === String(offerId)
            ) {
                recordsToDelete.push(
                    record
                );
            }
        });
    }

    function rollbackInsertedRows() {
        if (!insertedRecords.length) {
            return;
        }

        try {
            model.deleteRecords(
                insertedRecords
            );
        } catch (e) {
            apex.debug.error(
                "Could not remove partially inserted bundle rows.",
                e
            );
        }
    }

    function insertBundleLine(line) {
        var recordId;
        var record;
        var serviceId;
        var serviceDisplay;
        var quantity;

        serviceId =
            modelString(line.serviceId);

        if (!serviceId) {
            throw new Error(
                "Bundled Offer returned a line without a service."
            );
        }

        quantity =
            exactQuantity(
                line.qty,
                serviceId
            );

        serviceDisplay =
            modelString(
                line.serviceDisplay ||
                serviceId
            );

        recordId =
            model.insertNewRecord(
                null,
                lastRecord
            );

        if (
            recordId === null ||
            recordId === undefined
        ) {
            throw new Error(
                "A Bundled Offer row could not be inserted."
            );
        }

        record =
            model.getRecord(recordId);

        if (!record) {
            throw new Error(
                "The inserted Bundled Offer row could not be found."
            );
        }

        insertedRecords.push(record);
        lastRecord = record;

        setValue(record, "SEQ_NO", modelString(nextSequence));
        nextSequence += 10;

        setValue(record, "SOURCE_TYPE", "BUNDLE");
        setValue(record, "SOURCE_ID", modelDbValue(firstPresent(line.sourceId, line.offerId)));
        setValue(
            record,
            "QTY",
            modelDbValue(quantity)
        );

        setValue(
            record,
            "SERVICEID", {
                v: serviceId,
                d: serviceDisplay
            }
        );

        setValue(
            record,
            "SERVICEDESC",
            modelDbValue(line.serviceDesc)
        );

        setValue(record, "PRICE", modelDbValue(firstPresent(line.unitPrice, line.price, 0)));
        setValue(record, "MY_PRICE", modelDbValue(firstPresent(line.myPrice, line.grossAmount, 0)));
        setValue(record, "MY_NET", modelDbValue(firstPresent(line.myNet, line.netAmount, 0)));
        setValue(record, "THE_PAY", modelDbValue(firstPresent(line.thePay, line.patientShare, 0)));
        setValue(record, "THE_COMP", modelDbValue(firstPresent(line.theComp, line.providerShare, 0)));
        setValue(record, "VAT_RATE", modelDbValue(firstPresent(line.vatRate, 0)));
        setValue(record, "VAT_VAL_PAT", modelDbValue(firstPresent(line.vatValPat, line.patientVat, 0)));
        setValue(record, "VAT_VAL_CO", modelDbValue(firstPresent(line.vatValCo, line.providerVat, 0)));

        setValue(record, "PRICE_OVERRIDE", "");
        setValue(record, "USE_PRICE_OVERRIDE", "N");

        setValue(record, "DISCOUNT_TYPE", modelDbValue(firstPresent(line.discountType, "N")));
        setValue(record, "DISC", modelDbValue(firstPresent(line.disc, 0)));
        setValue(record, "MY_DISC", modelDbValue(firstPresent(line.myDisc, 0)));

        setValue(record, "REQ_NEED_A", modelDbValue(line.reqNeedA));
        setValue(record, "REQ_A_STATUS", modelDbValue(line.reqAStatus));

        setValue(record, "PACKAGE_SERVICE_ID", "");
        setValue(record, "PACKAGE_INSTANCE_ID", "");
        setValue(record, "PACKAGE_LINE_ROLE", "");
        setValue(record, "PACKAGE_COMPONENT_ORDER", "");
        setValue(record, "PACKAGE_PARENT_LINE_ID", "");
        setValue(record, "PACKAGE_DEFINITION_TOKEN", "");
        setValue(record, "PACKAGE_PRICING_METHOD", "");

        setValue(record, "OFFER_ID", modelDbValue(line.offerId));
        setValue(record, "OFFER_DTL_ID", modelDbValue(line.offerDtlId));
        setValue(record, "OFFER_TYPE", modelDbValue(line.offerType));
        setValue(record, "OFFER_INSTANCE_ID", modelDbValue(line.offerInstanceId));
        setValue(record, "OFFER_LINE_ROLE", modelDbValue(line.offerLineRole));
        setValue(record, "OFFER_PARENT_LINE_ID", modelDbValue(line.offerParentLineId));
        setValue(record, "OFFER_PRICE_APPLIED", modelDbValue(line.offerPriceApplied));
        setValue(record, "OFFER_DIS_APPLIED", modelDbValue(line.offerDisApplied));
        setValue(record, "OFFER_NAME_SNAPSHOT", modelDbValue(line.offerNameSnapshot));
        setValue(record, "OFFER_OBJECT_VERSION_NUMBER", modelDbValue(line.offerObjectVersionNumber));
        setValue(record, "OFFER_DTL_OBJECT_VERSION_NUMBER", modelDbValue(line.offerDtlObjectVersionNumber));

        setValue(record, "ALLOW_MANUAL_DISCOUNT", modelDbValue(firstPresent(line.allowManualDiscount, "N")));
        setValue(record, "ALLOW_PRICE_OVERRIDE", modelDbValue(firstPresent(line.allowPriceOverride, "N")));
    }

    if (!region) {
        showError(
            "The Invoice Services grid is not available."
        );
        return;
    }

    ig$ =
        region.widget();

    gridView =
        ig$.interactiveGrid(
            "getViews",
            "grid"
        );

    if (
        !gridView ||
        !gridView.view$ ||
        !gridView.model
    ) {
        showError(
            "The Invoice Services grid is not available."
        );
        return;
    }

    model =
        gridView.model;

    gridView.view$
        .grid("finishEditing")
        .done(function() {
            apex.server.process(
                    options.processName, {
                        pageItems: options.pageItems
                    }, {
                        dataType: "json"
                    }
                )
                .done(function(data) {
                    var lines;

                    if (
                        !data ||
                        data.success !== true
                    ) {
                        showError(
                            data && data.message ?
                            data.message :
                            "Bundled Offer could not be loaded."
                        );
                        return;
                    }


                    lines =
                        data.lines || [];

                    if (!lines.length) {
                        showError(
                            data.message ||
                            "The Bundled Offer contains no services."
                        );
                        return;
                    }

                    requestedBundleQty =
                        apex.item(
                            "P48_BUNDLE_QTY"
                        ).getNativeValue();

                    if (
                        !Number.isFinite(requestedBundleQty) ||
                        requestedBundleQty <= 0 ||
                        Math.floor(requestedBundleQty) !== requestedBundleQty
                    ) {
                        showError(
                            "Bundle quantity must be a positive whole number."
                        );

                        return;
                    }

                    initializeInsertionPosition();
                    collectExistingOfferRows(
                        $v("P48_OFFER_ID")
                    );

                    if (window.p48InvoicePreview) {
                        window.p48InvoicePreview.setBulkLoading(
                            true,
                            false
                        );
                    }

                    try {
                        lines.forEach(function(line) {
                            insertBundleLine(line);
                        });

                        if (recordsToDelete.length) {
                            model.deleteRecords(
                                recordsToDelete
                            );
                        }

                        if (window.p48InvoicePreview) {
                            window.p48InvoicePreview.setBulkLoading(
                                false,
                                true
                            );
                        }

                        apex.message.showPageSuccess(
                            data.message ||
                            options.successMessage ||
                            "Bundled Offer added."
                        );

                        apex.theme.closeRegion(
                            "import_offer_dlg"
                        );

                    } catch (e) {
                        rollbackInsertedRows();

                        if (window.p48InvoicePreview) {
                            window.p48InvoicePreview.setBulkLoading(
                                false,
                                true
                            );
                        }

                        showError(e.message);
                    }
                })
                .fail(function(
                    jqXHR,
                    textStatus,
                    errorThrown
                ) {
                    showError(
                        ajaxErrorMessage(
                            jqXHR,
                            textStatus,
                            errorThrown,
                            "Bundled Offer could not be loaded."
                        )
                    );
                });
        })
        .fail(function() {
            showError(
                "Complete or correct the active invoice line before adding a Bundled Offer."
            );

        });
}