create or replace package bil_offers_admin authid definer as

  procedure create_offer(
      p_offer_name             in  offers.offer_name%type,
      p_start_date             in  offers.start_date%type,
      p_end_date               in  offers.enddate%type,
      p_description            in  offers.notes%type,
      o_offer_id               out offers.oferid%type,
      o_object_version_number  out offers.object_version_number%type
  );

  procedure update_offer(
      p_offer_id               in  offers.oferid%type,
      p_offer_name             in  offers.offer_name%type,
      p_start_date             in  offers.start_date%type,
      p_end_date               in  offers.enddate%type,
      p_description            in  offers.notes%type,
      p_expected_ovn           in  offers.object_version_number%type,
      o_new_ovn                out offers.object_version_number%type
  );

  procedure retire_offer(
      p_offer_id               in offers.oferid%type,
      p_delete_reason          in offers.delete_reason%type,
      p_expected_ovn           in offers.object_version_number%type
  );

  procedure get_offer_service_pricing(
      p_offer_id       in  offers.oferid%type,
      p_service_id     in  offers_dtl.serviceid%type,
      o_org_price      out offers_dtl.org_price%type,
      o_org_discount   out offers_dtl.org_disc%type,
      o_vat_rate       out services.vat_rate%type
  );

  procedure add_offer_line(
      p_offer_id                  in  offers.oferid%type,
      p_service_id                in  offers_dtl.serviceid%type,
      p_offer_price               in  offers_dtl.offer_price%type,
      p_offer_discount            in  offers_dtl.offer_dis%type,
      o_row_id                    out offers_dtl.row_id%type,
      o_object_version_number     out offers_dtl.object_version_number%type
  );

  procedure update_offer_line(
      p_offer_id                  in  offers.oferid%type,
      p_row_id                    in  offers_dtl.row_id%type,
      p_offer_price               in  offers_dtl.offer_price%type,
      p_offer_discount            in  offers_dtl.offer_dis%type,
      p_expected_ovn              in  offers_dtl.object_version_number%type,
      o_new_ovn                   out offers_dtl.object_version_number%type
  );

  procedure remove_offer_line(
      p_offer_id                  in offers.oferid%type,
      p_row_id                    in offers_dtl.row_id%type,
      p_expected_ovn              in offers_dtl.object_version_number%type
  );

  procedure import_offer_lines(
      p_offer_id        in  offers.oferid%type,
      p_lines_json      in  clob,
      o_imported_count  out pls_integer,
      o_restored_count  out pls_integer
  );

  procedure create_bundled_offer(
      p_offer_name              in  offers.offer_name%type,
      p_start_date              in  offers.start_date%type,
      p_end_date                in  offers.enddate%type,
      p_description             in  offers.notes%type,
      p_valid_days              in  offers.valid_dayes%type,
      o_offer_id                out offers.oferid%type,
      o_object_version_number   out offers.object_version_number%type
  );

  procedure update_bundled_offer(
      p_offer_id                in  offers.oferid%type,
      p_offer_name              in  offers.offer_name%type,
      p_start_date              in  offers.start_date%type,
      p_end_date                in  offers.enddate%type,
      p_description             in  offers.notes%type,
      p_valid_days              in  offers.valid_dayes%type,
      p_expected_ovn            in  offers.object_version_number%type,
      o_new_ovn                 out offers.object_version_number%type
  );

  procedure retire_bundled_offer(
      p_offer_id                in offers.oferid%type,
      p_delete_reason           in offers.delete_reason%type,
      p_expected_ovn            in offers.object_version_number%type
  );

  procedure get_bundle_component_pricing(
      p_offer_id       in  offers.oferid%type,
      p_service_id     in  offers_dtl.serviceid%type,
      o_org_price      out offers_dtl.org_price%type,
      o_org_discount   out offers_dtl.org_disc%type,
      o_vat_rate       out services.vat_rate%type
  );

  procedure add_bundle_component(
      p_offer_id        in  offers.oferid%type,
      p_service_id      in  offers_dtl.serviceid%type,
      p_quantity        in  offers_dtl.qty%type,
      p_bundle_price    in  offers_dtl.offer_price%type,
      o_row_id          out offers_dtl.row_id%type,
      o_detail_ovn      out offers_dtl.object_version_number%type,
      o_header_ovn      out offers.object_version_number%type
  );

  procedure update_bundle_component(
      p_offer_id            in  offers.oferid%type,
      p_row_id              in  offers_dtl.row_id%type,
      p_quantity            in  offers_dtl.qty%type,
      p_bundle_price        in  offers_dtl.offer_price%type,
      p_expected_detail_ovn in  offers_dtl.object_version_number%type,
      o_detail_ovn          out offers_dtl.object_version_number%type,
      o_header_ovn          out offers.object_version_number%type
  );

  procedure remove_bundle_component(
      p_offer_id            in  offers.oferid%type,
      p_row_id              in  offers_dtl.row_id%type,
      p_expected_detail_ovn in  offers_dtl.object_version_number%type,
      o_header_ovn          out offers.object_version_number%type
  );

end bil_offers_admin;
/

