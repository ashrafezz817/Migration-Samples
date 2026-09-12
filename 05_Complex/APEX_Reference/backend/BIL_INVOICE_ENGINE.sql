create or replace package BIL_INVOICE_ENGINE authid definer as

  type t_header_input is record (
    patientno                t_inv.patientno%type,
    invdate                  t_inv.invdate%type,
    invtypeid                t_inv.invtypeid%type,
    paytype                  t_inv.paytype%type,
    sub_paytype              t_inv.sub_paytype%type,
    sub_paytype2             t_inv.sub_paytype2%type,
    clinicid                 t_inv.clinicid%type,
    docid                    t_inv.docid%type,
    curr_code                t_inv.curr_code%type, -- compatibility input; engine derives invoice currency from price list
    pre_authorization        t_inv.pre_authorization%type,
    claim_no                 t_inv.claim_no%type,
    claim_flag               t_inv.claim_flag%type,
    note_no                  t_inv.note_no%type,
    finaldisc_perc           t_inv.finaldisc_perc%type,
    finaldisc                t_inv.finaldisc%type,
    amount_1                 t_inv.amount_1%type,
    amount_2                 t_inv.amount_2%type,
    add_to_list              t_inv.add_to_list%type,
    user_no                  t_inv.user_no%type,
    machine_n                t_inv.machine_n%type,
    info_center_id           t_inv.info_center_id%type
  );

  type t_line_input is record (
    serviceid                d_inv.serviceid%type,
    qty                      number,
    price_override           d_inv.price%type,
    use_price_override       varchar2(1),
    discount_type            varchar2(1), -- N = none, R = rate, V = value
    disc                     d_inv.disc%type,
    my_disc                  d_inv.my_disc%type,
    teeth_no                 d_inv.teeth_no%type,
    tooth_surface            d_inv.tooth_surface%type,
    teeth_no2                d_inv.teeth_no2%type,
    pat_serv_req_row_id      d_inv.pat_serv_req_row_id%type,
    approv_date              d_inv.approv_date%type,
    approv_validity          d_inv.approv_validity%type,
    approv_ref_no            d_inv.approv_ref_no%type,
    claim_no                 d_inv.claim_no%type,
    req_need_a               d_inv.req_need_a%type,
    req_a_status             d_inv.req_a_status%type,
    package_service_id       d_inv.package_service_id%type,
    package_instance_id      d_inv.package_instance_id%type,
    package_line_role        d_inv.package_line_role%type,
    package_component_order  d_inv.package_component_order%type,
    package_parent_line_id   d_inv.package_parent_line_id%type,
    package_pricing_method   services.package_pricing_method%type,
    package_definition_token varchar2(64),
    offer_id                         d_inv.offer_id%type,
    offer_dtl_id                     d_inv.offer_dtl_id%type,
    offer_type                       d_inv.offer_type%type,
    offer_instance_id                d_inv.offer_instance_id%type,
    offer_line_role                  d_inv.offer_line_role%type,
    offer_parent_line_id             d_inv.offer_parent_line_id%type,
    offer_price_applied              d_inv.offer_price_applied%type,
    offer_dis_applied                d_inv.offer_dis_applied%type,
    offer_name_snapshot              d_inv.offer_name_snapshot%type,
    offer_object_version_number      d_inv.offer_object_version_number%type,
    offer_dtl_object_version_number  d_inv.offer_dtl_object_version_number%type
  );

  type t_line_input_tab is table of t_line_input index by pls_integer;

  type t_invoice_result is record (
    inv_no                   t_inv.inv_no%type,
    invdate                  t_inv.invdate%type,
    patientno                t_inv.patientno%type,
    curr_code                t_inv.curr_code%type,
    line_count               number,
    total_gross              number,
    total_discount           number,
    total_net                number,
    pat_pay                  number,
    comp_pay                 number,
    vat_total_pat            number,
    vat_total_co             number,
    vat_total                number,
    finaldisc                number,
    cash_collected           number,
    shift_system_unique      t_inv.shift_system_unique%type
  );

  -- PAGE48_BATCH_PREVIEW: public read-only calculated line shape for batch preview.
  type t_preview_line is record (
    line_no                  number,
    serviceid                d_inv.serviceid%type,
    servicedesc              d_inv.servicedesc%type,
    catid                    d_inv.catid%type,
    list_id                  d_inv.list_id%type,
    curr_code                d_inv.curr_code%type,
    qty                      d_inv.qty%type,
    price                    d_inv.price%type,
    plan_discount_pct        price_plan_dtl.price_disc%type,
    plan_discount_amount     d_inv.my_disc%type,
    manual_discount_type     varchar2(1),
    manual_discount_pct      d_inv.disc%type,
    manual_discount_amount   d_inv.my_disc%type,
    discount_source          varchar2(20),
    disc                     d_inv.disc%type,
    my_disc                  d_inv.my_disc%type,
    fixpay                   d_inv.fixpay%type,
    payrate                  d_inv.payrate%type,
    the_fix                  d_inv.the_fix%type,
    the_rate                 d_inv.the_rate%type,
    the_pay                  d_inv.the_pay%type,
    the_comp                 d_inv.the_comp%type,
    my_price                 d_inv.my_price%type,
    my_net                   d_inv.my_net%type,
    vat_rate                 d_inv.vat_rate%type,
    vat_val_pat              d_inv.vat_val_pat%type,
    vat_val_co               d_inv.vat_val_co%type,
    vat_val_pat_ex           d_inv.vat_val_pat_ex%type,
    sfda_code                d_inv.sfda_code%type,
    pat_serv_req_row_id      d_inv.pat_serv_req_row_id%type,
    req_need_a               d_inv.req_need_a%type,
    req_a_status             d_inv.req_a_status%type,
    allow_manual_discount    varchar2(1),
    allow_price_override     varchar2(1),
    package_service_id       d_inv.package_service_id%type,
    package_instance_id      d_inv.package_instance_id%type,
    package_line_role        d_inv.package_line_role%type,
    package_component_order  d_inv.package_component_order%type,
    package_parent_line_id   d_inv.package_parent_line_id%type,
    package_pricing_method   services.package_pricing_method%type,
    package_definition_token varchar2(64),
    offer_id                         d_inv.offer_id%type,
    offer_dtl_id                     d_inv.offer_dtl_id%type,
    offer_type                       d_inv.offer_type%type,
    offer_instance_id                d_inv.offer_instance_id%type,
    offer_line_role                  d_inv.offer_line_role%type,
    offer_parent_line_id             d_inv.offer_parent_line_id%type,
    offer_price_applied              d_inv.offer_price_applied%type,
    offer_dis_applied                d_inv.offer_dis_applied%type,
    offer_name_snapshot              d_inv.offer_name_snapshot%type,
    offer_object_version_number      d_inv.offer_object_version_number%type,
    offer_dtl_object_version_number  d_inv.offer_dtl_object_version_number%type
  );

  type t_preview_line_tab is table of t_preview_line index by pls_integer;

  function get_package_definition_token (
    p_package_serviceid in services.serviceid%type,
    p_list_id           in services.list_id%type
  ) return varchar2;

  -- PAGE48_BATCH_PREVIEW: calculate a full invoice preview without creating rows.
  procedure preview_invoice (
    p_header   in  t_header_input,
    p_lines    in  t_line_input_tab,
    o_lines    out nocopy t_preview_line_tab,
    o_result   out nocopy t_invoice_result
  );

  procedure create_invoice (
    p_header   in  t_header_input,
    p_lines    in  t_line_input_tab,
    o_result   out nocopy t_invoice_result
  );

end bil_invoice_engine;
/

