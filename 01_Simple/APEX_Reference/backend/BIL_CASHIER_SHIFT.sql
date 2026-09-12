create or replace package bil_cashier_shift authid definer as

  type t_shift_context is record (
    user_no                cashier_shift.user_no%type,
    shift_system_unique    cashier_shift.shift_system_unique%type,
    shift_status           cashier_shift.shift_status%type,
    info_center_id         cashier_shift.info_center_id%type,
    opened_at              cashier_shift.opened_at%type,
    closed_at              cashier_shift.closed_at%type,
    cash_at_begin          cashier_shift.cash_at_begin%type,
    cash_in                cashier_shift.cash_in%type,
    cash_out               cashier_shift.cash_out%type,
    cash_at_end            cashier_shift.cash_at_end%type,
    cash_as_inv            cashier_shift.cash_as_inv%type,
    start_inv              cashier_shift.start_inv%type,
    end_inv                cashier_shift.end_inv%type,

    shift_control_enabled  varchar2(1),
    is_invoice_admin       varchar2(1),

    is_allowed             varchar2(1),
    is_bypass              varchar2(1),
    bypass_reason          varchar2(100),
    message                varchar2(4000)
  );

  procedure start_shift (
    p_cash_at_begin        in  cashier_shift.cash_at_begin%type,
    o_shift_system_unique  out cashier_shift.shift_system_unique%type,
    p_user_no              in  cashier_shift.user_no%type default null,
    p_info_center_id       in  cashier_shift.info_center_id%type default null
  );

  procedure end_shift (
    p_shift_system_unique  in cashier_shift.shift_system_unique%type,
    p_cash_at_end          in cashier_shift.cash_at_end%type,
    p_user_no              in cashier_shift.user_no%type default null
  );

  procedure get_current_shift (
    p_user_no         in  cashier_shift.user_no%type,
    p_info_center_id  in  cashier_shift.info_center_id%type,
    o_shift_context   out nocopy t_shift_context
  );

  procedure get_open_shift_summary (
    p_user_no        in  cashier_shift.user_no%type,
    o_shift_context  out nocopy t_shift_context
  );

  procedure assert_can_create_invoice (
    p_user_no              in  cashier_shift.user_no%type,
    p_info_center_id       in  cashier_shift.info_center_id%type,
    o_shift_system_unique  out cashier_shift.shift_system_unique%type
  );

  function has_open_shift (
    p_user_no         in cashier_shift.user_no%type
  ) return varchar2;

end bil_cashier_shift;
/