create or replace package body bil_offers_admin as

  c_offer_type_standard      constant offers.offer_type%type := 1;
  c_offer_type_bundled       constant offers.offer_type%type := 0;
  c_with_vat_default         constant offers.with_vat%type := 0;
  c_not_deleted              constant offers.is_deleted%type := 'N';
  c_deleted                  constant offers.is_deleted%type := 'Y';
  c_delete_reason_offer_retired constant offers_dtl.delete_reason%type := 'OFFER_RETIRED';

  c_offer_notes_max_chars    constant pls_integer := 500;
  c_header_total_max         constant number := 999999.99;
  c_detail_price_max         constant number := 99999999.99;
  c_bundle_qty_max           constant number := 999;

  c_err_info_center_required constant number := -20640;
  c_err_offer_id_required    constant number := -20641;
  c_err_offer_name_required  constant number := -20642;
  c_err_start_date_required  constant number := -20643;
  c_err_end_date_required    constant number := -20644;
  c_err_date_range           constant number := -20645;
  c_err_description_too_long constant number := -20646;
  c_err_expected_ovn_req     constant number := -20647;
  c_err_no_cash_list         constant number := -20648;
  c_err_multiple_cash_lists  constant number := -20649;
  c_err_offer_not_found      constant number := -20650;
  c_err_wrong_info_center    constant number := -20651;
  c_err_wrong_type           constant number := -20652;
  c_err_retired              constant number := -20653;
  c_err_stale_ovn            constant number := -20654;
  c_err_no_cash_company      constant number := -20655;
  c_err_offer_name_too_long  constant number := -20656;
  c_err_row_id_required      constant number := -20657;
  c_err_service_id_required  constant number := -20658;
  c_err_offer_price_negative constant number := -20659;
  c_err_offer_disc_range     constant number := -20660;
  c_err_service_unavailable  constant number := -20661;
  c_err_service_list_missing constant number := -20662;
  c_err_no_plan_price        constant number := -20663;
  c_err_multiple_pricing     constant number := -20664;
  c_err_service_duplicate    constant number := -20665;
  c_err_line_not_found       constant number := -20666;
  c_err_line_wrong_offer     constant number := -20667;
  c_err_line_removed         constant number := -20668;
  c_err_line_stale           constant number := -20669;
  c_err_service_id_too_long  constant number := -20670;
  c_err_multiple_cash_plans  constant number := -20671;
  c_err_import_json_required constant number := -20672;
  c_err_import_json_bad      constant number := -20673;
  c_err_import_json_array    constant number := -20674;
  c_err_import_empty         constant number := -20675;
  c_err_import_service_req   constant number := -20676;
  c_err_import_duplicate     constant number := -20677;
  c_err_import_price_bad     constant number := -20678;
  c_err_import_disc_bad      constant number := -20679;
  c_err_valid_days_required  constant number := -20680;
  c_err_valid_days_invalid   constant number := -20681;
  c_err_bundle_qty_required  constant number := -20682;
  c_err_bundle_qty_invalid   constant number := -20683;
  c_err_bundle_price_req     constant number := -20684;
  c_err_bundle_price_invalid constant number := -20685;
  c_err_bundle_total_overflow constant number := -20686;
  c_err_bundle_component_bad constant number := -20687;
  c_err_bundle_price_above_org constant number := -20688;
  c_err_standard_noop          constant number := -20689;
  c_err_standard_overlap       constant number := -20690;
  c_err_date_has_time          constant number := -20691;

  c_action_add               constant varchar2(10) := 'ADD';
  c_action_restore           constant varchar2(10) := 'RESTORE';

  type t_import_line_rec is record (
    line_no        pls_integer,
    service_id     offers_dtl.serviceid%type,
    offer_price    offers_dtl.offer_price%type,
    offer_discount offers_dtl.offer_dis%type,
    org_price      offers_dtl.org_price%type,
    org_discount   offers_dtl.org_disc%type,
    vat_rate       services.vat_rate%type
  );

  type t_import_line_tab is table of t_import_line_rec index by pls_integer;

  function trim_to_null(
    p_value in varchar2
  ) return varchar2
  is
    l_value varchar2(32767);
  begin
    l_value := trim(p_value);
    return case when l_value is null then null else l_value end;
  end trim_to_null;


  function upper_trim_to_null(
    p_value in varchar2
  ) return varchar2
  is
    l_value varchar2(32767);
  begin
    l_value := trim_to_null(p_value);
    return case when l_value is null then null else upper(l_value) end;
  end upper_trim_to_null;


  function normalize_offer_name(
    p_offer_name in offers.offer_name%type
  ) return offers.offer_name%type
  is
    l_value varchar2(32767);
  begin
    l_value := trim_to_null(p_offer_name);

    if l_value is null then
      raise_application_error(c_err_offer_name_required, 'Offer name is required.');
    end if;

    if lengthb(l_value) > 50 then
      raise_application_error(c_err_offer_name_too_long, 'Offer name must not exceed 50 bytes.');
    end if;

    return l_value;
  end normalize_offer_name;


  function normalize_description(
    p_description in offers.notes%type
  ) return offers.notes%type
  is
    l_value varchar2(32767);
  begin
    l_value := trim_to_null(p_description);

    if l_value is not null and length(l_value) > c_offer_notes_max_chars then
      raise_application_error(c_err_description_too_long, 'Description must not exceed 500 characters.');
    end if;

    return l_value;
  end normalize_description;


  function normalize_delete_reason(
    p_delete_reason in offers.delete_reason%type
  ) return offers.delete_reason%type
  is
    l_value varchar2(32767);
  begin
    l_value := trim_to_null(p_delete_reason);

    if l_value is not null and length(l_value) > 400 then
      raise_application_error(c_err_description_too_long, 'Delete reason must not exceed 400 characters.');
    end if;

    return l_value;
  end normalize_delete_reason;


  function get_session_state(
    p_item_name in varchar2
  ) return varchar2
  is
  begin
    return trim_to_null(apex_util.get_session_state(p_item_name));
  end get_session_state;


  function current_info_center_id
    return offers.offer_info_center%type
  is
    l_info_center_id varchar2(32767);
  begin
    l_info_center_id := get_session_state('G_INFO_CENTER_ID');

    if l_info_center_id is null then
      raise_application_error(c_err_info_center_required, 'Current info center is required.');
    end if;

    if lengthb(l_info_center_id) > 10 then
      raise_application_error(c_err_info_center_required, 'Current info center is invalid.');
    end if;

    return l_info_center_id;
  end current_info_center_id;


  function get_cash_comp_code
    return insurance_net_works.comp_code%type
  is
    l_comp_code insurance_net_works.comp_code%type;
  begin
    l_comp_code := trim_to_null(ins_comp_util.get_cash_comp_code);

    if l_comp_code is null then
      raise_application_error(c_err_no_cash_company, 'Cash company is not configured.');
    end if;

    return l_comp_code;
  end get_cash_comp_code;


  function resolve_cash_list_id(
    p_info_center_id in offers.offer_info_center%type
  ) return offers.list_id%type
  is
    l_cash_comp_code insurance_net_works.comp_code%type;
    l_list_count     number;
    l_list_id        offers.list_id%type;
  begin
    l_cash_comp_code := get_cash_comp_code;

    select count(distinct ppm.list_id),
           min(ppm.list_id)
      into l_list_count,
           l_list_id
      from insurance_net_works inw
      join price_plan_m ppm
        on ppm.plan_code = inw.plan_code
      join price_list_master plm
        on plm.list_id = ppm.list_id
     where inw.info_center_id = p_info_center_id
       and inw.comp_code = l_cash_comp_code
       and (ppm.info_center_id is null or trim(ppm.info_center_id) = p_info_center_id)
       and trim(plm.the_info_center) = p_info_center_id
       and nvl(plm.canceld, 0) = 0
       and nvl(trim(plm.for_cash), 'N') = 'Y';

    if l_list_count = 0 then
      raise_application_error(
        c_err_no_cash_list,
        'No cash price list is configured for the current info center.'
      );
    elsif l_list_count > 1 then
      raise_application_error(
        c_err_multiple_cash_lists,
        'Multiple cash price lists are configured for the current info center.'
      );
    end if;

    return l_list_id;
  end resolve_cash_list_id;


  procedure assert_offer_id(
    p_offer_id in offers.oferid%type
  )
  is
  begin
    if p_offer_id is null then
      raise_application_error(c_err_offer_id_required, 'Offer ID is required.');
    end if;
  end assert_offer_id;


  procedure assert_expected_ovn(
    p_expected_ovn in offers.object_version_number%type
  )
  is
  begin
    if p_expected_ovn is null then
      raise_application_error(c_err_expected_ovn_req, 'Object version is required.');
    end if;
  end assert_expected_ovn;


  procedure assert_row_id(
    p_row_id in offers_dtl.row_id%type
  )
  is
  begin
    if p_row_id is null then
      raise_application_error(c_err_row_id_required, 'Offer service row ID is required.');
    end if;
  end assert_row_id;


  function normalize_service_id(
    p_service_id in offers_dtl.serviceid%type
  ) return offers_dtl.serviceid%type
  is
    l_service_id varchar2(32767);
  begin
    l_service_id := upper_trim_to_null(p_service_id);

    if l_service_id is null then
      raise_application_error(c_err_service_id_required, 'Service ID is required.');
    end if;

    if lengthb(l_service_id) > 20 then
      raise_application_error(c_err_service_id_too_long, 'Service ID must not exceed 20 bytes.');
    end if;

    return l_service_id;
  end normalize_service_id;


  procedure validate_line_overrides(
    p_offer_price    in offers_dtl.offer_price%type,
    p_offer_discount in offers_dtl.offer_dis%type
  )
  is
  begin
    if p_offer_price is null and p_offer_discount is null then
      raise_application_error(
        c_err_standard_noop,
        'A Standard Offer service requires an offer price or offer discount.'
      );
    end if;

    if p_offer_price is not null and p_offer_price < 0 then
      raise_application_error(c_err_offer_price_negative, 'Offer price cannot be negative.');
    end if;

    if p_offer_discount is not null
       and (p_offer_discount < 0 or p_offer_discount > 100)
    then
      raise_application_error(c_err_offer_disc_range, 'Offer discount must be between 0 and 100.');
    end if;
  end validate_line_overrides;


  procedure assert_dates(
    p_start_date in offers.start_date%type,
    p_end_date   in offers.enddate%type
  )
  is
  begin
    if p_start_date is null then
      raise_application_error(c_err_start_date_required, 'Start date is required.');
    end if;

    if p_end_date is null then
      raise_application_error(c_err_end_date_required, 'End date is required.');
    end if;

    if p_start_date <> trunc(p_start_date)
       or p_end_date <> trunc(p_end_date)
    then
      raise_application_error(c_err_date_has_time, 'Offer dates must not contain a time component.');
    end if;

    if p_end_date < p_start_date then
      raise_application_error(c_err_date_range, 'End date must be on or after start date.');
    end if;
  end assert_dates;


  procedure lock_standard_service(
    p_list_id    in services.list_id%type,
    p_service_id in services.serviceid%type
  ) is
    l_service_id services.serviceid%type;
  begin
    select s.serviceid
      into l_service_id
      from services s
     where s.list_id = p_list_id
       and s.serviceid = p_service_id
     for update;
  exception
    when no_data_found then
      raise_application_error(c_err_service_list_missing, 'Service is not available in the Cash price list.');
  end lock_standard_service;


  procedure assert_no_standard_overlap(
    p_offer_id       in offers.oferid%type,
    p_info_center_id in offers.offer_info_center%type,
    p_list_id        in offers.list_id%type,
    p_service_id     in offers_dtl.serviceid%type,
    p_start_date     in offers.start_date%type,
    p_end_date       in offers.enddate%type
  ) is
    l_count number;
  begin
    select count(*)
      into l_count
      from offers o
      join offers_dtl d
        on d.oferid = o.oferid
       and d.list_id = o.list_id
     where o.offer_type = c_offer_type_standard
       and o.is_deleted = c_not_deleted
       and d.is_deleted = c_not_deleted
       and o.offer_info_center = p_info_center_id
       and o.list_id = p_list_id
       and d.serviceid = p_service_id
       and (d.offer_price is not null or d.offer_dis is not null)
       and o.oferid <> p_offer_id
       and o.start_date <= p_end_date
       and p_start_date <= o.enddate;

    if l_count > 0 then
      raise_application_error(
        c_err_standard_overlap,
        'Service ' || p_service_id || ' already has an overlapping active Standard Offer.'
      );
    end if;
  end assert_no_standard_overlap;


  procedure lock_and_validate_standard_header(
    p_offer          in offers%rowtype,
    p_start_date     in offers.start_date%type,
    p_end_date       in offers.enddate%type
  ) is
  begin
    for r in (
      select distinct d.serviceid
        from offers_dtl d
       where d.oferid = p_offer.oferid
         and d.list_id = p_offer.list_id
         and d.is_deleted = c_not_deleted
         and (d.offer_price is not null or d.offer_dis is not null)
       order by d.serviceid
    ) loop
      lock_standard_service(p_offer.list_id, r.serviceid);
      assert_no_standard_overlap(
        p_offer.oferid,
        p_offer.offer_info_center,
        p_offer.list_id,
        r.serviceid,
        p_start_date,
        p_end_date
      );
    end loop;
  end lock_and_validate_standard_header;


  function offer_type_name(
    p_offer_type in offers.offer_type%type
  ) return varchar2
  is
  begin
    if p_offer_type = c_offer_type_standard then
      return 'standard offers';
    elsif p_offer_type = c_offer_type_bundled then
      return 'Bundled Offers';
    else
      return 'the requested Offer type';
    end if;
  end offer_type_name;


  procedure assert_valid_days(
    p_valid_days in offers.valid_dayes%type
  )
  is
  begin
    if p_valid_days is null then
      raise_application_error(c_err_valid_days_required, 'Valid Days is required.');
    elsif p_valid_days < 0 or p_valid_days <> trunc(p_valid_days) or p_valid_days > 9999 then
      raise_application_error(c_err_valid_days_invalid, 'Valid Days must be a nonnegative integer up to 9999.');
    end if;
  end assert_valid_days;


  procedure validate_bundle_quantity(
    p_quantity in offers_dtl.qty%type
  )
  is
  begin
    if p_quantity is null then
      raise_application_error(c_err_bundle_qty_required, 'Bundle quantity is required.');
    elsif p_quantity <= 0 or p_quantity <> trunc(p_quantity) or p_quantity > c_bundle_qty_max then
      raise_application_error(c_err_bundle_qty_invalid, 'Bundle quantity must be a positive integer from 1 through 999.');
    end if;
  end validate_bundle_quantity;


  procedure validate_bundle_price(
    p_bundle_price in offers_dtl.offer_price%type
  )
  is
  begin
    if p_bundle_price is null then
      raise_application_error(c_err_bundle_price_req, 'Bundle component price is required.');
    elsif p_bundle_price < 0 then
      raise_application_error(c_err_bundle_price_invalid, 'Bundle component price cannot be negative.');
    elsif p_bundle_price > c_detail_price_max then
      raise_application_error(c_err_bundle_price_invalid, 'Bundle component price exceeds the supported maximum.');
    elsif p_bundle_price <> round(p_bundle_price, 2) then
      raise_application_error(c_err_bundle_price_invalid, 'Bundle component price must not have more than two decimal places.');
    end if;
  end validate_bundle_price;


  procedure assert_bundle_price_not_above_org(
    p_bundle_price in offers_dtl.offer_price%type,
    p_org_price    in offers_dtl.org_price%type
  )
  is
  begin
    if p_org_price is null then
      raise_application_error(
        c_err_bundle_component_bad,
        'Bundled Offer component Original Unit Price is required.'
      );
    elsif p_bundle_price > p_org_price then
      raise_application_error(
        c_err_bundle_price_above_org,
        'Bundle Unit Price cannot exceed the Original Unit Price.'
      );
    end if;
  end assert_bundle_price_not_above_org;


  procedure load_and_validate_offer(
    p_offer_id             in  offers.oferid%type,
    p_expected_offer_type  in  offers.offer_type%type,
    p_lock_offer           in  boolean,
    o_offer                out offers%rowtype
  )
  is
    l_info_center_id offers.offer_info_center%type;
  begin
    assert_offer_id(p_offer_id);
    l_info_center_id := current_info_center_id;

    begin
      if p_lock_offer then
        select *
          into o_offer
          from offers
         where oferid = p_offer_id
         for update;
      else
        select *
          into o_offer
          from offers
         where oferid = p_offer_id;
      end if;
    exception
      when no_data_found then
        raise_application_error(c_err_offer_not_found, 'Offer was not found.');
    end;

    if o_offer.offer_info_center <> l_info_center_id then
      raise_application_error(c_err_wrong_info_center, 'Offer does not belong to the current info center.');
    elsif o_offer.offer_type <> p_expected_offer_type then
      if p_expected_offer_type = c_offer_type_standard then
        raise_application_error(c_err_wrong_type, 'Only standard offers can be managed by this package.');
      else
        raise_application_error(
          c_err_wrong_type,
          'Only ' || offer_type_name(p_expected_offer_type) || ' can be managed by this operation.'
        );
      end if;
    elsif o_offer.is_deleted <> c_not_deleted then
      raise_application_error(c_err_retired, 'Offer is already retired.');
    end if;
  end load_and_validate_offer;


  function resolve_cash_plan_code(
    p_info_center_id in offers.offer_info_center%type,
    p_list_id        in offers.list_id%type
  ) return price_plan_m.plan_code%type
  is
    l_cash_comp_code insurance_net_works.comp_code%type;
    l_plan_count     number;
    l_plan_code      price_plan_m.plan_code%type;
  begin
    l_cash_comp_code := get_cash_comp_code;

    select count(distinct ppm.plan_code),
           min(ppm.plan_code)
      into l_plan_count,
           l_plan_code
      from insurance_net_works inw
      join price_plan_m ppm
        on ppm.plan_code = inw.plan_code
      join price_list_master plm
        on plm.list_id = ppm.list_id
     where inw.info_center_id = p_info_center_id
       and inw.comp_code = l_cash_comp_code
       and ppm.list_id = p_list_id
       and (ppm.info_center_id is null or trim(ppm.info_center_id) = p_info_center_id)
       and trim(plm.the_info_center) = p_info_center_id
       and nvl(plm.canceld, 0) = 0
       and nvl(trim(plm.for_cash), 'N') = 'Y';

    if l_plan_count = 0 then
      raise_application_error(
        c_err_no_cash_list,
        'No cash price plan is configured for the current info center and Offer list.'
      );
    elsif l_plan_count > 1 then
      raise_application_error(
        c_err_multiple_cash_plans,
        'Multiple cash price plans are configured for the current info center and Offer list.'
      );
    end if;

    return l_plan_code;
  end resolve_cash_plan_code;


  procedure resolve_offer_service_pricing_for_offer(
    p_offer          in  offers%rowtype,
    p_service_id     in  offers_dtl.serviceid%type,
    o_service_id     out offers_dtl.serviceid%type,
    o_org_price      out offers_dtl.org_price%type,
    o_org_discount   out offers_dtl.org_disc%type,
    o_vat_rate       out services.vat_rate%type
  )
  is
    l_plan_code      price_plan_m.plan_code%type;
    l_result_count   number;
    l_plan_row_count number;
    l_svc_row_count  number;
  begin
    o_service_id := null;
    o_org_price := null;
    o_org_discount := null;
    o_vat_rate := null;

    o_service_id := normalize_service_id(p_service_id);
    l_plan_code := resolve_cash_plan_code(p_offer.offer_info_center, p_offer.list_id);

    select count(*),
           max(price),
           max(price_disc),
           max(vat_rate)
      into l_result_count,
           o_org_price,
           o_org_discount,
           o_vat_rate
      from (
        select distinct
               ppd.price,
               ppd.price_disc,
               svc.vat_rate
          from price_plan_dtl ppd
          join services svc
            on svc.list_id = ppd.list_id
           and upper(trim(svc.serviceid)) = upper(trim(ppd.serviceid))
         where ppd.plan_code = l_plan_code
           and ppd.list_id = p_offer.list_id
           and upper(trim(ppd.serviceid)) = o_service_id
      );

    if l_result_count = 0 then
      select count(*)
        into l_plan_row_count
        from price_plan_dtl ppd
       where ppd.plan_code = l_plan_code
         and ppd.list_id = p_offer.list_id
         and upper(trim(ppd.serviceid)) = o_service_id;

      if l_plan_row_count = 0 then
        raise_application_error(c_err_service_unavailable, 'Service is unavailable in the Offer cash plan.');
      end if;

      select count(*)
        into l_svc_row_count
        from services svc
       where svc.list_id = p_offer.list_id
         and upper(trim(svc.serviceid)) = o_service_id;

      if l_svc_row_count = 0 then
        raise_application_error(c_err_service_list_missing, 'Matching service/list row was not found.');
      end if;

      raise_application_error(c_err_service_list_missing, 'Valid service/list pricing relationship was not found.');
    elsif l_result_count > 1 then
      raise_application_error(c_err_multiple_pricing, 'Multiple conflicting pricing configurations were found.');
    end if;

    if o_org_price is null then
      raise_application_error(c_err_no_plan_price, 'No cash-plan price is configured for this service.');
    end if;
  end resolve_offer_service_pricing_for_offer;


  procedure resolve_offer_service_pricing_internal(
    p_offer_id       in  offers.oferid%type,
    p_service_id     in  offers_dtl.serviceid%type,
    p_expected_offer_type in offers.offer_type%type,
    p_lock_offer     in  boolean,
    o_list_id        out offers.list_id%type,
    o_service_id     out offers_dtl.serviceid%type,
    o_org_price      out offers_dtl.org_price%type,
    o_org_discount   out offers_dtl.org_disc%type,
    o_vat_rate       out services.vat_rate%type
  )
  is
    l_offer offers%rowtype;
  begin
    o_list_id := null;
    load_and_validate_offer(p_offer_id, p_expected_offer_type, p_lock_offer, l_offer);
    o_list_id := l_offer.list_id;

    resolve_offer_service_pricing_for_offer(
      p_offer        => l_offer,
      p_service_id   => p_service_id,
      o_service_id   => o_service_id,
      o_org_price    => o_org_price,
      o_org_discount => o_org_discount,
      o_vat_rate     => o_vat_rate
    );
  end resolve_offer_service_pricing_internal;


  procedure classify_offer_line_failure(
    p_offer_id       in offers.oferid%type,
    p_list_id        in offers.list_id%type,
    p_row_id         in offers_dtl.row_id%type,
    p_expected_ovn   in offers_dtl.object_version_number%type
  )
  is
    l_line_offer_id offers_dtl.oferid%type;
    l_line_list_id  offers_dtl.list_id%type;
    l_is_deleted    offers_dtl.is_deleted%type;
    l_ovn           offers_dtl.object_version_number%type;
  begin
    select oferid,
           list_id,
           is_deleted,
           object_version_number
      into l_line_offer_id,
           l_line_list_id,
           l_is_deleted,
           l_ovn
      from offers_dtl
     where row_id = p_row_id;

    if l_line_offer_id <> p_offer_id or l_line_list_id <> p_list_id then
      raise_application_error(c_err_line_wrong_offer, 'Offer service line belongs to another Offer.');
    elsif l_is_deleted <> c_not_deleted then
      raise_application_error(c_err_line_removed, 'Offer service line is already removed.');
    elsif p_expected_ovn is not null and l_ovn <> p_expected_ovn then
      raise_application_error(c_err_line_stale, 'This Offer service was changed by another user. Refresh and try again.');
    else
      raise_application_error(c_err_line_not_found, 'Offer service line was not updated.');
    end if;
  exception
    when no_data_found then
      raise_application_error(c_err_line_not_found, 'Offer service line was not found.');
  end classify_offer_line_failure;


  procedure add_or_restore_offer_line_internal(
    p_offer                  in  offers%rowtype,
    p_service_id             in  offers_dtl.serviceid%type,
    p_offer_price            in  offers_dtl.offer_price%type,
    p_offer_discount         in  offers_dtl.offer_dis%type,
    o_row_id                 out offers_dtl.row_id%type,
    o_object_version_number  out offers_dtl.object_version_number%type,
    o_action                 out varchar2
  )
  is
    l_service_id   offers_dtl.serviceid%type;
    l_org_price    offers_dtl.org_price%type;
    l_org_discount offers_dtl.org_disc%type;
    l_vat_rate     services.vat_rate%type;
    l_existing_row offers_dtl.row_id%type;
    l_existing_del offers_dtl.is_deleted%type;
  begin
    o_row_id := null;
    o_object_version_number := null;
    o_action := null;

    validate_line_overrides(p_offer_price, p_offer_discount);

    resolve_offer_service_pricing_for_offer(
      p_offer        => p_offer,
      p_service_id   => p_service_id,
      o_service_id   => l_service_id,
      o_org_price    => l_org_price,
      o_org_discount => l_org_discount,
      o_vat_rate     => l_vat_rate
    );

    if p_offer.offer_type = c_offer_type_standard then
      lock_standard_service(p_offer.list_id, l_service_id);
      assert_no_standard_overlap(
        p_offer.oferid,
        p_offer.offer_info_center,
        p_offer.list_id,
        l_service_id,
        p_offer.start_date,
        p_offer.enddate
      );
    end if;

    begin
      select row_id,
             is_deleted
        into l_existing_row,
             l_existing_del
        from offers_dtl
       where list_id = p_offer.list_id
         and oferid = p_offer.oferid
         and upper(trim(serviceid)) = l_service_id
       for update;

      if l_existing_del = c_not_deleted then
        raise_application_error(c_err_service_duplicate, 'Service ' || l_service_id || ' is already included in the Offer.');
      end if;

      update offers_dtl
         set is_deleted = c_not_deleted,
             deleted_by = null,
             deleted_date = null,
             delete_reason = null,
             org_price = l_org_price,
             org_disc = l_org_discount,
             offer_price = p_offer_price,
             offer_dis = p_offer_discount,
             qty = null
       where row_id = l_existing_row
      returning row_id,
                object_version_number
           into o_row_id,
                o_object_version_number;

      o_action := c_action_restore;

    exception
      when no_data_found then
        begin
          insert into offers_dtl (
            oferid,
            list_id,
            serviceid,
            org_price,
            org_disc,
            offer_price,
            offer_dis,
            qty,
            is_deleted
          ) values (
            p_offer.oferid,
            p_offer.list_id,
            l_service_id,
            l_org_price,
            l_org_discount,
            p_offer_price,
            p_offer_discount,
            null,
            c_not_deleted
          )
          returning row_id,
                    object_version_number
               into o_row_id,
                    o_object_version_number;

          o_action := c_action_add;
        exception
          when dup_val_on_index then
            raise_application_error(c_err_service_duplicate, 'Service ' || l_service_id || ' is already included in the Offer.');
        end;
    end;
  end add_or_restore_offer_line_internal;


  procedure recalc_bundle_totals(
    p_offer_id   in  offers.oferid%type,
    p_list_id    in  offers.list_id%type,
    o_header_ovn out offers.object_version_number%type
  )
  is
    l_info_center_id offers.offer_info_center%type;
    l_invalid_count  number;
    l_org_total      number;
    l_bundle_total   number;
  begin
    o_header_ovn := null;
    l_info_center_id := current_info_center_id;

    select count(*)
      into l_invalid_count
      from offers_dtl d
     where d.oferid = p_offer_id
       and d.list_id = p_list_id
       and d.is_deleted = c_not_deleted
       and (
             d.qty is null
          or d.qty <= 0
          or d.qty <> trunc(d.qty)
          or d.org_price is null
          or d.offer_price is null
       );

    if l_invalid_count > 0 then
      raise_application_error(
        c_err_bundle_component_bad,
        'Bundled Offer has invalid active component data and totals cannot be recalculated.'
      );
    end if;

    select nvl(sum(nvl(d.qty, 0) * d.org_price), 0),
           nvl(sum(nvl(d.qty, 0) * d.offer_price), 0)
      into l_org_total,
           l_bundle_total
      from offers_dtl d
     where d.oferid = p_offer_id
       and d.list_id = p_list_id
       and d.is_deleted = c_not_deleted;

    if l_org_total > c_header_total_max or l_bundle_total > c_header_total_max then
      raise_application_error(
        c_err_bundle_total_overflow,
        'The Bundled Offer total exceeds the supported maximum.'
      );
    end if;

    update offers o
       set o.org_price = l_org_total,
           o.new_price = l_bundle_total
     where o.oferid = p_offer_id
       and o.list_id = p_list_id
       and o.offer_type = c_offer_type_bundled
       and o.offer_info_center = l_info_center_id
       and o.is_deleted = c_not_deleted
    returning o.object_version_number
         into o_header_ovn;

    if sql%rowcount = 0 then
      raise_application_error(c_err_offer_not_found, 'Bundled Offer was not found.');
    end if;
  end recalc_bundle_totals;


  procedure classify_bundle_component_failure(
    p_offer_id       in offers.oferid%type,
    p_list_id        in offers.list_id%type,
    p_row_id         in offers_dtl.row_id%type,
    p_expected_ovn   in offers_dtl.object_version_number%type
  )
  is
    l_line_offer_id offers_dtl.oferid%type;
    l_line_list_id  offers_dtl.list_id%type;
    l_is_deleted    offers_dtl.is_deleted%type;
    l_ovn           offers_dtl.object_version_number%type;
  begin
    select oferid,
           list_id,
           is_deleted,
           object_version_number
      into l_line_offer_id,
           l_line_list_id,
           l_is_deleted,
           l_ovn
      from offers_dtl
     where row_id = p_row_id;

    if l_line_offer_id <> p_offer_id or l_line_list_id <> p_list_id then
      raise_application_error(c_err_line_wrong_offer, 'Bundle component belongs to another Bundled Offer.');
    elsif l_is_deleted <> c_not_deleted then
      raise_application_error(c_err_line_removed, 'Bundle component is already removed.');
    elsif p_expected_ovn is not null and l_ovn <> p_expected_ovn then
      raise_application_error(c_err_line_stale, 'This Bundle component was changed by another user. Refresh and try again.');
    else
      raise_application_error(c_err_line_not_found, 'Bundle component was not updated.');
    end if;
  exception
    when no_data_found then
      raise_application_error(c_err_line_not_found, 'Bundle component was not found.');
  end classify_bundle_component_failure;


  procedure add_or_restore_bundle_component_internal(
    p_offer        in  offers%rowtype,
    p_service_id   in  offers_dtl.serviceid%type,
    p_quantity     in  offers_dtl.qty%type,
    p_bundle_price in  offers_dtl.offer_price%type,
    o_row_id       out offers_dtl.row_id%type,
    o_detail_ovn   out offers_dtl.object_version_number%type,
    o_header_ovn   out offers.object_version_number%type
  )
  is
    l_service_id   offers_dtl.serviceid%type;
    l_org_price    offers_dtl.org_price%type;
    l_org_discount offers_dtl.org_disc%type;
    l_vat_rate     services.vat_rate%type;
    l_existing_row offers_dtl.row_id%type;
    l_existing_del offers_dtl.is_deleted%type;
  begin
    o_row_id := null;
    o_detail_ovn := null;
    o_header_ovn := null;

    validate_bundle_quantity(p_quantity);
    validate_bundle_price(p_bundle_price);

    resolve_offer_service_pricing_for_offer(
      p_offer        => p_offer,
      p_service_id   => p_service_id,
      o_service_id   => l_service_id,
      o_org_price    => l_org_price,
      o_org_discount => l_org_discount,
      o_vat_rate     => l_vat_rate
    );

    assert_bundle_price_not_above_org(p_bundle_price, l_org_price);

    begin
      select row_id,
             is_deleted
        into l_existing_row,
             l_existing_del
        from offers_dtl
       where list_id = p_offer.list_id
         and oferid = p_offer.oferid
         and upper(trim(serviceid)) = l_service_id
       for update;

      if l_existing_del = c_not_deleted then
        raise_application_error(c_err_service_duplicate, 'Bundled Offer already contains active service ' || l_service_id || '.');
      end if;

      update offers_dtl
         set is_deleted = c_not_deleted,
             deleted_by = null,
             deleted_date = null,
             delete_reason = null,
             org_price = l_org_price,
             org_disc = l_org_discount,
             offer_price = p_bundle_price,
             offer_dis = null,
             qty = p_quantity
       where row_id = l_existing_row
      returning row_id,
                object_version_number
           into o_row_id,
                o_detail_ovn;

    exception
      when no_data_found then
        begin
          insert into offers_dtl (
            oferid,
            list_id,
            serviceid,
            org_price,
            org_disc,
            offer_price,
            offer_dis,
            qty,
            is_deleted
          ) values (
            p_offer.oferid,
            p_offer.list_id,
            l_service_id,
            l_org_price,
            l_org_discount,
            p_bundle_price,
            null,
            p_quantity,
            c_not_deleted
          )
          returning row_id,
                    object_version_number
               into o_row_id,
                    o_detail_ovn;

        exception
          when dup_val_on_index then
            raise_application_error(c_err_service_duplicate, 'Bundled Offer already contains active service ' || l_service_id || '.');
        end;
    end;

    recalc_bundle_totals(
      p_offer_id   => p_offer.oferid,
      p_list_id    => p_offer.list_id,
      o_header_ovn => o_header_ovn
    );
  end add_or_restore_bundle_component_internal;


  procedure assert_import_json_array(
    p_lines_json in  clob,
    o_line_count out pls_integer
  )
  is
    l_array json_array_t;
  begin
    o_line_count := 0;

    if p_lines_json is null
       or dbms_lob.getlength(p_lines_json) = 0
       or trim(dbms_lob.substr(p_lines_json, 32767, 1)) is null
    then
      raise_application_error(c_err_import_json_required, 'Import JSON is required.');
    end if;

    begin
      l_array := json_array_t.parse(p_lines_json);
    exception
      when others then
        if sqlcode = -40587 then
          raise_application_error(c_err_import_json_array, 'Import JSON must be an array.');
        elsif sqlcode between -40599 and -40400 then
          raise_application_error(c_err_import_json_bad, 'Import JSON is malformed.');
        else
          raise;
        end if;
    end;

    o_line_count := l_array.get_size;

    if o_line_count = 0 then
      raise_application_error(c_err_import_empty, 'No services were selected.');
    end if;
  end assert_import_json_array;


  function parse_import_offer_price(
    p_raw_value in varchar2,
    p_line_no   in pls_integer
  ) return offers_dtl.offer_price%type
  is
    l_number number;
    l_value  offers_dtl.offer_price%type;
  begin
    if p_raw_value is null then
      return null;
    end if;

    begin
      l_number := to_number(trim(p_raw_value));
      l_value := l_number;
    exception
      when value_error or invalid_number then
        raise_application_error(
          c_err_import_price_bad,
          'Invalid Offer Price JSON value in row ' || p_line_no || '.'
        );
    end;

    return l_value;
  end parse_import_offer_price;


  function parse_import_offer_discount(
    p_raw_value in varchar2,
    p_line_no   in pls_integer
  ) return offers_dtl.offer_dis%type
  is
    l_number number;
    l_value  offers_dtl.offer_dis%type;
  begin
    if p_raw_value is null then
      return null;
    end if;

    begin
      l_number := to_number(trim(p_raw_value));
      l_value := l_number;
    exception
      when value_error or invalid_number then
        raise_application_error(
          c_err_import_disc_bad,
          'Invalid Offer Discount JSON value in row ' || p_line_no || '.'
        );
    end;

    return l_value;
  end parse_import_offer_discount;


  procedure sort_import_lines(
    io_lines in out nocopy t_import_line_tab,
    p_count  in pls_integer
  )
  is
    l_tmp t_import_line_rec;
  begin
    if p_count <= 1 then
      return;
    end if;

    for i in 1 .. p_count - 1 loop
      for j in i + 1 .. p_count loop
        if io_lines(i).service_id > io_lines(j).service_id then
          l_tmp := io_lines(i);
          io_lines(i) := io_lines(j);
          io_lines(j) := l_tmp;
        end if;
      end loop;
    end loop;
  end sort_import_lines;


  procedure parse_import_lines(
    p_lines_json in  clob,
    o_lines      out nocopy t_import_line_tab,
    o_count      out pls_integer
  )
  is
    l_expected_count pls_integer;
    l_service_id     offers_dtl.serviceid%type;
    l_offer_price    offers_dtl.offer_price%type;
    l_offer_discount offers_dtl.offer_dis%type;
  begin
    o_lines.delete;
    o_count := 0;

    assert_import_json_array(p_lines_json, l_expected_count);

    begin
      for r in (
        select jt.line_no,
               jt.service_id,
               jt.offer_price_raw,
               jt.offer_discount_raw
          from json_table(
                 p_lines_json,
                 '$[*]'
                 columns (
                   line_no            for ordinality,
                   service_id         varchar2(4000) path '$.serviceId' null on empty error on error,
                   offer_price_raw    varchar2(4000) path '$.offerPrice' null on empty error on error,
                   offer_discount_raw varchar2(4000) path '$.offerDiscount' null on empty error on error
                 )
               ) jt
         order by jt.line_no
      ) loop
        if trim_to_null(r.service_id) is null then
          raise_application_error(
            c_err_import_service_req,
            'Service ID is missing in imported row ' || r.line_no || '.'
          );
        end if;

        l_service_id := normalize_service_id(r.service_id);
        l_offer_price := parse_import_offer_price(r.offer_price_raw, r.line_no);
        l_offer_discount := parse_import_offer_discount(r.offer_discount_raw, r.line_no);
        validate_line_overrides(l_offer_price, l_offer_discount);

        for i in 1 .. o_count loop
          if o_lines(i).service_id = l_service_id then
            raise_application_error(
              c_err_import_duplicate,
              'The import contains the same service more than once: ' || l_service_id || '.'
            );
          end if;
        end loop;

        o_count := o_count + 1;
        o_lines(o_count).line_no := r.line_no;
        o_lines(o_count).service_id := l_service_id;
        o_lines(o_count).offer_price := l_offer_price;
        o_lines(o_count).offer_discount := l_offer_discount;
        o_lines(o_count).org_price := null;
        o_lines(o_count).org_discount := null;
        o_lines(o_count).vat_rate := null;
      end loop;
    exception
      when others then
        if sqlcode between -40599 and -40400 then
          raise_application_error(c_err_import_json_bad, 'Import JSON is malformed.');
        else
          raise;
        end if;
    end;

    if o_count <> l_expected_count then
      raise_application_error(c_err_import_json_bad, 'Import JSON is malformed.');
    end if;

    sort_import_lines(o_lines, o_count);
  end parse_import_lines;


  procedure validate_import_lines_for_offer(
    p_offer in offers%rowtype,
    io_lines in out nocopy t_import_line_tab,
    p_count in pls_integer
  )
  is
    l_existing_del offers_dtl.is_deleted%type;
  begin
    for i in 1 .. p_count loop
      resolve_offer_service_pricing_for_offer(
        p_offer        => p_offer,
        p_service_id   => io_lines(i).service_id,
        o_service_id   => io_lines(i).service_id,
        o_org_price    => io_lines(i).org_price,
        o_org_discount => io_lines(i).org_discount,
        o_vat_rate     => io_lines(i).vat_rate
      );

      begin
        select is_deleted
          into l_existing_del
          from offers_dtl
         where list_id = p_offer.list_id
           and oferid = p_offer.oferid
           and upper(trim(serviceid)) = io_lines(i).service_id
         for update;

        if l_existing_del = c_not_deleted then
          raise_application_error(
            c_err_service_duplicate,
            'Service ' || io_lines(i).service_id || ' is already included in the Offer.'
          );
        end if;
      exception
        when no_data_found then
          null;
      end;
    end loop;
  end validate_import_lines_for_offer;


  procedure classify_offer_failure(
    p_offer_id        in offers.oferid%type,
    p_info_center_id  in offers.offer_info_center%type,
    p_expected_offer_type in offers.offer_type%type,
    p_expected_ovn    in offers.object_version_number%type
  )
  is
    l_offer_type     offers.offer_type%type;
    l_info_center_id offers.offer_info_center%type;
    l_is_deleted     offers.is_deleted%type;
    l_ovn            offers.object_version_number%type;
  begin
    select offer_type,
           offer_info_center,
           is_deleted,
           object_version_number
      into l_offer_type,
           l_info_center_id,
           l_is_deleted,
           l_ovn
      from offers
     where oferid = p_offer_id;

    if l_info_center_id <> p_info_center_id then
      raise_application_error(c_err_wrong_info_center, 'Offer does not belong to the current info center.');
    elsif l_offer_type <> p_expected_offer_type then
      if p_expected_offer_type = c_offer_type_standard then
        raise_application_error(c_err_wrong_type, 'Only standard offers can be managed by this package.');
      else
        raise_application_error(
          c_err_wrong_type,
          'Only ' || offer_type_name(p_expected_offer_type) || ' can be managed by this operation.'
        );
      end if;
    elsif l_is_deleted <> c_not_deleted then
      raise_application_error(c_err_retired, 'Offer is already retired.');
    elsif p_expected_ovn is not null and l_ovn <> p_expected_ovn then
      raise_application_error(c_err_stale_ovn, 'Offer has been changed by another session.');
    else
      raise_application_error(c_err_offer_not_found, 'Offer was not updated.');
    end if;
  exception
    when no_data_found then
      raise_application_error(c_err_offer_not_found, 'Offer was not found.');
  end classify_offer_failure;


  procedure create_offer(
      p_offer_name             in  offers.offer_name%type,
      p_start_date             in  offers.start_date%type,
      p_end_date               in  offers.enddate%type,
      p_description            in  offers.notes%type,
      o_offer_id               out offers.oferid%type,
      o_object_version_number  out offers.object_version_number%type
  )
  is
    l_info_center_id offers.offer_info_center%type;
    l_list_id        offers.list_id%type;
    l_offer_name     offers.offer_name%type;
    l_description    offers.notes%type;
  begin
    o_offer_id := null;
    o_object_version_number := null;

    l_offer_name := normalize_offer_name(p_offer_name);
    l_description := normalize_description(p_description);
    assert_dates(p_start_date, p_end_date);

    l_info_center_id := current_info_center_id;
    l_list_id := resolve_cash_list_id(l_info_center_id);

    insert into offers (
      offer_name,
      start_date,
      enddate,
      notes,
      list_id,
      with_vat,
      offer_type,
      offer_info_center,
      is_deleted
    ) values (
      l_offer_name,
      p_start_date,
      p_end_date,
      l_description,
      l_list_id,
      c_with_vat_default,
      c_offer_type_standard,
      l_info_center_id,
      c_not_deleted
    )
    returning oferid,
              object_version_number
         into o_offer_id,
              o_object_version_number;
  end create_offer;


  procedure update_offer(
      p_offer_id               in  offers.oferid%type,
      p_offer_name             in  offers.offer_name%type,
      p_start_date             in  offers.start_date%type,
      p_end_date               in  offers.enddate%type,
      p_description            in  offers.notes%type,
      p_expected_ovn           in  offers.object_version_number%type,
      o_new_ovn                out offers.object_version_number%type
  )
  is
    l_info_center_id offers.offer_info_center%type;
    l_offer_name     offers.offer_name%type;
    l_description    offers.notes%type;
    l_offer          offers%rowtype;
  begin
    o_new_ovn := null;

    assert_offer_id(p_offer_id);
    assert_expected_ovn(p_expected_ovn);
    l_offer_name := normalize_offer_name(p_offer_name);
    l_description := normalize_description(p_description);
    assert_dates(p_start_date, p_end_date);

    l_info_center_id := current_info_center_id;

    load_and_validate_offer(p_offer_id, c_offer_type_standard, true, l_offer);
    if l_offer.object_version_number <> p_expected_ovn then
      raise_application_error(c_err_stale_ovn, 'Offer has been changed by another session.');
    end if;

    lock_and_validate_standard_header(
      p_offer      => l_offer,
      p_start_date => p_start_date,
      p_end_date   => p_end_date
    );

    update offers
       set offer_name = l_offer_name,
           start_date = p_start_date,
           enddate = p_end_date,
           notes = l_description
     where oferid = p_offer_id
       and offer_type = c_offer_type_standard
       and offer_info_center = l_info_center_id
       and is_deleted = c_not_deleted
       and object_version_number = p_expected_ovn
    returning object_version_number
         into o_new_ovn;

    if sql%rowcount = 0 then
      classify_offer_failure(p_offer_id, l_info_center_id, c_offer_type_standard, p_expected_ovn);
    end if;
  end update_offer;


  procedure retire_offer(
      p_offer_id               in offers.oferid%type,
      p_delete_reason          in offers.delete_reason%type,
      p_expected_ovn           in offers.object_version_number%type
  )
  is
    l_info_center_id offers.offer_info_center%type;
    l_delete_reason  offers.delete_reason%type;
    l_offer          offers%rowtype;
  begin
    assert_offer_id(p_offer_id);
    assert_expected_ovn(p_expected_ovn);

    l_info_center_id := current_info_center_id;
    l_delete_reason := normalize_delete_reason(p_delete_reason);

    begin
      select *
        into l_offer
        from offers
       where oferid = p_offer_id
       for update;
    exception
      when no_data_found then
        raise_application_error(c_err_offer_not_found, 'Offer was not found.');
    end;

    if l_offer.offer_info_center <> l_info_center_id then
      raise_application_error(c_err_wrong_info_center, 'Offer does not belong to the current info center.');
    elsif l_offer.offer_type <> c_offer_type_standard then
      raise_application_error(c_err_wrong_type, 'Only standard offers can be managed by this package.');
    elsif l_offer.is_deleted <> c_not_deleted then
      raise_application_error(c_err_retired, 'Offer is already retired.');
    elsif l_offer.object_version_number <> p_expected_ovn then
      raise_application_error(c_err_stale_ovn, 'Offer has been changed by another session.');
    end if;

    update offers_dtl
       set is_deleted = c_deleted,
           delete_reason = c_delete_reason_offer_retired
     where oferid = p_offer_id
       and list_id = l_offer.list_id
       and is_deleted = c_not_deleted;

    update offers
       set is_deleted = c_deleted,
           delete_reason = l_delete_reason
     where oferid = p_offer_id;
  end retire_offer;


  procedure get_offer_service_pricing(
      p_offer_id       in  offers.oferid%type,
      p_service_id     in  offers_dtl.serviceid%type,
      o_org_price      out offers_dtl.org_price%type,
      o_org_discount   out offers_dtl.org_disc%type,
      o_vat_rate       out services.vat_rate%type
  )
  is
    l_list_id    offers.list_id%type;
    l_service_id offers_dtl.serviceid%type;
  begin
    resolve_offer_service_pricing_internal(
      p_offer_id     => p_offer_id,
      p_service_id   => p_service_id,
      p_expected_offer_type => c_offer_type_standard,
      p_lock_offer   => false,
      o_list_id      => l_list_id,
      o_service_id   => l_service_id,
      o_org_price    => o_org_price,
      o_org_discount => o_org_discount,
      o_vat_rate     => o_vat_rate
    );
  end get_offer_service_pricing;


  procedure add_offer_line(
      p_offer_id                  in  offers.oferid%type,
      p_service_id                in  offers_dtl.serviceid%type,
      p_offer_price               in  offers_dtl.offer_price%type,
      p_offer_discount            in  offers_dtl.offer_dis%type,
      o_row_id                    out offers_dtl.row_id%type,
      o_object_version_number     out offers_dtl.object_version_number%type
  )
  is
    l_offer  offers%rowtype;
    l_action varchar2(10);
  begin
    o_row_id := null;
    o_object_version_number := null;

    assert_offer_id(p_offer_id);
    load_and_validate_offer(p_offer_id, c_offer_type_standard, true, l_offer);

    add_or_restore_offer_line_internal(
      p_offer                 => l_offer,
      p_service_id            => p_service_id,
      p_offer_price           => p_offer_price,
      p_offer_discount        => p_offer_discount,
      o_row_id                => o_row_id,
      o_object_version_number => o_object_version_number,
      o_action                => l_action
    );
  end add_offer_line;


  procedure update_offer_line(
      p_offer_id                  in  offers.oferid%type,
      p_row_id                    in  offers_dtl.row_id%type,
      p_offer_price               in  offers_dtl.offer_price%type,
      p_offer_discount            in  offers_dtl.offer_dis%type,
      p_expected_ovn              in  offers_dtl.object_version_number%type,
      o_new_ovn                   out offers_dtl.object_version_number%type
  )
  is
    l_offer offers%rowtype;
    l_service_id offers_dtl.serviceid%type;
  begin
    o_new_ovn := null;

    assert_offer_id(p_offer_id);
    assert_row_id(p_row_id);
    assert_expected_ovn(p_expected_ovn);
    validate_line_overrides(p_offer_price, p_offer_discount);
    load_and_validate_offer(p_offer_id, c_offer_type_standard, true, l_offer);

    begin
      select serviceid
        into l_service_id
        from offers_dtl
       where row_id = p_row_id
         and oferid = p_offer_id
         and list_id = l_offer.list_id
         and is_deleted = c_not_deleted
         and object_version_number = p_expected_ovn;
    exception
      when no_data_found then
        classify_offer_line_failure(p_offer_id, l_offer.list_id, p_row_id, p_expected_ovn);
    end;

    lock_standard_service(l_offer.list_id, l_service_id);
    assert_no_standard_overlap(
      l_offer.oferid,
      l_offer.offer_info_center,
      l_offer.list_id,
      l_service_id,
      l_offer.start_date,
      l_offer.enddate
    );

    update offers_dtl
       set offer_price = p_offer_price,
           offer_dis = p_offer_discount
     where row_id = p_row_id
       and oferid = p_offer_id
       and list_id = l_offer.list_id
       and is_deleted = c_not_deleted
       and object_version_number = p_expected_ovn
    returning object_version_number
         into o_new_ovn;

    if sql%rowcount = 0 then
      classify_offer_line_failure(p_offer_id, l_offer.list_id, p_row_id, p_expected_ovn);
    end if;
  end update_offer_line;


  procedure remove_offer_line(
      p_offer_id                  in offers.oferid%type,
      p_row_id                    in offers_dtl.row_id%type,
      p_expected_ovn              in offers_dtl.object_version_number%type
  )
  is
    l_offer offers%rowtype;
  begin
    assert_offer_id(p_offer_id);
    assert_row_id(p_row_id);
    assert_expected_ovn(p_expected_ovn);
    load_and_validate_offer(p_offer_id, c_offer_type_standard, true, l_offer);

    update offers_dtl
       set is_deleted = c_deleted,
           delete_reason = null
     where row_id = p_row_id
       and oferid = p_offer_id
       and list_id = l_offer.list_id
       and is_deleted = c_not_deleted
       and object_version_number = p_expected_ovn;

    if sql%rowcount = 0 then
      classify_offer_line_failure(p_offer_id, l_offer.list_id, p_row_id, p_expected_ovn);
    end if;
  end remove_offer_line;


  procedure import_offer_lines(
      p_offer_id        in  offers.oferid%type,
      p_lines_json      in  clob,
      o_imported_count  out pls_integer,
      o_restored_count  out pls_integer
  )
  is
    l_offer offers%rowtype;
    l_lines t_import_line_tab;
    l_count pls_integer;
    l_row_id offers_dtl.row_id%type;
    l_ovn offers_dtl.object_version_number%type;
    l_action varchar2(10);
  begin
    o_imported_count := 0;
    o_restored_count := 0;

    assert_offer_id(p_offer_id);
    parse_import_lines(p_lines_json, l_lines, l_count);
    load_and_validate_offer(p_offer_id, c_offer_type_standard, true, l_offer);
    validate_import_lines_for_offer(l_offer, l_lines, l_count);

    for r in (
      select distinct upper(trim(jt.service_id)) service_id
        from json_table(
               p_lines_json,
               '$[*]' columns (service_id varchar2(20) path '$.serviceId')
             ) jt
       order by upper(trim(jt.service_id))
    ) loop
      lock_standard_service(l_offer.list_id, r.service_id);
      assert_no_standard_overlap(
        l_offer.oferid,
        l_offer.offer_info_center,
        l_offer.list_id,
        r.service_id,
        l_offer.start_date,
        l_offer.enddate
      );
    end loop;

    for i in 1 .. l_count loop
      add_or_restore_offer_line_internal(
        p_offer                 => l_offer,
        p_service_id            => l_lines(i).service_id,
        p_offer_price           => l_lines(i).offer_price,
        p_offer_discount        => l_lines(i).offer_discount,
        o_row_id                => l_row_id,
        o_object_version_number => l_ovn,
        o_action                => l_action
      );

      if l_action = c_action_add then
        o_imported_count := o_imported_count + 1;
      elsif l_action = c_action_restore then
        o_restored_count := o_restored_count + 1;
      end if;
    end loop;
  end import_offer_lines;


  procedure create_bundled_offer(
      p_offer_name              in  offers.offer_name%type,
      p_start_date              in  offers.start_date%type,
      p_end_date                in  offers.enddate%type,
      p_description             in  offers.notes%type,
      p_valid_days              in  offers.valid_dayes%type,
      o_offer_id                out offers.oferid%type,
      o_object_version_number   out offers.object_version_number%type
  )
  is
    l_info_center_id offers.offer_info_center%type;
    l_list_id        offers.list_id%type;
    l_offer_name     offers.offer_name%type;
    l_description    offers.notes%type;
  begin
    o_offer_id := null;
    o_object_version_number := null;

    l_offer_name := normalize_offer_name(p_offer_name);
    l_description := normalize_description(p_description);
    assert_dates(p_start_date, p_end_date);
    assert_valid_days(p_valid_days);

    l_info_center_id := current_info_center_id;
    l_list_id := resolve_cash_list_id(l_info_center_id);

    insert into offers (
      offer_name,
      start_date,
      enddate,
      notes,
      list_id,
      serviceid,
      org_price,
      valid_dayes,
      with_vat,
      new_price,
      offer_type,
      offer_info_center,
      is_deleted
    ) values (
      l_offer_name,
      p_start_date,
      p_end_date,
      l_description,
      l_list_id,
      null,
      0,
      p_valid_days,
      c_with_vat_default,
      0,
      c_offer_type_bundled,
      l_info_center_id,
      c_not_deleted
    )
    returning oferid,
              object_version_number
         into o_offer_id,
              o_object_version_number;
  end create_bundled_offer;


  procedure update_bundled_offer(
      p_offer_id                in  offers.oferid%type,
      p_offer_name              in  offers.offer_name%type,
      p_start_date              in  offers.start_date%type,
      p_end_date                in  offers.enddate%type,
      p_description             in  offers.notes%type,
      p_valid_days              in  offers.valid_dayes%type,
      p_expected_ovn            in  offers.object_version_number%type,
      o_new_ovn                 out offers.object_version_number%type
  )
  is
    l_info_center_id offers.offer_info_center%type;
    l_offer_name     offers.offer_name%type;
    l_description    offers.notes%type;
  begin
    o_new_ovn := null;

    assert_offer_id(p_offer_id);
    assert_expected_ovn(p_expected_ovn);
    l_offer_name := normalize_offer_name(p_offer_name);
    l_description := normalize_description(p_description);
    assert_dates(p_start_date, p_end_date);
    assert_valid_days(p_valid_days);

    l_info_center_id := current_info_center_id;

    update offers
       set offer_name = l_offer_name,
           start_date = p_start_date,
           enddate = p_end_date,
           notes = l_description,
           valid_dayes = p_valid_days
     where oferid = p_offer_id
       and offer_type = c_offer_type_bundled
       and offer_info_center = l_info_center_id
       and is_deleted = c_not_deleted
       and object_version_number = p_expected_ovn
    returning object_version_number
         into o_new_ovn;

    if sql%rowcount = 0 then
      classify_offer_failure(p_offer_id, l_info_center_id, c_offer_type_bundled, p_expected_ovn);
    end if;
  end update_bundled_offer;


  procedure retire_bundled_offer(
      p_offer_id                in offers.oferid%type,
      p_delete_reason           in offers.delete_reason%type,
      p_expected_ovn            in offers.object_version_number%type
  )
  is
    l_offer         offers%rowtype;
    l_delete_reason offers.delete_reason%type;
  begin
    assert_offer_id(p_offer_id);
    assert_expected_ovn(p_expected_ovn);
    l_delete_reason := normalize_delete_reason(p_delete_reason);

    load_and_validate_offer(p_offer_id, c_offer_type_bundled, true, l_offer);

    if l_offer.object_version_number <> p_expected_ovn then
      raise_application_error(c_err_stale_ovn, 'Offer has been changed by another session.');
    end if;

    update offers_dtl
       set is_deleted = c_deleted,
           delete_reason = c_delete_reason_offer_retired
     where oferid = p_offer_id
       and list_id = l_offer.list_id
       and is_deleted = c_not_deleted;

    update offers
       set is_deleted = c_deleted,
           delete_reason = l_delete_reason
     where oferid = p_offer_id;
  end retire_bundled_offer;


  procedure get_bundle_component_pricing(
      p_offer_id       in  offers.oferid%type,
      p_service_id     in  offers_dtl.serviceid%type,
      o_org_price      out offers_dtl.org_price%type,
      o_org_discount   out offers_dtl.org_disc%type,
      o_vat_rate       out services.vat_rate%type
  )
  is
    l_list_id    offers.list_id%type;
    l_service_id offers_dtl.serviceid%type;
  begin
    resolve_offer_service_pricing_internal(
      p_offer_id             => p_offer_id,
      p_service_id           => p_service_id,
      p_expected_offer_type  => c_offer_type_bundled,
      p_lock_offer           => false,
      o_list_id              => l_list_id,
      o_service_id           => l_service_id,
      o_org_price            => o_org_price,
      o_org_discount         => o_org_discount,
      o_vat_rate             => o_vat_rate
    );
  end get_bundle_component_pricing;


  procedure add_bundle_component(
      p_offer_id        in  offers.oferid%type,
      p_service_id      in  offers_dtl.serviceid%type,
      p_quantity        in  offers_dtl.qty%type,
      p_bundle_price    in  offers_dtl.offer_price%type,
      o_row_id          out offers_dtl.row_id%type,
      o_detail_ovn      out offers_dtl.object_version_number%type,
      o_header_ovn      out offers.object_version_number%type
  )
  is
    l_offer offers%rowtype;
  begin
    o_row_id := null;
    o_detail_ovn := null;
    o_header_ovn := null;

    assert_offer_id(p_offer_id);
    load_and_validate_offer(p_offer_id, c_offer_type_bundled, true, l_offer);

    add_or_restore_bundle_component_internal(
      p_offer        => l_offer,
      p_service_id   => p_service_id,
      p_quantity     => p_quantity,
      p_bundle_price => p_bundle_price,
      o_row_id       => o_row_id,
      o_detail_ovn   => o_detail_ovn,
      o_header_ovn   => o_header_ovn
    );
  end add_bundle_component;


  procedure update_bundle_component(
      p_offer_id            in  offers.oferid%type,
      p_row_id              in  offers_dtl.row_id%type,
      p_quantity            in  offers_dtl.qty%type,
      p_bundle_price        in  offers_dtl.offer_price%type,
      p_expected_detail_ovn in  offers_dtl.object_version_number%type,
      o_detail_ovn          out offers_dtl.object_version_number%type,
      o_header_ovn          out offers.object_version_number%type
  )
  is
    l_offer     offers%rowtype;
    l_org_price offers_dtl.org_price%type;
  begin
    o_detail_ovn := null;
    o_header_ovn := null;

    assert_offer_id(p_offer_id);
    assert_row_id(p_row_id);
    assert_expected_ovn(p_expected_detail_ovn);
    validate_bundle_quantity(p_quantity);
    validate_bundle_price(p_bundle_price);
    load_and_validate_offer(p_offer_id, c_offer_type_bundled, true, l_offer);

    begin
      select d.org_price
        into l_org_price
        from offers_dtl d
       where d.row_id = p_row_id
         and d.oferid = p_offer_id
         and d.list_id = l_offer.list_id
         and d.is_deleted = c_not_deleted
         and d.object_version_number = p_expected_detail_ovn
       for update;
    exception
      when no_data_found then
        classify_bundle_component_failure(p_offer_id, l_offer.list_id, p_row_id, p_expected_detail_ovn);
    end;

    assert_bundle_price_not_above_org(p_bundle_price, l_org_price);

    update offers_dtl
       set qty = p_quantity,
           offer_price = p_bundle_price,
           offer_dis = null
     where row_id = p_row_id
       and oferid = p_offer_id
       and list_id = l_offer.list_id
       and is_deleted = c_not_deleted
       and object_version_number = p_expected_detail_ovn
    returning object_version_number
         into o_detail_ovn;

    if sql%rowcount = 0 then
      classify_bundle_component_failure(p_offer_id, l_offer.list_id, p_row_id, p_expected_detail_ovn);
    end if;

    recalc_bundle_totals(
      p_offer_id   => p_offer_id,
      p_list_id    => l_offer.list_id,
      o_header_ovn => o_header_ovn
    );
  end update_bundle_component;


  procedure remove_bundle_component(
      p_offer_id            in  offers.oferid%type,
      p_row_id              in  offers_dtl.row_id%type,
      p_expected_detail_ovn in  offers_dtl.object_version_number%type,
      o_header_ovn          out offers.object_version_number%type
  )
  is
    l_offer offers%rowtype;
  begin
    o_header_ovn := null;

    assert_offer_id(p_offer_id);
    assert_row_id(p_row_id);
    assert_expected_ovn(p_expected_detail_ovn);
    load_and_validate_offer(p_offer_id, c_offer_type_bundled, true, l_offer);

    update offers_dtl
       set is_deleted = c_deleted,
           delete_reason = null
     where row_id = p_row_id
       and oferid = p_offer_id
       and list_id = l_offer.list_id
       and is_deleted = c_not_deleted
       and object_version_number = p_expected_detail_ovn;

    if sql%rowcount = 0 then
      classify_bundle_component_failure(p_offer_id, l_offer.list_id, p_row_id, p_expected_detail_ovn);
    end if;

    recalc_bundle_totals(
      p_offer_id   => p_offer_id,
      p_list_id    => l_offer.list_id,
      o_header_ovn => o_header_ovn
    );
  end remove_bundle_component;

end bil_offers_admin;
/