create or replace PACKAGE BODY           "BIL_INVOICE_ENGINE" as

  ------------------------------------------------------------------------------
  -- Constants
  ------------------------------------------------------------------------------
  c_yes constant varchar2(1) := 'Y';
  c_no  constant varchar2(1) := 'N';
  c_paytype_cash    constant number := 1;
  c_paytype_credit  constant number := 2;
  c_default_invtype constant number := 1;
  c_request_unavailable_error constant number := -20931;
  c_pkg_role_parent    constant varchar2(20) := 'PARENT';
  c_pkg_role_component constant varchar2(20) := 'COMPONENT';
  c_pkg_fixed_price    constant varchar2(20) := 'FIXED_PRICE';
  c_pkg_component_price constant varchar2(20) := 'COMPONENT_PRICE';
  c_pkg_free           constant varchar2(20) := 'FREE';
  c_max_invoice_qty    constant number := 999999.99;

  ------------------------------------------------------------------------------
  -- Internal calculation record
  ------------------------------------------------------------------------------

  type t_calc_line is record (
    d_inv_row_id       d_inv.d_inv_row_id%type,
    serviceid          d_inv.serviceid%type,
    servicedesc        d_inv.servicedesc%type,
    catid              d_inv.catid%type,
    list_id            d_inv.list_id%type,
    curr_code          d_inv.curr_code%type,
    qty                d_inv.qty%type,
    price              d_inv.price%type,
    plan_discount_pct      price_plan_dtl.price_disc%type,
    plan_discount_amount   d_inv.my_disc%type,
    manual_discount_type   varchar2(1),
    manual_discount_pct    d_inv.disc%type,
    manual_discount_amount d_inv.my_disc%type,
    discount_source        varchar2(20),
    disc               d_inv.disc%type,
    my_disc            d_inv.my_disc%type,
    fixpay             d_inv.fixpay%type,
    payrate            d_inv.payrate%type,
    the_fix            d_inv.the_fix%type,
    the_rate           d_inv.the_rate%type,
    the_pay            d_inv.the_pay%type,
    the_comp           d_inv.the_comp%type,
    my_price           d_inv.my_price%type,
    my_net             d_inv.my_net%type,
    vat_rate           d_inv.vat_rate%type,
    vat_val_pat        d_inv.vat_val_pat%type,
    vat_val_co         d_inv.vat_val_co%type,
    vat_val_pat_ex     d_inv.vat_val_pat_ex%type,
    sfda_code          d_inv.sfda_code%type,
    teeth_no           d_inv.teeth_no%type,
    tooth_surface      d_inv.tooth_surface%type,
    teeth_no2          d_inv.teeth_no2%type,
    pat_serv_req_row_id d_inv.pat_serv_req_row_id%type,
    approv_date         d_inv.approv_date%type,
    approv_validity     d_inv.approv_validity%type,
    approv_ref_no       d_inv.approv_ref_no%type,
    claim_no            d_inv.claim_no%type,
    req_need_a          d_inv.req_need_a%type,
    req_a_status        d_inv.req_a_status%type,
    is_deleted          d_inv.is_deleted%type,
    info_center_id      d_inv.info_center_id%type,
    package_service_id       d_inv.package_service_id%type,
    package_instance_id      d_inv.package_instance_id%type,
    package_line_role        d_inv.package_line_role%type,
    package_component_order  d_inv.package_component_order%type,
    package_parent_line_id   d_inv.package_parent_line_id%type,
    package_pricing_method   services.package_pricing_method%type,
    package_definition_token varchar2(64),
    offer_id                         d_inv.offer_id%type,
    offer_dtl_id                     d_inv.offer_dtl_id%type,
    offer_type                       d_inv.offer_type%type,
    offer_instance_id                d_inv.offer_instance_id%type,
    offer_line_role                  d_inv.offer_line_role%type,
    offer_parent_line_id             d_inv.offer_parent_line_id%type,
    offer_price_applied              d_inv.offer_price_applied%type,
    offer_dis_applied                d_inv.offer_dis_applied%type,
    offer_name_snapshot              d_inv.offer_name_snapshot%type,
    offer_object_version_number      d_inv.offer_object_version_number%type,
    offer_dtl_object_version_number  d_inv.offer_dtl_object_version_number%type,
    allow_manual_discount    varchar2(1),
    allow_price_override     varchar2(1),
    package_parent_line_idx  pls_integer,
    offer_parent_line_idx    pls_integer
  );

  type t_calc_line_tab is table of t_calc_line index by pls_integer;

  type t_package_component is record (
    serviceid        package_dtl.sub_serviceid%type,
    qty              package_dtl.qty%type,
    component_order  number
  );

  type t_package_component_tab is table of t_package_component index by pls_integer;

  type t_req_row_id_tab is table of pat_serv_req.pat_serv_req_row_id%type
    index by pls_integer;

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

  function get_package_definition_token (
    p_package_serviceid in services.serviceid%type,
    p_list_id           in services.list_id%type
  ) return varchar2
  is
    l_method          services.package_pricing_method%type;
    l_payload         varchar2(32767);
    l_token           varchar2(64);
    l_component_count pls_integer := 0;
  begin
    select upper(trim(s.package_pricing_method))
      into l_method
      from services s
     where s.serviceid = p_package_serviceid
       and s.list_id = p_list_id
       and s.is_package = 1;

    l_payload := p_package_serviceid || '|' || p_list_id || '|' || l_method;
    for r in (
      select d.sub_serviceid,
             d.qty,
             d.object_version_number
        from package_dtl d
       where d.serviceid = p_package_serviceid
         and d.list_id = p_list_id
       order by d.sub_serviceid
    ) loop
      l_component_count := l_component_count + 1;
      if length(l_payload) + length(r.sub_serviceid) + 80 > 32767 then
        raise_application_error(
          -20945,
          'Invoice create failed: package definition is too large to validate.'
        );
      end if;
      l_payload := l_payload
        || '|'
        || length(r.sub_serviceid)
        || ':'
        || r.sub_serviceid
        || ':'
        || to_char(r.qty, 'TM9')
        || ':'
        || to_char(r.object_version_number, 'TM9');
    end loop;

    if l_component_count = 0 then
      raise_application_error(
        -20944,
        'Invoice create failed: package '
        || p_package_serviceid
        || ' has no configured components.'
      );
    end if;

    select lower(rawtohex(standard_hash(l_payload, 'SHA256')))
      into l_token
      from dual;
    return l_token;
  exception
    when no_data_found then
      raise_application_error(
        -20946,
        'Invoice create failed: package '
        || p_package_serviceid
        || ' is not active in list '
        || p_list_id
        || '.'
      );
  end get_package_definition_token;

  function round_money (
    p_value in number
  ) return number
  is
  begin
    return round(nvl(p_value, 0), 2);
  end round_money;

  function safe_to_number (
    p_value in varchar2
  ) return number
  is
  begin
    return to_number(trim(p_value));
  exception
    when others then
      return null;
  end safe_to_number;

  function get_apex_session_state (
    p_item_name in varchar2
  ) return varchar2
  is
    l_value varchar2(32767);
  begin
    execute immediate
      'begin :x := apex_util.get_session_state(:p); end;'
      using out l_value, in p_item_name;
    return trim_to_null(l_value);
  exception
    when others then
      return null;
  end get_apex_session_state;

  function get_effective_user_no (
    p_user_no in t_inv.user_no%type
  ) return t_inv.user_no%type
  is
    l_user_id fnd_users.user_id%type;
  begin
    if p_user_no is not null then
      return p_user_no;
    end if;
    l_user_id := fnd_app_security.get_current_user_id;
    if nvl(l_user_id, 0) > 0 then
      return l_user_id;
    end if;
    return safe_to_number(get_apex_session_state('G_USER_ID'));
  end get_effective_user_no;

  function get_effective_info_center_id (
    p_info_center_id in t_inv.info_center_id%type
  ) return t_inv.info_center_id%type
  is
    l_value varchar2(100);
  begin
    if p_info_center_id is not null then
      return p_info_center_id;
    end if;
    l_value := get_apex_session_state('G_CURRENT_INFO_CENTER_ID');
    if l_value is not null then
      return safe_to_number(l_value);
    end if;
    l_value := get_apex_session_state('G_INFO_CENTER_ID');
    if l_value is not null then
      return safe_to_number(l_value);
    end if;
    l_value := get_apex_session_state('CURRENT_INFO_CENTER_ID');
    if l_value is not null then
      return safe_to_number(l_value);
    end if;
    return null;
  end get_effective_info_center_id;

  function get_effective_machine_n (
    p_machine_n in t_inv.machine_n%type
  ) return t_inv.machine_n%type
  is
    l_value varchar2(255);
  begin
    if trim_to_null(p_machine_n) is not null then
      return substr(trim_to_null(p_machine_n), 1, 15);
    end if;
    l_value := get_apex_session_state('G_MACHINE_N');
    if l_value is not null then
      return substr(l_value, 1, 15);
    end if;
    l_value := trim_to_null(sys_context('USERENV', 'HOST'));
    if l_value is not null then
      return substr(l_value, 1, 15);
    end if;
    return substr(trim_to_null(sys_context('USERENV', 'TERMINAL')), 1, 15);
  end get_effective_machine_n;

  function get_pflag (
    p_invoice_datetime in t_inv.invdate%type
  )
  return t_inv.pflag%type
  is
    l_hour number;
  begin
    l_hour := to_number(to_char(p_invoice_datetime, 'HH24'));
    if l_hour >= 12 then
      return 'PM';
    end if;
    return 'AM';
  end get_pflag;

  function get_inv_time (
    p_invoice_datetime in t_inv.invdate%type
  )
  return varchar2
  is
  begin
    return to_char(p_invoice_datetime, 'HH24:MI:SS');
  end get_inv_time;

  function get_default_paytype (
    p_header          in t_header_input,
    p_patient_context in bil_types.t_patient_context
  ) return t_inv.paytype%type
  is
  begin
    if p_header.paytype is not null then
      return p_header.paytype;
    end if;
    if p_patient_context.is_cash = c_yes then
      return c_paytype_cash;
    end if;
    return c_paytype_credit;
  end get_default_paytype;

  procedure assert_header_valid (
    p_header in t_header_input
  )
  is
    l_exists number;
  begin
    if trim_to_null(p_header.patientno) is null then
      raise_application_error(
        -20900,
        'Invoice create failed: patient number is required.'
      );
    end if;
    if p_header.finaldisc_perc is not null
       and (p_header.finaldisc_perc < 0 or p_header.finaldisc_perc > 100) then
      raise_application_error(
        -20901,
        'Invoice create failed: final discount percent must be between 0 and 100.'
      );
    end if;
    if nvl(p_header.finaldisc, 0) < 0 then
      raise_application_error(
        -20902,
        'Invoice create failed: final discount amount cannot be negative.'
      );
    end if;
    if p_header.docid is not null then
      if p_header.clinicid is null then
        raise_application_error(
          -20923,
          'Invoice create failed: clinic is required when doctor is supplied.'
        );
      end if;

      select count(*)
        into l_exists
        from doctors
       where docid = p_header.docid
         and clinicid = p_header.clinicid
         and nvl(doc_active, 1) <> 0;

      if l_exists = 0 then
        raise_application_error(
          -20924,
          'Invoice create failed: selected doctor does not belong to the selected clinic.'
        );
      end if;
    end if;
  end assert_header_valid;

  procedure assert_lines_valid (
    p_lines in t_line_input_tab
  )
  is
    l_idx           pls_integer;
    l_discount_type varchar2(1);
  begin
    if p_lines.count = 0 then
      raise_application_error(
        -20903,
        'Invoice create failed: at least one service line is required.'
      );
    end if;
    l_idx := p_lines.first;
    while l_idx is not null loop
      if trim_to_null(p_lines(l_idx).serviceid) is null
         and not (p_lines(l_idx).offer_type = 0
                  and upper_trim_to_null(p_lines(l_idx).offer_line_role) = 'PARENT') then
        raise_application_error(
          -20904,
          'Invoice create failed: service ID is required on line ' || l_idx || '.'
        );
      end if;
      if p_lines(l_idx).qty is null
         or p_lines(l_idx).qty <= 0
         or p_lines(l_idx).qty <> trunc(p_lines(l_idx).qty)
      then
        raise_application_error(
          -20905,
          'Invoice create failed: quantity must be a positive whole number on line ' || l_idx || '.'
        );
      end if;
      if nvl(p_lines(l_idx).disc, 0) < 0 then
        raise_application_error(
          -20906,
          'Invoice create failed: discount percent cannot be negative on line ' || l_idx || '.'
        );
      end if;
      if nvl(p_lines(l_idx).my_disc, 0) < 0 then
        raise_application_error(
          -20907,
          'Invoice create failed: discount amount cannot be negative on line ' || l_idx || '.'
        );
      end if;
      l_discount_type := nvl(upper_trim_to_null(p_lines(l_idx).discount_type), 'R');
      if l_discount_type not in ('N', 'R', 'V') then
        raise_application_error(
          -20908,
          'Invoice create failed: discount type must be N, R or V on line ' || l_idx || '.'
        );
      end if;
      if l_discount_type = 'N'
         and (nvl(p_lines(l_idx).disc, 0) <> 0 or nvl(p_lines(l_idx).my_disc, 0) <> 0) then
        raise_application_error(
          -20919,
          'Invoice create failed: no discount line must have zero discount percent and amount on line ' || l_idx || '.'
        );
      end if;
      if l_discount_type = 'R' and nvl(p_lines(l_idx).my_disc, 0) <> 0 then
        raise_application_error(
          -20920,
          'Invoice create failed: percent discount line cannot have discount amount on line ' || l_idx || '.'
        );
      end if;
      if l_discount_type = 'V' and nvl(p_lines(l_idx).disc, 0) <> 0 then
        raise_application_error(
          -20921,
          'Invoice create failed: amount discount line cannot have discount percent on line ' || l_idx || '.'
        );
      end if;
      l_idx := p_lines.next(l_idx);
    end loop;
  end assert_lines_valid;

  procedure raise_request_unavailable
  is
  begin
    raise_application_error(
      c_request_unavailable_error,
      'One or more requested services were already invoiced or are no longer available.'
    );
  end raise_request_unavailable;

  procedure add_request_row_id (
    io_row_ids in out nocopy t_req_row_id_tab,
    p_row_id   in pat_serv_req.pat_serv_req_row_id%type
  )
  is
    l_idx pls_integer;
  begin
    if p_row_id is null then
      return;
    end if;

    l_idx := io_row_ids.first;
    while l_idx is not null loop
      if io_row_ids(l_idx) = p_row_id then
        raise_request_unavailable;
      end if;
      l_idx := io_row_ids.next(l_idx);
    end loop;

    io_row_ids(io_row_ids.count + 1) := p_row_id;
  end add_request_row_id;

  procedure sort_request_row_ids (
    io_row_ids in out nocopy t_req_row_id_tab
  )
  is
    l_i    pls_integer;
    l_j    pls_integer;
    l_temp pat_serv_req.pat_serv_req_row_id%type;
  begin
    if io_row_ids.count < 2 then
      return;
    end if;

    l_i := io_row_ids.first;
    while l_i is not null loop
      l_j := io_row_ids.next(l_i);
      while l_j is not null loop
        if io_row_ids(l_j) < io_row_ids(l_i) then
          l_temp := io_row_ids(l_i);
          io_row_ids(l_i) := io_row_ids(l_j);
          io_row_ids(l_j) := l_temp;
        end if;
        l_j := io_row_ids.next(l_j);
      end loop;
      l_i := io_row_ids.next(l_i);
    end loop;
  end sort_request_row_ids;

  procedure refresh_request_line_from_source (
    io_line          in out nocopy t_line_input,
    p_line_no        in pls_integer,
    p_patientno      in t_inv.patientno%type,
    p_paytype        in t_inv.paytype%type,
    p_invdate        in t_inv.invdate%type,
    p_patient_context in bil_types.t_patient_context,
    p_cash_comp_code in companys.comp_code%type
  )
  is
    l_patientno       v_services_req.patientno%type;
    l_visit_unique    v_services_req.visit_unique%type;
    l_paytype         number;
    l_serviceid       v_services_req.serviceid%type;
    l_qty             v_services_req.qty%type;
    l_request_price   v_services_req.price%type;
    l_price_disc      v_services_req.price_disc%type;
    l_req_need_a      number;
    l_req_a_status    number;
    l_approv_ref_no   v_services_req.approv_ref_no%type;
    l_approv_date     v_services_req.approv_date%type;
    l_approv_validity v_services_req.approv_validity%type;
    l_claim_no        v_services_req.claim_no%type;
    l_teeth_no        v_services_req.teeth_no%type;
    l_teeth_no2       v_services_req.teeth_no2%type;
    l_tooth_surface   v_services_req.tooth_surface%type;
    l_d_inv_row_id    v_services_req.d_inv_row_id%type;
    l_service_context bil_types.t_service_context;
  begin
    begin
      select r.patientno,
             r.visit_unique,
             case upper(trim(r.pay_type))
               when 'CASH' then c_paytype_cash
               when 'CREDIT' then c_paytype_credit
             end,
             r.serviceid,
             r.qty,
             r.price,
             nvl(r.price_disc, 0),
             nvl(r.req_need_a, 0),
             nvl(r.req_a_status, 0),
             r.approv_ref_no,
             r.approv_date,
             r.approv_validity,
             r.claim_no,
             r.teeth_no,
             r.teeth_no2,
             r.tooth_surface,
             r.d_inv_row_id
        into l_patientno,
             l_visit_unique,
             l_paytype,
             l_serviceid,
             l_qty,
             l_request_price,
             l_price_disc,
             l_req_need_a,
             l_req_a_status,
             l_approv_ref_no,
             l_approv_date,
             l_approv_validity,
             l_claim_no,
             l_teeth_no,
             l_teeth_no2,
             l_tooth_surface,
             l_d_inv_row_id
        from v_services_req r
       where r.pat_serv_req_row_id = io_line.pat_serv_req_row_id;
    exception
      when no_data_found or too_many_rows then
        raise_request_unavailable;
    end;

    if l_patientno <> p_patientno
       or l_paytype <> p_paytype
       or l_d_inv_row_id is not null
       or trim_to_null(l_serviceid) is null
       or nvl(l_qty, 0) <= 0
       or l_req_a_status = 3
       or l_req_need_a = 2
    then
      raise_request_unavailable;
    end if;

    if p_paytype = c_paytype_credit
       and l_req_need_a <> 0
    then
      if l_approv_ref_no is null then
        raise_request_unavailable;
      end if;

      if l_approv_date is not null
         and l_approv_validity is not null
         and trunc(l_approv_date) + l_approv_validity < trunc(p_invdate)
      then
        raise_request_unavailable;
      end if;
    end if;

    io_line.serviceid           := l_serviceid;
    io_line.qty                 := l_qty;
    bil_service_context.get_context(
      p_patient_context => p_patient_context,
      p_serviceid       => l_serviceid,
      p_qty             => l_qty,
      p_invoice_date    => p_invdate,
      o_context         => l_service_context
    );
    bil_import.resolve_request_price_override(
      p_patient_context    => p_patient_context,
      p_service_context    => l_service_context,
      p_qty                => l_qty,
      p_request_price      => l_request_price,
      p_invoice_date       => p_invdate,
      p_cash_comp_code     => p_cash_comp_code,
      o_price_override     => io_line.price_override,
      o_has_price_override => io_line.use_price_override
    );
    -- Request PRICE_DISC is a request-time plan snapshot. Resolve the current
    -- plan discount from PRICE_PLAN_DTL instead of resubmitting it as manual.
    io_line.discount_type       := 'N';
    io_line.disc                := 0;
    io_line.my_disc             := null;
    io_line.teeth_no            := l_teeth_no;
    io_line.tooth_surface       := l_tooth_surface;
    io_line.teeth_no2           := nvl(l_teeth_no2, l_teeth_no);
    io_line.approv_date         := l_approv_date;
    io_line.approv_validity     := l_approv_validity;
    io_line.approv_ref_no       := l_approv_ref_no;
    io_line.claim_no            := l_claim_no;
    io_line.req_need_a          := l_req_need_a;
    io_line.req_a_status        := l_req_a_status;
    if nvl(l_service_context.is_package, 0) = 1 then
      io_line.price_override          := null;
      io_line.use_price_override      := c_no;
      io_line.package_service_id      := l_serviceid;
      io_line.package_instance_id     :=
        bil_import.get_request_package_instance_id(io_line.pat_serv_req_row_id);
      io_line.package_line_role       := c_pkg_role_parent;
      io_line.package_component_order := 0;
      io_line.package_parent_line_id  := null;
      io_line.package_pricing_method  :=
        upper_trim_to_null(l_service_context.package_pricing_method);
      io_line.package_definition_token :=
        get_package_definition_token(l_serviceid, p_patient_context.list_id);
    else
      io_line.package_service_id      := null;
      io_line.package_instance_id     := null;
      io_line.package_line_role       := null;
      io_line.package_component_order := null;
      io_line.package_parent_line_id  := null;
      io_line.package_pricing_method  := null;
      io_line.package_definition_token := null;
    end if;
  exception
    when others then
      if sqlcode = c_request_unavailable_error then
        raise;
      end if;
      raise;
  end refresh_request_line_from_source;

  procedure lock_and_refresh_request_sources (
    p_header          in            t_header_input,
    p_paytype         in            t_inv.paytype%type,
    p_patient_context in            bil_types.t_patient_context,
    io_lines          in out nocopy t_line_input_tab,
    p_lock_rows       in            boolean default true
  )
  is
    type t_instance_set is table of pls_integer
      index by varchar2(64);

    l_row_ids       t_req_row_id_tab;
    l_request_instances t_instance_set;
    l_rebuilt_lines t_line_input_tab;
    l_idx           pls_integer;
    l_line_idx      pls_integer;
    l_out_idx       pls_integer := 0;
    l_locked_row_id pat_serv_req.pat_serv_req_row_id%type;
    l_cash_comp_code companys.comp_code%type;
    l_component      t_line_input;
    l_component_order number;
    l_component_count number;
    l_component_qty   number;

    procedure append_rebuilt_line (
      p_line in t_line_input
    )
    is
    begin
      l_out_idx := l_out_idx + 1;
      l_rebuilt_lines(l_out_idx) := p_line;
    end append_rebuilt_line;
  begin
    l_line_idx := io_lines.first;
    while l_line_idx is not null loop
      add_request_row_id(l_row_ids, io_lines(l_line_idx).pat_serv_req_row_id);
      if io_lines(l_line_idx).pat_serv_req_row_id is not null
         and trim_to_null(io_lines(l_line_idx).package_instance_id) is not null
      then
        l_request_instances(io_lines(l_line_idx).package_instance_id) := 1;
      end if;
      l_line_idx := io_lines.next(l_line_idx);
    end loop;

    if l_row_ids.count = 0 then
      return;
    end if;

    l_cash_comp_code := ins_comp_util.get_cash_comp_code;
    if l_cash_comp_code is null then
      raise_application_error(
        -20965,
        'Invoice create failed: configured cash company could not be resolved.'
      );
    end if;

    sort_request_row_ids(l_row_ids);

    l_idx := l_row_ids.first;
    while l_idx is not null loop
      begin
        if p_lock_rows then
          select p.pat_serv_req_row_id
            into l_locked_row_id
            from pat_serv_req p
           where p.pat_serv_req_row_id = l_row_ids(l_idx)
           for update;
        else
          select p.pat_serv_req_row_id
            into l_locked_row_id
            from pat_serv_req p
           where p.pat_serv_req_row_id = l_row_ids(l_idx);
        end if;
      exception
        when no_data_found then
          raise_request_unavailable;
      end;

      l_line_idx := io_lines.first;
      while l_line_idx is not null loop
        if io_lines(l_line_idx).pat_serv_req_row_id = l_locked_row_id then
          refresh_request_line_from_source(
            io_line     => io_lines(l_line_idx),
            p_line_no   => l_line_idx,
            p_patientno => p_header.patientno,
            p_paytype   => p_paytype,
            p_invdate   => p_header.invdate,
            p_patient_context => p_patient_context,
            p_cash_comp_code  => l_cash_comp_code
          );
        end if;
        l_line_idx := io_lines.next(l_line_idx);
      end loop;

      l_idx := l_row_ids.next(l_idx);
    end loop;

    /*
      Rebuild every physical request package after the request rows are locked.
      The incoming component rows are discarded for those instances; package
      definition, quantities, pricing method and request ownership all come
      from current authoritative database state.
    */
    l_line_idx := io_lines.first;
    while l_line_idx is not null loop
      if io_lines(l_line_idx).pat_serv_req_row_id is not null then
        append_rebuilt_line(io_lines(l_line_idx));

        if upper_trim_to_null(io_lines(l_line_idx).package_line_role) = c_pkg_role_parent
           and io_lines(l_line_idx).package_service_id = io_lines(l_line_idx).serviceid
        then
          l_request_instances(io_lines(l_line_idx).package_instance_id) := 1;
          l_component_order := 0;
          l_component_count := 0;

          for r in (
            select d.sub_serviceid,
                   d.qty
              from package_dtl d
             where d.serviceid = io_lines(l_line_idx).serviceid
               and d.list_id = p_patient_context.list_id
             order by d.sub_serviceid
          ) loop
            if trim_to_null(r.sub_serviceid) is null
               or r.qty is null
               or r.qty <= 0
               or r.qty <> trunc(r.qty)
            then
              raise_application_error(
                -20967,
                'Invoice create failed: package definition contains an invalid component.'
              );
            end if;

            l_component_qty := io_lines(l_line_idx).qty * r.qty;
            if l_component_qty <= 0
               or l_component_qty <> trunc(l_component_qty)
               or l_component_qty > trunc(c_max_invoice_qty)
            then
              raise_application_error(
                -20966,
                'Invoice create failed: multiplied package component quantity must be a positive whole number within the invoice quantity limit.'
              );
            end if;

            l_component := null;
            l_component_order := l_component_order + 1;
            l_component_count := l_component_count + 1;
            l_component.serviceid               := r.sub_serviceid;
            l_component.qty                     := l_component_qty;
            l_component.discount_type           := 'N';
            l_component.disc                    := 0;
            l_component.my_disc                 := null;
            l_component.price_override          := null;
            l_component.use_price_override      := c_no;
            l_component.pat_serv_req_row_id     := null;
            l_component.package_service_id      := io_lines(l_line_idx).serviceid;
            l_component.package_instance_id     := io_lines(l_line_idx).package_instance_id;
            l_component.package_line_role       := c_pkg_role_component;
            l_component.package_component_order := l_component_order;
            l_component.package_parent_line_id  := null;
            l_component.package_pricing_method  :=
              io_lines(l_line_idx).package_pricing_method;
            l_component.package_definition_token :=
              io_lines(l_line_idx).package_definition_token;
            append_rebuilt_line(l_component);
          end loop;

          if l_component_count = 0 then
            raise_application_error(
              -20968,
              'Invoice create failed: requested package has no components.'
            );
          end if;
        end if;
      elsif trim_to_null(io_lines(l_line_idx).package_instance_id) is not null
            and l_request_instances.exists(io_lines(l_line_idx).package_instance_id)
      then
        null;
      else
        append_rebuilt_line(io_lines(l_line_idx));
      end if;

      l_line_idx := io_lines.next(l_line_idx);
    end loop;

    io_lines := l_rebuilt_lines;
  end lock_and_refresh_request_sources;

  function yn_flag (
    p_value in varchar2
  ) return varchar2
  is
    l_value varchar2(100);
  begin
    l_value := upper(trim(p_value));
    if l_value in ('Y', 'YES', '1', 'TRUE') then
      return 'Y';
    end if;
    return 'N';
  end yn_flag;

  function line_uses_price_override (
    p_line in t_line_input
  ) return boolean
  is
  begin
    if yn_flag(p_line.use_price_override) = 'Y' then
      return true;
    end if;
    if p_line.price_override is not null then
      return true;
    end if;
    return false;
  end line_uses_price_override;

  function get_effective_line_price (
    p_normal_price in number,
    p_line         in t_line_input,
    p_line_no      in number
  ) return number
  is
    l_price number;
  begin
    if not line_uses_price_override(p_line) then
      return p_normal_price;
    end if;
    if p_line.price_override is null then
      raise_application_error(
        -20780,
        'Invoice line ' || p_line_no ||
        ' uses price override but PRICE_OVERRIDE is null.'
      );
    end if;
    if p_line.price_override < 0 then
      raise_application_error(
        -20781,
        'Invoice line ' || p_line_no ||
        ' price override cannot be negative.'
      );
    end if;
    l_price := round(p_line.price_override, 3);
    return l_price;
  end get_effective_line_price;

  function get_next_invoice_no_safe
  return t_inv.inv_no%type
  is
    l_inv_no t_inv.inv_no%type;
    l_count  number;
  begin
    for i in 1 .. 20 loop
      l_inv_no := get_next_invoice_no();
      select count(*)
        into l_count
        from t_inv
       where inv_no = l_inv_no;
      if nvl(l_count, 0) = 0 then
        return l_inv_no;
      end if;
    end loop;
    raise_application_error(
      -20909,
      'Invoice create failed: could not generate a unique invoice number after 20 attempts.'
    );
  end get_next_invoice_no_safe;

  function get_old_or_new (
    p_patientno in t_inv.patientno%type
  ) return t_inv.old_or_new%type
  is
    l_count number;
  begin
    select count(*)
      into l_count
      from t_inv
     where patientno = p_patientno;
    if nvl(l_count, 0) = 0 then
      return 'N';
    end if;
    return 'O';
  end get_old_or_new;

  function calc_discount_amount (
    p_discount_type in varchar2,
    p_disc          in number,
    p_my_disc       in number,
    p_gross_amount  in number
  ) return number
  is
    l_type varchar2(1);
    l_disc number;
  begin
    l_type := nvl(upper_trim_to_null(p_discount_type), 'R');
    if l_type = 'N' then
      return 0;
    end if;
    if l_type = 'R' then
      if nvl(p_disc, 0) > 100 then
        raise_application_error(
          -20910,
          'Invoice create failed: line discount percent cannot exceed 100.'
        );
      end if;
      return round_money(p_gross_amount * nvl(p_disc, 0) / 100);
    end if;
    l_disc := round_money(nvl(p_my_disc, 0));
    if l_disc > p_gross_amount then
      raise_application_error(
        -20911,
        'Invoice create failed: line discount amount cannot exceed line gross amount.'
      );
    end if;
    return l_disc;
  end calc_discount_amount;

  function calc_discount_percent (
    p_discount_type  in varchar2,
    p_disc           in number,
    p_discount_amt   in number,
    p_gross_amount   in number
  ) return number
  is
    l_type varchar2(1);
  begin
    l_type := nvl(upper_trim_to_null(p_discount_type), 'R');
    if l_type = 'N' then
      return 0;
    end if;
    if l_type = 'R' then
      return nvl(p_disc, 0);
    end if;
    if nvl(p_gross_amount, 0) = 0 then
      return 0;
    end if;
    return round((100 * nvl(p_discount_amt, 0)) / p_gross_amount, 2);
  end calc_discount_percent;

  procedure calc_vat_for_line (
    p_patient_context in  bil_types.t_patient_context,
    p_service_context in  bil_types.t_service_context,
    p_patient_share   in  number,
    p_company_share   in  number,
    o_vat_rate        out number,
    o_vat_val_pat     out number,
    o_vat_val_co      out number,
    o_vat_val_pat_ex  out number
  )
  is
    l_rate        number;
    l_non_medical number;
  begin
    l_rate        := nvl(p_service_context.vat_rate, 0);
    l_non_medical := nvl(p_service_context.non_medical, 0);
    if l_rate < 0 or l_rate > 100 then
      raise_application_error(
        -20912,
        'Invoice create failed: VAT rate must be between 0 and 100 for service '
        || p_service_context.serviceid
      );
    end if;
    o_vat_rate       := l_rate;
    o_vat_val_pat    := 0;
    o_vat_val_co     := 0;
    o_vat_val_pat_ex := 0;
    if l_rate = 0 then
      return;
    end if;
    /*
      Real Forms-compatible VAT rule:
        Patient VAT:
          NATIONALITY.PAY_VAT = N -> no VAT unless NON_MEDICAL = 1.
          If exempt and medical, store exempt VAT in VAT_VAL_PAT_EX.
        Company VAT:
          COMPANYS.PAY_VAT = 0 -> no VAT unless NON_MEDICAL = 1.
    */
    if nvl(p_patient_context.pay_vat, 1) = 0 then
      if l_non_medical = 1 then
        o_vat_val_pat := round_money(nvl(p_patient_share, 0) * l_rate / 100);
      else
        o_vat_val_pat_ex := round_money(nvl(p_patient_share, 0) * l_rate / 100);
        o_vat_val_pat    := 0;
      end if;
    else
      o_vat_val_pat := round_money(nvl(p_patient_share, 0) * l_rate / 100);
    end if;
    if nvl(p_patient_context.pay_vat_co, 1) = 0 then
      if l_non_medical = 1 then
        o_vat_val_co := round_money(nvl(p_company_share, 0) * l_rate / 100);
      else
        o_vat_val_co := 0;
      end if;
    else
      o_vat_val_co := round_money(nvl(p_company_share, 0) * l_rate / 100);
    end if;
  end calc_vat_for_line;

  function calc_final_discount (
    p_total_patient_share in number,
    p_total_net           in number,
    p_header              in t_header_input
  ) return number
  is
    l_finaldisc number;
  begin
    if p_header.finaldisc is not null then
      l_finaldisc := round_money(p_header.finaldisc);
    elsif p_header.finaldisc_perc is not null then
      l_finaldisc := round_money(nvl(p_total_net, 0) * p_header.finaldisc_perc / 100);
    else
      l_finaldisc := 0;
    end if;
    if l_finaldisc < 0 then
      raise_application_error(
        -20913,
        'Invoice create failed: final discount cannot be negative.'
      );
    end if;
    if l_finaldisc > nvl(p_total_patient_share, 0) then
      raise_application_error(
        -20914,
        'Invoice create failed: final discount cannot exceed patient share.'
      );
    end if;
    return l_finaldisc;
  end calc_final_discount;

  procedure calculate_lines (
    p_header          in  t_header_input,
    p_patient_context in  bil_types.t_patient_context,
    p_paytype         in  t_inv.paytype%type,
    p_info_center_id  in  t_inv.info_center_id%type,
    p_lines           in  t_line_input_tab,
    p_validate_offer_versions in boolean,
    o_calc_lines      out nocopy t_calc_line_tab,
    io_result         in out nocopy t_invoice_result
  )
  is
    l_idx                  pls_integer;
    l_out_idx              pls_integer := 0;
    l_service_context      bil_types.t_service_context;
    l_price_result         bil_types.t_price_result;
    l_class_result         bil_class_rule.t_class_result;
    l_curr_code            t_inv.curr_code%type;
    l_qty                  number;
    l_effective_price      number;
    l_gross                number;
    l_plan_disc_pct        number;
    l_plan_disc_amt        number;
    l_manual_disc_type     varchar2(1);
    l_manual_disc_pct      number;
    l_manual_disc_amt      number;
    l_discount_source      varchar2(20);
    l_disc_amt             number;
    l_disc_pct             number;
    l_net                  number;
    l_vat_rate             number;
    l_vat_pat              number;
    l_vat_co               number;
    l_vat_pat_ex           number;
    type t_offer_instance_set is table of pls_integer index by varchar2(64);
    l_offer_instances      t_offer_instance_set;
    type t_package_instance_set is table of pls_integer index by varchar2(64);
    l_package_instances    t_package_instance_set;
    type t_package_qty_map is table of number index by pls_integer;
    l_package_qty          t_package_qty_map;
    type t_package_token_map is table of varchar2(64) index by varchar2(64);
    l_package_tokens       t_package_token_map;

    procedure raise_package_stale is
    begin
      raise_application_error(
        -20969,
        'The package definition changed after the invoice was calculated. ' ||
        'Refresh the invoice and review the package lines.'
      );
    end raise_package_stale;

    procedure raise_offer_stale is
    begin
      raise_application_error(
        -20970,
        'The offer changed after the invoice was calculated. ' ||
        'Refresh the invoice and review the updated pricing.'
      );
    end raise_offer_stale;

    function same_number(p_left number, p_right number) return boolean is
    begin
      if p_left is null and p_right is null then
        return true;
      elsif p_left is null or p_right is null then
        return false;
      end if;
      return p_left = p_right;
    end same_number;

    function same_text(p_left varchar2, p_right varchar2) return boolean is
    begin
      if p_left is null and p_right is null then
        return true;
      elsif p_left is null or p_right is null then
        return false;
      end if;
      return p_left = p_right;
    end same_text;

    procedure assert_expected_no_offer(p_line in t_line_input) is
    begin
      if p_validate_offer_versions
         and (p_line.offer_id is not null
              or p_line.offer_dtl_id is not null
              or p_line.offer_type is not null
              or p_line.offer_instance_id is not null
              or p_line.offer_line_role is not null
              or p_line.offer_parent_line_id is not null
              or p_line.offer_price_applied is not null
              or p_line.offer_dis_applied is not null
              or p_line.offer_name_snapshot is not null
              or p_line.offer_object_version_number is not null
              or p_line.offer_dtl_object_version_number is not null)
      then
        raise_offer_stale;
      end if;
    end assert_expected_no_offer;

    procedure assert_standard_evidence(
      p_line  in t_line_input,
      p_offer in bil_offer_rule.t_standard_offer
    ) is
    begin
      if not p_validate_offer_versions then
        return;
      end if;

      if p_offer.matched = 'N' then
        assert_expected_no_offer(p_line);
      elsif p_line.offer_type <> 1
         or not same_number(p_line.offer_id, p_offer.offer_id)
         or not same_number(p_line.offer_dtl_id, p_offer.offer_dtl_id)
         or not same_text(p_line.offer_line_role, 'SERVICE')
         or p_line.offer_instance_id is not null
         or p_line.offer_parent_line_id is not null
         or not same_number(p_line.offer_price_applied, p_offer.offer_price)
         or not same_number(p_line.offer_dis_applied, p_offer.offer_dis)
         or not same_text(p_line.offer_name_snapshot, p_offer.offer_name)
         or not same_number(p_line.offer_object_version_number, p_offer.offer_object_version)
         or not same_number(p_line.offer_dtl_object_version_number, p_offer.detail_object_version)
      then
        raise_offer_stale;
      end if;
    end assert_standard_evidence;

    procedure assert_currency (
      p_curr_code in varchar2,
      p_line_no   in number,
      p_serviceid in varchar2
    ) is
      l_curr_code t_inv.curr_code%type;
    begin
      l_curr_code := upper_trim_to_null(p_curr_code);
      if l_curr_code is null then
        raise_application_error(
          -20917,
          'Invoice create failed: currency is missing from price list/service for line '
          || p_line_no
          || ', service '
          || p_serviceid
          || '.'
        );
      end if;
      if io_result.curr_code is null then
        io_result.curr_code := l_curr_code;
      elsif upper_trim_to_null(io_result.curr_code) <> l_curr_code then
        raise_application_error(
          -20918,
          'Invoice create failed: mixed currencies are not allowed. Expected '
          || io_result.curr_code
          || ' but line '
          || p_line_no
          || ' uses '
          || l_curr_code
          || '.'
        );
      end if;
    end assert_currency;

    function has_manual_discount (
      p_line in t_line_input
    ) return boolean is
      l_type varchar2(1);
    begin
      l_type := nvl(upper_trim_to_null(p_line.discount_type), 'N');
      if l_type = 'N' then
        return nvl(p_line.disc, 0) <> 0 or nvl(p_line.my_disc, 0) <> 0;
      end if;
      if l_type = 'R' then
        return nvl(p_line.disc, 0) <> 0 or nvl(p_line.my_disc, 0) <> 0;
      end if;
      return nvl(p_line.disc, 0) <> 0 or nvl(p_line.my_disc, 0) <> 0;
    end has_manual_discount;

    procedure assert_no_package_override (
      p_line    in t_line_input,
      p_line_no in number
    ) is
    begin
      if line_uses_price_override(p_line) then
        raise_application_error(
          -20940,
          'Invoice create failed: package line '
          || p_line_no
          || ' cannot use a price override.'
        );
      end if;
    end assert_no_package_override;

    procedure assert_no_package_discount (
      p_line    in t_line_input,
      p_line_no in number
    ) is
    begin
      if has_manual_discount(p_line) then
        raise_application_error(
          -20941,
          'Invoice create failed: package line '
          || p_line_no
          || ' cannot use a manual discount.'
        );
      end if;
    end assert_no_package_discount;

    procedure load_package_components (
      p_package_serviceid in services.serviceid%type,
      p_list_id           in services.list_id%type,
      o_components        out nocopy t_package_component_tab
    ) is
      l_count number := 0;
    begin
      o_components.delete;
      for r in (
        select sub_serviceid,
               qty
          from package_dtl
         where serviceid = p_package_serviceid
           and list_id = p_list_id
         order by sub_serviceid
      ) loop
        if trim_to_null(r.sub_serviceid) is null then
          raise_application_error(
            -20942,
            'Invoice create failed: package '
            || p_package_serviceid
            || ' has a blank component.'
          );
        end if;
        if r.qty is null
           or r.qty <= 0
           or r.qty <> trunc(r.qty)
        then
          raise_application_error(
            -20943,
            'Invoice create failed: package '
            || p_package_serviceid
            || ' has an invalid component quantity.'
          );
        end if;
        l_count := l_count + 1;
        o_components(l_count).serviceid := r.sub_serviceid;
        o_components(l_count).qty := r.qty;
        o_components(l_count).component_order := l_count;
      end loop;
      if l_count = 0 then
        raise_application_error(
          -20944,
          'Invoice create failed: package '
          || p_package_serviceid
          || ' has no configured components.'
        );
      end if;
    end load_package_components;

    procedure normalize_package_occurrences
    is
      l_scan_idx          pls_integer;
      l_sub_idx           pls_integer;
      l_parent_idx        pls_integer;
      l_parent_count      pls_integer;
      l_component_count   pls_integer;
      l_match_idx         pls_integer;
      l_match_count       pls_integer;
      l_component_idx     pls_integer;
      l_instance_id       d_inv.package_instance_id%type;
      l_package_serviceid d_inv.package_service_id%type;
      l_method            services.package_pricing_method%type;
      l_token             varchar2(64);
      l_derived_qty       number;
      l_components        t_package_component_tab;
    begin
      l_scan_idx := p_lines.first;
      while l_scan_idx is not null loop
        l_instance_id := trim_to_null(p_lines(l_scan_idx).package_instance_id);
        if l_instance_id is not null
           and not l_package_instances.exists(l_instance_id)
        then
          l_parent_idx := null;
          l_parent_count := 0;
          l_component_count := 0;
          l_sub_idx := p_lines.first;
          while l_sub_idx is not null loop
            if trim_to_null(p_lines(l_sub_idx).package_instance_id) = l_instance_id then
              if upper_trim_to_null(p_lines(l_sub_idx).package_line_role) = c_pkg_role_parent then
                l_parent_count := l_parent_count + 1;
                l_parent_idx := l_sub_idx;
              elsif upper_trim_to_null(p_lines(l_sub_idx).package_line_role) = c_pkg_role_component then
                l_component_count := l_component_count + 1;
              else
                raise_application_error(
                  -20948,
                  'Invoice create failed: package occurrence contains an invalid line role.'
                );
              end if;
            end if;
            l_sub_idx := p_lines.next(l_sub_idx);
          end loop;

          if l_parent_count <> 1 then
            raise_application_error(
              -20948,
              'Invoice create failed: package occurrence must contain exactly one parent.'
            );
          end if;

          l_package_serviceid := p_lines(l_parent_idx).serviceid;
          if trim_to_null(l_package_serviceid) is null
             or p_lines(l_parent_idx).package_service_id <> l_package_serviceid
          then
            raise_application_error(
              -20949,
              'Invoice create failed: package parent service metadata was changed.'
            );
          end if;

          if p_lines(l_parent_idx).qty is null
             or p_lines(l_parent_idx).qty <= 0
             or p_lines(l_parent_idx).qty <> trunc(p_lines(l_parent_idx).qty)
             or p_lines(l_parent_idx).qty > trunc(c_max_invoice_qty)
          then
            raise_application_error(
              -20947,
              'Invoice create failed: package parent quantity must be a positive whole number not greater than '
              || trunc(c_max_invoice_qty)
              || ' for package '
              || l_package_serviceid
              || '.'
            );
          end if;

          begin
            select upper(trim(s.package_pricing_method))
              into l_method
              from services s
             where s.serviceid = l_package_serviceid
               and s.list_id = p_patient_context.list_id
               and s.is_package = 1;
          exception
            when no_data_found then
              raise_application_error(
                -20946,
                'Invoice create failed: package '
                || l_package_serviceid
                || ' is not active in the patient price list.'
              );
          end;

          if l_method not in (c_pkg_fixed_price, c_pkg_component_price, c_pkg_free) then
            raise_application_error(
              -20946,
              'Invoice create failed: invalid package pricing method for package '
              || l_package_serviceid
              || '.'
            );
          end if;

          load_package_components(
            p_package_serviceid => l_package_serviceid,
            p_list_id           => p_patient_context.list_id,
            o_components        => l_components
          );
          l_token := get_package_definition_token(
                       l_package_serviceid,
                       p_patient_context.list_id
                     );

          if l_component_count <> l_components.count then
            raise_application_error(
              -20951,
              'Invoice create failed: package components are missing or extra.'
            );
          end if;

          l_sub_idx := p_lines.first;
          while l_sub_idx is not null loop
            if trim_to_null(p_lines(l_sub_idx).package_instance_id) = l_instance_id then
              if p_lines(l_sub_idx).package_service_id <> l_package_serviceid then
                raise_application_error(
                  -20955,
                  'Invoice create failed: package line parent metadata was changed.'
                );
              end if;
              if p_lines(l_sub_idx).package_pricing_method is not null
                 and upper_trim_to_null(p_lines(l_sub_idx).package_pricing_method) <> l_method
              then
                raise_application_error(
                  -20962,
                  'Invoice create failed: package pricing method metadata was changed.'
                );
              end if;
              if p_lines(l_sub_idx).package_definition_token is not null
                 and p_lines(l_sub_idx).package_definition_token <> l_token
              then
                raise_package_stale;
              end if;
              if p_validate_offer_versions
                 and p_lines(l_sub_idx).package_definition_token is null
              then
                raise_package_stale;
              end if;
            end if;
            l_sub_idx := p_lines.next(l_sub_idx);
          end loop;

          l_component_idx := l_components.first;
          while l_component_idx is not null loop
            l_match_idx := null;
            l_match_count := 0;
            l_sub_idx := p_lines.first;
            while l_sub_idx is not null loop
              if trim_to_null(p_lines(l_sub_idx).package_instance_id) = l_instance_id
                 and upper_trim_to_null(p_lines(l_sub_idx).package_line_role) = c_pkg_role_component
                 and p_lines(l_sub_idx).serviceid = l_components(l_component_idx).serviceid
                 and p_lines(l_sub_idx).package_component_order =
                       l_components(l_component_idx).component_order
              then
                l_match_count := l_match_count + 1;
                l_match_idx := l_sub_idx;
              end if;
              l_sub_idx := p_lines.next(l_sub_idx);
            end loop;

            if l_match_count <> 1 then
              raise_application_error(
                -20952,
                'Invoice create failed: package component service was changed, duplicated, or reordered.'
              );
            end if;

            l_derived_qty :=
              p_lines(l_parent_idx).qty * l_components(l_component_idx).qty;
            if l_derived_qty <= 0
               or l_derived_qty <> trunc(l_derived_qty)
               or l_derived_qty > trunc(c_max_invoice_qty)
            then
              raise_application_error(
                -20966,
                'Invoice create failed: multiplied package component quantity must be a positive whole number within the invoice quantity limit.'
              );
            end if;
            l_package_qty(l_match_idx) := l_derived_qty;
            l_component_idx := l_components.next(l_component_idx);
          end loop;

          l_package_tokens(l_instance_id) := l_token;
          l_package_instances(l_instance_id) := l_parent_idx;
        end if;

        l_scan_idx := p_lines.next(l_scan_idx);
      end loop;
    end normalize_package_occurrences;

    procedure append_calc_line (
      p_line                  in t_line_input,
      p_service_context       in bil_types.t_service_context,
      p_qty                   in number,
      p_price                 in number,
      p_plan_disc_pct         in number,
      p_plan_disc_amt         in number,
      p_manual_disc_type      in varchar2,
      p_manual_disc_pct       in number,
      p_manual_disc_amt       in number,
      p_discount_source       in varchar2,
      p_disc_pct              in number,
      p_disc_amt              in number,
      p_fixpay                in number,
      p_payrate               in number,
      p_the_fix               in number,
      p_the_rate              in number,
      p_the_pay               in number,
      p_the_comp              in number,
      p_my_price              in number,
      p_my_net                in number,
      p_vat_rate              in number,
      p_vat_pat               in number,
      p_vat_co                in number,
      p_vat_pat_ex            in number,
      p_req_need_a            in number,
      p_req_a_status          in number,
      p_package_service_id    in d_inv.package_service_id%type default null,
      p_package_instance_id   in d_inv.package_instance_id%type default null,
      p_package_line_role     in d_inv.package_line_role%type default null,
      p_package_component_ord in d_inv.package_component_order%type default null,
      p_package_parent_idx    in pls_integer default null,
      p_package_pricing_method in services.package_pricing_method%type default null,
      p_package_definition_token in varchar2 default null,
      p_offer_parent_idx      in pls_integer default null,
      p_allow_manual_discount in varchar2 default 'N',
      p_allow_price_override  in varchar2 default 'N'
    ) is
    begin
      l_out_idx := l_out_idx + 1;
      o_calc_lines(l_out_idx).serviceid           := p_service_context.serviceid;
      o_calc_lines(l_out_idx).servicedesc         := p_service_context.servicedesc;
      o_calc_lines(l_out_idx).catid               := p_service_context.catid;
      o_calc_lines(l_out_idx).list_id             := p_service_context.list_id;
      o_calc_lines(l_out_idx).curr_code           := upper_trim_to_null(p_service_context.curr_code);
      o_calc_lines(l_out_idx).qty                 := p_qty;
      o_calc_lines(l_out_idx).price               := round(nvl(p_price, 0), 3);
      o_calc_lines(l_out_idx).plan_discount_pct   := nvl(p_plan_disc_pct, 0);
      o_calc_lines(l_out_idx).plan_discount_amount := round_money(p_plan_disc_amt);
      o_calc_lines(l_out_idx).manual_discount_type :=
        nvl(upper_trim_to_null(p_manual_disc_type), 'N');
      o_calc_lines(l_out_idx).manual_discount_pct := nvl(p_manual_disc_pct, 0);
      o_calc_lines(l_out_idx).manual_discount_amount := round_money(p_manual_disc_amt);
      o_calc_lines(l_out_idx).discount_source     := nvl(p_discount_source, 'NONE');
      o_calc_lines(l_out_idx).disc                := nvl(p_disc_pct, 0);
      o_calc_lines(l_out_idx).my_disc             := round_money(p_disc_amt);
      o_calc_lines(l_out_idx).fixpay              := p_fixpay;
      o_calc_lines(l_out_idx).payrate             := p_payrate;
      o_calc_lines(l_out_idx).the_fix             := p_the_fix;
      o_calc_lines(l_out_idx).the_rate            := p_the_rate;
      o_calc_lines(l_out_idx).the_pay             := round_money(p_the_pay);
      o_calc_lines(l_out_idx).the_comp            := round_money(p_the_comp);
      o_calc_lines(l_out_idx).my_price            := round_money(p_my_price);
      o_calc_lines(l_out_idx).my_net              := round_money(p_my_net);
      o_calc_lines(l_out_idx).vat_rate            := nvl(p_vat_rate, 0);
      o_calc_lines(l_out_idx).vat_val_pat         := round_money(p_vat_pat);
      o_calc_lines(l_out_idx).vat_val_co          := round_money(p_vat_co);
      o_calc_lines(l_out_idx).vat_val_pat_ex      := round_money(p_vat_pat_ex);
      o_calc_lines(l_out_idx).sfda_code           := p_service_context.sfda_code;
      o_calc_lines(l_out_idx).teeth_no            := p_line.teeth_no;
      o_calc_lines(l_out_idx).tooth_surface       := p_line.tooth_surface;
      o_calc_lines(l_out_idx).teeth_no2           := p_line.teeth_no2;
      if p_line.pat_serv_req_row_id is not null then
        o_calc_lines(l_out_idx).pat_serv_req_row_id := p_line.pat_serv_req_row_id;
        o_calc_lines(l_out_idx).approv_date         := p_line.approv_date;
        o_calc_lines(l_out_idx).approv_validity     := p_line.approv_validity;
        o_calc_lines(l_out_idx).approv_ref_no       := p_line.approv_ref_no;
      else
        o_calc_lines(l_out_idx).pat_serv_req_row_id := null;
        o_calc_lines(l_out_idx).approv_date         := null;
        o_calc_lines(l_out_idx).approv_validity     := null;
        o_calc_lines(l_out_idx).approv_ref_no       := null;
      end if;
      o_calc_lines(l_out_idx).claim_no            := p_line.claim_no;
      o_calc_lines(l_out_idx).req_need_a          := p_req_need_a;
      o_calc_lines(l_out_idx).req_a_status        := p_req_a_status;
      o_calc_lines(l_out_idx).is_deleted          := 0;
      o_calc_lines(l_out_idx).info_center_id      := p_info_center_id;
      o_calc_lines(l_out_idx).package_service_id  := p_package_service_id;
      o_calc_lines(l_out_idx).package_instance_id := p_package_instance_id;
      o_calc_lines(l_out_idx).package_line_role   := p_package_line_role;
      o_calc_lines(l_out_idx).package_component_order := p_package_component_ord;
      o_calc_lines(l_out_idx).package_parent_line_id := p_package_parent_idx;
      o_calc_lines(l_out_idx).package_parent_line_idx := p_package_parent_idx;
      o_calc_lines(l_out_idx).package_pricing_method := p_package_pricing_method;
      o_calc_lines(l_out_idx).package_definition_token := p_package_definition_token;
      o_calc_lines(l_out_idx).offer_id := p_line.offer_id;
      o_calc_lines(l_out_idx).offer_dtl_id := p_line.offer_dtl_id;
      o_calc_lines(l_out_idx).offer_type := p_line.offer_type;
      o_calc_lines(l_out_idx).offer_instance_id := p_line.offer_instance_id;
      o_calc_lines(l_out_idx).offer_line_role := p_line.offer_line_role;
      o_calc_lines(l_out_idx).offer_parent_line_id := p_offer_parent_idx;
      o_calc_lines(l_out_idx).offer_parent_line_idx := p_offer_parent_idx;
      o_calc_lines(l_out_idx).offer_price_applied := p_line.offer_price_applied;
      o_calc_lines(l_out_idx).offer_dis_applied := p_line.offer_dis_applied;
      o_calc_lines(l_out_idx).offer_name_snapshot := p_line.offer_name_snapshot;
      o_calc_lines(l_out_idx).offer_object_version_number :=
        p_line.offer_object_version_number;
      o_calc_lines(l_out_idx).offer_dtl_object_version_number :=
        p_line.offer_dtl_object_version_number;
      o_calc_lines(l_out_idx).allow_manual_discount :=
        case when upper_trim_to_null(p_allow_manual_discount) = 'Y' then 'Y' else 'N' end;
      o_calc_lines(l_out_idx).allow_price_override :=
        case when upper_trim_to_null(p_allow_price_override) = 'Y' then 'Y' else 'N' end;

      io_result.total_gross    := round_money(io_result.total_gross + nvl(p_my_price, 0));
      io_result.total_discount := round_money(io_result.total_discount + nvl(p_disc_amt, 0));
      io_result.total_net      := round_money(io_result.total_net + nvl(p_my_net, 0));
      io_result.pat_pay        := round_money(io_result.pat_pay + nvl(p_the_pay, 0));
      io_result.comp_pay       := round_money(io_result.comp_pay + nvl(p_the_comp, 0));
      io_result.vat_total_pat  := round_money(io_result.vat_total_pat + nvl(p_vat_pat, 0));
      io_result.vat_total_co   := round_money(io_result.vat_total_co + nvl(p_vat_co, 0));
      io_result.vat_total      := round_money(io_result.vat_total_pat + io_result.vat_total_co);
      io_result.line_count     := io_result.line_count + 1;
    end append_calc_line;

    procedure calculate_financial_line (
      p_line                  in t_line_input,
      p_line_no               in pls_integer,
      p_service_context       in bil_types.t_service_context,
      p_price_result          in bil_types.t_price_result,
      p_qty                   in number,
      p_package_service_id    in d_inv.package_service_id%type default null,
      p_package_instance_id   in d_inv.package_instance_id%type default null,
      p_package_line_role     in d_inv.package_line_role%type default null,
      p_package_component_ord in d_inv.package_component_order%type default null,
      p_package_parent_idx    in pls_integer default null,
      p_package_pricing_method in services.package_pricing_method%type default null,
      p_package_definition_token in varchar2 default null,
      p_offer_parent_idx      in pls_integer default null,
      p_disable_standard_offer in boolean default false,
      p_authoritative_price   in number default null,
      p_authoritative_discount in number default null,
      p_allow_manual_discount in varchar2 default null,
      p_allow_price_override  in varchar2 default null
    ) is
      l_allow_manual_discount varchar2(1);
      l_allow_price_override  varchar2(1);
      l_line                  t_line_input;
      l_offer                 bil_offer_rule.t_standard_offer;
      l_standard_eligible     boolean;
    begin
      l_line := p_line;
      l_allow_manual_discount :=
        nvl(upper_trim_to_null(p_allow_manual_discount),
            nvl(upper_trim_to_null(p_price_result.allow_discount), 'N'));
      l_allow_price_override :=
        nvl(upper_trim_to_null(p_allow_price_override),
            nvl(upper_trim_to_null(p_price_result.allow_manual_price), 'N'));

      l_standard_eligible :=
        not p_disable_standard_offer
        and p_paytype = c_paytype_cash
        and upper_trim_to_null(p_patient_context.coverage_type) = bil_types.c_coverage_cash
        and p_package_service_id is null
        and not (p_line.pat_serv_req_row_id is not null and line_uses_price_override(p_line));

      if l_standard_eligible then
        bil_offer_rule.resolve_standard_offer(
          p_info_center_id => p_info_center_id,
          p_cash_list_id   => p_patient_context.list_id,
          p_serviceid      => p_line.serviceid,
          p_paytype        => p_paytype,
          p_invoice_date   => p_header.invdate,
          o_offer          => l_offer
        );
        assert_standard_evidence(p_line, l_offer);
      else
        l_offer.matched := 'N';
        if p_line.offer_type is null then
          assert_expected_no_offer(p_line);
        elsif p_line.offer_type <> 0 then
          raise_offer_stale;
        end if;
      end if;

      if l_offer.matched = 'Y' then
        if line_uses_price_override(p_line) then
          raise_application_error(-20971, 'A manual price cannot be combined with a Standard Offer.');
        end if;
        if has_manual_discount(p_line) then
          raise_application_error(-20972, 'A manual line discount cannot be combined with a Standard Offer.');
        end if;

        l_line.offer_id := l_offer.offer_id;
        l_line.offer_dtl_id := l_offer.offer_dtl_id;
        l_line.offer_type := 1;
        l_line.offer_instance_id := null;
        l_line.offer_line_role := 'SERVICE';
        l_line.offer_parent_line_id := null;
        l_line.offer_price_applied := l_offer.offer_price;
        l_line.offer_dis_applied := l_offer.offer_dis;
        l_line.offer_name_snapshot := l_offer.offer_name;
        l_line.offer_object_version_number := l_offer.offer_object_version;
        l_line.offer_dtl_object_version_number := l_offer.detail_object_version;
      end if;

      if line_uses_price_override(l_line) and l_allow_price_override <> 'Y' then
        raise_application_error(
          -20963,
          'Invoice create failed: service '
          || p_line.serviceid
          || ' does not allow a price override on line '
          || p_line_no
          || '.'
        );
      end if;

      if p_authoritative_price is not null then
        l_effective_price := p_authoritative_price;
      elsif l_offer.matched = 'Y' and l_offer.offer_price is not null then
        l_effective_price := l_offer.offer_price;
      else
        l_effective_price := get_effective_line_price(
                               p_normal_price => p_price_result.billing_price,
                               p_line         => l_line,
                               p_line_no      => p_line_no
        );
      end if;
      l_gross := round_money(l_effective_price * p_qty);

      if p_authoritative_discount is not null then
        l_plan_disc_pct := p_authoritative_discount;
      elsif l_offer.matched = 'Y' and l_offer.offer_dis is not null then
        l_plan_disc_pct := l_offer.offer_dis;
      else
        l_plan_disc_pct := nvl(p_service_context.plan_price_disc, 0);
      end if;
      if l_plan_disc_pct < 0 or l_plan_disc_pct > 100 then
        raise_application_error(
          -20945,
          'Invoice create failed: plan discount must be between 0 and 100 for service '
          || p_line.serviceid
          || '.'
        );
      end if;
      l_plan_disc_amt := round_money(l_gross * l_plan_disc_pct / 100);

      if l_allow_manual_discount <> 'Y' and has_manual_discount(l_line) then
        raise_application_error(
          -20922,
          'Invoice create failed: service '
          || p_line.serviceid
          || ' is non-discountable on line '
          || p_line_no
          || '.'
        );
      end if;

      l_manual_disc_type := nvl(upper_trim_to_null(l_line.discount_type), 'N');
      l_manual_disc_amt := calc_discount_amount(
                             p_discount_type => l_manual_disc_type,
                             p_disc          => l_line.disc,
                             p_my_disc       => l_line.my_disc,
                             p_gross_amount  => l_gross
                           );
      l_manual_disc_pct := calc_discount_percent(
                             p_discount_type => l_manual_disc_type,
                             p_disc          => l_line.disc,
                             p_discount_amt  => l_manual_disc_amt,
                             p_gross_amount  => l_gross
                           );

      l_disc_amt := round_money(l_plan_disc_amt + l_manual_disc_amt);
      if l_disc_amt > l_gross then
        raise_application_error(
          -20961,
          'Invoice create failed: combined plan and manual discount cannot exceed gross amount on line '
          || p_line_no
          || '.'
        );
      end if;
      l_disc_pct := case
                      when nvl(l_gross, 0) = 0 then 0
                      else round(100 * l_disc_amt / l_gross, 2)
                    end;
      l_discount_source := case
                             when l_offer.matched = 'Y' then 'OFFER'
                             when p_disable_standard_offer and p_authoritative_price is not null
                               then 'BUNDLE'
                             when l_plan_disc_amt <> 0 and l_manual_disc_amt <> 0
                               then 'PLAN_AND_MANUAL'
                             when l_plan_disc_amt <> 0 then 'PLAN'
                             when l_manual_disc_amt <> 0 then 'MANUAL'
                             else 'NONE'
                           end;

      l_net := round_money(l_gross - l_disc_amt);

      bil_class_rule.resolve_share(
        p_patient_context     => p_patient_context,
        p_service_context     => p_service_context,
        p_paytype             => p_paytype,
        p_clinicid            => p_header.clinicid,
        p_net_amount          => l_net,
        p_qty                 => p_qty,
        p_patient_paid_so_far => io_result.pat_pay,
        o_class               => l_class_result
      );
      calc_vat_for_line(
        p_patient_context => p_patient_context,
        p_service_context => p_service_context,
        p_patient_share   => l_class_result.the_pay,
        p_company_share   => l_class_result.the_comp,
        o_vat_rate        => l_vat_rate,
        o_vat_val_pat     => l_vat_pat,
        o_vat_val_co      => l_vat_co,
        o_vat_val_pat_ex  => l_vat_pat_ex
      );
      append_calc_line(
        p_line                  => l_line,
        p_service_context       => p_service_context,
        p_qty                   => p_qty,
        p_price                 => l_effective_price,
        p_plan_disc_pct         => l_plan_disc_pct,
        p_plan_disc_amt         => l_plan_disc_amt,
        p_manual_disc_type      => l_manual_disc_type,
        p_manual_disc_pct       => l_manual_disc_pct,
        p_manual_disc_amt       => l_manual_disc_amt,
        p_discount_source       => l_discount_source,
        p_disc_pct              => l_disc_pct,
        p_disc_amt              => l_disc_amt,
        p_fixpay                => l_class_result.fixpay,
        p_payrate               => l_class_result.payrate,
        p_the_fix               => l_class_result.the_fix,
        p_the_rate              => l_class_result.the_rate,
        p_the_pay               => l_class_result.the_pay,
        p_the_comp              => l_class_result.the_comp,
        p_my_price              => l_gross,
        p_my_net                => l_net,
        p_vat_rate              => l_vat_rate,
        p_vat_pat               => l_vat_pat,
        p_vat_co                => l_vat_co,
        p_vat_pat_ex            => l_vat_pat_ex,
        p_req_need_a            =>
          case
            when p_line.pat_serv_req_row_id is not null then p_line.req_need_a
            else l_class_result.req_need_a
          end,
        p_req_a_status          =>
          case
            when p_line.pat_serv_req_row_id is not null then p_line.req_a_status
            else l_class_result.req_a_status
          end,
        p_package_service_id    => p_package_service_id,
        p_package_instance_id   => p_package_instance_id,
        p_package_line_role     => p_package_line_role,
        p_package_component_ord => p_package_component_ord,
        p_package_parent_idx    => p_package_parent_idx,
        p_package_pricing_method => p_package_pricing_method,
        p_package_definition_token => p_package_definition_token,
        p_offer_parent_idx      => p_offer_parent_idx,
        p_allow_manual_discount => l_allow_manual_discount,
        p_allow_price_override  => l_allow_price_override
      );
    end calculate_financial_line;

    procedure append_zero_line (
      p_line                  in t_line_input,
      p_service_context       in bil_types.t_service_context,
      p_qty                   in number,
      p_package_service_id    in d_inv.package_service_id%type,
      p_package_instance_id   in d_inv.package_instance_id%type,
      p_package_line_role     in d_inv.package_line_role%type,
      p_package_component_ord in d_inv.package_component_order%type,
      p_package_parent_idx    in pls_integer,
      p_package_pricing_method in services.package_pricing_method%type,
      p_package_definition_token in varchar2 default null,
      p_offer_parent_idx      in pls_integer default null
    ) is
    begin
      append_calc_line(
        p_line                  => p_line,
        p_service_context       => p_service_context,
        p_qty                   => p_qty,
        p_price                 => 0,
        p_plan_disc_pct         => 0,
        p_plan_disc_amt         => 0,
        p_manual_disc_type      => 'N',
        p_manual_disc_pct       => 0,
        p_manual_disc_amt       => 0,
        p_discount_source       => 'NONE',
        p_disc_pct              => 0,
        p_disc_amt              => 0,
        p_fixpay                => null,
        p_payrate               => null,
        p_the_fix               => null,
        p_the_rate              => null,
        p_the_pay               => 0,
        p_the_comp              => 0,
        p_my_price              => 0,
        p_my_net                => 0,
        p_vat_rate              => nvl(p_service_context.vat_rate, 0),
        p_vat_pat               => 0,
        p_vat_co                => 0,
        p_vat_pat_ex            => 0,
        p_req_need_a            =>
          case
            when p_line.pat_serv_req_row_id is not null then p_line.req_need_a
            else 0
          end,
        p_req_a_status          =>
          case
            when p_line.pat_serv_req_row_id is not null then p_line.req_a_status
            else null
          end,
        p_package_service_id    => p_package_service_id,
        p_package_instance_id   => p_package_instance_id,
        p_package_line_role     => p_package_line_role,
        p_package_component_ord => p_package_component_ord,
        p_package_parent_idx    => p_package_parent_idx,
        p_package_pricing_method => p_package_pricing_method,
        p_package_definition_token => p_package_definition_token,
        p_offer_parent_idx      => p_offer_parent_idx,
        p_allow_manual_discount => 'N',
        p_allow_price_override  => 'N'
      );
    end append_zero_line;

  begin
    io_result.total_gross    := 0;
    io_result.total_discount := 0;
    io_result.total_net      := 0;
    io_result.pat_pay        := 0;
    io_result.comp_pay       := 0;
    io_result.vat_total_pat  := 0;
    io_result.vat_total_co   := 0;
    io_result.vat_total      := 0;
    io_result.line_count     := 0;
    io_result.curr_code      := null;
    o_calc_lines.delete;
    normalize_package_occurrences;

    l_idx := p_lines.first;
    while l_idx is not null loop
      if p_lines(l_idx).offer_type = 0 then
        declare
          l_instance_id       d_inv.offer_instance_id%type;
          l_parent_idx        pls_integer;
          l_parent_count      pls_integer := 0;
          l_component_count   pls_integer := 0;
          l_sub_idx           pls_integer;
          l_match_idx         pls_integer;
          l_match_count       pls_integer;
          l_parent_out_idx    pls_integer;
          l_parent_line       t_line_input;
          l_component_line    t_line_input;
          l_parent_ctx        bil_types.t_service_context;
          l_component_ctx     bil_types.t_service_context;
          l_component_price   bil_types.t_price_result;
          l_bundle_header     bil_offer_rule.t_bundle_header;
          l_bundle_details    bil_offer_rule.t_bundle_detail_tab;
          l_detail_idx        pls_integer;
          l_expected_parent   number;
        begin
          l_instance_id := trim_to_null(p_lines(l_idx).offer_instance_id);
          if l_instance_id is null then
            raise_application_error(-20973, 'Bundled Offer instance identity is required.');
          end if;

          if not l_offer_instances.exists(l_instance_id) then
            l_sub_idx := p_lines.first;
            while l_sub_idx is not null loop
              if p_lines(l_sub_idx).offer_type = 0
                 and p_lines(l_sub_idx).offer_instance_id = l_instance_id
              then
                if upper_trim_to_null(p_lines(l_sub_idx).offer_line_role) = 'PARENT' then
                  l_parent_count := l_parent_count + 1;
                  l_parent_idx := l_sub_idx;
                elsif upper_trim_to_null(p_lines(l_sub_idx).offer_line_role) = 'COMPONENT' then
                  l_component_count := l_component_count + 1;
                else
                  raise_application_error(-20974, 'Bundled Offer line role is invalid.');
                end if;
              end if;
              l_sub_idx := p_lines.next(l_sub_idx);
            end loop;

            if l_parent_count <> 1 then
              raise_application_error(-20975, 'Bundled Offer occurrence must contain exactly one parent.');
            end if;

            l_parent_line := p_lines(l_parent_idx);
            if l_parent_line.serviceid is not null
               or l_parent_line.qty is null
               or l_parent_line.qty <= 0
               or l_parent_line.qty <> trunc(l_parent_line.qty)
               or line_uses_price_override(l_parent_line)
               or has_manual_discount(l_parent_line)
               or l_parent_line.package_service_id is not null
               or l_parent_line.package_instance_id is not null
               or l_parent_line.package_line_role is not null
               or l_parent_line.package_component_order is not null
               or l_parent_line.package_parent_line_id is not null
            then
              raise_application_error(-20976, 'Bundled Offer parent was changed.');
            end if;

            bil_offer_rule.load_bundled_offer(
              p_offer_id       => l_parent_line.offer_id,
              p_info_center_id => p_info_center_id,
              p_cash_list_id   => p_patient_context.list_id,
              p_paytype        => p_paytype,
              p_invoice_date   => p_header.invdate,
              o_header         => l_bundle_header,
              o_details        => l_bundle_details
            );

            if l_parent_line.offer_id <> l_bundle_header.offer_id
               or l_parent_line.offer_dtl_id is not null
               or upper_trim_to_null(l_parent_line.offer_line_role) <> 'PARENT'
               or l_parent_line.offer_parent_line_id is not null
               or not same_number(l_parent_line.offer_price_applied, 0)
               or not same_number(l_parent_line.offer_dis_applied, 0)
               or not same_text(l_parent_line.offer_name_snapshot, l_bundle_header.offer_name)
               or not same_number(l_parent_line.offer_object_version_number,
                                  l_bundle_header.offer_object_version)
               or l_parent_line.offer_dtl_object_version_number is not null
               or l_component_count <> l_bundle_details.count
            then
              raise_offer_stale;
            end if;

            l_detail_idx := l_bundle_details.first;
            while l_detail_idx is not null loop
              l_match_count := 0;
              l_match_idx := null;
              l_sub_idx := p_lines.first;
              while l_sub_idx is not null loop
                if p_lines(l_sub_idx).offer_type = 0
                   and p_lines(l_sub_idx).offer_instance_id = l_instance_id
                   and upper_trim_to_null(p_lines(l_sub_idx).offer_line_role) = 'COMPONENT'
                   and p_lines(l_sub_idx).offer_dtl_id = l_bundle_details(l_detail_idx).offer_dtl_id
                then
                  l_match_count := l_match_count + 1;
                  l_match_idx := l_sub_idx;
                end if;
                l_sub_idx := p_lines.next(l_sub_idx);
              end loop;

              if l_match_count <> 1 then
                raise_offer_stale;
              end if;

              l_component_line := p_lines(l_match_idx);
              if l_expected_parent is null then
                l_expected_parent := l_component_line.offer_parent_line_id;
              elsif l_expected_parent <> l_component_line.offer_parent_line_id then
                raise_offer_stale;
              end if;
              if l_component_line.offer_id <> l_bundle_header.offer_id
                 or l_component_line.serviceid <> l_bundle_details(l_detail_idx).serviceid
                 or l_component_line.qty <>
                      l_parent_line.qty * l_bundle_details(l_detail_idx).qty
                 or l_component_line.offer_parent_line_id is null
                 or not same_number(l_component_line.offer_price_applied,
                                    l_bundle_details(l_detail_idx).offer_price)
                 or not same_number(l_component_line.offer_dis_applied, 0)
                 or l_component_line.offer_name_snapshot is not null
                 or not same_number(l_component_line.offer_object_version_number,
                                    l_bundle_header.offer_object_version)
                 or not same_number(l_component_line.offer_dtl_object_version_number,
                                    l_bundle_details(l_detail_idx).detail_object_version)
                 or line_uses_price_override(l_component_line)
                 or has_manual_discount(l_component_line)
                 or l_component_line.package_service_id is not null
                 or l_component_line.package_instance_id is not null
                 or l_component_line.package_line_role is not null
                 or l_component_line.package_component_order is not null
                 or l_component_line.package_parent_line_id is not null
              then
                raise_offer_stale;
              end if;

              l_detail_idx := l_bundle_details.next(l_detail_idx);
            end loop;

            l_detail_idx := l_bundle_details.first;
            bil_service_context.get_context(
              p_patient_context => p_patient_context,
              p_serviceid       => l_bundle_details(l_detail_idx).serviceid,
              p_qty             => l_parent_line.qty * l_bundle_details(l_detail_idx).qty,
              p_invoice_date    => p_header.invdate,
              o_context         => l_parent_ctx
            );
            assert_currency(l_parent_ctx.curr_code, l_parent_idx,
                            l_bundle_details(l_detail_idx).serviceid);
            l_parent_ctx.serviceid := null;
            l_parent_ctx.servicedesc := l_bundle_header.offer_name;
            l_parent_ctx.catid := null;
            l_parent_ctx.sfda_code := null;
            l_parent_ctx.vat_rate := 0;

            l_parent_line.offer_id := l_bundle_header.offer_id;
            l_parent_line.offer_dtl_id := null;
            l_parent_line.offer_type := 0;
            l_parent_line.offer_instance_id := l_instance_id;
            l_parent_line.offer_line_role := 'PARENT';
            l_parent_line.offer_parent_line_id := null;
            l_parent_line.offer_price_applied := 0;
            l_parent_line.offer_dis_applied := 0;
            l_parent_line.offer_name_snapshot := l_bundle_header.offer_name;
            l_parent_line.offer_object_version_number := l_bundle_header.offer_object_version;
            l_parent_line.offer_dtl_object_version_number := null;
            l_parent_line.discount_type := 'N';
            l_parent_line.disc := 0;
            l_parent_line.my_disc := 0;

            append_zero_line(
              p_line                   => l_parent_line,
              p_service_context        => l_parent_ctx,
              p_qty                    => l_parent_line.qty,
              p_package_service_id     => null,
              p_package_instance_id    => null,
              p_package_line_role      => null,
              p_package_component_ord  => null,
              p_package_parent_idx     => null,
              p_package_pricing_method => null
            );
            l_parent_out_idx := l_out_idx;

            l_detail_idx := l_bundle_details.first;
            while l_detail_idx is not null loop
              l_sub_idx := p_lines.first;
              while l_sub_idx is not null loop
                exit when p_lines(l_sub_idx).offer_type = 0
                  and p_lines(l_sub_idx).offer_instance_id = l_instance_id
                  and p_lines(l_sub_idx).offer_dtl_id = l_bundle_details(l_detail_idx).offer_dtl_id
                  and upper_trim_to_null(p_lines(l_sub_idx).offer_line_role) = 'COMPONENT';
                l_sub_idx := p_lines.next(l_sub_idx);
              end loop;

              l_component_line := p_lines(l_sub_idx);
              l_component_line.serviceid := l_bundle_details(l_detail_idx).serviceid;
              l_component_line.qty := l_parent_line.qty * l_bundle_details(l_detail_idx).qty;
              if l_component_line.qty is null
                 or l_component_line.qty <= 0
                 or l_component_line.qty <> trunc(l_component_line.qty)
              then
                raise_application_error(
                  -20966,
                  'Invoice create failed: bundled offer component quantity must be a positive whole number.'
                );
              end if;
              l_component_line.price_override := null;
              l_component_line.use_price_override := 'N';
              l_component_line.discount_type := 'N';
              l_component_line.disc := 0;
              l_component_line.my_disc := 0;
              l_component_line.offer_price_applied := l_bundle_details(l_detail_idx).offer_price;
              l_component_line.offer_dis_applied := 0;
              l_component_line.offer_name_snapshot := null;

              bil_service_context.get_context(
                p_patient_context => p_patient_context,
                p_serviceid       => l_component_line.serviceid,
                p_qty             => l_component_line.qty,
                p_invoice_date    => p_header.invdate,
                o_context         => l_component_ctx
              );
              if nvl(l_component_ctx.is_package, 2) = 1 then
                raise_application_error(-20977, 'Bundled Offer components cannot be service packages.');
              end if;
              assert_currency(l_component_ctx.curr_code, l_sub_idx, l_component_line.serviceid);
              bil_price_rule.resolve_price(
                p_patient_context => p_patient_context,
                p_service_context => l_component_ctx,
                p_qty             => l_component_line.qty,
                p_invoice_date    => p_header.invdate,
                o_price           => l_component_price
              );
              calculate_financial_line(
                p_line                   => l_component_line,
                p_line_no                => l_sub_idx,
                p_service_context        => l_component_ctx,
                p_price_result           => l_component_price,
                p_qty                    => l_component_line.qty,
                p_offer_parent_idx       => l_parent_out_idx,
                p_disable_standard_offer => true,
                p_authoritative_price    => l_bundle_details(l_detail_idx).offer_price,
                p_authoritative_discount => 0,
                p_allow_manual_discount  => 'N',
                p_allow_price_override   => 'N'
              );
              l_detail_idx := l_bundle_details.next(l_detail_idx);
            end loop;

            l_offer_instances(l_instance_id) := 1;
          end if;
          l_idx := p_lines.next(l_idx);
        end;
      else
      l_qty := p_lines(l_idx).qty;
      bil_service_context.get_context(
        p_patient_context => p_patient_context,
        p_serviceid       => p_lines(l_idx).serviceid,
        p_qty             => l_qty,
        p_invoice_date    => p_header.invdate,
        o_context         => l_service_context
      );
      assert_currency(l_service_context.curr_code, l_idx, p_lines(l_idx).serviceid);
      bil_price_rule.resolve_price(
        p_patient_context => p_patient_context,
        p_service_context => l_service_context,
        p_qty             => l_qty,
        p_invoice_date    => p_header.invdate,
        o_price           => l_price_result
      );

      if nvl(l_service_context.is_package, 2) = 1 then
        declare
          l_method          varchar2(20);
          l_components      t_package_component_tab;
          l_component_idx   pls_integer;
          l_parent_out_idx  pls_integer;
          l_component_line  pls_integer;
          l_component_ctx   bil_types.t_service_context;
          l_component_price bil_types.t_price_result;
          l_instance_id     d_inv.package_instance_id%type;
          l_component_input t_line_input;
          l_definition_token varchar2(64);
        begin
          l_method := upper_trim_to_null(l_service_context.package_pricing_method);
          if l_method not in (c_pkg_fixed_price, c_pkg_component_price, c_pkg_free) then
            raise_application_error(
              -20946,
              'Invoice create failed: invalid package pricing method for package '
              || p_lines(l_idx).serviceid
              || '.'
            );
          end if;
          if l_qty is null
             or l_qty <= 0
             or l_qty <> trunc(l_qty)
             or l_qty > trunc(c_max_invoice_qty)
          then
            raise_application_error(
              -20947,
              'Invoice create failed: package parent quantity must be a positive whole number not greater than '
              || trunc(c_max_invoice_qty)
              || ' for package '
              || p_lines(l_idx).serviceid
              || '.'
            );
          end if;
          if p_lines(l_idx).package_line_role is not null
             and upper_trim_to_null(p_lines(l_idx).package_line_role) <> c_pkg_role_parent then
            raise_application_error(-20948, 'Invoice create failed: package parent role was changed.');
          end if;
          if p_lines(l_idx).package_service_id is not null
             and p_lines(l_idx).package_service_id <> p_lines(l_idx).serviceid then
            raise_application_error(-20949, 'Invoice create failed: package parent service metadata was changed.');
          end if;
          if p_lines(l_idx).package_pricing_method is not null
             and upper_trim_to_null(p_lines(l_idx).package_pricing_method) <> l_method then
            raise_application_error(-20962, 'Invoice create failed: package pricing method metadata was changed.');
          end if;
          assert_no_package_override(p_lines(l_idx), l_idx);
          assert_no_package_discount(p_lines(l_idx), l_idx);

          load_package_components(
            p_package_serviceid => p_lines(l_idx).serviceid,
            p_list_id           => p_patient_context.list_id,
            o_components        => l_components
          );
          l_instance_id := trim_to_null(p_lines(l_idx).package_instance_id);
          if l_instance_id is null
             or not l_package_tokens.exists(l_instance_id)
          then
            raise_application_error(
              -20949,
              'Invoice create failed: package instance identity is required.'
            );
          end if;
          l_definition_token := l_package_tokens(l_instance_id);

          if l_method = c_pkg_fixed_price then
            if nvl(l_price_result.billing_price, 0) <= 0 then
              raise_application_error(
                -20950,
                'Invoice create failed: fixed-price package '
                || p_lines(l_idx).serviceid
                || ' has no valid package plan price.'
              );
            end if;
            calculate_financial_line(
              p_line                  => p_lines(l_idx),
              p_line_no               => l_idx,
              p_service_context       => l_service_context,
              p_price_result          => l_price_result,
              p_qty                   => l_qty,
              p_package_service_id    => p_lines(l_idx).serviceid,
              p_package_instance_id   => l_instance_id,
              p_package_line_role     => c_pkg_role_parent,
              p_package_component_ord => 0,
              p_package_pricing_method => l_method,
              p_package_definition_token => l_definition_token,
              p_disable_standard_offer => true,
              p_allow_manual_discount => 'N',
              p_allow_price_override  => 'N'
            );
          else
            append_zero_line(
              p_line                  => p_lines(l_idx),
              p_service_context       => l_service_context,
              p_qty                   => l_qty,
              p_package_service_id    => p_lines(l_idx).serviceid,
              p_package_instance_id   => l_instance_id,
              p_package_line_role     => c_pkg_role_parent,
              p_package_component_ord => 0,
              p_package_parent_idx    => null,
              p_package_pricing_method => l_method,
              p_package_definition_token => l_definition_token
            );
          end if;
          l_parent_out_idx := l_out_idx;

          l_component_line := l_idx;
          l_component_idx := l_components.first;
          while l_component_idx is not null loop
            l_component_line := p_lines.next(l_component_line);
            if l_component_line is null then
              raise_application_error(-20951, 'Invoice create failed: package component line is missing.');
            end if;
            if p_lines(l_component_line).serviceid <> l_components(l_component_idx).serviceid then
              raise_application_error(-20952, 'Invoice create failed: package component service was changed or reordered.');
            end if;
            if not l_package_qty.exists(l_component_line) then
              raise_application_error(
                -20966,
                'Invoice create failed: authoritative package component quantity is missing.'
              );
            end if;
            l_component_input := p_lines(l_component_line);
            l_component_input.qty := l_package_qty(l_component_line);
            l_component_input.package_definition_token := l_definition_token;
            if p_lines(l_component_line).package_line_role is not null
               and upper_trim_to_null(p_lines(l_component_line).package_line_role) <> c_pkg_role_component then
              raise_application_error(-20954, 'Invoice create failed: package component role was changed.');
            end if;
            if p_lines(l_component_line).package_service_id is not null
               and p_lines(l_component_line).package_service_id <> p_lines(l_idx).serviceid then
              raise_application_error(-20955, 'Invoice create failed: package component parent metadata was changed.');
            end if;
            if p_lines(l_component_line).package_instance_id is not null
               and p_lines(l_component_line).package_instance_id <> l_instance_id then
              raise_application_error(-20956, 'Invoice create failed: package component instance metadata was changed.');
            end if;
            if p_lines(l_component_line).package_component_order is not null
               and p_lines(l_component_line).package_component_order <> l_components(l_component_idx).component_order then
              raise_application_error(-20957, 'Invoice create failed: package component order metadata was changed.');
            end if;
            if p_lines(l_component_line).package_pricing_method is not null
               and upper_trim_to_null(p_lines(l_component_line).package_pricing_method) <> l_method then
              raise_application_error(-20962, 'Invoice create failed: package pricing method metadata was changed.');
            end if;
            assert_no_package_override(l_component_input, l_component_line);
            if l_method in (c_pkg_fixed_price, c_pkg_free) then
              assert_no_package_discount(l_component_input, l_component_line);
            end if;

            bil_service_context.get_context(
              p_patient_context => p_patient_context,
              p_serviceid       => l_component_input.serviceid,
              p_qty             => l_component_input.qty,
              p_invoice_date    => p_header.invdate,
              o_context         => l_component_ctx
            );
            if nvl(l_component_ctx.is_package, 2) = 1 then
              raise_application_error(-20958, 'Invoice create failed: nested packages are not supported.');
            end if;
            assert_currency(l_component_ctx.curr_code, l_component_line, l_component_input.serviceid);
            bil_price_rule.resolve_price(
              p_patient_context => p_patient_context,
              p_service_context => l_component_ctx,
              p_qty             => l_component_input.qty,
              p_invoice_date    => p_header.invdate,
              o_price           => l_component_price
            );

            if l_method = c_pkg_component_price then
              calculate_financial_line(
                p_line                  => l_component_input,
                p_line_no               => l_component_line,
                p_service_context       => l_component_ctx,
                p_price_result          => l_component_price,
                p_qty                   => l_component_input.qty,
                p_package_service_id    => p_lines(l_idx).serviceid,
                p_package_instance_id   => l_instance_id,
                p_package_line_role     => c_pkg_role_component,
                p_package_component_ord => l_components(l_component_idx).component_order,
                p_package_parent_idx    => l_parent_out_idx,
                p_package_pricing_method => l_method,
                p_package_definition_token => l_definition_token,
                p_disable_standard_offer => true,
                p_allow_price_override  => 'N'
              );
            else
              append_zero_line(
                p_line                  => l_component_input,
                p_service_context       => l_component_ctx,
                p_qty                   => l_component_input.qty,
                p_package_service_id    => p_lines(l_idx).serviceid,
                p_package_instance_id   => l_instance_id,
                p_package_line_role     => c_pkg_role_component,
                p_package_component_ord => l_components(l_component_idx).component_order,
                p_package_parent_idx    => l_parent_out_idx,
                p_package_pricing_method => l_method,
                p_package_definition_token => l_definition_token
              );
            end if;
            l_component_idx := l_components.next(l_component_idx);
          end loop;
          l_idx := p_lines.next(l_component_line);
        end;
      else
        if p_lines(l_idx).package_line_role is not null
           or p_lines(l_idx).package_service_id is not null
           or p_lines(l_idx).package_instance_id is not null
           or p_lines(l_idx).package_component_order is not null
           or p_lines(l_idx).package_parent_line_id is not null
           or p_lines(l_idx).package_pricing_method is not null
           or p_lines(l_idx).package_definition_token is not null then
          raise_application_error(
            -20959,
            'Invoice create failed: package component was submitted without its package parent.'
          );
        end if;
        calculate_financial_line(
          p_line            => p_lines(l_idx),
          p_line_no         => l_idx,
          p_service_context => l_service_context,
          p_price_result    => l_price_result,
          p_qty             => l_qty
        );
        l_idx := p_lines.next(l_idx);
      end if;
      end if;
    end loop;
  end calculate_lines;

  procedure insert_header (
    p_header              in t_header_input,
    p_patient_context     in bil_types.t_patient_context,
    p_inv_no              in t_inv.inv_no%type,
    p_paytype             in t_inv.paytype%type,
    p_user_no             in t_inv.user_no%type,
    p_machine_n           in t_inv.machine_n%type,
    p_info_center_id      in t_inv.info_center_id%type,
    p_shift_system_unique in t_inv.shift_system_unique%type,
    p_result              in t_invoice_result
  )
  is
    l_invdate     date;
    l_old_or_new  t_inv.old_or_new%type;
    l_finaldisc_p t_inv.finaldisc_perc%type;
    l_pflag       t_inv.pflag%type;
  begin
    l_invdate := p_header.invdate;
    l_old_or_new := get_old_or_new(p_patient_context.patientno);
    l_pflag      := get_pflag(l_invdate);
    if p_header.finaldisc_perc is not null then
      l_finaldisc_p := p_header.finaldisc_perc;
    elsif nvl(p_result.total_net, 0) > 0 and nvl(p_result.finaldisc, 0) > 0 then
      l_finaldisc_p := round((100 * p_result.finaldisc) / p_result.total_net, 2);
    else
      l_finaldisc_p := null;
    end if;
    insert into t_inv (
      inv_no,
      invtypeid,
      invdate,
      patientno,
      patientname,
      comp_code,
      sub_comp_code,
      class_code,
      paytype,
      curr_code,
      docid,
      clinicid,
      pre_authorization,
      user_no,
      comp_pay,
      approv_limit,
      finaldisc_perc,
      finaldisc,
      amount_1,
      amount_2,
      sub_paytype,
      sub_paytype2,
      cash_payed,
      cash_collected,
      max_deductable,
      the_month,
      the_year,
      pflag,
      machine_n,
      shift_system_unique,
      xgroup,
      pat_pay,
      claim_no,
      list_id,
      plan_code,
      ins_number,
      card_end,
      pat_policy_no,
      add_to_list,
      vat_total_co,
      vat_total_pat,
      vat_total,
      claim_flag,
      info_center_id,
      note_no,
      old_or_new
    )
    values (
      p_inv_no,
      nvl(p_header.invtypeid, c_default_invtype),
      l_invdate,
      p_patient_context.patientno,
      p_patient_context.patientname,
      p_patient_context.comp_code,
      p_patient_context.sub_comp_code,
      p_patient_context.class_code,
      p_paytype,
      p_result.curr_code,
      p_header.docid,
      p_header.clinicid,
      p_header.pre_authorization,
      p_user_no,
      p_result.comp_pay,
      p_patient_context.approval_limit,
      l_finaldisc_p,
      p_result.finaldisc,
      nvl(p_header.amount_1, p_result.cash_collected),
      nvl(p_header.amount_2, 0),
      p_header.sub_paytype,
      p_header.sub_paytype2,
      p_result.cash_collected,
      p_result.cash_collected,
      p_patient_context.max_deductable,
      to_number(to_char(l_invdate, 'MM')),
      to_number(to_char(l_invdate, 'YYYY')),
      l_pflag,
      p_machine_n,
      p_shift_system_unique,
      p_patient_context.xgroup,
      p_result.pat_pay,
      p_header.claim_no,
      p_patient_context.list_id,
      p_patient_context.plan_code,
      p_patient_context.ins_number,
      p_patient_context.card_end,
      p_patient_context.pat_policy_no,
      nvl(p_header.add_to_list, 0),
      p_result.vat_total_co,
      p_result.vat_total_pat,
      p_result.vat_total,
      p_header.claim_flag,
      p_info_center_id,
      p_header.note_no,
      l_old_or_new
    );

  end insert_header;

  procedure insert_lines (
    p_inv_no         in t_inv.inv_no%type,
    p_calc_lines     in t_calc_line_tab,
    p_info_center_id in t_inv.info_center_id%type
  )
  is
    type t_d_inv_row_id_tab is table of d_inv.d_inv_row_id%type
      index by pls_integer;

    l_idx          pls_integer;
    l_d_inv_row_id t_d_inv_row_id_tab;
    l_package_parent_line_id d_inv.package_parent_line_id%type;
    l_offer_parent_line_id d_inv.offer_parent_line_id%type;

    function get_parent_d_inv_row_id (
      p_parent_idx in pls_integer
    ) return d_inv.d_inv_row_id%type
    is
    begin
      if p_parent_idx is null then
        return null;
      end if;
      if not l_d_inv_row_id.exists(p_parent_idx) then
        raise_application_error(
          -20960,
          'Invoice create failed: component parent line metadata is invalid.'
        );
      end if;
      return l_d_inv_row_id(p_parent_idx);
    end get_parent_d_inv_row_id;
  begin
    l_idx := p_calc_lines.first;
    while l_idx is not null loop
      select d_inv_seq.nextval
        into l_d_inv_row_id(l_idx)
        from dual;
      l_idx := p_calc_lines.next(l_idx);
    end loop;

    l_idx := p_calc_lines.first;
    while l_idx is not null loop
      l_package_parent_line_id :=
        get_parent_d_inv_row_id(p_calc_lines(l_idx).package_parent_line_idx);
      l_offer_parent_line_id :=
        get_parent_d_inv_row_id(p_calc_lines(l_idx).offer_parent_line_idx);

      insert into d_inv (
        inv_no,
        catid,
        serviceid,
        servicedesc,
        price,
        qty,
        disc,
        my_disc,
        fixpay,
        payrate,
        d_inv_row_id,
        srv_state,
        my_net,
        the_fix,
        the_rate,
        the_pay,
        my_price,
        curr_code,
        teeth_no,
        tooth_surface,
        teeth_no2,
        pat_serv_req_row_id,
        approv_date,
        approv_validity,
        approv_ref_no,
        list_id,
        req_need_a,
        the_comp,
        claim_no,
        vat_rate,
        vat_val_co,
        vat_val_pat,
        vat_val_pat_ex,
        sfda_code,
        is_deleted,
        info_center_id,
        req_a_status,
        package_service_id,
        package_instance_id,
        package_line_role,
        package_component_order,
        package_parent_line_id,
        package_pricing_method,
        offer_id,
        offer_dtl_id,
        offer_type,
        offer_instance_id,
        offer_line_role,
        offer_parent_line_id,
        offer_price_applied,
        offer_dis_applied,
        offer_name_snapshot,
        offer_object_version_number,
        offer_dtl_object_version_number
      )
      values (
        p_inv_no,
        p_calc_lines(l_idx).catid,
        p_calc_lines(l_idx).serviceid,
        p_calc_lines(l_idx).servicedesc,
        p_calc_lines(l_idx).price,
        p_calc_lines(l_idx).qty,
        p_calc_lines(l_idx).disc,
        p_calc_lines(l_idx).my_disc,
        p_calc_lines(l_idx).fixpay,
        p_calc_lines(l_idx).payrate,
        l_d_inv_row_id(l_idx),
        0,
        p_calc_lines(l_idx).my_net,
        p_calc_lines(l_idx).the_fix,
        p_calc_lines(l_idx).the_rate,
        p_calc_lines(l_idx).the_pay,
        p_calc_lines(l_idx).my_price,
        p_calc_lines(l_idx).curr_code,
        p_calc_lines(l_idx).teeth_no,
        p_calc_lines(l_idx).tooth_surface,
        p_calc_lines(l_idx).teeth_no2,
        p_calc_lines(l_idx).pat_serv_req_row_id,
        p_calc_lines(l_idx).approv_date,
        p_calc_lines(l_idx).approv_validity,
        p_calc_lines(l_idx).approv_ref_no,
        p_calc_lines(l_idx).list_id,
        p_calc_lines(l_idx).req_need_a,
        p_calc_lines(l_idx).the_comp,
        p_calc_lines(l_idx).claim_no,
        p_calc_lines(l_idx).vat_rate,
        p_calc_lines(l_idx).vat_val_co,
        p_calc_lines(l_idx).vat_val_pat,
        p_calc_lines(l_idx).vat_val_pat_ex,
        p_calc_lines(l_idx).sfda_code,
        p_calc_lines(l_idx).is_deleted,
        nvl(p_calc_lines(l_idx).info_center_id, p_info_center_id),
        p_calc_lines(l_idx).req_a_status,
        p_calc_lines(l_idx).package_service_id,
        p_calc_lines(l_idx).package_instance_id,
        p_calc_lines(l_idx).package_line_role,
        p_calc_lines(l_idx).package_component_order,
        l_package_parent_line_id,
        p_calc_lines(l_idx).package_pricing_method,
        p_calc_lines(l_idx).offer_id,
        p_calc_lines(l_idx).offer_dtl_id,
        p_calc_lines(l_idx).offer_type,
        p_calc_lines(l_idx).offer_instance_id,
        p_calc_lines(l_idx).offer_line_role,
        l_offer_parent_line_id,
        p_calc_lines(l_idx).offer_price_applied,
        p_calc_lines(l_idx).offer_dis_applied,
        p_calc_lines(l_idx).offer_name_snapshot,
        p_calc_lines(l_idx).offer_object_version_number,
        p_calc_lines(l_idx).offer_dtl_object_version_number
      );
      if p_calc_lines(l_idx).pat_serv_req_row_id is not null then
        update pat_serv_req
           set d_inv_row_id = l_d_inv_row_id(l_idx)
         where pat_serv_req_row_id = p_calc_lines(l_idx).pat_serv_req_row_id
           and d_inv_row_id is null;
        if sql%rowcount <> 1 then
          raise_application_error(
            -20930,
            'Invoice create failed: request line '
            || p_calc_lines(l_idx).pat_serv_req_row_id
            || ' was already invoiced by another session.'
          );
        end if;
      end if;
      l_idx := p_calc_lines.next(l_idx);
    end loop;
  end insert_lines;

  ------------------------------------------------------------------------------
  -- Public API
  ------------------------------------------------------------------------------


  -- PAGE48_BATCH_PREVIEW: reusable read-only calculator for editable Page 48 previews.
  -- Uses the same calculate_lines path as create_invoice, including cumulative
  -- class-rule deductible tracking and central VAT/share calculation.
  procedure preview_invoice (
    p_header   in  t_header_input,
    p_lines    in  t_line_input_tab,
    o_lines    out nocopy t_preview_line_tab,
    o_result   out nocopy t_invoice_result
  )
  is
    l_header          t_header_input;
    l_lines           t_line_input_tab;
    l_patient_context bil_types.t_patient_context;
    l_calc_lines      t_calc_line_tab;
    l_result          t_invoice_result;
    l_invdate         date;
    l_paytype         t_inv.paytype%type;
    l_info_center_id  t_inv.info_center_id%type;
    l_idx             pls_integer;
  begin
    o_lines.delete;
    o_result := null;

    l_header := p_header;
    l_lines := p_lines;
    l_header.invdate := nvl(p_header.invdate, sysdate);

    assert_header_valid(l_header);

    l_invdate := l_header.invdate;
    l_info_center_id := get_effective_info_center_id(l_header.info_center_id);

    if l_header.paytype is not null then
      bil_patient_context.get_context(
        p_patientno      => l_header.patientno,
        p_invoice_date   => l_invdate,
        p_paytype        => l_header.paytype,
        p_info_center_id => l_info_center_id,
        o_context        => l_patient_context
      );
    else
      bil_patient_context.get_context(
        p_patientno    => l_header.patientno,
        p_invoice_date => l_invdate,
        p_paytype      => l_header.paytype,
        o_context      => l_patient_context
      );
    end if;

    l_paytype := get_default_paytype(
                   p_header           => l_header,
                   p_patient_context  => l_patient_context
                 );

    lock_and_refresh_request_sources(
      p_header          => l_header,
      p_paytype         => l_paytype,
      p_patient_context => l_patient_context,
      io_lines          => l_lines,
      p_lock_rows       => false
    );
    assert_lines_valid(l_lines);

    l_result.invdate := l_invdate;
    l_result.patientno := l_patient_context.patientno;

    calculate_lines(
      p_header          => l_header,
      p_patient_context => l_patient_context,
      p_paytype         => l_paytype,
      p_info_center_id  => l_info_center_id,
      p_lines           => l_lines,
      p_validate_offer_versions => false,
      o_calc_lines      => l_calc_lines,
      io_result         => l_result
    );

    l_result.finaldisc := calc_final_discount(
                            p_total_patient_share => l_result.pat_pay,
                            p_total_net           => l_result.total_net,
                            p_header              => l_header
                          );

    l_result.cash_collected :=
      round_money(l_result.pat_pay - l_result.finaldisc + l_result.vat_total_pat);

    if l_result.cash_collected < 0 then
      raise_application_error(
        -20916,
        'Invoice preview failed: cash collected cannot be negative.'
      );
    end if;

    l_idx := l_calc_lines.first;
    while l_idx is not null loop
      o_lines(l_idx).line_no             := l_idx;
      o_lines(l_idx).serviceid           := l_calc_lines(l_idx).serviceid;
      o_lines(l_idx).servicedesc         := l_calc_lines(l_idx).servicedesc;
      o_lines(l_idx).catid               := l_calc_lines(l_idx).catid;
      o_lines(l_idx).list_id             := l_calc_lines(l_idx).list_id;
      o_lines(l_idx).curr_code           := l_calc_lines(l_idx).curr_code;
      o_lines(l_idx).qty                 := l_calc_lines(l_idx).qty;
      o_lines(l_idx).price               := l_calc_lines(l_idx).price;
      o_lines(l_idx).plan_discount_pct   := l_calc_lines(l_idx).plan_discount_pct;
      o_lines(l_idx).plan_discount_amount := l_calc_lines(l_idx).plan_discount_amount;
      o_lines(l_idx).manual_discount_type := l_calc_lines(l_idx).manual_discount_type;
      o_lines(l_idx).manual_discount_pct := l_calc_lines(l_idx).manual_discount_pct;
      o_lines(l_idx).manual_discount_amount := l_calc_lines(l_idx).manual_discount_amount;
      o_lines(l_idx).discount_source     := l_calc_lines(l_idx).discount_source;
      o_lines(l_idx).disc                := l_calc_lines(l_idx).disc;
      o_lines(l_idx).my_disc             := l_calc_lines(l_idx).my_disc;
      o_lines(l_idx).fixpay              := l_calc_lines(l_idx).fixpay;
      o_lines(l_idx).payrate             := l_calc_lines(l_idx).payrate;
      o_lines(l_idx).the_fix             := l_calc_lines(l_idx).the_fix;
      o_lines(l_idx).the_rate            := l_calc_lines(l_idx).the_rate;
      o_lines(l_idx).the_pay             := l_calc_lines(l_idx).the_pay;
      o_lines(l_idx).the_comp            := l_calc_lines(l_idx).the_comp;
      o_lines(l_idx).my_price            := l_calc_lines(l_idx).my_price;
      o_lines(l_idx).my_net              := l_calc_lines(l_idx).my_net;
      o_lines(l_idx).vat_rate            := l_calc_lines(l_idx).vat_rate;
      o_lines(l_idx).vat_val_pat         := l_calc_lines(l_idx).vat_val_pat;
      o_lines(l_idx).vat_val_co          := l_calc_lines(l_idx).vat_val_co;
      o_lines(l_idx).vat_val_pat_ex      := l_calc_lines(l_idx).vat_val_pat_ex;
      o_lines(l_idx).sfda_code           := l_calc_lines(l_idx).sfda_code;
      o_lines(l_idx).pat_serv_req_row_id := l_calc_lines(l_idx).pat_serv_req_row_id;
      o_lines(l_idx).req_need_a          := l_calc_lines(l_idx).req_need_a;
      o_lines(l_idx).req_a_status        := l_calc_lines(l_idx).req_a_status;
      o_lines(l_idx).allow_manual_discount := l_calc_lines(l_idx).allow_manual_discount;
      o_lines(l_idx).allow_price_override := l_calc_lines(l_idx).allow_price_override;
      o_lines(l_idx).package_service_id  := l_calc_lines(l_idx).package_service_id;
      o_lines(l_idx).package_instance_id := l_calc_lines(l_idx).package_instance_id;
      o_lines(l_idx).package_line_role   := l_calc_lines(l_idx).package_line_role;
      o_lines(l_idx).package_component_order :=
        l_calc_lines(l_idx).package_component_order;
      o_lines(l_idx).package_parent_line_id :=
        l_calc_lines(l_idx).package_parent_line_id;
      o_lines(l_idx).package_pricing_method :=
        l_calc_lines(l_idx).package_pricing_method;
      o_lines(l_idx).package_definition_token :=
        l_calc_lines(l_idx).package_definition_token;
      o_lines(l_idx).offer_id := l_calc_lines(l_idx).offer_id;
      o_lines(l_idx).offer_dtl_id := l_calc_lines(l_idx).offer_dtl_id;
      o_lines(l_idx).offer_type := l_calc_lines(l_idx).offer_type;
      o_lines(l_idx).offer_instance_id := l_calc_lines(l_idx).offer_instance_id;
      o_lines(l_idx).offer_line_role := l_calc_lines(l_idx).offer_line_role;
      o_lines(l_idx).offer_parent_line_id := l_calc_lines(l_idx).offer_parent_line_id;
      o_lines(l_idx).offer_price_applied := l_calc_lines(l_idx).offer_price_applied;
      o_lines(l_idx).offer_dis_applied := l_calc_lines(l_idx).offer_dis_applied;
      o_lines(l_idx).offer_name_snapshot := l_calc_lines(l_idx).offer_name_snapshot;
      o_lines(l_idx).offer_object_version_number :=
        l_calc_lines(l_idx).offer_object_version_number;
      o_lines(l_idx).offer_dtl_object_version_number :=
        l_calc_lines(l_idx).offer_dtl_object_version_number;

      l_idx := l_calc_lines.next(l_idx);
    end loop;

    o_result := l_result;
  end preview_invoice;

  procedure create_invoice (
    p_header   in  t_header_input,
    p_lines    in  t_line_input_tab,
    o_result   out nocopy t_invoice_result
  )
  is
    l_header               t_header_input;
    l_lines                t_line_input_tab;
    l_patient_context      bil_types.t_patient_context;
    l_calc_lines           t_calc_line_tab;
    l_result               t_invoice_result;
    l_inv_no               t_inv.inv_no%type;
    l_invdate              date;
    l_paytype              t_inv.paytype%type;
    l_user_no              t_inv.user_no%type;
    l_machine_n            t_inv.machine_n%type;
    l_info_center_id       t_inv.info_center_id%type;
    l_shift_system_unique  t_inv.shift_system_unique%type;
  begin
    o_result := null;
    if p_header.invdate is null then
      raise_application_error(
        -20964,
        'Invoice create failed: creation date/time is required.'
      );
    end if;
    l_header := p_header;
    l_lines := p_lines;
    l_header.invdate := p_header.invdate;
    assert_header_valid(l_header);
    l_invdate        := l_header.invdate;
    l_user_no        := get_effective_user_no(l_header.user_no);
    l_machine_n      := get_effective_machine_n(l_header.machine_n);
    l_info_center_id := get_effective_info_center_id(l_header.info_center_id);
    if l_user_no is null then
      raise_application_error(
        -20915,
        'Invoice create failed: user number is required.'
      );
    end if;
    if l_header.paytype is not null then
      bil_patient_context.get_context(
        p_patientno      => l_header.patientno,
        p_invoice_date   => l_invdate,
        p_paytype        => l_header.paytype,
        p_info_center_id => l_info_center_id,
        o_context        => l_patient_context
      );
    else
      bil_patient_context.get_context(
        p_patientno    => l_header.patientno,
        p_invoice_date => l_invdate,
        p_paytype      => l_header.paytype,
        o_context      => l_patient_context
      );
    end if;
    l_paytype := get_default_paytype(
                   p_header           => l_header,
                   p_patient_context  => l_patient_context
                 );
    lock_and_refresh_request_sources(
      p_header          => l_header,
      p_paytype         => l_paytype,
      p_patient_context => l_patient_context,
      io_lines          => l_lines,
      p_lock_rows       => true
    );
    assert_lines_valid(l_lines);
    bil_cashier_shift.assert_can_create_invoice(
      p_user_no             => l_user_no,
      p_info_center_id      => p_header.info_center_id,
      o_shift_system_unique => l_shift_system_unique
    );
    l_result.invdate             := l_invdate;
    l_result.patientno           := l_patient_context.patientno;
    l_result.shift_system_unique := l_shift_system_unique;
    calculate_lines(
      p_header          => l_header,
      p_patient_context => l_patient_context,
      p_paytype         => l_paytype,
      p_info_center_id  => l_info_center_id,
      p_lines           => l_lines,
      p_validate_offer_versions => true,
      o_calc_lines      => l_calc_lines,
      io_result         => l_result
    );
    l_result.finaldisc := calc_final_discount(
                            p_total_patient_share => l_result.pat_pay,
                            p_total_net           => l_result.total_net,
                            p_header              => l_header
                          );
    l_result.cash_collected :=
      round_money(l_result.pat_pay - l_result.finaldisc + l_result.vat_total_pat);
    if l_result.cash_collected < 0 then
      raise_application_error(
        -20916,
        'Invoice create failed: cash collected cannot be negative.'
      );
    end if;
    l_inv_no := get_next_invoice_no_safe;
    l_result.inv_no := l_inv_no;
    insert_header(
      p_header              => l_header,
      p_patient_context     => l_patient_context,
      p_inv_no              => l_inv_no,
      p_paytype             => l_paytype,
      p_user_no             => l_user_no,
      p_machine_n           => l_machine_n,
      p_info_center_id      => l_info_center_id,
      p_shift_system_unique => l_shift_system_unique,
      p_result              => l_result
    );
    insert_lines(
      p_inv_no         => l_inv_no,
      p_calc_lines     => l_calc_lines,
      p_info_center_id => l_info_center_id
    );
    bil_audit.log_event(
      p_event_code   => 'INVOICE_CREATE_SUCCESS',
      p_entity_type  => 'T_INV',
      p_entity_id    => to_char(l_inv_no),
      p_inv_no       => l_inv_no,
      p_patientno    => l_patient_context.patientno,
      p_payload_json => '{"source":"BIL_INVOICE_ENGINE.CREATE_INVOICE"}',
      p_user_id      => l_user_no
    );
    o_result := l_result;
  exception
    when others then
      bil_audit.log_error(
        p_event_code    => 'INVOICE_CREATE_FAILED',
        p_entity_type   => 'T_INV',
        p_entity_id     => null,
        p_inv_no        => null,
        p_patientno     => p_header.patientno,
        p_error_message => sqlerrm,
        p_payload_json  => '{"source":"BIL_INVOICE_ENGINE.CREATE_INVOICE"}',
        p_user_id       => get_effective_user_no(p_header.user_no)
      );
      raise;
  end create_invoice;

end bil_invoice_engine;
/