create or replace package body bil_cashier_shift as

  c_yes constant varchar2(1) := 'Y';
  c_no  constant varchar2(1) := 'N';

  c_shift_status_closed constant number := 1;
  c_shift_status_open   constant number := 2;

  c_require_shift_setting constant fnd_app_settings.setting_code%type :=
    'BILLING.REQUIRE_ACTIVE_SHIFT_FOR_INVOICE';

  c_invoice_admin_perm constant fnd_permissions.permission_code%type :=
    'BILLING_INVOICE_ADMIN';

  c_invoice_admin_item constant varchar2(100) :=
    'G_BILLING_INVOICE_ADMIN';


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


  function normalize_yes_no (
    p_value        in varchar2,
    p_value_name   in varchar2,
    p_allow_null   in varchar2 default c_no
  ) return varchar2
  is
    l_value varchar2(100);
  begin
    l_value := upper(trim(p_value));

    if l_value is null then
      if p_allow_null = c_yes then
        return null;
      end if;

      raise_application_error(
        -20876,
        p_value_name || ' is required. Expected Y or N.'
      );
    end if;

    if l_value in ('Y', 'YES', 'TRUE', '1') then
      return c_yes;
    elsif l_value in ('N', 'NO', 'FALSE', '0') then
      return c_no;
    end if;

    raise_application_error(
      -20877,
      'Invalid ' || p_value_name || ' value. Expected Y or N.'
    );
  end normalize_yes_no;


  function shift_control_enabled
    return varchar2
  is
  begin
    return normalize_yes_no(
             p_value      => fnd_app_settings_pkg.get_value(
                               p_setting_code => c_require_shift_setting,
                               p_required     => c_yes
                             ),
             p_value_name => c_require_shift_setting
           );
  end shift_control_enabled;


  function invoice_admin_from_session
    return varchar2
  is
  begin
    return normalize_yes_no(
             p_value      => v(c_invoice_admin_item),
             p_value_name => c_invoice_admin_item,
             p_allow_null => c_yes
           );
  end invoice_admin_from_session;


  function is_invoice_admin
    return varchar2
  is
    l_session_value varchar2(1);
  begin
    l_session_value := invoice_admin_from_session;

    if l_session_value is not null then
      return l_session_value;
    end if;

    if upper(trim(fnd_app_security.has_permission(c_invoice_admin_perm))) = 'TRUE' then
      return c_yes;
    end if;

    return c_no;
  end is_invoice_admin;


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


  procedure init_context (
    p_user_no        in  cashier_shift.user_no%type,
    o_shift_context  out nocopy t_shift_context
  )
  is
  begin
    o_shift_context.user_no               := p_user_no;
    o_shift_context.shift_system_unique   := null;
    o_shift_context.shift_status          := null;
    o_shift_context.info_center_id        := null;
    o_shift_context.opened_at             := null;
    o_shift_context.closed_at             := null;
    o_shift_context.cash_at_begin         := null;
    o_shift_context.cash_in               := null;
    o_shift_context.cash_out              := null;
    o_shift_context.cash_at_end           := null;
    o_shift_context.cash_as_inv           := null;
    o_shift_context.start_inv             := null;
    o_shift_context.end_inv               := null;
    o_shift_context.shift_control_enabled := shift_control_enabled;
    o_shift_context.is_invoice_admin      := is_invoice_admin;
    o_shift_context.is_allowed            := c_no;
    o_shift_context.is_bypass             := c_no;
    o_shift_context.bypass_reason         := null;
    o_shift_context.message               := null;
  end init_context;


procedure get_open_shift_raw (
  p_user_no              in  cashier_shift.user_no%type,
  p_info_center_id       in  cashier_shift.info_center_id%type,
  o_open_count           out number,
  o_shift_system_unique  out cashier_shift.shift_system_unique%type
)
is
begin
  if p_user_no is null then
    raise_application_error(
      -20870,
      'Cashier shift validation failed: user number is required.'
    );
  end if;

  if p_info_center_id is null then
    raise_application_error(
      -20879,
      'Cashier shift validation failed: information center is required.'
    );
  end if;

  select count(*),
         min(cs.shift_system_unique)
    into o_open_count,
         o_shift_system_unique
    from cashier_shift cs
   where cs.user_no        = p_user_no
     and cs.info_center_id = p_info_center_id
     and cs.shift_status   = c_shift_status_open;
end get_open_shift_raw;

procedure load_shift_context (
  p_shift_system_unique in cashier_shift.shift_system_unique%type,
  p_user_no             in cashier_shift.user_no%type,
  p_info_center_id      in cashier_shift.info_center_id%type,
  io_shift_context      in out nocopy t_shift_context
)
is
begin
  select cs.user_no,
         cs.shift_system_unique,
         cs.shift_status,
         cs.info_center_id,
         cs.opened_at,
         cs.closed_at,
         cs.cash_at_begin,
         cs.cash_in,
         cs.cash_out,
         cs.cash_at_end,
         cs.cash_as_inv,
         cs.start_inv,
         cs.end_inv
    into io_shift_context.user_no,
         io_shift_context.shift_system_unique,
         io_shift_context.shift_status,
         io_shift_context.info_center_id,
         io_shift_context.opened_at,
         io_shift_context.closed_at,
         io_shift_context.cash_at_begin,
         io_shift_context.cash_in,
         io_shift_context.cash_out,
         io_shift_context.cash_at_end,
         io_shift_context.cash_as_inv,
         io_shift_context.start_inv,
         io_shift_context.end_inv
    from cashier_shift cs
   where cs.shift_system_unique = p_shift_system_unique
     and cs.user_no             = p_user_no
     and cs.info_center_id      = p_info_center_id
     and cs.shift_status        = c_shift_status_open
   for update;
