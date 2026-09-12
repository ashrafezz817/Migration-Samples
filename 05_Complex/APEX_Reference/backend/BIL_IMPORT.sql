create or replace package BIL_IMPORT authid definer as
  c_source_request constant varchar2(30) := 'REQUEST';
  c_source_package constant varchar2(30) := 'PACKAGE';
  c_source_visit   constant varchar2(30) := 'NEW_VISIT';

  type t_import_line is record (
    source_type          varchar2(30),
    source_id            varchar2(100),
    serviceid            d_inv.serviceid%type,
    qty                  d_inv.qty%type,
    discount_type        varchar2(1),
    disc                 d_inv.disc%type,
    my_disc              d_inv.my_disc%type,
    price_override       d_inv.price%type,
    has_price_override   varchar2(1),
    request_price        pat_serv_req.price%type,
    teeth_no             d_inv.teeth_no%type,
    tooth_surface        d_inv.tooth_surface%type,
    teeth_no2            d_inv.teeth_no2%type,
    pat_serv_req_row_id  d_inv.pat_serv_req_row_id%type,
    approv_date          d_inv.approv_date%type,
    approv_validity      d_inv.approv_validity%type,
    approv_ref_no        d_inv.approv_ref_no%type,
    claim_no             d_inv.claim_no%type,
    req_need_a           d_inv.req_need_a%type,
    req_a_status         d_inv.req_a_status%type,
    package_service_id   d_inv.serviceid%type,
    package_instance_id  varchar2(64),
    package_line_role    varchar2(20),
    package_component_order number,
    package_parent_line_id number,
    package_pricing_method services.package_pricing_method%type,
    package_definition_token varchar2(64),
    allow_manual_discount varchar2(1),
    allow_price_override  varchar2(1),
    message              varchar2(4000)
  );

  type t_import_line_tab is table of t_import_line index by pls_integer;

  type t_import_result is record (
    source_type              varchar2(30),
    source_count             number,
    imported_count           number,
    skipped_rejected_count   number,
    skipped_need_approval_count number,
    skipped_invalid_count    number,
    has_price_overrides      varchar2(1),
    message                  varchar2(4000)
  );

  procedure get_request_lines (
    p_patientno              in  t_inv.patientno%type,
    p_visit_unique           in  pat_visit_m.visit_unique%type,
    p_paytype                in  t_inv.paytype%type,
    p_app_id                 in  number,
    p_app_session_id         in  varchar2,
    p_app_user               in  varchar2,
    p_approval_check_mode    in  number default 1,
    p_raise_on_blocked       in  varchar2 default 'N',
    o_lines                  out nocopy t_import_line_tab,
    o_result                 out nocopy t_import_result
  );

  procedure get_invoice_request_lines (
    p_patientno              in  t_inv.patientno%type,
    p_visit_unique           in  pat_visit_m.visit_unique%type,
    p_paytype                in  t_inv.paytype%type,
    p_app_id                 in  number,
    p_app_session_id         in  varchar2,
    p_app_user               in  varchar2,
    p_invoice_date           in  t_inv.invdate%type,
    p_approval_check_mode    in  number default 1,
    p_raise_on_blocked       in  varchar2 default 'N',
    o_lines                  out nocopy t_import_line_tab,
    o_result                 out nocopy t_import_result
  );

  function get_request_package_instance_id (
    p_pat_serv_req_row_id in pat_serv_req.pat_serv_req_row_id%type
  ) return d_inv.package_instance_id%type;

  procedure resolve_request_price_override (
    p_patient_context       in  bil_types.t_patient_context,
    p_service_context       in  bil_types.t_service_context,
    p_qty                   in  d_inv.qty%type,
    p_request_price         in  pat_serv_req.price%type,
    p_invoice_date          in  t_inv.invdate%type,
    p_cash_comp_code        in  companys.comp_code%type,
    o_price_override        out d_inv.price%type,
    o_has_price_override    out varchar2
  );

  procedure set_request_line_selection (
    p_patientno              in  t_inv.patientno%type,
    p_visit_unique           in  pat_visit_m.visit_unique%type,
    p_paytype                in  t_inv.paytype%type,
    p_app_id                 in  number,
    p_app_session_id         in  varchar2,
    p_app_user               in  varchar2,
    p_pat_serv_req_row_id    in  pat_serv_req.pat_serv_req_row_id%type,
    p_selected               in  number
  );

  procedure clear_request_invoice_selection (
    p_patientno              in  t_inv.patientno%type,
    p_app_id                 in  number,
    p_app_session_id         in  varchar2,
    p_app_user               in  varchar2
  );

  procedure get_package_lines (
    p_package_serviceid      in  d_inv.serviceid%type,
    p_list_id                in  d_inv.list_id%type,
    p_parent_source_id       in  varchar2 default null,
    o_lines                  out nocopy t_import_line_tab,
    o_result                 out nocopy t_import_result
  );

  procedure get_visit_line (
    p_patientno              in  t_inv.patientno%type,
    p_docid                  in  t_inv.docid%type,
    p_new_visit_type         in  varchar2,
    p_paytype                in  t_inv.paytype%type,
    p_clinicid               in  t_inv.clinicid%type,
    p_info_center_id         in  t_inv.info_center_id%type,
    p_invoice_date           in  t_inv.invdate%type,
    o_line                   out nocopy t_import_line,
    o_result                 out nocopy t_import_result
  );

  procedure to_engine_lines (
    p_import_lines           in  t_import_line_tab,
    o_engine_lines           out nocopy bil_invoice_engine.t_line_input_tab
  );

end bil_import;
/

