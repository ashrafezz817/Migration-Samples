-- migration reference extract.

create or replace package bil_cashier_shift authid definer as

  procedure start_shift (
    p_cash_at_begin        in  cashier_shift.cash_at_begin%type,
    o_shift_system_unique  out cashier_shift.shift_system_unique%type,
    p_user_no              in  cashier_shift.user_no%type default null,
    p_info_center_id       in  cashier_shift.info_center_id%type default null
  );

end bil_cashier_shift;
/

create or replace package body bil_cashier_shift as

  c_shift_status_open constant number := 2;


  function trim_to_null (
    p_value in varchar2
  ) return varchar2
  is
    l_value varchar2(32767);
  begin
    l_value := trim(p_value);
    return case when l_value is null then null else l_value end;
  end trim_to_null;


  function safe_to_number (
    p_value in varchar2
  ) return number
  is
  begin
    if trim_to_null(p_value) is null then
      return null;
    end if;

    return to_number(trim(p_value));
  exception
    when value_error or invalid_number then
      return null;
  end safe_to_number;


  function session_number (
    p_item_name in varchar2
  ) return number
  is
  begin
    return safe_to_number(v(p_item_name));
  exception
    when others then
      return null;
  end session_number;


  function session_varchar2 (
    p_item_name in varchar2
  ) return varchar2
  is
  begin
    return trim_to_null(v(p_item_name));
  exception
    when others then
      return null;
  end session_varchar2;


  function effective_user_no (
    p_user_no in cashier_shift.user_no%type
  ) return cashier_shift.user_no%type
  is
    l_user_no cashier_shift.user_no%type;
  begin
    l_user_no := p_user_no;

    if l_user_no is null then
      l_user_no := session_number('G_USER_ID');
    end if;

    if l_user_no is null then
      raise_application_error(
        -20878,
        'Cashier shift failed: user number is required.'
      );
    end if;

    return l_user_no;
  end effective_user_no;


  function effective_info_center_id (
    p_info_center_id in cashier_shift.info_center_id%type
  ) return cashier_shift.info_center_id%type
  is
    l_info_center_id cashier_shift.info_center_id%type;
  begin
    l_info_center_id := trim_to_null(p_info_center_id);

    if l_info_center_id is null then
      l_info_center_id := session_varchar2('G_INFO_CENTER_ID');
    end if;

    if l_info_center_id is null then
      raise_application_error(
        -20879,
        'Cashier shift failed: info center is required.'
      );
    end if;

    return l_info_center_id;
  end effective_info_center_id;


  procedure start_shift (
    p_cash_at_begin        in  cashier_shift.cash_at_begin%type,
    o_shift_system_unique  out cashier_shift.shift_system_unique%type,
    p_user_no              in  cashier_shift.user_no%type default null,
    p_info_center_id       in  cashier_shift.info_center_id%type default null
  )
  is
    l_user_no        cashier_shift.user_no%type;
    l_info_center_id cashier_shift.info_center_id%type;
    l_cash_at_begin  cashier_shift.cash_at_begin%type;
  begin
    o_shift_system_unique := null;

    l_user_no        := effective_user_no(p_user_no);
    l_info_center_id := effective_info_center_id(p_info_center_id);
    l_cash_at_begin  := nvl(p_cash_at_begin, 0);

    if l_cash_at_begin < 0 then
      raise_application_error(
        -20880,
        'Cashier shift start failed: cash at begin cannot be negative.'
      );
    end if;

    insert into cashier_shift (
      the_date,
      user_no,
      cash_at_begin,
      shift_status,
      info_center_id,
      start_time,
      opened_at
    )
    values (
      trunc(sysdate),
      l_user_no,
      l_cash_at_begin,
      c_shift_status_open,
      l_info_center_id,
      to_char(sysdate, 'HH24:MI:SS'),
      systimestamp
    )
    returning shift_system_unique into o_shift_system_unique;
  exception
    when dup_val_on_index then
      raise_application_error(
        -20881,
        'Cashier shift start failed: this user already has an open shift.'
      );
  end start_shift;

end bil_cashier_shift;
/