exception
  when no_data_found then
    raise_application_error(
      -20872,
      'Cannot create invoice. The cashier shift is closed or is no longer available for this information center.'
    );
end load_shift_context;


  procedure calculate_shift_totals (
    p_shift_system_unique in  cashier_shift.shift_system_unique%type,
    o_cash_in             out cashier_shift.cash_in%type,
    o_cash_out            out cashier_shift.cash_out%type,
    o_cash_as_inv         out cashier_shift.cash_as_inv%type,
    o_start_inv           out cashier_shift.start_inv%type,
    o_end_inv             out cashier_shift.end_inv%type
  )
  is
  begin
    select nvl(sum(
             case
               when t.deduct_type = 'A' then tp.amount
               when tp.inv_no is null then tp.amount
               when t.deduct_type = 'B' then tp.amount_ab
               else tp.amount
             end
           ), 0)
      into o_cash_in
      from trans_payment tp
      left join t_inv t
        on t.inv_no = tp.inv_no
     where tp.pay_type_id <= 4
       and tp.shift_system_unique = p_shift_system_unique;

    select nvl(sum(tp.local_amount), 0)
      into o_cash_out
      from trans_payment tp
     where tp.pay_type_id = 1
       and tp.shift_system_unique = p_shift_system_unique
       and nvl(tp.amount_out, 0) > 0;

    select min(t.inv_no),
           max(t.inv_no)
      into o_start_inv,
           o_end_inv
      from t_inv t
     where t.shift_system_unique = p_shift_system_unique;

    select nvl(sum(
             case
               when t.deduct_type = 'A' then tp.amount
               when t.deduct_type = 'B' then tp.amount_ab
               else tp.amount
             end
           ), 0)
      into o_cash_as_inv
      from trans_payment tp
      join t_inv t
        on t.inv_no = tp.inv_no
     where tp.pay_type_id <= 4
       and tp.shift_system_unique = p_shift_system_unique;
  end calculate_shift_totals;


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


  procedure end_shift (
    p_shift_system_unique  in cashier_shift.shift_system_unique%type,
    p_cash_at_end          in cashier_shift.cash_at_end%type,
    p_user_no              in cashier_shift.user_no%type default null
  )
  is
    l_user_no        cashier_shift.user_no%type;
    l_shift_user_no  cashier_shift.user_no%type;
    l_shift_status   cashier_shift.shift_status%type;
    l_cash_in        cashier_shift.cash_in%type;
    l_cash_out       cashier_shift.cash_out%type;
    l_cash_as_inv    cashier_shift.cash_as_inv%type;
    l_start_inv      cashier_shift.start_inv%type;
    l_end_inv        cashier_shift.end_inv%type;
  begin
    if p_shift_system_unique is null then
      raise_application_error(
        -20882,
        'Cashier shift end failed: shift reference is required.'
      );
    end if;

    if p_cash_at_end is null or p_cash_at_end < 0 then
      raise_application_error(
        -20883,
        'Cashier shift end failed: cash at end is required and cannot be negative.'
      );
    end if;

    l_user_no := effective_user_no(p_user_no);

    select cs.user_no,
           cs.shift_status
      into l_shift_user_no,
           l_shift_status
      from cashier_shift cs
     where cs.shift_system_unique = p_shift_system_unique
     for update;

    if l_shift_status <> c_shift_status_open then
      raise_application_error(
        -20884,
        'Cashier shift end failed: shift is not open.'
      );
    end if;

    if l_shift_user_no <> l_user_no then
      raise_application_error(
        -20885,
        'Cashier shift end failed: shift does not belong to the current user.'
      );
    end if;

    calculate_shift_totals(
      p_shift_system_unique => p_shift_system_unique,
      o_cash_in             => l_cash_in,
      o_cash_out            => l_cash_out,
      o_cash_as_inv         => l_cash_as_inv,
      o_start_inv           => l_start_inv,
      o_end_inv             => l_end_inv
    );

    update cashier_shift
       set shift_status = c_shift_status_closed,
           cash_at_end  = p_cash_at_end,
           cash_in      = l_cash_in,
           cash_out     = l_cash_out,
           cash_as_inv  = l_cash_as_inv,
           start_inv    = l_start_inv,
           end_inv      = l_end_inv,
           close_date   = trunc(sysdate),
           close_time   = to_char(sysdate, 'HH24:MI:SS'),
           closed_at    = systimestamp
     where shift_system_unique = p_shift_system_unique;
  exception
    when no_data_found then
      raise_application_error(
        -20886,
        'Cashier shift end failed: shift reference was not found.'
      );
  end end_shift;


  procedure get_open_shift_summary (
    p_user_no        in  cashier_shift.user_no%type,
    o_shift_context  out nocopy t_shift_context
  )
  is
    l_user_no cashier_shift.user_no%type;
  begin
    l_user_no := effective_user_no(p_user_no);

    o_shift_context.user_no               := l_user_no;
    o_shift_context.shift_system_unique   := null;
    o_shift_context.shift_status          := null;
    o_shift_context.info_center_id        := null;
    o_shift_context.opened_at             := null;
    o_shift_context.closed_at             := null;
    o_shift_context.cash_at_begin         := null;
    o_shift_context.cash_in               := null;
    o_shift_context.cash_out              := null;
    o_shift_context.cash_at_end           := null;
    o_shift_context.cash_as_inv           := null;
    o_shift_context.start_inv             := null;
    o_shift_context.end_inv               := null;
    o_shift_context.shift_control_enabled := null;
    o_shift_context.is_invoice_admin      := null;
    o_shift_context.is_allowed            := null;
    o_shift_context.is_bypass             := null;
    o_shift_context.bypass_reason         := null;
    o_shift_context.message               := null;

    begin
      select cs.user_no,
             cs.shift_system_unique,
             cs.shift_status,
             cs.info_center_id,
             cs.opened_at,
             cs.closed_at,
             cs.cash_at_begin,
             cs.cash_at_end
        into o_shift_context.user_no,
             o_shift_context.shift_system_unique,
             o_shift_context.shift_status,
             o_shift_context.info_center_id,
             o_shift_context.opened_at,
             o_shift_context.closed_at,
             o_shift_context.cash_at_begin,
             o_shift_context.cash_at_end
        from cashier_shift cs
       where cs.user_no = l_user_no
         and cs.shift_status = c_shift_status_open;
    exception
      when no_data_found then
        o_shift_context.message := 'No open cashier shift was found.';
        return;
      when too_many_rows then
        raise_application_error(
          -20887,
          'More than one open cashier shift exists. Contact billing support before ending a shift.'
        );
    end;

    calculate_shift_totals(
      p_shift_system_unique => o_shift_context.shift_system_unique,
      o_cash_in             => o_shift_context.cash_in,
      o_cash_out            => o_shift_context.cash_out,
      o_cash_as_inv         => o_shift_context.cash_as_inv,
      o_start_inv           => o_shift_context.start_inv,
      o_end_inv             => o_shift_context.end_inv
    );

    o_shift_context.message := 'Open cashier shift was found.';
  end get_open_shift_summary;