create or replace package body BIL_IMPORT as

  ------------------------------------------------------------------------------
  -- Constants
  ------------------------------------------------------------------------------
  c_yes constant varchar2(1) := 'Y';
  c_no  constant varchar2(1) := 'N';
  c_paytype_cash   constant number := 1;
  c_paytype_credit constant number := 2;

  ------------------------------------------------------------------------------
  -- Helpers
  ------------------------------------------------------------------------------

  function trim_to_null (
    p_value in varchar2
  ) return varchar2
  is
    l_value varchar2(32767);
  begin
    l_value := trim(p_value);
    return case when l_value is null then null else l_value end;
  end trim_to_null;

  function upper_trim_to_null (
    p_value in varchar2
  ) return varchar2
  is
    l_value varchar2(32767);
  begin
    l_value := trim_to_null(p_value);
    return case when l_value is null then null else upper(l_value) end;
  end upper_trim_to_null;

  function strict_yn_flag (
    p_value in varchar2,
    p_name  in varchar2
  ) return varchar2
  is
    l_value varchar2(100);
  begin
    l_value := upper_trim_to_null(p_value);
    if l_value in ('Y', 'YES', '1', 'TRUE') then
      return c_yes;
    end if;
    if l_value is null or l_value in ('N', 'NO', '0', 'FALSE') then
      return c_no;
    end if;
    raise_application_error(
      -20759,
      p_name || ' must be Y or N.'
    );
  end strict_yn_flag;

  function has_price_override (
    p_price_override in number
  ) return varchar2
  is
  begin
    if p_price_override is not null then
      return c_yes;
    end if;
    return c_no;
  end has_price_override;

  procedure init_result (
    p_source_type in varchar2,
    o_result      out nocopy t_import_result
  )
  is
  begin
    o_result.source_type := p_source_type;
    o_result.source_count := 0;
    o_result.imported_count := 0;
    o_result.skipped_rejected_count := 0;
    o_result.skipped_need_approval_count := 0;
    o_result.skipped_invalid_count := 0;
    o_result.has_price_overrides := c_no;
    o_result.message := null;
  end init_result;

  procedure append_line (
    io_lines  in out nocopy t_import_line_tab,
    io_result in out nocopy t_import_result,
    p_line    in t_import_line
  )
  is
    l_idx pls_integer;
  begin
    l_idx := nvl(io_lines.last, 0) + 1;
    io_lines(l_idx) := p_line;
    io_result.imported_count := nvl(io_result.imported_count, 0) + 1;
    if p_line.has_price_override = c_yes then
      io_result.has_price_overrides := c_yes;
    end if;
  end append_line;

  procedure assert_paytype (
    p_paytype in t_inv.paytype%type
  )
  is
  begin
    if p_paytype is null or p_paytype not in (c_paytype_cash, c_paytype_credit) then
      raise_application_error(
        -20760,
        'Import failed: pay type must be 1 Cash or 2 Credit.'
      );
    end if;
  end assert_paytype;

  procedure assert_serviceid (
    p_serviceid in d_inv.serviceid%type,
    p_context   in varchar2
  )
  is
  begin
    if trim_to_null(p_serviceid) is null then
      raise_application_error(
        -20761,
        'Import failed: service ID is required. Context: ' || p_context
      );
    end if;
  end assert_serviceid;

  function get_request_package_instance_id (
    p_pat_serv_req_row_id in pat_serv_req.pat_serv_req_row_id%type
  ) return d_inv.package_instance_id%type
  is
    l_instance_id d_inv.package_instance_id%type;
  begin
    if p_pat_serv_req_row_id is null or p_pat_serv_req_row_id <= 0 then
      raise_application_error(
        -20690,
        'Request package expansion failed: request row ID is required.'
      );
    end if;

    l_instance_id := 'REQ:' || to_char(p_pat_serv_req_row_id, 'TM9');
    if length(l_instance_id) > 64 then
      raise_application_error(
        -20691,
        'Request package expansion failed: package instance ID exceeds 64 characters.'
      );
    end if;

    return l_instance_id;
  end get_request_package_instance_id;

  procedure resolve_request_price_override (
    p_patient_context       in  bil_types.t_patient_context,
    p_service_context       in  bil_types.t_service_context,
    p_qty                   in  d_inv.qty%type,
    p_request_price         in  pat_serv_req.price%type,
    p_invoice_date          in  t_inv.invdate%type,
    p_cash_comp_code        in  companys.comp_code%type,
    o_price_override        out d_inv.price%type,
    o_has_price_override    out varchar2
  )
  is
    l_price_result bil_types.t_price_result;
    l_method       services.package_pricing_method%type;
    l_is_cash      varchar2(1);
  begin
    o_price_override     := null;
    o_has_price_override := c_no;

    if p_invoice_date is null then
      raise_application_error(
        -20692,
        'Request price validation failed: invoice date/time is required.'
      );
    end if;
    if p_qty is null or p_qty <= 0 then
      raise_application_error(
        -20693,
        'Request price validation failed: quantity must be greater than zero.'
      );
    end if;
    if p_cash_comp_code is null then
      raise_application_error(
        -20694,
        'Request price validation failed: configured cash company could not be resolved.'
      );
    end if;

    l_is_cash := case when nvl(p_patient_context.is_cash, c_no) = c_yes then c_yes else c_no end;
    if (l_is_cash = c_yes and p_patient_context.comp_code <> p_cash_comp_code)
       or (l_is_cash = c_no and p_patient_context.comp_code = p_cash_comp_code)
    then
      raise_application_error(
        -20695,
        'Request price validation failed: payer type and company context are inconsistent.'
      );
    end if;

    bil_price_rule.resolve_price(
      p_patient_context => p_patient_context,
      p_service_context => p_service_context,
      p_qty             => p_qty,
      p_invoice_date    => p_invoice_date,
      o_price           => l_price_result
    );

    -- Null, zero and negative request prices are not usable override candidates.
    if p_request_price is null or p_request_price <= 0 then
      return;
    end if;

    l_method := upper_trim_to_null(p_service_context.package_pricing_method);
    if l_method = 'FREE' then
      raise_application_error(
        -20696,
        'Request price validation failed: a FREE package cannot have a nonzero request price.'
      );
    elsif l_method = 'COMPONENT_PRICE' then
      raise_application_error(
        -20697,
        'Request price validation failed: a COMPONENT_PRICE package parent cannot have a nonzero request price.'
      );
    end if;

    if round(p_request_price, 2) = round(l_price_result.billing_price, 2) then
      return;
    end if;

    if upper_trim_to_null(p_service_context.price_is_fixed) <> c_no then
      raise_application_error(
        -20698,
        'Request price validation failed: service '
        || p_service_context.serviceid
        || ' has a fixed price and the changed request price cannot be honored.'
      );
    end if;

    if l_is_cash <> c_yes or p_patient_context.comp_code <> p_cash_comp_code then
      raise_application_error(
        -20699,
        'Request price validation failed: changed request prices are allowed only for the configured cash company.'
      );
    end if;

    o_price_override     := p_request_price;
    o_has_price_override := c_yes;
  end resolve_request_price_override;

  ------------------------------------------------------------------------------
  -- Public API
  ------------------------------------------------------------------------------

  procedure get_request_lines (
    p_patientno              in  t_inv.patientno%type,
    p_visit_unique           in  pat_visit_m.visit_unique%type,
    p_paytype                in  t_inv.paytype%type,
    p_app_id                 in  number,
    p_app_session_id         in  varchar2,
    p_app_user               in  varchar2,
    p_approval_check_mode    in  number default 1,
    p_raise_on_blocked       in  varchar2 default 'N',
    o_lines                  out nocopy t_import_line_tab,
    o_result                 out nocopy t_import_result
  )
  is
    l_line         t_import_line;
    l_result       t_import_result;
    l_raise_blocked varchar2(1);
  begin
    o_lines.delete;
    init_result(c_source_request, l_result);
    if trim_to_null(p_patientno) is null then
      raise_application_error(
        -20762,
        'Request import failed: patient number is required.'
      );
    end if;
    if p_visit_unique is null then
      raise_application_error(
        -20763,
        'Request import failed: visit unique is required.'
      );
    end if;
    if p_app_id is null then
      raise_application_error(
        -20778,
        'Request import failed: application ID is required.'
      );
    end if;
    if trim_to_null(p_app_session_id) is null then
      raise_application_error(
        -20779,
        'Request import failed: application session is required.'
      );
    end if;
    if trim_to_null(p_app_user) is null then
      raise_application_error(
        -20782,
        'Request import failed: application user is required.'
      );
    end if;
    assert_paytype(p_paytype);
    if p_approval_check_mode is null or p_approval_check_mode not in (0, 1) then
      raise_application_error(
        -20758,
        'Request import failed: approval check mode must be 0 or 1.'
      );
    end if;
    l_raise_blocked := strict_yn_flag(p_raise_on_blocked, 'p_raise_on_blocked');
    /*
      Import only rows explicitly selected by this APEX app/session/user.
      Do not use the legacy PAT_SERV_REQ selection flag here; it is not
      session-scoped and can leak selections between users/sessions.
    */
    for r in (
      select r.serviceid,
             r.qty,
             r.price,
             nvl(r.price_disc, 0) price_disc,
             r.pat_serv_req_row_id,
             nvl(r.req_need_a, 0) req_need_a,
             nvl(r.req_a_status, 0) req_a_status,
             r.approv_ref_no,
             r.approv_date,
             r.approv_validity,
             r.claim_no,
             r.teeth_no,
             r.teeth_no2,
             r.tooth_surface
        from v_services_req r
        join bil_request_inv_selection s
          on s.app_id              = p_app_id
         and s.app_session_id      = p_app_session_id
         and s.app_user            = p_app_user
         and s.patientno           = r.patientno
         and s.visit_unique        = r.visit_unique
         and s.pat_serv_req_row_id = r.pat_serv_req_row_id
         and s.paytype             = p_paytype
       where r.patientno = p_patientno
         and r.d_inv_row_id is null
         and r.visit_unique = p_visit_unique
         and case upper(trim(r.pay_type))
               when 'CASH' then 1
               when 'CREDIT' then 2
             end = p_paytype
       order by r.pat_serv_req_row_id
    ) loop
      l_result.source_count := l_result.source_count + 1;
      if r.req_a_status = 3 then
        l_result.skipped_rejected_count := l_result.skipped_rejected_count + 1;
        continue;
      end if;
      /*
        Forms:
          If approval check mode = 1, approval required, no approv ref, and paytype=2:
          show "Need Approval" and skip/block.
      */
      if p_approval_check_mode = 1
         and nvl(r.req_need_a, 0) <> 0
         and r.approv_ref_no is null
         and p_paytype = c_paytype_credit then
        l_result.skipped_need_approval_count :=
          l_result.skipped_need_approval_count + 1;
        if l_raise_blocked = c_yes then
          raise_application_error(
            -20764,
            'Request import failed: service '
            || r.serviceid
            || ' needs approval before import.'
          );
        end if;
        continue;
      end if;
      if trim_to_null(r.serviceid) is null then
        raise_application_error(
          -20770,
          'Request import failed: selected request line '
          || r.pat_serv_req_row_id
          || ' has no service ID.'
        );
      end if;
      if nvl(r.qty, 0) <= 0 then
        raise_application_error(
          -20771,
          'Request import failed: selected request line '
          || r.pat_serv_req_row_id
          || ' has invalid quantity.'
        );
      end if;
      l_line.source_type         := c_source_request;
      l_line.source_id           := to_char(r.pat_serv_req_row_id);
      l_line.serviceid           := r.serviceid;
      l_line.qty                 := r.qty;
      -- V_SERVICES_REQ.PRICE_DISC is the request-time plan discount snapshot.
      -- The invoice engine resolves the current authoritative plan discount.
      l_line.discount_type       := 'N';
      l_line.disc                := 0;
      l_line.my_disc             := null;

     -- PAT_SERV_REQ.PRICE is NOT invoice price override.
     -- Request invoice price must be recalculated from billing context / price rules.
      l_line.price_override      := null;
      l_line.has_price_override  := c_no;
      l_line.request_price       := r.price;
      l_line.teeth_no            := r.teeth_no;
      l_line.teeth_no2           := nvl(r.teeth_no2, r.teeth_no);
      l_line.tooth_surface       := r.tooth_surface;
      l_line.pat_serv_req_row_id := r.pat_serv_req_row_id;
      l_line.approv_date         := r.approv_date;
      l_line.approv_validity     := r.approv_validity;
      l_line.approv_ref_no       := r.approv_ref_no;
      l_line.claim_no            := r.claim_no;
      l_line.req_need_a          := r.req_need_a;
      l_line.req_a_status        := r.req_a_status;
      l_line.message             := 'Imported from V_SERVICES_REQ.';
      append_line(
        io_lines  => o_lines,
        io_result => l_result,
        p_line    => l_line
      );
    end loop;
    l_result.message :=
         'Request import completed. Imported '
      || l_result.imported_count
      || ' of '
      || l_result.source_count
      || ' selected request lines.';
    o_result := l_result;
  end get_request_lines;

  procedure get_invoice_request_lines (
    p_patientno              in  t_inv.patientno%type,
    p_visit_unique           in  pat_visit_m.visit_unique%type,
    p_paytype                in  t_inv.paytype%type,
    p_app_id                 in  number,
    p_app_session_id         in  varchar2,
    p_app_user               in  varchar2,
    p_invoice_date           in  t_inv.invdate%type,
    p_approval_check_mode    in  number default 1,
    p_raise_on_blocked       in  varchar2 default 'N',
    o_lines                  out nocopy t_import_line_tab,
    o_result                 out nocopy t_import_result
  )
  is
    l_source_lines        t_import_line_tab;
    l_source_result       t_import_result;
    l_result              t_import_result;
    l_line                t_import_line;
    l_patient_context     bil_types.t_patient_context;
    l_service_context     bil_types.t_service_context;
    l_cash_comp_code      companys.comp_code%type;
    l_instance_id         d_inv.package_instance_id%type;
    l_component_order     number;
    l_expected_qty        number;
    l_idx                 pls_integer;
  begin
    if p_invoice_date is null then
      raise_application_error(
        -20692,
        'Request package expansion failed: invoice date/time is required.'
      );
    end if;

    get_request_lines(
      p_patientno           => p_patientno,
      p_visit_unique        => p_visit_unique,
      p_paytype             => p_paytype,
      p_app_id              => p_app_id,
      p_app_session_id      => p_app_session_id,
      p_app_user            => p_app_user,
      p_approval_check_mode => p_approval_check_mode,
      p_raise_on_blocked    => p_raise_on_blocked,
      o_lines               => l_source_lines,
      o_result              => l_source_result
    );

    o_lines.delete;
    init_result(c_source_request, l_result);
    l_result.source_count := l_source_result.source_count;
    l_result.skipped_rejected_count := l_source_result.skipped_rejected_count;
    l_result.skipped_need_approval_count := l_source_result.skipped_need_approval_count;
    l_result.skipped_invalid_count := l_source_result.skipped_invalid_count;

    bil_patient_context.get_context(
      p_patientno    => p_patientno,
      p_invoice_date => p_invoice_date,
      p_paytype      => p_paytype,
      o_context      => l_patient_context
    );
    l_cash_comp_code := ins_comp_util.get_cash_comp_code;
    if l_cash_comp_code is null then
      raise_application_error(
        -20694,
        'Request package expansion failed: configured cash company could not be resolved.'
      );
    end if;

    l_idx := l_source_lines.first;
    while l_idx is not null loop
      l_line := l_source_lines(l_idx);

      bil_service_context.get_context(
        p_patient_context => l_patient_context,
        p_serviceid       => l_line.serviceid,
        p_qty             => l_line.qty,
        p_invoice_date    => p_invoice_date,
        o_context         => l_service_context
      );

      resolve_request_price_override(
        p_patient_context    => l_patient_context,
        p_service_context    => l_service_context,
        p_qty                => l_line.qty,
        p_request_price      => l_line.request_price,
        p_invoice_date       => p_invoice_date,
        p_cash_comp_code     => l_cash_comp_code,
        o_price_override     => l_line.price_override,
        o_has_price_override => l_line.has_price_override
      );

      if nvl(l_service_context.is_package, 0) <> 1 then
        l_line.package_service_id      := null;
        l_line.package_instance_id     := null;
        l_line.package_line_role       := null;
        l_line.package_component_order := null;
        l_line.package_parent_line_id  := null;
        l_line.package_pricing_method  := null;
        l_line.package_definition_token := null;
        append_line(o_lines, l_result, l_line);
      else
        l_instance_id := get_request_package_instance_id(l_line.pat_serv_req_row_id);
        l_line.package_service_id      := l_line.serviceid;
        l_line.package_instance_id     := l_instance_id;
        l_line.package_line_role       := 'PARENT';
        l_line.package_component_order := 0;
        l_line.package_parent_line_id  := null;
        l_line.package_pricing_method  :=
          upper_trim_to_null(l_service_context.package_pricing_method);
        l_line.package_definition_token :=
          bil_invoice_engine.get_package_definition_token(
            l_line.serviceid,
            l_patient_context.list_id
          );
        l_line.allow_manual_discount   := c_no;
        l_line.allow_price_override    :=
          case when l_line.has_price_override = c_yes then c_yes else c_no end;
        l_line.message := 'Imported requested package parent.';
        append_line(o_lines, l_result, l_line);

        l_component_order := 0;
        for r in (
          select d.sub_serviceid,
                 d.qty
            from package_dtl d
           where d.serviceid = l_line.serviceid
             and d.list_id = l_patient_context.list_id
           order by d.sub_serviceid
        ) loop
          if trim_to_null(r.sub_serviceid) is null
             or r.qty is null
             or r.qty <= 0
          then
            raise_application_error(
              -20773,
              'Request package expansion failed: invalid component definition for package '
              || l_line.serviceid
              || '.'
            );
          end if;

          l_expected_qty := l_line.qty * r.qty;
          if l_expected_qty <= 0 or l_expected_qty <> round(l_expected_qty, 2) then
            raise_application_error(
              -20771,
              'Request package expansion failed: multiplied quantity exceeds the supported two-decimal quantity precision for component '
              || r.sub_serviceid
              || '.'
            );
          end if;

          l_component_order := l_component_order + 1;
          declare
            l_component t_import_line;
          begin
            l_component.source_type             := c_source_request;
            l_component.source_id               := to_char(l_line.pat_serv_req_row_id);
            l_component.serviceid               := r.sub_serviceid;
            l_component.qty                     := l_expected_qty;
            l_component.discount_type           := 'N';
            l_component.disc                    := 0;
            l_component.my_disc                 := null;
            l_component.price_override          := null;
            l_component.has_price_override      := c_no;
            l_component.request_price           := null;
            l_component.pat_serv_req_row_id     := null;
            l_component.package_service_id      := l_line.serviceid;
            l_component.package_instance_id     := l_instance_id;
            l_component.package_line_role       := 'COMPONENT';
            l_component.package_component_order := l_component_order;
            l_component.package_parent_line_id  := null;
            l_component.package_pricing_method  := l_line.package_pricing_method;
            l_component.package_definition_token :=
              l_line.package_definition_token;
            l_component.allow_manual_discount   := c_no;
            l_component.allow_price_override    := c_no;
            l_component.message := 'Expanded requested package component.';
            append_line(o_lines, l_result, l_component);
          end;
        end loop;

        if l_component_order = 0 then
          raise_application_error(
            -20774,
            'Request package expansion failed: package '
            || l_line.serviceid
            || ' has no components.'
          );
        end if;
      end if;

      l_idx := l_source_lines.next(l_idx);
    end loop;

    l_result.message :=
         'Invoice request import completed. Expanded '
      || l_result.source_count
      || ' request rows into '
      || l_result.imported_count
      || ' invoice lines.';
    o_result := l_result;
  end get_invoice_request_lines;

  procedure set_request_line_selection (
    p_patientno              in  t_inv.patientno%type,
    p_visit_unique           in  pat_visit_m.visit_unique%type,
    p_paytype                in  t_inv.paytype%type,
    p_app_id                 in  number,
    p_app_session_id         in  varchar2,
    p_app_user               in  varchar2,
    p_pat_serv_req_row_id    in  pat_serv_req.pat_serv_req_row_id%type,
    p_selected               in  number
  )
  is
    l_exists number;
  begin
    if trim_to_null(p_patientno) is null then
      raise_application_error(
        -20772,
        'Request selection failed: patient number is required.'
      );
    end if;

    if p_visit_unique is null then
      raise_application_error(
        -20773,
        'Request selection failed: visit unique is required.'
      );
    end if;

    if p_pat_serv_req_row_id is null then
      raise_application_error(
        -20774,
        'Request selection failed: request line row ID is required.'
      );
    end if;

    assert_paytype(p_paytype);

    if p_app_id is null then
      raise_application_error(
        -20778,
        'Request selection failed: application ID is required.'
      );
    end if;

    if trim_to_null(p_app_session_id) is null then
      raise_application_error(
        -20779,
        'Request selection failed: application session is required.'
      );
    end if;

    if trim_to_null(p_app_user) is null then
      raise_application_error(
        -20782,
        'Request selection failed: application user is required.'
      );
    end if;

    if p_selected not in (0, 1) then
      raise_application_error(
        -20775,
        'Request selection failed: select value must be 0 or 1.'
      );
    end if;

    select count(*)
      into l_exists
      from v_services_req r
     where r.pat_serv_req_row_id = p_pat_serv_req_row_id
       and r.patientno = p_patientno
       and r.visit_unique = p_visit_unique
       and r.d_inv_row_id is null
       and case upper(trim(r.pay_type))
             when 'CASH' then c_paytype_cash
             when 'CREDIT' then c_paytype_credit
           end = p_paytype;

    if l_exists <> 1 then
      raise_application_error(
        -20776,
        'Request selection failed: the request line is no longer available.'
      );
    end if;

    if p_selected = 1 then
      merge into bil_request_inv_selection s
      using (
        select p_app_id app_id,
               p_app_session_id app_session_id,
               p_app_user app_user,
               p_patientno patientno,
               p_visit_unique visit_unique,
               p_paytype paytype,
               p_pat_serv_req_row_id pat_serv_req_row_id
          from dual
      ) src
         on (s.app_id = src.app_id
         and s.app_session_id = src.app_session_id
         and s.app_user = src.app_user
         and s.patientno = src.patientno
         and s.visit_unique = src.visit_unique
         and s.paytype = src.paytype
         and s.pat_serv_req_row_id = src.pat_serv_req_row_id)
       when not matched then
         insert (
           app_id,
           app_session_id,
           app_user,
           patientno,
           visit_unique,
           paytype,
           pat_serv_req_row_id
         )
         values (
           src.app_id,
           src.app_session_id,
           src.app_user,
           src.patientno,
           src.visit_unique,
           src.paytype,
           src.pat_serv_req_row_id
         );
    else
      delete from bil_request_inv_selection s
       where s.app_id = p_app_id
         and s.app_session_id = p_app_session_id
         and s.app_user = p_app_user
         and s.patientno = p_patientno
         and s.visit_unique = p_visit_unique
         and s.paytype = p_paytype
         and s.pat_serv_req_row_id = p_pat_serv_req_row_id;
    end if;
  end set_request_line_selection;

  procedure clear_request_invoice_selection (
    p_patientno              in  t_inv.patientno%type,
    p_app_id                 in  number,
    p_app_session_id         in  varchar2,
    p_app_user               in  varchar2
  )
  is
  begin
    if trim_to_null(p_patientno) is null then
      raise_application_error(
        -20777,
        'Request selection clear failed: patient number is required.'
      );
    end if;

    if p_app_id is null then
      raise_application_error(
        -20778,
        'Request selection clear failed: application ID is required.'
      );
    end if;

    if trim_to_null(p_app_session_id) is null then
      raise_application_error(
        -20779,
        'Request selection clear failed: application session is required.'
      );
    end if;

    if trim_to_null(p_app_user) is null then
      raise_application_error(
        -20782,
        'Request selection clear failed: application user is required.'
      );
    end if;

    delete from bil_request_inv_selection s
     where s.app_id = p_app_id
       and s.app_session_id = p_app_session_id
       and s.app_user = p_app_user
       and s.patientno = p_patientno;
  end clear_request_invoice_selection;

  procedure get_package_lines (
    p_package_serviceid      in  d_inv.serviceid%type,
    p_list_id                in  d_inv.list_id%type,
    p_parent_source_id       in  varchar2 default null,
    o_lines                  out nocopy t_import_line_tab,
    o_result                 out nocopy t_import_result
  )
  is
    l_line                t_import_line;
    l_result              t_import_result;
    l_package_method      services.package_pricing_method%type;
    l_package_instance_id varchar2(64);
    l_component_order     number := 0;
    l_definition_token    varchar2(64);
  begin
    o_lines.delete;
    init_result(c_source_package, l_result);
    assert_serviceid(p_package_serviceid, 'PACKAGE SERVICE');
    if p_list_id is null then
      raise_application_error(
        -20766,
        'Package import failed: list ID is required.'
      );
    end if;
    begin
      select upper(trim(package_pricing_method))
        into l_package_method
        from services
       where serviceid = p_package_serviceid
         and list_id = p_list_id
         and is_package = 1;
    exception
      when no_data_found then
        raise_application_error(
          -20767,
          'Package import failed: service '
          || p_package_serviceid
          || ' is not a package in list '
          || p_list_id
          || '.'
        );
    end;
    if l_package_method not in ('FIXED_PRICE', 'COMPONENT_PRICE', 'FREE') then
      raise_application_error(
        -20768,
        'Package import failed: package pricing method is invalid for service '
        || p_package_serviceid
        || '.'
      );
    end if;
    l_definition_token := bil_invoice_engine.get_package_definition_token(
                            p_package_serviceid,
                            p_list_id
                          );
    l_package_instance_id :=
      substr(
        p_package_serviceid
        || ':'
        || rawtohex(sys_guid()),
        1,
        64
      );

    l_line.source_type             := c_source_package;
    l_line.source_id               := l_package_instance_id;
    l_line.serviceid               := p_package_serviceid;
    l_line.qty                     := 1;
    l_line.discount_type           := 'N';
    l_line.disc                    := 0;
    l_line.my_disc                 := null;
    l_line.price_override          := null;
    l_line.has_price_override      := c_no;
    l_line.request_price           := null;
    l_line.teeth_no                := null;
    l_line.teeth_no2               := null;
    l_line.tooth_surface           := null;
    l_line.pat_serv_req_row_id     := null;
    l_line.approv_date             := null;
    l_line.approv_validity         := null;
    l_line.approv_ref_no           := null;
    l_line.claim_no                := null;
    l_line.req_need_a              := null;
    l_line.req_a_status            := null;
    l_line.package_service_id      := p_package_serviceid;
    l_line.package_instance_id     := l_package_instance_id;
    l_line.package_line_role       := 'PARENT';
    l_line.package_component_order := 0;
    l_line.package_parent_line_id  := null;
    l_line.package_pricing_method  := l_package_method;
    l_line.package_definition_token := l_definition_token;
    l_line.allow_manual_discount   := c_no;
    l_line.allow_price_override    := c_no;
    l_line.message                 := 'Imported package parent.';
    l_result.source_count          := 1;
    append_line(
      io_lines  => o_lines,
      io_result => l_result,
      p_line    => l_line
    );
    /*
      Legacy Forms cursor selected PACKAGE_DTL rows by parent SERVICEID
      and invoice LIST_ID.
    */
    for r in (
      select d.sub_serviceid,
             d.qty,
             s.non_disc
        from package_dtl d
        join services s
          on s.serviceid = d.sub_serviceid
         and s.list_id = d.list_id
       where d.serviceid = p_package_serviceid
         and d.list_id = p_list_id
       order by d.sub_serviceid
    ) loop
      l_result.source_count := l_result.source_count + 1;
      if trim_to_null(r.sub_serviceid) is null then
        raise_application_error(
          -20772,
          'Package import failed: package service '
          || p_package_serviceid
          || ' has a blank sub-service in PACKAGE_DTL.'
        );
      end if;
      if nvl(r.qty, 0) <= 0 then
        raise_application_error(
          -20773,
          'Package import failed: package service '
          || p_package_serviceid
          || ' has invalid quantity for sub-service '
          || r.sub_serviceid
          || '.'
        );
      end if;
      l_component_order := l_component_order + 1;
      l_line.source_type             := c_source_package;
      l_line.source_id               := l_package_instance_id;
      l_line.serviceid               := r.sub_serviceid;
      l_line.qty                     := r.qty;
      l_line.discount_type           := 'N';
      l_line.disc                    := 0;
      l_line.my_disc                 := null;
      l_line.price_override          := null;
      l_line.has_price_override      := c_no;
      l_line.request_price           := null;
      l_line.teeth_no                := null;
      l_line.teeth_no2               := null;
      l_line.tooth_surface           := null;
      l_line.pat_serv_req_row_id     := null;
      l_line.approv_date             := null;
      l_line.approv_validity         := null;
      l_line.approv_ref_no           := null;
      l_line.claim_no                := null;
      l_line.req_need_a              := null;
      l_line.req_a_status            := null;
      l_line.package_service_id      := p_package_serviceid;
      l_line.package_instance_id     := l_package_instance_id;
      l_line.package_line_role       := 'COMPONENT';
      l_line.package_component_order := l_component_order;
      l_line.package_parent_line_id  := null;
      l_line.package_pricing_method  := l_package_method;
      l_line.package_definition_token := l_definition_token;
      l_line.allow_manual_discount   :=
        case
          when l_package_method = 'COMPONENT_PRICE'
           and nvl(r.non_disc, 1) <> 1 then c_yes
          else c_no
        end;
      l_line.allow_price_override    := c_no;
      l_line.message                 := 'Imported package component from PACKAGE_DTL.';
      append_line(
        io_lines  => o_lines,
        io_result => l_result,
        p_line    => l_line
      );
    end loop;
    l_result.message :=
         'Package import completed. Imported '
      || l_result.imported_count
      || ' of '
      || l_result.source_count
      || ' package lines.';
    o_result := l_result;
  end get_package_lines;

  procedure resolve_visit_line (
    p_patientno              in  t_inv.patientno%type,
    p_docid                  in  t_inv.docid%type,
    p_new_visit_type         in  varchar2,
    p_paytype                in  t_inv.paytype%type,
    p_clinicid               in  t_inv.clinicid%type,
    p_info_center_id         in  t_inv.info_center_id%type,
    p_invoice_date           in  t_inv.invdate%type,
    o_line                   out nocopy t_import_line,
    o_result                 out nocopy t_import_result
  )
  is
    l_patient        bil_types.t_patient_context;
    l_service        bil_types.t_service_context;
    l_price          bil_types.t_price_result;
    l_new_visit_type varchar2(30);
    l_serviceid      d_inv.serviceid%type;
    l_invoice_date   t_inv.invdate%type;
    l_exists         number;
    l_line           t_import_line;
    l_result         t_import_result;
  begin
    init_result(c_source_visit, l_result);
    if p_patientno is null then
      raise_application_error(
        -20750,
        'Visit import failed: patient number is required.'
      );
    end if;
    if p_docid is null then
      raise_application_error(
        -20751,
        'Visit import failed: doctor is required.'
      );
    end if;

    if p_invoice_date is null then
      raise_application_error(
        -20756,
        'Visit import failed: invoice date/time is required.'
      );
    end if;

    l_invoice_date := p_invoice_date;

    assert_paytype(p_paytype);

    if p_clinicid is null then
      raise_application_error(
        -20757,
        'Visit import failed: clinic is required.'
      );
    end if;

    if p_info_center_id is null then
      raise_application_error(
        -20758,
        'Visit import failed: info center is required.'
      );
    end if;

    select count(*)
      into l_exists
      from doctors d
     where d.docid = p_docid
       and d.clinicid = p_clinicid
       and nvl(d.doc_active, 1) <> 0;

    if l_exists = 0 then
      raise_application_error(
        -20759,
        'Visit import failed: selected doctor is not active in the selected clinic.'
      );
    end if;

    bil_patient_context.get_context(
      p_patientno      => p_patientno,
      p_invoice_date   => l_invoice_date,
      p_paytype        => p_paytype,
      p_info_center_id => p_info_center_id,
      o_context        => l_patient
    );

    l_new_visit_type := upper_trim_to_null(p_new_visit_type);
    if l_new_visit_type is null
       or l_new_visit_type not in ('CONSULTATION', 'REVIEW') then
      raise_application_error(
        -20752,
        'Visit import failed: new visit type must be CONSULTATION or REVIEW.'
      );
    end if;
    begin
      select case
               when l_new_visit_type = 'CONSULTATION' then cons_servid
               else review_servid
             end
        into l_serviceid
        from doctor_consultation
       where list_id = l_patient.list_id
         and docid   = p_docid;
    exception
      when no_data_found then
        raise_application_error(
          -20753,
          'Visit import failed: no consultation/review setup was found for this doctor and patient price list.'
        );
      when too_many_rows then
        raise_application_error(
          -20754,
          'Visit import failed: consultation/review setup is duplicated for this doctor and patient price list.'
        );
    end;
    if trim_to_null(l_serviceid) is null then
      raise_application_error(
        -20755,
        case
          when l_new_visit_type = 'CONSULTATION' then
            'Visit import failed: no consultation service is configured for this doctor and patient price list.'
          else
            'Visit import failed: no review service is configured for this doctor and patient price list.'
        end
      );
    end if;

    bil_service_context.get_context(
      p_patient_context => l_patient,
      p_serviceid       => l_serviceid,
      p_qty             => 1,
      p_invoice_date    => l_invoice_date,
      o_context         => l_service
    );

    bil_price_rule.resolve_price(
      p_patient_context => l_patient,
      p_service_context => l_service,
      p_qty             => 1,
      p_invoice_date    => l_invoice_date,
      o_price           => l_price
    );

    l_line.source_type         := c_source_visit;
    l_line.source_id           := l_new_visit_type || ':' || to_char(p_docid);
    l_line.serviceid           := l_serviceid;
    l_line.qty                 := 1;
    l_line.discount_type       := 'N';
    l_line.disc                := 0;
    l_line.my_disc             := 0;
    l_line.price_override      := null;
    l_line.has_price_override  := c_no;
    l_line.request_price       := null;
    l_line.teeth_no            := null;
    l_line.teeth_no2           := null;
    l_line.tooth_surface       := null;
    l_line.pat_serv_req_row_id := null;
    l_line.approv_date         := null;
    l_line.approv_validity     := null;
    l_line.approv_ref_no       := null;
    l_line.claim_no            := null;
    l_line.req_need_a          := null;
    l_line.req_a_status        := null;
    if nvl(l_service.is_package, 0) = 1 then
      l_line.package_service_id      := l_serviceid;
      l_line.package_instance_id     := null;
      l_line.package_line_role       := 'PARENT';
      l_line.package_component_order := 0;
      l_line.package_parent_line_id  := null;
      l_line.package_pricing_method  := l_service.package_pricing_method;
      l_line.package_definition_token :=
        bil_invoice_engine.get_package_definition_token(
          l_serviceid,
          l_patient.list_id
        );
      l_line.allow_manual_discount   := c_no;
      l_line.allow_price_override    := c_no;
    end if;
    l_line.message             := 'Resolved from DOCTOR_CONSULTATION.';
    l_result.source_count := 1;
    l_result.imported_count := 1;
    l_result.message :=
      'Visit service resolved. Service: ' || l_serviceid || '.';
    o_line   := l_line;
    o_result := l_result;
  end resolve_visit_line;

  procedure get_visit_line (
    p_patientno              in  t_inv.patientno%type,
    p_docid                  in  t_inv.docid%type,
    p_new_visit_type         in  varchar2,
    p_paytype                in  t_inv.paytype%type,
    p_clinicid               in  t_inv.clinicid%type,
    p_info_center_id         in  t_inv.info_center_id%type,
    p_invoice_date           in  t_inv.invdate%type,
    o_line                   out nocopy t_import_line,
    o_result                 out nocopy t_import_result
  )
  is
  begin
    resolve_visit_line(
      p_patientno        => p_patientno,
      p_docid            => p_docid,
      p_new_visit_type   => p_new_visit_type,
      p_paytype          => p_paytype,
      p_clinicid         => p_clinicid,
      p_info_center_id   => p_info_center_id,
      p_invoice_date     => p_invoice_date,
      o_line             => o_line,
      o_result           => o_result
    );
  end get_visit_line;

  procedure to_engine_lines (
    p_import_lines           in  t_import_line_tab,
    o_engine_lines           out nocopy bil_invoice_engine.t_line_input_tab
  )
  is
    l_idx     pls_integer;
    l_out_idx pls_integer := 0;
  begin
    o_engine_lines.delete;
    l_idx := p_import_lines.first;
    while l_idx is not null loop
      l_out_idx := l_out_idx + 1;
      o_engine_lines(l_out_idx).serviceid           := p_import_lines(l_idx).serviceid;
      o_engine_lines(l_out_idx).qty                 := p_import_lines(l_idx).qty;
      o_engine_lines(l_out_idx).price_override      := p_import_lines(l_idx).price_override;
      o_engine_lines(l_out_idx).use_price_override  := p_import_lines(l_idx).has_price_override;
      o_engine_lines(l_out_idx).discount_type       := p_import_lines(l_idx).discount_type;
      o_engine_lines(l_out_idx).disc                := p_import_lines(l_idx).disc;
      o_engine_lines(l_out_idx).my_disc             := p_import_lines(l_idx).my_disc;
      o_engine_lines(l_out_idx).teeth_no            := p_import_lines(l_idx).teeth_no;
      o_engine_lines(l_out_idx).tooth_surface       := p_import_lines(l_idx).tooth_surface;
      o_engine_lines(l_out_idx).teeth_no2           := p_import_lines(l_idx).teeth_no2;
      o_engine_lines(l_out_idx).pat_serv_req_row_id := p_import_lines(l_idx).pat_serv_req_row_id;
      o_engine_lines(l_out_idx).approv_date         := p_import_lines(l_idx).approv_date;
      o_engine_lines(l_out_idx).approv_validity     := p_import_lines(l_idx).approv_validity;
      o_engine_lines(l_out_idx).approv_ref_no       := p_import_lines(l_idx).approv_ref_no;
      o_engine_lines(l_out_idx).claim_no            := p_import_lines(l_idx).claim_no;
      o_engine_lines(l_out_idx).req_need_a          := p_import_lines(l_idx).req_need_a;
      o_engine_lines(l_out_idx).req_a_status        := p_import_lines(l_idx).req_a_status;
      o_engine_lines(l_out_idx).package_service_id  := p_import_lines(l_idx).package_service_id;
      o_engine_lines(l_out_idx).package_instance_id := p_import_lines(l_idx).package_instance_id;
      o_engine_lines(l_out_idx).package_line_role   := p_import_lines(l_idx).package_line_role;
      o_engine_lines(l_out_idx).package_component_order := p_import_lines(l_idx).package_component_order;
      o_engine_lines(l_out_idx).package_parent_line_id := p_import_lines(l_idx).package_parent_line_id;
      o_engine_lines(l_out_idx).package_pricing_method := p_import_lines(l_idx).package_pricing_method;
      o_engine_lines(l_out_idx).package_definition_token :=
        p_import_lines(l_idx).package_definition_token;
      l_idx := p_import_lines.next(l_idx);
    end loop;
  end to_engine_lines;

end bil_import;
/
