/* ============================================================================
 * Function: p48InvoiceServicesInit
 * Purpose : Configure the Page 48 Invoice Services Interactive Grid toolbar,
 *           package-aware line removal, and bundled-offer occurrence actions.
 * ========================================================================== */
window.p48InvoiceServicesInit = function(options) {
    "use strict";

    var $ = apex.jQuery;

    var oldInitActions =
        options.initActions;

    var toolbarData =
        $.apex.interactiveGrid
        .copyDefaultToolbar();

    var addRowGroup =
        toolbarData.toolbarFind(
            "actions3"
        );

    /* ==========================================================================
     * Remove APEX toolbar actions handled by Page 48 itself.
     * ======================================================================== */

    toolbarData.toolbarRemove(
        "save"
    );

    toolbarData.toolbarRemove(
        "edit"
    );

    /* ==========================================================================
     * Add import actions beside Add Service.
     * ======================================================================== */

    if (addRowGroup) {
        addRowGroup.controls.push({
            type: "BUTTON",
            action: "open-import-package"
        });

        /*
         * Bundled Offers are available only for Cash invoices.
         */
        if (
            String(
                $v("P48_PAYTYPE")
            ) === "1"
        ) {
            addRowGroup.controls.push({
                type: "BUTTON",
                action: "open-import-offer"
            });
        }
    }

    /* ==========================================================================
     * Add bundled-offer and removal actions on the far-right side.
     * ======================================================================== */

    toolbarData.push({
        type: "GROUP",
        align: "end",

        controls: [{
                type: "BUTTON",
                action: "remove-selected-lines"
            },
            {
                type: "BUTTON",
                action: "clear-all-lines"
            }
        ]
    });

    options.toolbarData =
        toolbarData;

    /* ==========================================================================
     * Register Interactive Grid actions.
     * ======================================================================== */

    options.initActions =
        function(actions) {
            var igContext$ =
                $(actions.context);

            /* ======================================================================
             * Function: removeAction
             * Purpose : Remove an APEX IG action only when it exists.
             * ==================================================================== */
            function removeAction(name) {
                if (actions.lookup(name)) {
                    actions.remove(name);
                }
            }

            /* ======================================================================
             * Function: getGridContext
             * Purpose : Return the Invoice Services grid view and model.
             * ==================================================================== */
            function getGridContext() {
                var gridView;

                try {
                    gridView =
                        igContext$
                        .interactiveGrid(
                            "getViews",
                            "grid"
                        );
                } catch (e) {
                    return null;
                }

                if (
                    !gridView ||
                    !gridView.view$ ||
                    !gridView.model
                ) {
                    return null;
                }

                return {
                    gridView: gridView,
                    model: gridView.model
                };
            }

            /* ======================================================================
             * Function: getRawValue
             * Purpose : Read normal and Popup LOV model values safely.
             * ==================================================================== */
            function getRawValue(
                model,
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
                    return "";
                }

                /*
                 * Popup LOV columns may contain:
                 *
                 * {
                 *   v: returnValue,
                 *   d: displayValue
                 * }
                 */
                if (
                    value &&
                    typeof value === "object" &&
                    Object.prototype
                    .hasOwnProperty.call(
                        value,
                        "v"
                    )
                ) {
                    return value.v;
                }

                return value;
            }

            /* ======================================================================
             * Function: isDeleted
             * Purpose : Determine whether a model row is marked for deletion.
             * ==================================================================== */
            function isDeleted(
                model,
                record
            ) {
                var recordId;
                var metadata;

                /*
                 * A stale selection can contain a record that is no longer
                 * usable by the grid/model. Treat it as unavailable.
                 */
                if (!record) {
                    return true;
                }

                try {
                    recordId =
                        model.getRecordId(
                            record
                        );

                    if (
                        recordId === null ||
                        recordId === undefined
                    ) {
                        return true;
                    }

                    metadata =
                        model.getRecordMetadata(
                            recordId
                        );
                } catch (e) {
                    return true;
                }

                return !!(
                    metadata &&
                    metadata.deleted
                );
            }

            /* ======================================================================
             * Function: invoicePreviewBusy
             * Purpose : Prevent invoice structure changes while calculated totals
             *           are provisional.
             * ==================================================================== */
            function invoicePreviewBusy() {
                return !!(
                    window.p48InvoicePreview &&
                    typeof window.p48InvoicePreview.isBusy ===
                    "function" &&
                    window.p48InvoicePreview.isBusy()
                );
            }


            /* ======================================================================
             * Function: invoiceStructureChangeBlocked
             * Purpose : Block package/bundle structural changes during preview or
             *           final invoice submission.
             * ==================================================================== */
            function invoiceStructureChangeBlocked() {
                return (
                    invoicePreviewBusy() ||
                    !!window.p48InvoiceSubmitting
                );
            }


            /* ======================================================================
             * Function: requireInvoiceStructureChangeAvailable
             * ==================================================================== */
            function requireInvoiceStructureChangeAvailable() {
                if (!invoiceStructureChangeBlocked()) {
                    return true;
                }

                showPageError(
                    "Invoice calculation is in progress. Complete the calculation before changing packages or bundled offers."
                );

                return false;
            }

            /* ======================================================================
             * Function: objectKeys
             * Purpose : Safe Object.keys wrapper.
             * ==================================================================== */
            function objectKeys(obj) {
                return Object.keys(
                    obj || {}
                );
            }

            /* ======================================================================
             * Function: hasValue
             * Purpose : Determine whether a model value contains meaningful text.
             * ==================================================================== */
            function hasValue(value) {
                return String(
                    value === null ||
                    value === undefined ?
                    "" :
                    value
                ).trim() !== "";
            }


            /* ======================================================================
             * Function: bundleRowInfo
             * Purpose : Identify a true bundled-offer occurrence.
             *
             * Important:
             * OFFER_ID, OFFER_DTL_ID, OFFER_LINE_ROLE, etc. are offer evidence.
             * They do not by themselves mean that the row is a bundled offer.
             *
             * Bundled Offers are identified by:
             * - SOURCE_TYPE = BUNDLE
             * - or OFFER_TYPE = 0
             * ==================================================================== */
            function bundleRowInfo(
                model,
                record
            ) {
                var sourceType =
                    String(
                        getRawValue(
                            model,
                            record,
                            "SOURCE_TYPE"
                        ) || ""
                    )
                    .trim()
                    .toUpperCase();

                var rawOfferType =
                    getRawValue(
                        model,
                        record,
                        "OFFER_TYPE"
                    );

                var offerType =
                    String(
                        rawOfferType === null ||
                        rawOfferType === undefined ?
                        "" :
                        rawOfferType
                    ).trim();

                var offerInstanceId =
                    getRawValue(
                        model,
                        record,
                        "OFFER_INSTANCE_ID"
                    );

                return {
                    isBundle: (
                        sourceType === "BUNDLE" ||
                        offerType === "0"
                    ),

                    offerInstanceId: offerInstanceId
                };
            }


            /* ======================================================================
             * Function: clearGridSelection
             * Purpose : Clear row selection without changing the current grid cell.
             * ==================================================================== */
            function clearGridSelection(
                gridView
            ) {
                try {
                    if (
                        gridView &&
                        gridView.view$
                    ) {
                        gridView.view$.grid(
                            "setSelectedRecords",
                            [],
                            null,
                            true
                        );
                    }
                } catch (e) {
                    apex.debug.warn(
                        "Page 48 could not clear the Invoice Services selection: " +
                        e.message
                    );
                }
            }

            /* ======================================================================
             * Function: prepareGridForDelete
             * Purpose : Leave cell-edit mode and clear row selection before records
             *           are removed from the model.
             *
             * Notes   : finishEditing() synchronizes editor values with the model but
             *           does not leave edit mode. Deleting the active record while the
             *           grid still owns its editor can cause APEX active-row errors.
             * ==================================================================== */
            function prepareGridForDelete(
                gridView
            ) {
                if (
                    !gridView ||
                    !gridView.view$
                ) {
                    return;
                }

                try {
                    if (
                        gridView.view$.grid(
                            "inEditMode"
                        )
                    ) {
                        gridView.view$.grid(
                            "setEditMode",
                            false
                        );
                    }
                } catch (e) {
                    apex.debug.warn(
                        "Page 48 could not leave Invoice Services edit mode before deletion: " +
                        e.message
                    );
                }

                clearGridSelection(
                    gridView
                );
            }

            /* ======================================================================
             * Function: showPageError
             * Purpose : Show one safe page-level error.
             * ==================================================================== */
            function showPageError(message) {
                apex.message.clearErrors();

                apex.message.showErrors([{
                    type: "error",
                    location: "page",
                    message: message,
                    unsafe: false
                }]);
            }

            /* ======================================================================
             * Function: requireGridContext
             * Purpose : Resolve Invoice Services context for a user-triggered action.
             *           User actions must fail visibly if the grid is unavailable.
             * ==================================================================== */
            function requireGridContext(operationName) {
                var context =
                    getGridContext();

                if (context) {
                    return context;
                }

                apex.debug.error(
                    "Page 48 " +
                    operationName +
                    " failed: Invoice Services grid view/model is unavailable."
                );

                showPageError(
                    "Invoice lines are not available. Refresh the page."
                );

                return null;
            }

            /* ======================================================================
             * Function: beginBatchChange
             * Purpose : Suppress intermediate invoice-preview calculations.
             * ==================================================================== */
            function beginBatchChange() {
                if (
                    window.p48InvoicePreview
                ) {
                    window.p48InvoicePreview
                        .setBulkLoading(
                            true,
                            false
                        );
                }
            }

            /* ======================================================================
             * Function: endBatchChange
             * Purpose : End batch mode and run one authoritative preview.
             * ==================================================================== */
            function endBatchChange() {
                if (
                    window.p48InvoicePreview
                ) {
                    window.p48InvoicePreview
                        .setBulkLoading(
                            false,
                            true
                        );
                }
            }

            if (oldInitActions) {
                oldInitActions(
                    actions
                );
            }

            /* ======================================================================
             * Function: hasActiveRows
             * Purpose : Return true when the IG contains at least one non-deleted row.
             * ==================================================================== */
            function hasActiveRows(model) {
                var found =
                    false;

                if (!model) {
                    return false;
                }

                model.forEach(function(record) {
                    if (
                        !found &&
                        !isDeleted(
                            model,
                            record
                        )
                    ) {
                        found =
                            true;
                    }
                });

                return found;
            }


            /* ======================================================================
             * Function: hasActiveSelection
             * Purpose : Return true when at least one active row is selected.
             * ==================================================================== */
            function hasActiveSelection(
                gridView,
                model
            ) {
                var selectedRecords;

                if (
                    !gridView ||
                    !gridView.view$ ||
                    !model
                ) {
                    return false;
                }

                selectedRecords =
                    gridView.view$
                    .grid(
                        "getSelectedRecords"
                    ) || [];

                return selectedRecords.some(
                    function(record) {
                        return !isDeleted(
                            model,
                            record
                        );
                    }
                );
            }


            /* ======================================================================
             * Function: refreshRemovalActionState
             * Purpose : Synchronize invoice structural actions with preview and IG state.
             * ==================================================================== */
            function refreshRemovalActionState() {
                var context;
                var rowsExist;
                var selectionExists;

                /*
                 * While calculated totals are provisional, no package/bundle import or
                 * removal operation may begin.
                 */
                if (invoiceStructureChangeBlocked()) {
                    actions.disable(
                        "open-import-package"
                    );

                    actions.disable(
                        "open-import-offer"
                    );

                    actions.disable(
                        "remove-selected-lines"
                    );

                    actions.disable(
                        "clear-all-lines"
                    );

                    return;
                }

                /*
                 * Import Package is available whenever the normal editable invoice
                 * toolbar itself is available.
                 */
                actions.enable(
                    "open-import-package"
                );

                /*
                 * Bundled Offers remain Cash-only.
                 */
                if (
                    String(
                        $v("P48_PAYTYPE")
                    ) === "1"
                ) {
                    actions.enable(
                        "open-import-offer"
                    );
                } else {
                    actions.disable(
                        "open-import-offer"
                    );
                }

                context =
                    getGridContext();

                if (!context) {
                    actions.disable(
                        "remove-selected-lines"
                    );

                    actions.disable(
                        "clear-all-lines"
                    );

                    return;
                }

                rowsExist =
                    hasActiveRows(
                        context.model
                    );

                selectionExists =
                    hasActiveSelection(
                        context.gridView,
                        context.model
                    );

                if (selectionExists) {
                    actions.enable(
                        "remove-selected-lines"
                    );
                } else {
                    actions.disable(
                        "remove-selected-lines"
                    );
                }

                if (rowsExist) {
                    actions.enable(
                        "clear-all-lines"
                    );
                } else {
                    actions.disable(
                        "clear-all-lines"
                    );
                }
            }


            /* ======================================================================
             * Function: subscribeRemovalActionState
             * Purpose : Subscribe once to model changes that affect row availability.
             * ==================================================================== */
            function subscribeRemovalActionState(model) {
                if (
                    !model ||
                    model._p48RemovalActionStateSubscribed
                ) {
                    return;
                }

                model._p48RemovalActionStateSubscribed =
                    true;

                model.subscribe({
                    onChange: function(type) {
                        /*
                         * addData is critical here:
                         * it fires when the initial/server-fetched rows enter the model.
                         */
                        if (
                            [
                                "addData",
                                "insert",
                                "delete",
                                "refresh"
                            ].indexOf(type) !== -1
                        ) {
                            window.setTimeout(
                                refreshRemovalActionState,
                                0
                            );
                        }
                    }
                });
            }


            /* ======================================================================
             * Function: bindRemovalActionState
             * Purpose : Bind model/selection lifecycle events to the actual IG
             *           actions context created during initialization.
             * ==================================================================== */
            function bindRemovalActionState() {

                igContext$
                    .off(
                        ".p48RemovalActionState"
                    )

                    /*
                     * This is the authoritative point where the IG model exists.
                     */
                    .on(
                        "interactivegridviewmodelcreate.p48RemovalActionState",
                        function(
                            event,
                            data
                        ) {
                            if (
                                !data ||
                                !data.model
                            ) {
                                return;
                            }

                            /*
                             * We only care about the editable Grid view.
                             */
                            if (
                                data.viewId &&
                                String(
                                    data.viewId
                                ) !== "grid"
                            ) {
                                return;
                            }

                            subscribeRemovalActionState(
                                data.model
                            );

                            window.setTimeout(
                                refreshRemovalActionState,
                                0
                            );
                        }
                    )

                    /*
                     * Remove Selected depends on the current row selection.
                     */
                    .on(
                        "interactivegridselectionchange.p48RemovalActionState",
                        function() {
                            window.setTimeout(
                                refreshRemovalActionState,
                                0
                            );
                        }
                    )

                    /*
                     * Recheck when the Grid view is created/switched.
                     */
                    .on(
                        "interactivegridviewchange.p48RemovalActionState",
                        function(
                            event,
                            data
                        ) {
                            if (
                                data &&
                                data.view &&
                                data.view !== "grid"
                            ) {
                                return;
                            }

                            window.setTimeout(
                                function() {
                                    var context =
                                        getGridContext();

                                    if (!context) {
                                        return;
                                    }

                                    subscribeRemovalActionState(
                                        context.model
                                    );

                                    refreshRemovalActionState();
                                },
                                0
                            );
                        }
                    );

                /*
                 * Re-evaluate toolbar actions whenever invoice preview busy
                 * state changes.
                 */
                $(document)
                    .off(
                        "p48invoicepreviewstatechange.p48InvoiceActions"
                    )
                    .on(
                        "p48invoicepreviewstatechange.p48InvoiceActions",
                        function() {
                            refreshRemovalActionState();
                        }
                    );

                /*
                 * Fallback for the case where the model already exists before
                 * this handler completes.
                 */
                window.setTimeout(
                    function() {
                        var context =
                            getGridContext();

                        if (!context) {
                            return;
                        }

                        subscribeRemovalActionState(
                            context.model
                        );

                        refreshRemovalActionState();
                    },
                    0
                );
            }

            actions.add([
                /* ====================================================================
                 * Action: open-import-package
                 * ================================================================== */
                {
                    name: "open-import-package",

                    label: "Import Package",

                    action: function() {
                        if (
                            !requireInvoiceStructureChangeAvailable()
                        ) {
                            return;
                        }
                        apex.theme.openRegion(
                            "import_package_dlg"
                        );
                    }
                },

                /* ====================================================================
                 * Action: open-import-offer
                 * ================================================================== */
                {
                    name: "open-import-offer",

                    label: "Add Bundle",

                    action: function() {

                        if (
                            !requireInvoiceStructureChangeAvailable()
                        ) {
                            return;
                        }

                        apex.theme.openRegion(
                            "import_offer_dlg"
                        );
                    }
                },

                /* ====================================================================
                 * Action: remove-selected-lines
                 * Purpose:
                 * - normal line     -> remove selected row;
                 * - package row    -> remove complete PACKAGE_INSTANCE_ID;
                 * - bundled row    -> remove complete OFFER_INSTANCE_ID.
                 *
                 * All removals operate on the current IG model. No draft-table AJAX
                 * operation is required for the manual invoice workflow.
                 * ================================================================== */
                {
                    name: "remove-selected-lines",

                    label: "Remove Selected",

                    disabled: true,

                    action: function() {

                        if (
                            !requireInvoiceStructureChangeAvailable()
                        ) {
                            return;
                        }
                        var context =
                            requireGridContext(
                                "Remove Selected"
                            );

                        if (!context) {
                            return;
                        }

                        var gridView =
                            context.gridView;

                        var model =
                            context.model;

                        gridView.view$
                            .grid(
                                "finishEditing"
                            )
                            .done(function() {
                                var selectedRecords =
                                    gridView.view$
                                    .grid(
                                        "getSelectedRecords"
                                    ) || [];

                                var selectedRecordIds = {};

                                var packageInstanceIds = {};

                                var offerInstanceIds = {};

                                var recordsToDelete = [];

                                var invalidPackageMetadata =
                                    false;

                                var invalidOfferMetadata =
                                    false;

                                var hasOfferSelection =
                                    false;

                                var hasNonOfferSelection =
                                    false;

                                /*
                                 * APEX can retain selected records that have already been
                                 * marked for deletion. Never allow them to participate in
                                 * another Remove Selected operation.
                                 */
                                selectedRecords =
                                    selectedRecords.filter(
                                        function(record) {
                                            return !isDeleted(
                                                model,
                                                record
                                            );
                                        }
                                    );

                                if (!selectedRecords.length) {
                                    clearGridSelection(
                                        gridView
                                    );

                                    showPageError(
                                        "Select at least one invoice line to remove."
                                    );

                                    return;
                                }

                                /*
                                 * Classify the selected active rows.
                                 */
                                selectedRecords.forEach(
                                    function(record) {
                                        var recordId =
                                            model.getRecordId(
                                                record
                                            );

                                        var bundleInfo =
                                            bundleRowInfo(
                                                model,
                                                record
                                            );

                                        var packageInstanceId =
                                            getRawValue(
                                                model,
                                                record,
                                                "PACKAGE_INSTANCE_ID"
                                            );

                                        var packageServiceId =
                                            getRawValue(
                                                model,
                                                record,
                                                "PACKAGE_SERVICE_ID"
                                            );

                                        var packageLineRole =
                                            getRawValue(
                                                model,
                                                record,
                                                "PACKAGE_LINE_ROLE"
                                            );

                                        /*
                                         * Bundled Offers are occurrence-based.
                                         */
                                        if (bundleInfo.isBundle) {
                                            if (
                                                !hasValue(
                                                    bundleInfo.offerInstanceId
                                                )
                                            ) {
                                                invalidOfferMetadata =
                                                    true;

                                                return;
                                            }

                                            hasOfferSelection =
                                                true;

                                            offerInstanceIds[
                                                String(
                                                    bundleInfo.offerInstanceId
                                                )
                                            ] = true;

                                            return;
                                        }

                                        /*
                                         * Normal services, including services carrying a normal
                                         * offer, come through this path.
                                         */
                                        hasNonOfferSelection =
                                            true;

                                        /*
                                         * Package rows are occurrence-based.
                                         */
                                        if (packageInstanceId) {
                                            packageInstanceIds[
                                                String(
                                                    packageInstanceId
                                                )
                                            ] = true;

                                            return;
                                        }

                                        /*
                                         * Fail closed if something looks like a package row but
                                         * has lost its PACKAGE_INSTANCE_ID.
                                         */
                                        if (
                                            packageServiceId ||
                                            packageLineRole
                                        ) {
                                            invalidPackageMetadata =
                                                true;

                                            return;
                                        }

                                        /*
                                         * Ordinary service row.
                                         */
                                        selectedRecordIds[
                                            String(recordId)
                                        ] = true;
                                    }
                                );

                                if (invalidOfferMetadata) {
                                    showPageError(
                                        "A selected bundled offer line has incomplete bundle metadata and cannot be removed safely."
                                    );

                                    return;
                                }

                                if (invalidPackageMetadata) {
                                    showPageError(
                                        "A selected package line has incomplete package metadata and cannot be removed safely."
                                    );

                                    return;
                                }

                                /*
                                 * Preserve the existing behavior:
                                 * do not mix bundle removal with normal/package removal in one
                                 * Remove Selected operation.
                                 */
                                if (
                                    hasOfferSelection &&
                                    hasNonOfferSelection
                                ) {
                                    showPageError(
                                        "Remove bundled offer lines separately from normal or package lines."
                                    );

                                    return;
                                }

                                /*
                                 * Bundled Offer removal.
                                 *
                                 * Selecting any component deletes every active row with the
                                 * same OFFER_INSTANCE_ID.
                                 */
                                if (hasOfferSelection) {
                                    apex.message.confirm(
                                        "Remove the selected bundled offer occurrence(s)? " +
                                        "Selecting any bundled offer line removes the entire bundle.",

                                        function(confirmed) {
                                            if (!confirmed) {
                                                return;
                                            }

                                            apex.message.clearErrors();

                                            recordsToDelete = [];

                                            model.forEach(
                                                function(record) {
                                                    var offerInstanceId;

                                                    if (
                                                        isDeleted(
                                                            model,
                                                            record
                                                        )
                                                    ) {
                                                        return;
                                                    }

                                                    offerInstanceId =
                                                        getRawValue(
                                                            model,
                                                            record,
                                                            "OFFER_INSTANCE_ID"
                                                        );

                                                    if (
                                                        offerInstanceId &&
                                                        offerInstanceIds[
                                                            String(
                                                                offerInstanceId
                                                            )
                                                        ]
                                                    ) {
                                                        recordsToDelete.push(
                                                            record
                                                        );
                                                    }
                                                }
                                            );

                                            if (
                                                !recordsToDelete.length
                                            ) {
                                                clearGridSelection(
                                                    gridView
                                                );

                                                return;
                                            }

                                            /*
                                             * Clear the selection while the selected records are still
                                             * valid model records. Deleting first can leave the grid trying
                                             * to activate/deactivate a record that no longer has an identity.
                                             */
                                            prepareGridForDelete(
                                                gridView
                                            );

                                            beginBatchChange();

                                            try {
                                                model.deleteRecords(
                                                    recordsToDelete
                                                );
                                            } finally {
                                                endBatchChange();
                                            }

                                            apex.message.showPageSuccess(
                                                "Bundled Offer removed."
                                            );
                                        }
                                    );

                                    return;
                                }

                                /*
                                 * Normal/package removal.
                                 */
                                model.forEach(
                                    function(record) {
                                        var recordId;
                                        var packageInstanceId;

                                        if (
                                            isDeleted(
                                                model,
                                                record
                                            )
                                        ) {
                                            return;
                                        }

                                        recordId =
                                            model.getRecordId(
                                                record
                                            );

                                        packageInstanceId =
                                            getRawValue(
                                                model,
                                                record,
                                                "PACKAGE_INSTANCE_ID"
                                            );

                                        if (
                                            selectedRecordIds[
                                                String(recordId)
                                            ] ||
                                            (
                                                packageInstanceId &&
                                                packageInstanceIds[
                                                    String(
                                                        packageInstanceId
                                                    )
                                                ]
                                            )
                                        ) {
                                            recordsToDelete.push(
                                                record
                                            );
                                        }
                                    }
                                );

                                if (
                                    !recordsToDelete.length
                                ) {
                                    clearGridSelection(
                                        gridView
                                    );

                                    return;
                                }

                                apex.message.confirm(
                                    objectKeys(
                                        packageInstanceIds
                                    ).length > 0 ?
                                    (
                                        "Remove " +
                                        recordsToDelete.length +
                                        " invoice line(s)? " +
                                        "Selecting any package line removes the entire package."
                                    ) :
                                    (
                                        "Remove " +
                                        recordsToDelete.length +
                                        " selected invoice line(s)?"
                                    ),

                                    function(confirmed) {
                                        if (!confirmed) {
                                            return;
                                        }

                                        apex.message.clearErrors();

                                        prepareGridForDelete(
                                            gridView
                                        );

                                        beginBatchChange();

                                        try {
                                            model.deleteRecords(
                                                recordsToDelete
                                            );
                                        } finally {
                                            endBatchChange();
                                        }
                                    }
                                );
                            })

                            .fail(function() {
                                showPageError(
                                    "Complete or correct the active invoice line before removing invoice lines."
                                );
                            });
                    }
                },

                /* ====================================================================
                 * Action: clear-all-lines
                 * Purpose: Remove every active Invoice Services row in one operation,
                 *          including normal, package, and bundled-offer rows.
                 * ================================================================== */
                {
                    name: "clear-all-lines",

                    label: "Clear All Lines",

                    disabled: true,

                    action: function() {

                        if (
                            !requireInvoiceStructureChangeAvailable()
                        ) {
                            return;
                        }
                        var context =
                            requireGridContext(
                                "Clear All Lines"
                            );

                        if (!context) {
                            return;
                        }

                        var gridView =
                            context.gridView;

                        var model =
                            context.model;

                        gridView.view$
                            .grid(
                                "finishEditing"
                            )
                            .done(function() {
                                var records = [];

                                model.forEach(
                                    function(record) {
                                        if (
                                            isDeleted(
                                                model,
                                                record
                                            )
                                        ) {
                                            return;
                                        }

                                        records.push(
                                            record
                                        );
                                    }
                                );

                                if (!records.length) {
                                    clearGridSelection(
                                        gridView
                                    );

                                    return;
                                }

                                apex.message.confirm(
                                    "Remove all " +
                                    records.length +
                                    " invoice line(s)?",

                                    function(confirmed) {
                                        if (!confirmed) {
                                            return;
                                        }

                                        apex.message.clearErrors();

                                        prepareGridForDelete(
                                            gridView
                                        );

                                        beginBatchChange();

                                        try {
                                            model.deleteRecords(
                                                records
                                            );
                                        } finally {
                                            endBatchChange();
                                        }
                                    }
                                );
                            })

                            .fail(function() {
                                showPageError(
                                    "Complete or correct the active invoice line before clearing invoice lines."
                                );
                            });

                    }
                }
            ]);

            /* ======================================================================
             * Remove built-in actions that can bypass package atomicity or expose
             * functionality that Page 48 does not need.
             * ==================================================================== */

            [
                "single-row-view",
                "row-duplicate",
                "row-refresh",
                "row-revert",
                "selection-copy",
                "selection-cut",
                "selection-paste",
                "selection-paste-insert",
                "selection-delete",
                "selection-fill",
                "selection-copy-down",
                "selection-clear",
                "selection-duplicate",
                "selection-refresh",
                "selection-revert"
            ].forEach(
                removeAction
            );
            bindRemovalActionState();
        };

    return options;
};