procedure get_current_shift (
  p_user_no         in  cashier_shift.user_no%type,
  p_info_center_id  in  cashier_shift.info_center_id%type,
  o_shift_context   out nocopy t_shift_context
)
is
  l_user_no             cashier_shift.user_no%type;
  l_info_center_id      cashier_shift.info_center_id%type;
  l_open_count          number;
  l_shift_system_unique cashier_shift.shift_system_unique%type;
begin
  init_context(
    p_user_no       => p_user_no,
    o_shift_context => o_shift_context
  );

  if o_shift_context.shift_control_enabled = c_no then
    o_shift_context.is_allowed    := c_yes;
    o_shift_context.is_bypass     := c_yes;
    o_shift_context.bypass_reason := 'SHIFT_CONTROL_DISABLED';
    o_shift_context.message       :=
      'Shift control is disabled. Invoice creation is allowed.';

    return;
  end if;

  /*
   * Resolve the effective user and information center only when
   * shift control is enabled.
   */
  l_user_no :=
    effective_user_no(p_user_no);

  l_info_center_id :=
    effective_info_center_id(p_info_center_id);

  o_shift_context.user_no :=
    l_user_no;

  o_shift_context.info_center_id :=
    l_info_center_id;

  get_open_shift_raw(
    p_user_no             => l_user_no,
    p_info_center_id      => l_info_center_id,
    o_open_count          => l_open_count,
    o_shift_system_unique => l_shift_system_unique
  );

  if l_open_count = 1 then
    load_shift_context(
      p_shift_system_unique => l_shift_system_unique,
      p_user_no             => l_user_no,
      p_info_center_id      => l_info_center_id,
      io_shift_context      => o_shift_context
    );

    o_shift_context.is_allowed    := c_yes;
    o_shift_context.is_bypass     := c_no;
    o_shift_context.bypass_reason := null;
    o_shift_context.message       :=
      'One open cashier shift was found. Invoice creation is allowed.';

    return;
  end if;

  if l_open_count = 0 then
    if o_shift_context.is_invoice_admin = c_yes then
      o_shift_context.is_allowed    := c_yes;
      o_shift_context.is_bypass     := c_yes;
      o_shift_context.bypass_reason :=
        'INVOICE_ADMIN_NO_OPEN_SHIFT';

      o_shift_context.message :=
        'No open cashier shift was found for this information center, but invoice admin bypass is allowed.';

      return;
    end if;

    o_shift_context.is_allowed := c_no;

    o_shift_context.message :=
      'Cannot create invoice. No open cashier shift was found for this user and information center.';

    raise_application_error(
      -20872,
      o_shift_context.message
    );
  end if;

  o_shift_context.is_allowed := c_no;

  o_shift_context.message :=
    'Cannot create invoice. More than one open cashier shift exists for this user and information center.';

  raise_application_error(
    -20873,
    o_shift_context.message
  );
