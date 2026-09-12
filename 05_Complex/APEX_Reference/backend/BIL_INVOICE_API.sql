-- migration reference extract.

create or replace package BIL_INVOICE_API authid definer as
  c_import_preview_collection constant varchar2(30) := 'BIL_IMPORT_PREVIEW_LINES';

  type t_full_invoice_result is record (
    invoice_result       bil_invoice_engine.t_invoice_result,
    payment_result       bil_payment.t_payment_result,
    queue_result         bil_queue_posting.t_queue_result,
    stock_result         bil_stock_posting.t_stock_result,
    print_result         bil_reports_print.t_print_result,
    message_result       bil_message.t_message_result,
    payment_posted       varchar2(1),
    queue_posted         varchar2(1),
    stock_posted         varchar2(1),
    print_url_built      varchar2(1),
    sms_sent             varchar2(1),
    message              varchar2(4000)
  );

  type t_preview_totals is record (
    line_count         number,
    total_gross        number,
    total_discount     number,
    total_net          number,
    pat_pay            number,
    comp_pay           number,
    vat_total_pat      number,
    vat_total_co       number,
    cash_collected     number,
    amount_1           number,
    amount_2           number,
    remaining_amount   number,
    payment_status     varchar2(30)
  );

  type t_client_id_tab is table of varchar2(4000) index by pls_integer;

  type t_editable_preview_line is record (
    client_id                        varchar2(4000),
    line_no                          number,
    serviceid                        d_inv.serviceid%type,
    servicedesc                      d_inv.servicedesc%type,
    catid                            d_inv.catid%type,
    list_id                          d_inv.list_id%type,
    curr_code                        d_inv.curr_code%type,
    qty                              d_inv.qty%type,
    price                            d_inv.price%type,
    plan_discount_pct                price_plan_dtl.price_disc%type,
    plan_discount_amount             d_inv.my_disc%type,
    manual_discount_type             varchar2(1),
    manual_discount_pct              d_inv.disc%type,
    manual_discount_amount           d_inv.my_disc%type,
    discount_source                  varchar2(20),
    disc                             d_inv.disc%type,
    my_disc                          d_inv.my_disc%type,
    my_price                         d_inv.my_price%type,
    my_net                           d_inv.my_net%type,
    the_pay                          d_inv.the_pay%type,
    the_comp                         d_inv.the_comp%type,
    vat_rate                         d_inv.vat_rate%type,
    vat_val_pat                      d_inv.vat_val_pat%type,
    vat_val_co                       d_inv.vat_val_co%type,
    vat_val_pat_ex                   d_inv.vat_val_pat_ex%type,
    req_need_a                       d_inv.req_need_a%type,
    req_a_status                     d_inv.req_a_status%type,
    allow_manual_discount            varchar2(1),
    allow_price_override             varchar2(1),
    package_service_id               d_inv.package_service_id%type,
    package_instance_id              d_inv.package_instance_id%type,
    package_line_role                d_inv.package_line_role%type,
    package_component_order          d_inv.package_component_order%type,
    package_parent_line_id           d_inv.package_parent_line_id%type,
    package_pricing_method           services.package_pricing_method%type,
    package_definition_token         varchar2(64),
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

  type t_editable_preview_line_tab is table of t_editable_preview_line index by pls_integer;

  procedure get_bundled_offer_ig_lines (
    p_patientno      in  t_inv.patientno%type,
    p_paytype        in  t_inv.paytype%type,
    p_invoice_date   in  t_inv.invdate%type,
    p_info_center_id in  t_inv.info_center_id%type,
    p_offer_id       in  offers.oferid%type,
    p_bundle_qty     in  number,
    o_lines          out nocopy t_editable_preview_line_tab
  );

  procedure expand_bundled_offer_ig_lines (
    p_visible_lines      in  bil_invoice_engine.t_line_input_tab,
    p_visible_client_ids in  t_client_id_tab,
    o_full_lines         out nocopy bil_invoice_engine.t_line_input_tab,
    o_full_client_ids    out nocopy t_client_id_tab
  );

  procedure get_package_lines (
    p_package_serviceid in  d_inv.serviceid%type,
    p_list_id           in  d_inv.list_id%type,
    p_parent_source_id  in  varchar2 default null,
    o_lines             out nocopy bil_import.t_import_line_tab,
    o_result            out nocopy bil_import.t_import_result
  );

  procedure calculate_editable_invoice_preview (
    p_header        in  bil_invoice_engine.t_header_input,
    p_lines         in  bil_invoice_engine.t_line_input_tab,
    p_client_ids    in  t_client_id_tab,
    p_amount_1      in  number default 0,
    p_amount_2      in  number default 0,
    p_amount_1_auto in  varchar2 default 'Y',
    o_lines         out nocopy t_editable_preview_line_tab,
    o_totals        out nocopy t_preview_totals
  );

  procedure build_import_preview_collection (
    p_source_mode        in varchar2,
    p_patientno          in t_inv.patientno%type,
    p_paytype            in t_inv.paytype%type,
    p_clinicid           in t_inv.clinicid%type,
    p_visit_unique       in pat_visit_m.visit_unique%type default null,
    p_app_id             in number default null,
    p_app_session_id     in varchar2 default null,
    p_app_user           in varchar2 default null,
    p_inv_date           in t_inv.invdate%type default sysdate,
    p_seed_serviceid     in d_inv.serviceid%type default null,
    p_final_disc         in number default 0,
    p_amount_1           in number default 0,
    p_amount_2           in number default 0,
    p_amount_1_auto      in varchar2 default 'Y',
    p_collection_name    in varchar2 default 'BIL_IMPORT_PREVIEW_LINES',
    p_docid              in t_inv.docid%type default null,
    p_new_visit_type     in varchar2 default null,
    p_info_center_id     in t_inv.info_center_id%type default null,
    o_totals             out nocopy t_preview_totals,
    o_import_result      out nocopy bil_import.t_import_result
  );

  procedure create_full_invoice (
    p_header                 in  bil_invoice_engine.t_header_input,
    p_lines                  in  bil_invoice_engine.t_line_input_tab,
    p_post_payment           in  varchar2 default 'Y',
    p_amount_1               in  t_inv.amount_1%type default null,
    p_amount_2               in  t_inv.amount_2%type default 0,
    p_sub_paytype            in  t_inv.sub_paytype%type default null,
    p_sub_paytype2           in  t_inv.sub_paytype2%type default null,
    p_allow_partial          in  varchar2 default 'N',
    p_allow_overpayment      in  varchar2 default 'N',
    p_post_queue             in  varchar2 default 'Y',
    p_queue_force            in  varchar2 default 'N',
    p_reserv_system_enabled  in  varchar2 default 'N',
    p_post_stock             in  varchar2 default 'Y',
    p_stock_repost           in  varchar2 default 'Y',
    p_build_print_url        in  varchar2 default 'N',
    p_send_sms               in  varchar2 default 'N',
    p_sms_template_code      in  varchar2 default bil_message.c_template_invoice_created,
    p_sms_language_code      in  varchar2 default 'BI',
    p_sms_mobile_no          in  varchar2 default null,
    o_result                 out nocopy t_full_invoice_result,
    p_request_id             in  bil_inv_draft_lines.draft_id%type default null
  );

  procedure build_print_url (
    p_request in  bil_reports_print.t_print_request,
    o_result  out nocopy bil_reports_print.t_print_result
  );

  procedure send_invoice_message (
    p_inv_no        in  t_inv.inv_no%type,
    p_template_code in  varchar2 default bil_message.c_template_invoice_created,
    p_language_code in  varchar2 default 'BI',
    p_mobile_no     in  varchar2 default null,
    p_user_id       in  number default null,
    o_result        out nocopy bil_message.t_message_result
  );

end bil_invoice_api;
/

create or replace package body BIL_INVOICE_API as

  function is_yes (
    p_value in varchar2
  ) return boolean
  is
  begin
    return upper(trim(nvl(p_value, 'N'))) in ('Y', 'YES', '1', 'TRUE');
  end is_yes;


  function money (
    p_value in number
  ) return number
  is
  begin
    return round(nvl(p_value, 0), 2);
  end money;


  procedure build_print_url (
    p_request in  bil_reports_print.t_print_request,
    o_result  out nocopy bil_reports_print.t_print_result
  )
  is
  begin
    bil_reports_print.build_print_url(
      p_request => p_request,
      o_result  => o_result
    );
  end build_print_url;


  procedure send_invoice_message (
    p_inv_no        in  t_inv.inv_no%type,
    p_template_code in  varchar2 default bil_message.c_template_invoice_created,
    p_language_code in  varchar2 default 'BI',
    p_mobile_no     in  varchar2 default null,
    p_user_id       in  number default null,
    o_result        out nocopy bil_message.t_message_result
  )
  is
  begin
    bil_message.send_invoice_message(
      p_inv_no        => p_inv_no,
      p_template_code => p_template_code,
      p_language_code => p_language_code,
      p_mobile_no     => p_mobile_no,
      p_user_id       => p_user_id,
      o_result        => o_result
    );
  end send_invoice_message;


  procedure get_package_lines (
    p_package_serviceid in  d_inv.serviceid%type,
    p_list_id           in  d_inv.list_id%type,
    p_parent_source_id  in  varchar2 default null,
    o_lines             out nocopy bil_import.t_import_line_tab,
    o_result            out nocopy bil_import.t_import_result
  )
  is
  begin
    bil_import.get_package_lines(
      p_package_serviceid => p_package_serviceid,
      p_list_id           => p_list_id,
      p_parent_source_id  => p_parent_source_id,
      o_lines             => o_lines,
      o_result            => o_result
    );
  end get_package_lines;


  procedure get_bundled_offer_ig_lines (
    p_patientno      in  t_inv.patientno%type,
    p_paytype        in  t_inv.paytype%type,
    p_invoice_date   in  t_inv.invdate%type,
    p_info_center_id in  t_inv.info_center_id%type,
    p_offer_id       in  offers.oferid%type,
    p_bundle_qty     in  number,
    o_lines          out nocopy t_editable_preview_line_tab
  )
  is
    l_patient         bil_types.t_patient_context;
    l_bundle_header   bil_offer_rule.t_bundle_header;
    l_bundle_details  bil_offer_rule.t_bundle_detail_tab;
    l_header          bil_invoice_engine.t_header_input;
    l_full_lines      bil_invoice_engine.t_line_input_tab;
    l_full_client_ids t_client_id_tab;
    l_preview_lines   t_editable_preview_line_tab;
    l_totals          t_preview_totals;
    l_instance_id     d_inv.offer_instance_id%type;
    l_detail_idx      pls_integer;
    l_line_idx        pls_integer := 1;
    l_out_idx         pls_integer := 0;
    l_parent_token    d_inv.offer_parent_line_id%type := -1;
  begin
    o_lines.delete;

    if p_patientno is null
       or p_paytype is null
       or p_invoice_date is null
       or p_info_center_id is null
       or p_offer_id is null
    then
      raise_application_error(
        -20979,
        'Patient, payer type, invoice date, info center and Bundled Offer are required.'
      );
    end if;

    if p_bundle_qty is null
       or p_bundle_qty <= 0
       or p_bundle_qty <> trunc(p_bundle_qty)
    then
      raise_application_error(
        -20979,
        'Bundled Offer quantity must be a positive whole number.'
      );
    end if;

    if p_paytype <> 1 then
      raise_application_error(
        -20871,
        'Bundled Offers are available only for Cash invoices.'
      );
    end if;

    bil_patient_context.get_context(
      p_patientno      => p_patientno,
      p_invoice_date   => p_invoice_date,
      p_paytype        => p_paytype,
      p_info_center_id => p_info_center_id,
      o_context        => l_patient
    );

    bil_offer_rule.load_bundled_offer(
      p_offer_id       => p_offer_id,
      p_info_center_id => p_info_center_id,
      p_cash_list_id   => l_patient.list_id,
      p_paytype        => p_paytype,
      p_invoice_date   => p_invoice_date,
      o_header         => l_bundle_header,
      o_details        => l_bundle_details
    );

    l_instance_id := rawtohex(sys_guid());

    l_full_lines(1).serviceid := null;
    l_full_lines(1).qty := p_bundle_qty;
    l_full_lines(1).price_override := null;
    l_full_lines(1).use_price_override := 'N';
    l_full_lines(1).discount_type := 'N';
    l_full_lines(1).disc := 0;
    l_full_lines(1).my_disc := 0;
    l_full_lines(1).offer_id := l_bundle_header.offer_id;
    l_full_lines(1).offer_dtl_id := null;
    l_full_lines(1).offer_type := 0;
    l_full_lines(1).offer_instance_id := l_instance_id;
    l_full_lines(1).offer_line_role := 'PARENT';
    l_full_lines(1).offer_parent_line_id := null;
    l_full_lines(1).offer_price_applied := 0;
    l_full_lines(1).offer_dis_applied := 0;
    l_full_lines(1).offer_name_snapshot := l_bundle_header.offer_name;
    l_full_lines(1).offer_object_version_number :=
      l_bundle_header.offer_object_version;
    l_full_lines(1).offer_dtl_object_version_number := null;

    l_detail_idx := l_bundle_details.first;
    while l_detail_idx is not null loop
      l_line_idx := l_line_idx + 1;
      l_full_lines(l_line_idx).serviceid :=
        l_bundle_details(l_detail_idx).serviceid;
      l_full_lines(l_line_idx).qty :=
        p_bundle_qty * l_bundle_details(l_detail_idx).qty;
      l_full_lines(l_line_idx).price_override := null;
      l_full_lines(l_line_idx).use_price_override := 'N';
      l_full_lines(l_line_idx).discount_type := 'N';
      l_full_lines(l_line_idx).disc := 0;
      l_full_lines(l_line_idx).my_disc := 0;
      l_full_lines(l_line_idx).offer_id := l_bundle_header.offer_id;
      l_full_lines(l_line_idx).offer_dtl_id :=
        l_bundle_details(l_detail_idx).offer_dtl_id;
      l_full_lines(l_line_idx).offer_type := 0;
      l_full_lines(l_line_idx).offer_instance_id := l_instance_id;
      l_full_lines(l_line_idx).offer_line_role := 'COMPONENT';
      l_full_lines(l_line_idx).offer_parent_line_id := l_parent_token;
      l_full_lines(l_line_idx).offer_price_applied :=
        l_bundle_details(l_detail_idx).offer_price;
      l_full_lines(l_line_idx).offer_dis_applied := 0;
      l_full_lines(l_line_idx).offer_name_snapshot := null;
      l_full_lines(l_line_idx).offer_object_version_number :=
        l_bundle_header.offer_object_version;
      l_full_lines(l_line_idx).offer_dtl_object_version_number :=
        l_bundle_details(l_detail_idx).detail_object_version;
      l_full_client_ids(l_line_idx) :=
        l_instance_id || ':' || l_bundle_details(l_detail_idx).offer_dtl_id;

      l_detail_idx := l_bundle_details.next(l_detail_idx);
    end loop;

    l_header.patientno := p_patientno;
    l_header.invdate := p_invoice_date;
    l_header.paytype := p_paytype;
    l_header.info_center_id := p_info_center_id;

    calculate_editable_invoice_preview(
      p_header        => l_header,
      p_lines         => l_full_lines,
      p_client_ids    => l_full_client_ids,
      p_amount_1      => 0,
      p_amount_2      => 0,
      p_amount_1_auto => 'Y',
      o_lines         => l_preview_lines,
      o_totals        => l_totals
    );

    l_line_idx := l_preview_lines.first;
    while l_line_idx is not null loop
      if l_preview_lines(l_line_idx).offer_type = 0
         and upper(trim(l_preview_lines(l_line_idx).offer_line_role)) = 'COMPONENT'
      then
        l_out_idx := l_out_idx + 1;
        o_lines(l_out_idx) := l_preview_lines(l_line_idx);
      end if;
      l_line_idx := l_preview_lines.next(l_line_idx);
    end loop;
  end get_bundled_offer_ig_lines;


  procedure expand_bundled_offer_ig_lines (
    p_visible_lines      in  bil_invoice_engine.t_line_input_tab,
    p_visible_client_ids in  t_client_id_tab,
    o_full_lines         out nocopy bil_invoice_engine.t_line_input_tab,
    o_full_client_ids    out nocopy t_client_id_tab
  )
  is
    type t_instance_set is table of pls_integer index by varchar2(64);
    type t_input_set is table of pls_integer index by pls_integer;

    l_processed_instances t_instance_set;
    l_consumed_inputs     t_input_set;
    l_idx                 pls_integer;
    l_out_idx             pls_integer := 0;
    l_instance_id         d_inv.offer_instance_id%type;
    l_role                d_inv.offer_line_role%type;

    procedure raise_ig_mismatch (
      p_message in varchar2
    ) is
    begin
      raise_application_error(
        -20978,
        'Bundled Offer invoice rows are invalid. ' || p_message
      );
    end raise_ig_mismatch;

    function same_number (
      p_left  in number,
      p_right in number
    ) return boolean
    is
    begin
      if p_left is null and p_right is null then
        return true;
      end if;
      if p_left is null or p_right is null then
        return false;
      end if;
      return abs(p_left - p_right) < 0.0000001;
    end same_number;

    function uses_price_override (
      p_line in bil_invoice_engine.t_line_input
    ) return boolean
    is
    begin
      return p_line.price_override is not null
        or upper(trim(nvl(p_line.use_price_override, 'N'))) in
             ('Y', 'YES', '1', 'TRUE');
    end uses_price_override;

    function has_manual_discount (
      p_line in bil_invoice_engine.t_line_input
    ) return boolean
    is
    begin
      return upper(trim(nvl(p_line.discount_type, 'N'))) <> 'N'
        or nvl(p_line.disc, 0) <> 0
        or nvl(p_line.my_disc, 0) <> 0;
    end has_manual_discount;

    procedure append_visible_line (
      p_input_idx in pls_integer
    ) is
    begin
      l_out_idx := l_out_idx + 1;
      o_full_lines(l_out_idx) := p_visible_lines(p_input_idx);
      if p_visible_client_ids.exists(p_input_idx) then
        o_full_client_ids(l_out_idx) := p_visible_client_ids(p_input_idx);
      end if;
    end append_visible_line;

    procedure append_occurrence (
      p_instance_id in d_inv.offer_instance_id%type
    )
    is
      l_bundle_header     bil_offer_rule.t_bundle_header;
      l_bundle_details    bil_offer_rule.t_bundle_detail_tab;
      l_offer_id          d_inv.offer_id%type;
      l_parent_token      d_inv.offer_parent_line_id%type;
      l_bundle_qty        number;
      l_candidate_qty     number;
      l_detail_idx        pls_integer := 0;
      l_input_idx         pls_integer;
      l_match_idx         pls_integer;
      l_match_count       pls_integer;
      l_group_count       pls_integer := 0;
      l_service_count     pls_integer;

      procedure find_visible_component (
        p_offer_dtl_id in  d_inv.offer_dtl_id%type,
        o_input_idx    out pls_integer,
        o_match_count  out pls_integer
      ) is
        l_find_idx pls_integer;
      begin
        o_input_idx := null;
        o_match_count := 0;
        l_find_idx := p_visible_lines.first;
        while l_find_idx is not null loop
          if p_visible_lines(l_find_idx).offer_type = 0
             and trim(p_visible_lines(l_find_idx).offer_instance_id) = p_instance_id
             and p_visible_lines(l_find_idx).offer_dtl_id = p_offer_dtl_id
          then
            o_match_count := o_match_count + 1;
            o_input_idx := l_find_idx;
          end if;
          l_find_idx := p_visible_lines.next(l_find_idx);
        end loop;
      end find_visible_component;
    begin
      l_input_idx := p_visible_lines.first;
      while l_input_idx is not null loop
        if p_visible_lines(l_input_idx).offer_type = 0
           and trim(p_visible_lines(l_input_idx).offer_instance_id) = p_instance_id
        then
          l_group_count := l_group_count + 1;
          l_role := upper(trim(p_visible_lines(l_input_idx).offer_line_role));
          if l_role <> 'COMPONENT'
             or p_visible_lines(l_input_idx).offer_id is null
             or p_visible_lines(l_input_idx).offer_dtl_id is null
          then
            raise_ig_mismatch('Only complete component rows may be submitted by the IG.');
          end if;

          if l_offer_id is null then
            l_offer_id := p_visible_lines(l_input_idx).offer_id;
            l_parent_token := p_visible_lines(l_input_idx).offer_parent_line_id;
          elsif l_offer_id <> p_visible_lines(l_input_idx).offer_id then
            raise_ig_mismatch('One occurrence contains more than one OFFER_ID.');
          end if;

          if p_visible_lines(l_input_idx).offer_parent_line_id is null
             or l_parent_token <> p_visible_lines(l_input_idx).offer_parent_line_id
          then
            raise_ig_mismatch('Component parent evidence is missing or inconsistent.');
          end if;
        end if;
        l_input_idx := p_visible_lines.next(l_input_idx);
      end loop;

      if l_group_count = 0 or l_offer_id is null then
        raise_ig_mismatch('The selected bundle occurrence has no components.');
      end if;

      begin
        select o.oferid,
               o.offer_name,
               o.list_id,
               o.offer_info_center,
               o.object_version_number
          into l_bundle_header.offer_id,
               l_bundle_header.offer_name,
               l_bundle_header.list_id,
               l_bundle_header.info_center_id,
               l_bundle_header.offer_object_version
          from offers o
         where o.oferid = l_offer_id
           and o.offer_type = 0
           and o.is_deleted = 'N';
      exception
        when no_data_found then
          raise_ig_mismatch('The Bundled Offer is deleted, retired or unavailable.');
        when too_many_rows then
          raise_ig_mismatch('The Bundled Offer identity is not unique.');
      end;

      for r in (
        select d.row_id offer_dtl_id,
               d.serviceid,
               d.qty,
               d.offer_price,
               d.object_version_number detail_object_version
          from offers_dtl d
         where d.oferid = l_offer_id
           and d.list_id = l_bundle_header.list_id
           and d.is_deleted = 'N'
         order by d.row_id
      ) loop
        if r.qty is null
           or r.qty <= 0
           or r.qty <> trunc(r.qty)
           or r.offer_price is null
           or r.offer_price < 0
        then
          raise_ig_mismatch('The Bundled Offer has invalid component setup.');
        end if;

        select count(*)
          into l_service_count
          from services s
         where s.serviceid = r.serviceid
           and s.list_id = l_bundle_header.list_id;
        if l_service_count <> 1 then
          raise_ig_mismatch('A component service is outside the offer Cash list.');
        end if;

        l_detail_idx := l_detail_idx + 1;
        l_bundle_details(l_detail_idx).offer_dtl_id := r.offer_dtl_id;
        l_bundle_details(l_detail_idx).serviceid := r.serviceid;
        l_bundle_details(l_detail_idx).qty := r.qty;
        l_bundle_details(l_detail_idx).offer_price := r.offer_price;
        l_bundle_details(l_detail_idx).detail_object_version :=
          r.detail_object_version;
      end loop;

      if l_bundle_details.count = 0 then
        raise_ig_mismatch('The Bundled Offer has no active components.');
      end if;

      l_detail_idx := l_bundle_details.first;
      while l_detail_idx is not null loop
        find_visible_component(
          p_offer_dtl_id => l_bundle_details(l_detail_idx).offer_dtl_id,
          o_input_idx    => l_match_idx,
          o_match_count  => l_match_count
        );

        if l_match_count <> 1 then
          raise_ig_mismatch('Every active component must appear exactly once.');
        end if;

        if p_visible_lines(l_match_idx).serviceid is null
           or p_visible_lines(l_match_idx).serviceid <>
                l_bundle_details(l_detail_idx).serviceid
           or p_visible_lines(l_match_idx).offer_id <> l_bundle_header.offer_id
           or upper(trim(p_visible_lines(l_match_idx).offer_line_role)) <> 'COMPONENT'
           or not same_number(
                    p_visible_lines(l_match_idx).offer_price_applied,
                    l_bundle_details(l_detail_idx).offer_price
                  )
           or not same_number(p_visible_lines(l_match_idx).offer_dis_applied, 0)
           or p_visible_lines(l_match_idx).offer_name_snapshot is not null
           or not same_number(
                    p_visible_lines(l_match_idx).offer_object_version_number,
                    l_bundle_header.offer_object_version
                  )
           or not same_number(
                    p_visible_lines(l_match_idx).offer_dtl_object_version_number,
                    l_bundle_details(l_detail_idx).detail_object_version
                  )
           or uses_price_override(p_visible_lines(l_match_idx))
           or has_manual_discount(p_visible_lines(l_match_idx))
           or p_visible_lines(l_match_idx).package_service_id is not null
           or p_visible_lines(l_match_idx).package_instance_id is not null
           or p_visible_lines(l_match_idx).package_line_role is not null
           or p_visible_lines(l_match_idx).package_component_order is not null
           or p_visible_lines(l_match_idx).package_parent_line_id is not null
           or p_visible_lines(l_match_idx).package_definition_token is not null
        then
          raise_ig_mismatch('Component evidence does not match the current offer definition.');
        end if;

        if p_visible_lines(l_match_idx).qty is null
           or p_visible_lines(l_match_idx).qty <= 0
        then
          raise_ig_mismatch('Component quantity is invalid.');
        end if;

        l_candidate_qty :=
          p_visible_lines(l_match_idx).qty / l_bundle_details(l_detail_idx).qty;
        if l_candidate_qty <= 0 or l_candidate_qty <> trunc(l_candidate_qty) then
          raise_ig_mismatch('Component quantity does not represent a whole bundle quantity.');
        end if;

        if l_bundle_qty is null then
          l_bundle_qty := l_candidate_qty;
        elsif not same_number(l_bundle_qty, l_candidate_qty) then
          raise_ig_mismatch('Component quantities do not represent one bundle quantity.');
        end if;

        l_detail_idx := l_bundle_details.next(l_detail_idx);
      end loop;

      if l_group_count <> l_bundle_details.count then
        raise_ig_mismatch('The occurrence contains missing or unexpected components.');
      end if;

      l_out_idx := l_out_idx + 1;
      o_full_lines(l_out_idx).serviceid := null;
      o_full_lines(l_out_idx).qty := l_bundle_qty;
      o_full_lines(l_out_idx).price_override := null;
      o_full_lines(l_out_idx).use_price_override := 'N';
      o_full_lines(l_out_idx).discount_type := 'N';
      o_full_lines(l_out_idx).disc := 0;
      o_full_lines(l_out_idx).my_disc := 0;
      o_full_lines(l_out_idx).offer_id := l_bundle_header.offer_id;
      o_full_lines(l_out_idx).offer_dtl_id := null;
      o_full_lines(l_out_idx).offer_type := 0;
      o_full_lines(l_out_idx).offer_instance_id := p_instance_id;
      o_full_lines(l_out_idx).offer_line_role := 'PARENT';
      o_full_lines(l_out_idx).offer_parent_line_id := null;
      o_full_lines(l_out_idx).offer_price_applied := 0;
      o_full_lines(l_out_idx).offer_dis_applied := 0;
      o_full_lines(l_out_idx).offer_name_snapshot := l_bundle_header.offer_name;
      o_full_lines(l_out_idx).offer_object_version_number :=
        l_bundle_header.offer_object_version;
      o_full_lines(l_out_idx).offer_dtl_object_version_number := null;

      l_detail_idx := l_bundle_details.first;
      while l_detail_idx is not null loop
        find_visible_component(
          p_offer_dtl_id => l_bundle_details(l_detail_idx).offer_dtl_id,
          o_input_idx    => l_match_idx,
          o_match_count  => l_match_count
        );

        l_out_idx := l_out_idx + 1;
        o_full_lines(l_out_idx) := p_visible_lines(l_match_idx);
        if p_visible_client_ids.exists(l_match_idx) then
          o_full_client_ids(l_out_idx) := p_visible_client_ids(l_match_idx);
        end if;
        l_consumed_inputs(l_match_idx) := 1;

        l_detail_idx := l_bundle_details.next(l_detail_idx);
      end loop;

      l_processed_instances(p_instance_id) := 1;
    end append_occurrence;
  begin
    o_full_lines.delete;
    o_full_client_ids.delete;

    l_idx := p_visible_lines.first;
    while l_idx is not null loop
      l_role := upper(trim(p_visible_lines(l_idx).offer_line_role));

      if p_visible_lines(l_idx).offer_type = 0 then
        l_instance_id := trim(p_visible_lines(l_idx).offer_instance_id);
        if l_instance_id is null or l_role <> 'COMPONENT' then
          raise_ig_mismatch('A visible bundle row has invalid occurrence identity.');
        end if;

        if not l_processed_instances.exists(l_instance_id) then
          append_occurrence(l_instance_id);
        end if;
      else
        if p_visible_lines(l_idx).offer_instance_id is not null
           or l_role in ('PARENT', 'COMPONENT')
        then
          raise_ig_mismatch('A visible row contains incomplete bundle identity.');
        end if;
        append_visible_line(l_idx);
      end if;

      l_idx := p_visible_lines.next(l_idx);
    end loop;

    l_idx := p_visible_lines.first;
    while l_idx is not null loop
      if p_visible_lines(l_idx).offer_type = 0
         and not l_consumed_inputs.exists(l_idx)
      then
        raise_ig_mismatch('A visible component does not match its bundle occurrence.');
      end if;
      l_idx := p_visible_lines.next(l_idx);
    end loop;
  end expand_bundled_offer_ig_lines;


  procedure calculate_editable_invoice_preview (
    p_header        in  bil_invoice_engine.t_header_input,
    p_lines         in  bil_invoice_engine.t_line_input_tab,
    p_client_ids    in  t_client_id_tab,
    p_amount_1      in  number default 0,
    p_amount_2      in  number default 0,
    p_amount_1_auto in  varchar2 default 'Y',
    o_lines         out nocopy t_editable_preview_line_tab,
    o_totals        out nocopy t_preview_totals
  )
  is
    l_engine_lines bil_invoice_engine.t_preview_line_tab;
    l_result       bil_invoice_engine.t_invoice_result;
    l_idx          pls_integer;
    l_input_idx    pls_integer;
  begin
    o_lines.delete;

    o_totals.line_count        := 0;
    o_totals.total_gross       := 0;
    o_totals.total_discount    := 0;
    o_totals.total_net         := 0;
    o_totals.pat_pay           := 0;
    o_totals.comp_pay          := 0;
    o_totals.vat_total_pat     := 0;
    o_totals.vat_total_co      := 0;
    o_totals.cash_collected    := 0;
    o_totals.amount_1          := 0;
    o_totals.amount_2          := 0;
    o_totals.remaining_amount  := 0;
    o_totals.payment_status    := null;

    bil_invoice_engine.preview_invoice(
      p_header => p_header,
      p_lines  => p_lines,
      o_lines  => l_engine_lines,
      o_result => l_result
    );

    l_idx := l_engine_lines.first;
    while l_idx is not null loop
      if l_engine_lines(l_idx).offer_type = 0 then
        l_input_idx := p_lines.first;
        while l_input_idx is not null loop
          exit when p_lines(l_input_idx).offer_type = 0
            and p_lines(l_input_idx).offer_instance_id =
                  l_engine_lines(l_idx).offer_instance_id
            and p_lines(l_input_idx).offer_line_role =
                  l_engine_lines(l_idx).offer_line_role
            and (p_lines(l_input_idx).offer_dtl_id = l_engine_lines(l_idx).offer_dtl_id
                 or (p_lines(l_input_idx).offer_dtl_id is null
                     and l_engine_lines(l_idx).offer_dtl_id is null));
          l_input_idx := p_lines.next(l_input_idx);
        end loop;
      elsif l_engine_lines(l_idx).package_instance_id is not null then
        l_input_idx := p_lines.first;
        while l_input_idx is not null loop
          exit when p_lines(l_input_idx).package_instance_id =
                    l_engine_lines(l_idx).package_instance_id
            and p_lines(l_input_idx).package_line_role =
                  l_engine_lines(l_idx).package_line_role
            and (
                  p_lines(l_input_idx).package_component_order =
                    l_engine_lines(l_idx).package_component_order
                  or (
                       p_lines(l_input_idx).package_component_order is null
                       and l_engine_lines(l_idx).package_component_order is null
                     )
                );
          l_input_idx := p_lines.next(l_input_idx);
        end loop;
      else
        l_input_idx := l_idx;
      end if;

      if l_input_idx is not null and p_client_ids.exists(l_input_idx) then
        o_lines(l_idx).client_id := p_client_ids(l_input_idx);
      elsif p_client_ids.exists(l_idx) then
        o_lines(l_idx).client_id := p_client_ids(l_idx);
      end if;

      o_lines(l_idx).line_no := l_engine_lines(l_idx).line_no;
      o_lines(l_idx).serviceid := l_engine_lines(l_idx).serviceid;
      o_lines(l_idx).servicedesc := l_engine_lines(l_idx).servicedesc;
      o_lines(l_idx).catid := l_engine_lines(l_idx).catid;
      o_lines(l_idx).list_id := l_engine_lines(l_idx).list_id;
      o_lines(l_idx).curr_code := l_engine_lines(l_idx).curr_code;
      o_lines(l_idx).qty := l_engine_lines(l_idx).qty;
      o_lines(l_idx).price := l_engine_lines(l_idx).price;
      o_lines(l_idx).plan_discount_pct := l_engine_lines(l_idx).plan_discount_pct;
      o_lines(l_idx).plan_discount_amount := l_engine_lines(l_idx).plan_discount_amount;
      o_lines(l_idx).manual_discount_type := l_engine_lines(l_idx).manual_discount_type;
      o_lines(l_idx).manual_discount_pct := l_engine_lines(l_idx).manual_discount_pct;
      o_lines(l_idx).manual_discount_amount := l_engine_lines(l_idx).manual_discount_amount;
      o_lines(l_idx).discount_source := l_engine_lines(l_idx).discount_source;
      o_lines(l_idx).disc := l_engine_lines(l_idx).disc;
      o_lines(l_idx).my_disc := l_engine_lines(l_idx).my_disc;
      o_lines(l_idx).my_price := l_engine_lines(l_idx).my_price;
      o_lines(l_idx).my_net := l_engine_lines(l_idx).my_net;
      o_lines(l_idx).the_pay := l_engine_lines(l_idx).the_pay;
      o_lines(l_idx).the_comp := l_engine_lines(l_idx).the_comp;
      o_lines(l_idx).vat_rate := l_engine_lines(l_idx).vat_rate;
      o_lines(l_idx).vat_val_pat := l_engine_lines(l_idx).vat_val_pat;
      o_lines(l_idx).vat_val_co := l_engine_lines(l_idx).vat_val_co;
      o_lines(l_idx).vat_val_pat_ex := l_engine_lines(l_idx).vat_val_pat_ex;
      o_lines(l_idx).req_need_a := l_engine_lines(l_idx).req_need_a;
      o_lines(l_idx).req_a_status := l_engine_lines(l_idx).req_a_status;
      o_lines(l_idx).allow_manual_discount := l_engine_lines(l_idx).allow_manual_discount;
      o_lines(l_idx).allow_price_override := l_engine_lines(l_idx).allow_price_override;
      o_lines(l_idx).package_service_id := l_engine_lines(l_idx).package_service_id;
      o_lines(l_idx).package_instance_id := l_engine_lines(l_idx).package_instance_id;
      o_lines(l_idx).package_line_role := l_engine_lines(l_idx).package_line_role;
      o_lines(l_idx).package_component_order := l_engine_lines(l_idx).package_component_order;
      o_lines(l_idx).package_parent_line_id := l_engine_lines(l_idx).package_parent_line_id;
      o_lines(l_idx).package_pricing_method := l_engine_lines(l_idx).package_pricing_method;
      o_lines(l_idx).package_definition_token := l_engine_lines(l_idx).package_definition_token;
      o_lines(l_idx).offer_id := l_engine_lines(l_idx).offer_id;
      o_lines(l_idx).offer_dtl_id := l_engine_lines(l_idx).offer_dtl_id;
      o_lines(l_idx).offer_type := l_engine_lines(l_idx).offer_type;
      o_lines(l_idx).offer_instance_id := l_engine_lines(l_idx).offer_instance_id;
      o_lines(l_idx).offer_line_role := l_engine_lines(l_idx).offer_line_role;
      o_lines(l_idx).offer_parent_line_id := l_engine_lines(l_idx).offer_parent_line_id;
      o_lines(l_idx).offer_price_applied := l_engine_lines(l_idx).offer_price_applied;
      o_lines(l_idx).offer_dis_applied := l_engine_lines(l_idx).offer_dis_applied;
      o_lines(l_idx).offer_name_snapshot := l_engine_lines(l_idx).offer_name_snapshot;
      o_lines(l_idx).offer_object_version_number :=
        l_engine_lines(l_idx).offer_object_version_number;
      o_lines(l_idx).offer_dtl_object_version_number :=
        l_engine_lines(l_idx).offer_dtl_object_version_number;

      l_idx := l_engine_lines.next(l_idx);
    end loop;

    o_totals.line_count := l_result.line_count;
    o_totals.total_gross := l_result.total_gross;
    o_totals.total_discount := l_result.total_discount;
    o_totals.total_net := l_result.total_net;
    o_totals.pat_pay := l_result.pat_pay;
    o_totals.comp_pay := l_result.comp_pay;
    o_totals.vat_total_pat := l_result.vat_total_pat;
    o_totals.vat_total_co := l_result.vat_total_co;
    o_totals.cash_collected := l_result.cash_collected;
    o_totals.amount_2 := money(nvl(p_amount_2, 0));

    if is_yes(p_amount_1_auto) then
      o_totals.amount_1 := greatest(money(o_totals.cash_collected - o_totals.amount_2), 0);
    else
      o_totals.amount_1 := money(nvl(p_amount_1, 0));
    end if;

    o_totals.remaining_amount :=
      money(o_totals.cash_collected - o_totals.amount_1 - o_totals.amount_2);

    o_totals.payment_status :=
      case
        when o_totals.cash_collected = 0 then 'No Amount Due'
        when o_totals.amount_1 + o_totals.amount_2 = 0 then 'Unpaid'
        when o_totals.amount_1 + o_totals.amount_2 < o_totals.cash_collected then 'Partial'
        when o_totals.amount_1 + o_totals.amount_2 = o_totals.cash_collected then 'Paid'
        else 'Overpaid'
      end;
  end calculate_editable_invoice_preview;


  procedure build_import_preview_collection (
    p_source_mode        in varchar2,
    p_patientno          in t_inv.patientno%type,
    p_paytype            in t_inv.paytype%type,
    p_clinicid           in t_inv.clinicid%type,
    p_visit_unique       in pat_visit_m.visit_unique%type,
    p_app_id             in number,
    p_app_session_id     in varchar2,
    p_app_user           in varchar2,
    p_inv_date           in t_inv.invdate%type,
    p_seed_serviceid     in d_inv.serviceid%type,
    p_final_disc         in number,
    p_amount_1           in number,
    p_amount_2           in number,
    p_amount_1_auto      in varchar2,
    p_collection_name    in varchar2,
    p_docid              in t_inv.docid%type,
    p_new_visit_type     in varchar2,
    p_info_center_id     in t_inv.info_center_id%type,
    o_totals             out nocopy t_preview_totals,
    o_import_result      out nocopy bil_import.t_import_result
  )
  is
    l_collection_name varchar2(255) :=
      upper(trim(nvl(p_collection_name, c_import_preview_collection)));
    l_source_mode varchar2(30) := upper(trim(p_source_mode));
    l_invoice_datetime t_inv.invdate%type := nvl(p_inv_date, sysdate);
    l_import_lines bil_import.t_import_line_tab;
    l_result bil_import.t_import_result;
    l_line bil_import.t_import_line;
    l_idx pls_integer;
    l_engine_lines bil_invoice_engine.t_line_input_tab;
    l_preview_lines bil_invoice_engine.t_preview_line_tab;
    l_preview_result bil_invoice_engine.t_invoice_result;
    l_preview_header bil_invoice_engine.t_header_input;
    l_patient_context bil_types.t_patient_context;
    l_service_context bil_types.t_service_context;
    l_effective_seed_serviceid d_inv.serviceid%type;

    procedure init_totals is
    begin
      o_totals.line_count := 0;
      o_totals.total_gross := 0;
      o_totals.total_discount := 0;
      o_totals.total_net := 0;
      o_totals.pat_pay := 0;
      o_totals.comp_pay := 0;
      o_totals.vat_total_pat := 0;
      o_totals.vat_total_co := 0;
      o_totals.cash_collected := 0;
      o_totals.amount_1 := 0;
      o_totals.amount_2 := 0;
      o_totals.remaining_amount := 0;
      o_totals.payment_status := null;
    end init_totals;

    procedure add_line (
      p_line in bil_import.t_import_line,
      p_calc in bil_invoice_engine.t_preview_line
    ) is
    begin
      if p_line.qty is null or p_line.qty <= 0 or p_line.qty <> trunc(p_line.qty) then
        raise_application_error(-20896, 'Imported service quantity must be a positive whole number.');
      end if;

      apex_collection.add_member(
        p_collection_name => l_collection_name,
        p_c001 => p_line.source_type,
        p_c002 => p_line.source_id,
        p_c003 => p_line.serviceid,
        p_c004 => nvl(p_line.discount_type, 'N'),
        p_c005 => nvl(p_line.has_price_override, 'N'),
        p_c006 => p_line.teeth_no,
        p_c007 => p_line.tooth_surface,
        p_c008 => p_line.teeth_no2,
        p_c009 => p_line.approv_ref_no,
        p_c010 => p_line.claim_no,
        p_c011 => to_char(p_line.req_need_a),
        p_c012 => to_char(p_line.req_a_status),
        p_c013 => to_char(p_line.pat_serv_req_row_id),
        p_c014 => p_line.package_service_id,
        p_c015 => p_line.package_instance_id,
        p_c016 => p_line.package_line_role,
        p_c017 => to_char(p_line.package_component_order),
        p_c018 => to_char(p_line.package_parent_line_id),
        p_c019 => p_line.package_pricing_method,
        p_c040 => p_line.package_definition_token,
        p_c020 => to_char(p_calc.price),
        p_c021 => to_char(p_calc.my_price),
        p_c022 => to_char(p_calc.my_net),
        p_c023 => to_char(p_calc.the_pay),
        p_c024 => to_char(p_calc.the_comp),
        p_c025 => to_char(p_calc.vat_val_pat),
        p_c026 => to_char(p_calc.vat_val_co),
        p_n001 => p_line.qty,
        p_n002 => nvl(p_line.disc, 0),
        p_n003 => nvl(p_line.my_disc, 0),
        p_n004 => p_line.price_override,
        p_n005 => p_line.approv_validity,
        p_d001 => p_line.approv_date
      );
    end add_line;

  begin
    init_totals;

    if l_collection_name is null then
      raise_application_error(-20890, 'Import preview collection name is required.');
    end if;

    if l_source_mode is null or l_source_mode not in ('NEW_VISIT', 'REQUEST') then
      raise_application_error(-20891, 'Invalid import preview source mode.');
    end if;

    if p_patientno is null then
      raise_application_error(-20892, 'Import preview patient number is required.');
    end if;

    if p_paytype is null or p_paytype not in (1, 2) then
      raise_application_error(-20893, 'Import preview pay type must be Cash or Credit.');
    end if;

    apex_collection.create_or_truncate_collection(l_collection_name);

    if l_source_mode = 'NEW_VISIT' then
      bil_import.get_visit_line(
        p_patientno => p_patientno,
        p_docid => p_docid,
        p_new_visit_type => p_new_visit_type,
        p_paytype => p_paytype,
        p_clinicid => p_clinicid,
        p_info_center_id => p_info_center_id,
        p_invoice_date => l_invoice_datetime,
        o_line => l_line,
        o_result => l_result
      );

      l_effective_seed_serviceid := l_line.serviceid;

      if p_seed_serviceid is not null and p_seed_serviceid <> l_effective_seed_serviceid then
        raise_application_error(
          -20894,
          'The new-visit service changed for the selected payer context. Refresh the visit and try again.'
        );
      end if;

      bil_patient_context.get_context(
        p_patientno => p_patientno,
        p_invoice_date => l_invoice_datetime,
        p_paytype => p_paytype,
        p_info_center_id => p_info_center_id,
        o_context => l_patient_context
      );

      bil_service_context.get_context(
        p_patient_context => l_patient_context,
        p_serviceid => l_effective_seed_serviceid,
        p_qty => 1,
        p_invoice_date => l_invoice_datetime,
        o_context => l_service_context
      );

      if nvl(l_service_context.is_package, 0) = 1 then
        bil_import.get_package_lines(
          p_package_serviceid => l_effective_seed_serviceid,
          p_list_id => l_patient_context.list_id,
          p_parent_source_id => l_line.source_id,
          o_lines => l_import_lines,
          o_result => l_result
        );
        l_idx := l_import_lines.first;
        while l_idx is not null loop
          l_import_lines(l_idx).source_type := bil_import.c_source_visit;
          l_import_lines(l_idx).source_id := l_line.source_id;
          l_idx := l_import_lines.next(l_idx);
        end loop;
      else
        l_import_lines(1) := l_line;
      end if;

    elsif l_source_mode = 'REQUEST' then
      bil_import.get_invoice_request_lines(
        p_patientno => p_patientno,
        p_visit_unique => p_visit_unique,
        p_paytype => p_paytype,
        p_app_id => p_app_id,
        p_app_session_id => p_app_session_id,
        p_app_user => p_app_user,
        p_invoice_date => l_invoice_datetime,
        p_approval_check_mode => 1,
        p_raise_on_blocked => 'Y',
        o_lines => l_import_lines,
        o_result => l_result
      );
    end if;

    bil_import.to_engine_lines(
      p_import_lines => l_import_lines,
      o_engine_lines => l_engine_lines
    );

    l_preview_header.patientno := p_patientno;
    l_preview_header.invdate := l_invoice_datetime;
    l_preview_header.paytype := p_paytype;
    l_preview_header.clinicid := p_clinicid;
    l_preview_header.info_center_id := p_info_center_id;
    l_preview_header.finaldisc := nvl(p_final_disc, 0);

    bil_invoice_engine.preview_invoice(
      p_header => l_preview_header,
      p_lines => l_engine_lines,
      o_lines => l_preview_lines,
      o_result => l_preview_result
    );

    l_idx := l_import_lines.first;
    while l_idx is not null loop
      if not l_preview_lines.exists(l_idx) then
        raise_application_error(-20898, 'Import preview failed: engine line mapping is incomplete.');
      end if;
      add_line(l_import_lines(l_idx), l_preview_lines(l_idx));
      l_idx := l_import_lines.next(l_idx);
    end loop;

    o_totals.line_count := l_preview_result.line_count;
    o_totals.total_gross := l_preview_result.total_gross;
    o_totals.total_discount := l_preview_result.total_discount;
    o_totals.total_net := l_preview_result.total_net;
    o_totals.pat_pay := l_preview_result.pat_pay;
    o_totals.comp_pay := l_preview_result.comp_pay;
    o_totals.vat_total_pat := l_preview_result.vat_total_pat;
    o_totals.vat_total_co := l_preview_result.vat_total_co;

    if o_totals.line_count = 0 then
      raise_application_error(-20897, 'No invoice lines were found for this source invoice.');
    end if;

    o_totals.amount_2 := money(nvl(p_amount_2, 0));
    o_totals.cash_collected := greatest(
      money(o_totals.pat_pay - nvl(p_final_disc, 0) + o_totals.vat_total_pat),
      0
    );

    if is_yes(p_amount_1_auto) then
      o_totals.amount_1 := greatest(money(o_totals.cash_collected - o_totals.amount_2), 0);
    else
      o_totals.amount_1 := money(nvl(p_amount_1, 0));
    end if;

    o_totals.remaining_amount :=
      money(o_totals.cash_collected - o_totals.amount_1 - o_totals.amount_2);

    o_totals.payment_status :=
      case
        when o_totals.cash_collected = 0 then 'No Amount Due'
        when o_totals.amount_1 + o_totals.amount_2 = 0 then 'Unpaid'
        when o_totals.amount_1 + o_totals.amount_2 < o_totals.cash_collected then 'Partial'
        when o_totals.amount_1 + o_totals.amount_2 = o_totals.cash_collected then 'Paid'
        else 'Overpaid'
      end;

    o_import_result := l_result;
  end build_import_preview_collection;


  procedure create_full_invoice (
    p_header                 in  bil_invoice_engine.t_header_input,
    p_lines                  in  bil_invoice_engine.t_line_input_tab,
    p_post_payment           in  varchar2 default 'Y',
    p_amount_1               in  t_inv.amount_1%type default null,
    p_amount_2               in  t_inv.amount_2%type default 0,
    p_sub_paytype            in  t_inv.sub_paytype%type default null,
    p_sub_paytype2           in  t_inv.sub_paytype2%type default null,
    p_allow_partial          in  varchar2 default 'N',
    p_allow_overpayment      in  varchar2 default 'N',
    p_post_queue             in  varchar2 default 'Y',
    p_queue_force            in  varchar2 default 'N',
    p_reserv_system_enabled  in  varchar2 default 'N',
    p_post_stock             in  varchar2 default 'Y',
    p_stock_repost           in  varchar2 default 'Y',
    p_build_print_url        in  varchar2 default 'N',
    p_send_sms               in  varchar2 default 'N',
    p_sms_template_code      in  varchar2 default bil_message.c_template_invoice_created,
    p_sms_language_code      in  varchar2 default 'BI',
    p_sms_mobile_no          in  varchar2 default null,
    o_result                 out nocopy t_full_invoice_result,
    p_request_id             in  bil_inv_draft_lines.draft_id%type default null
  )
  is
    l_inv_no              t_inv.inv_no%type;
    l_user_id             t_inv.user_no%type;
    l_payment_amt_1       t_inv.amount_1%type;
    l_print_request       bil_reports_print.t_print_request;
    l_request_id          bil_invoice_create_request.request_id%type;
    l_existing_inv_no     bil_invoice_create_request.inv_no%type;
    l_existing_patientno  bil_invoice_create_request.patientno%type;
    l_existing_completed  bil_invoice_create_request.completed_at%type;

    procedure load_existing_invoice_result (
      p_inv_no in t_inv.inv_no%type
    )
    is
    begin
      select t.inv_no,
             t.invdate,
             t.patientno,
             t.curr_code,
             t.pat_pay,
             t.comp_pay,
             t.vat_total_pat,
             t.vat_total_co,
             t.vat_total,
             t.finaldisc,
             t.cash_collected,
             t.shift_system_unique
        into o_result.invoice_result.inv_no,
             o_result.invoice_result.invdate,
             o_result.invoice_result.patientno,
             o_result.invoice_result.curr_code,
             o_result.invoice_result.pat_pay,
             o_result.invoice_result.comp_pay,
             o_result.invoice_result.vat_total_pat,
             o_result.invoice_result.vat_total_co,
             o_result.invoice_result.vat_total,
             o_result.invoice_result.finaldisc,
             o_result.invoice_result.cash_collected,
             o_result.invoice_result.shift_system_unique
        from t_inv t
       where t.inv_no = p_inv_no;

      select count(*),
             nvl(sum(nvl(d.my_price, 0)), 0),
             nvl(sum(nvl(d.my_disc, 0)), 0),
             nvl(sum(nvl(d.my_net, 0)), 0)
        into o_result.invoice_result.line_count,
             o_result.invoice_result.total_gross,
             o_result.invoice_result.total_discount,
             o_result.invoice_result.total_net
        from d_inv d
       where d.inv_no = p_inv_no
         and nvl(d.is_deleted, 0) = 0;
    exception
      when no_data_found then
        raise_application_error(
          -20848,
          'Invoice request ' || l_request_id
          || ' refers to unavailable invoice ' || p_inv_no || '.'
        );
    end load_existing_invoice_result;
  begin
    o_result := null;
    o_result.payment_posted := 'N';
    o_result.queue_posted := 'N';
    o_result.stock_posted := 'N';
    o_result.print_url_built := 'N';
    o_result.sms_sent := 'N';

    if p_request_id is not null then
      l_request_id := trim(p_request_id);

      if l_request_id is null or lengthb(l_request_id) > 64 then
        raise_application_error(
          -20847,
          'Invoice create request ID must contain between 1 and 64 bytes.'
        );
      end if;

      begin
        insert into bil_invoice_create_request (
          request_id,
          patientno,
          created_by
        ) values (
          l_request_id,
          p_header.patientno,
          p_header.user_no
        );
      exception
        when dup_val_on_index then
          select r.inv_no,
                 r.patientno,
                 r.completed_at
            into l_existing_inv_no,
                 l_existing_patientno,
                 l_existing_completed
            from bil_invoice_create_request r
           where r.request_id = l_request_id;

          if l_existing_inv_no is null or l_existing_completed is null then
            raise_application_error(
              -20848,
              'Invoice request ' || l_request_id
              || ' exists but has no completed invoice.'
            );
          end if;

          if trim(l_existing_patientno) <> trim(p_header.patientno)
             or p_header.patientno is null
          then
            raise_application_error(
              -20849,
              'Invoice request ' || l_request_id
              || ' already belongs to invoice ' || l_existing_inv_no
              || ' for another patient.'
            );
          end if;

          load_existing_invoice_result(l_existing_inv_no);
          l_inv_no := l_existing_inv_no;
          l_user_id := p_header.user_no;

          if is_yes(p_build_print_url) then
            l_print_request.inv_no := l_inv_no;
            l_print_request.report_type := bil_reports_print.c_report_normal;
            l_print_request.print_mode := bil_reports_print.c_mode_preview;
            l_print_request.user_id := l_user_id;

            bil_reports_print.build_print_url(
              p_request => l_print_request,
              o_result => o_result.print_result
            );
            o_result.print_url_built := 'Y';
          end if;

          o_result.message :=
            'Invoice ' || l_inv_no || ' was already created for this request.';
          return;
      end;
    end if;

    bil_invoice_engine.create_invoice(
      p_header => p_header,
      p_lines => p_lines,
      o_result => o_result.invoice_result
    );

    l_inv_no := o_result.invoice_result.inv_no;
    l_user_id := p_header.user_no;

    if is_yes(p_post_payment) then
      l_payment_amt_1 := nvl(
        p_amount_1,
        greatest(o_result.invoice_result.cash_collected - nvl(p_amount_2, 0), 0)
      );

      bil_payment.post_payment(
        p_inv_no => l_inv_no,
        p_amount_1 => l_payment_amt_1,
        p_amount_2 => p_amount_2,
        p_sub_paytype => p_sub_paytype,
        p_sub_paytype2 => p_sub_paytype2,
        p_allow_partial => p_allow_partial,
        p_allow_overpayment => p_allow_overpayment,
        p_user_id => l_user_id,
        o_result => o_result.payment_result
      );
      o_result.payment_posted := 'Y';
    end if;

    if is_yes(p_post_queue) then
      bil_queue_posting.post_invoice_queue(
        p_inv_no => l_inv_no,
        p_force => p_queue_force,
        p_reserv_system_enabled => p_reserv_system_enabled,
        p_user_id => l_user_id,
        o_result => o_result.queue_result
      );
      o_result.queue_posted := 'Y';
    end if;

    if is_yes(p_post_stock) then
      bil_stock_posting.post_invoice_stock(
        p_inv_no => l_inv_no,
        p_repost => p_stock_repost,
        p_user_id => l_user_id,
        o_result => o_result.stock_result
      );
      o_result.stock_posted := 'Y';
    end if;

    if is_yes(p_build_print_url) then
      l_print_request.inv_no := l_inv_no;
      l_print_request.report_type := bil_reports_print.c_report_normal;
      l_print_request.print_mode := bil_reports_print.c_mode_preview;
      l_print_request.user_id := l_user_id;

      bil_reports_print.build_print_url(
        p_request => l_print_request,
        o_result => o_result.print_result
      );
      o_result.print_url_built := 'Y';
    end if;

    if is_yes(p_send_sms) then
      begin
        bil_message.send_invoice_message(
          p_inv_no => l_inv_no,
          p_template_code => p_sms_template_code,
          p_language_code => p_sms_language_code,
          p_mobile_no => p_sms_mobile_no,
          p_user_id => l_user_id,
          o_result => o_result.message_result
        );
        o_result.sms_sent := 'Y';
      exception
        when others then
          o_result.sms_sent := 'N';
          o_result.message_result.send_status := 'FAILED';
          o_result.message_result.message :=
            'Invoice was created, but SMS could not be sent.';
      end;
    end if;

    if l_request_id is not null then
      update bil_invoice_create_request
         set inv_no = l_inv_no,
             completed_at = systimestamp
       where request_id = l_request_id
         and inv_no is null;

      if sql%rowcount <> 1 then
        raise_application_error(
          -20848,
          'Invoice request ' || l_request_id
          || ' could not be completed for invoice ' || l_inv_no || '.'
        );
      end if;
    end if;

    o_result.message := 'Invoice ' || l_inv_no || ' created successfully.';
  exception
    when others then
      o_result.message := 'Full invoice create failed: ' || sqlerrm;
      raise;
  end create_full_invoice;

end bil_invoice_api;
/