end get_current_shift;


procedure assert_can_create_invoice (
  p_user_no              in  cashier_shift.user_no%type,
  p_info_center_id       in  cashier_shift.info_center_id%type,
  o_shift_system_unique  out cashier_shift.shift_system_unique%type
)
is
  l_context t_shift_context;
begin
  o_shift_system_unique := null;

  get_current_shift(
    p_user_no        => p_user_no,
    p_info_center_id => p_info_center_id,
    o_shift_context  => l_context
  );

  if l_context.is_allowed <> c_yes then
    raise_application_error(
      -20874,
      nvl(
        l_context.message,
        'Cannot create invoice. Cashier shift validation failed.'
      )
    );
  end if;

  o_shift_system_unique :=
    l_context.shift_system_unique;
end assert_can_create_invoice;

function has_open_shift (
  p_user_no in cashier_shift.user_no%type
) return varchar2
is
  l_user_no    cashier_shift.user_no%type;
  l_open_count number;
begin
  l_user_no :=
    effective_user_no(p_user_no);

  select count(*)
    into l_open_count
    from cashier_shift cs
   where cs.user_no      = l_user_no
     and cs.shift_status = c_shift_status_open;

  if l_open_count = 1 then
    return c_yes;
  elsif l_open_count = 0 then
    return c_no;
  else
    raise_application_error(
      -20875,
      'More than one open cashier shift exists for this user.'
    );
  end if;
end has_open_shift;

end bil_cashier_shift;
/
