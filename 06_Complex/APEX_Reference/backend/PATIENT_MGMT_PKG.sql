create or replace package           "PATIENT_MGMT_PKG" authid definer is


  subtype t_patientno is patient.patientno%type;

  subtype t_object_version_number is patient.object_version_number%type;


  type t_patient_rec is record (

    patientno               patient.patientno%type,

    visit_type              patient.visit_type%type,

    iqama_no                patient.iqama_no%type,

    file_expire_date        patient.file_expire_date%type,

    bdate                   patient.bdate%type,

    is_external_referral    patient.is_external_referral%type,


    p_name_ar               patient.p_name_ar%type,

    father_name_ar          patient.father_name_ar%type,

    grand_f_name_ar         patient.grand_f_name_ar%type,

    family_name_ar          patient.family_name_ar%type,


    p_name_en               patient.p_name_en%type,

    father_name_en          patient.father_name_en%type,

    grand_f_name_en         patient.grand_f_name_en%type,

    family_name_en          patient.family_name_en%type,


    natid                   patient.natid%type,

    passport_no             patient.passport_no%type,

    pass_border_no          patient.pass_border_no%type,

    six                     patient.six%type,

    mar_status              patient.mar_status%type,

    relag_id                patient.relag_id%type,


    phone_h                 patient.phone_h%type,

    phone_w                 patient.phone_w%type,

    postal_code             patient.postal_code%type,

    address                 patient.address%type,

    the_email               patient.the_email%type,

    occupation_type_id      patient.occupation_type_id%type,

    rem                     patient.rem%type,

    info_center_id          patient.info_center_id%type,



    emergency_contact_name  patient.emergency_contact_name%type,

    emergency_relation_id   patient.emergency_relation_id%type,

    emergency_mobile        patient.emergency_mobile%type,


    nok_name            patient.nok_name%type,

    nok_mobile          patient.nok_mobile%type,

    relative_id         patient.relative_id%type,


    coverage_type       patient.coverage_type%type,


    comp_code           patient.comp_code%type,

    sub_comp_code       patient.sub_comp_code%type,

    class_code          patient.class_code%type,

    xgroup              patient.xgroup%type,

    card_id             patient.card_id%type,

    pat_policy_no       patient.pat_policy_no%type,

    card_start          patient.card_start%type,

    card_end            patient.card_end%type,

    ins_number          patient.ins_number%type,

    mainmember          patient.mainmember%type,

    relationcode        patient.relationcode%type,

    aramco_mr_no        patient.aramco_mr_no%type,

    member_id           patient.member_id%type,


    is_new_born         patient.is_new_born%type,

    parent_patient_no   patient.parent_patient_no%type

  );


  type t_save_result is record (

    patientno                patient.patientno%type,

    patientname              patient.patientname%type,

    patientname_ar           patient.patientname_ar%type,

    object_version_number    patient.object_version_number%type,

    last_upd_date            patient.last_upd_date%type,

    upd_by                   patient.upd_by%type

  );


  procedure create_patient(

    p_patient in out nocopy t_patient_rec,

    p_result  out nocopy t_save_result

  );


  procedure update_patient(

    p_patient                         in out nocopy t_patient_rec,

    p_expected_object_version_number  in patient.object_version_number%type,

    p_result                          out nocopy t_save_result

  );


end patient_mgmt_pkg;
/

create or replace package body           "PATIENT_MGMT_PKG" is

  type t_name_pairs_rec is record (
    p_name_ar       patient.p_name_ar%type,
    p_name_en       patient.p_name_en%type,
    father_name_ar  patient.father_name_ar%type,
    father_name_en  patient.father_name_en%type,
    grand_f_name_ar patient.grand_f_name_ar%type,
    grand_f_name_en patient.grand_f_name_en%type,
    family_name_ar  patient.family_name_ar%type,
    family_name_en  patient.family_name_en%type
  );


  ------------------------------------------------------------------------------

  -- Private helpers

  ------------------------------------------------------------------------------


  c_visit_type_resident constant patient.visit_type%type := 1;

  c_visit_type_visitor  constant patient.visit_type%type := 2;

  c_saudi_natid         constant patient.natid%type := 1;


  function trim_to_null (

    p_value in varchar2

  ) return varchar2

  is

    l_value varchar2(32767);

  begin

    l_value := trim(p_value);

    return case when l_value is null then null else l_value end;

  end trim_to_null;


    function generate_patientno

    return patient.patientno%type

  is

    l_patientno patient.patientno%type;

  begin

    l_patientno := to_char(patient_mrn_seq.nextval);


    if length(l_patientno) > 12 then

      raise_application_error(

        -20083,

        'Generated MRN exceeds PATIENT.PATIENTNO length.'

      );

    end if;


    return l_patientno;

  end generate_patientno;



  procedure derive_patientno_for_create (

    io_patient in out nocopy t_patient_rec

  )

  is

    l_mode varchar2(20);

  begin

    l_mode := fnd_app_settings_pkg.get_mrn_generation_mode;


    if l_mode = 'AUTO' then


      if io_patient.patientno is not null then

        raise_application_error(

          -20084,

          'MRN generation is set to AUTO. Do not enter patient number manually.'

        );

      end if;


      io_patient.patientno := generate_patientno;


    elsif l_mode = 'MANUAL' then


      if io_patient.patientno is null then

        raise_application_error(

          -20007,

          'Patient number is required because MRN generation mode is MANUAL.'

        );

      end if;


    else

      raise_application_error(

        -20085,

        'Unsupported MRN generation mode: ' || l_mode

      );

    end if;

  end derive_patientno_for_create;



  procedure normalize_patient (

    io_patient in out nocopy t_patient_rec

  )

  is

  begin

    io_patient.patientno         := trim_to_null(io_patient.patientno);

    io_patient.iqama_no          := trim_to_null(io_patient.iqama_no);


    io_patient.p_name_ar         := trim_to_null(io_patient.p_name_ar);

    io_patient.father_name_ar    := trim_to_null(io_patient.father_name_ar);

    io_patient.grand_f_name_ar   := trim_to_null(io_patient.grand_f_name_ar);

    io_patient.family_name_ar    := trim_to_null(io_patient.family_name_ar);


    io_patient.p_name_en         := trim_to_null(io_patient.p_name_en);

    io_patient.father_name_en    := trim_to_null(io_patient.father_name_en);

    io_patient.grand_f_name_en   := trim_to_null(io_patient.grand_f_name_en);

    io_patient.family_name_en    := trim_to_null(io_patient.family_name_en);


    io_patient.passport_no       := trim_to_null(io_patient.passport_no);

    io_patient.pass_border_no    := trim_to_null(io_patient.pass_border_no);

    io_patient.phone_h           := trim_to_null(io_patient.phone_h);

    io_patient.phone_w           := trim_to_null(io_patient.phone_w);

    io_patient.postal_code       := trim_to_null(io_patient.postal_code);

    io_patient.address           := trim_to_null(io_patient.address);

    io_patient.the_email         := lower(trim_to_null(io_patient.the_email));


    io_patient.emergency_contact_name := trim_to_null(io_patient.emergency_contact_name);

    io_patient.emergency_mobile       := trim_to_null(io_patient.emergency_mobile);


    io_patient.nok_name               := trim_to_null(io_patient.nok_name);

    io_patient.nok_mobile             := trim_to_null(io_patient.nok_mobile);


    io_patient.rem               := trim_to_null(io_patient.rem);

    io_patient.card_id           := trim_to_null(io_patient.card_id);

    io_patient.pat_policy_no     := trim_to_null(io_patient.pat_policy_no);

    io_patient.ins_number        := trim_to_null(io_patient.ins_number);

    io_patient.mainmember        := trim_to_null(io_patient.mainmember);

    io_patient.relationcode      := lower(trim_to_null(io_patient.relationcode));

    io_patient.aramco_mr_no      := trim_to_null(io_patient.aramco_mr_no);

    io_patient.member_id         := trim_to_null(io_patient.member_id);


    io_patient.is_external_referral := nvl(io_patient.is_external_referral, 0);


    if io_patient.is_external_referral <> 1 then

      io_patient.file_expire_date := null;

    end if;


    io_patient.is_new_born       := nvl(trim_to_null(io_patient.is_new_born), '0');

    io_patient.parent_patient_no := trim_to_null(io_patient.parent_patient_no);

  end normalize_patient;


  function iqama_exists (

    p_iqama_no         in patient.iqama_no%type,

    p_current_patientno in patient.patientno%type

  ) return boolean

  is

    l_count number;

  begin

    if p_iqama_no is null then

      return false;

    end if;


    select count(*)

      into l_count

      from patient p

     where p.iqama_no = p_iqama_no

       and (p_current_patientno is null or p.patientno <> p_current_patientno);


    return l_count > 0;

  end iqama_exists;


  function border_number_exists (

    p_pass_border_no    in patient.pass_border_no%type,

    p_current_patientno in patient.patientno%type

  ) return boolean

  is

    l_count number;

  begin

    if p_pass_border_no is null then

      return false;

    end if;


    select count(*)

      into l_count

      from patient p

     where p.pass_border_no = p_pass_border_no

       and (p_current_patientno is null or p.patientno <> p_current_patientno);


    return l_count > 0;

  end border_number_exists;


  procedure raise_duplicate_identity_error (

    p_patient           in t_patient_rec,

    p_current_patientno in patient.patientno%type,

    p_fallback_code     in number,

    p_fallback_message  in varchar2

  )

  is

  begin

    if iqama_exists(p_patient.iqama_no, p_current_patientno) then

      raise_application_error(

        -20025,

        'A patient already exists with this National ID / Iqama.'

      );

    end if;


    if border_number_exists(p_patient.pass_border_no, p_current_patientno) then

      raise_application_error(

        -20026,

        'A patient already exists with this Border Number.'

      );

    end if;


    raise_application_error(p_fallback_code, p_fallback_message);

  end raise_duplicate_identity_error;


  procedure validate_identity (

    p_patient           in t_patient_rec,

    p_current_patientno in patient.patientno%type

  )

  is

  begin

    if p_patient.visit_type is null

       or p_patient.visit_type not in (

      c_visit_type_resident,

      c_visit_type_visitor

    ) then

      raise_application_error(-20018, 'Residency status is required and must be valid.');

    end if;


    if p_patient.is_new_born <> '1'

       and p_patient.visit_type = c_visit_type_resident

       and p_patient.iqama_no is null then

      raise_application_error(

        -20019,

        'National ID / Iqama is required for resident registration.'

      );

    end if;


    if p_patient.is_new_born <> '1'

       and p_patient.visit_type = c_visit_type_resident

       and p_patient.natid is null then

      raise_application_error(-20022, 'Nationality is required for resident registration.');

    end if;


    if p_patient.iqama_no is not null then

      if not regexp_like(p_patient.iqama_no, '^[0-9]{10}$') then

        raise_application_error(

          -20020,

          'National ID / Iqama must contain exactly 10 digits.'

        );

      end if;


      if substr(p_patient.iqama_no, 1, 1) not in ('1', '2') then

        raise_application_error(

          -20021,

          'Saudi National ID must start with 1 and Resident ID / Iqama must start with 2.'

        );

      end if;


      if p_patient.natid is not null

         and substr(p_patient.iqama_no, 1, 1) = '1'

         and p_patient.natid <> c_saudi_natid then

        raise_application_error(

          -20071,

          'Saudi National ID starts with 1. Nationality must be Saudi.'

        );

      end if;


      if p_patient.natid is not null

         and substr(p_patient.iqama_no, 1, 1) = '2'

         and p_patient.natid = c_saudi_natid then

        raise_application_error(

          -20072,

          'Iqama number starts with 2. Saudi nationality is not valid for Iqama holders.'

        );

      end if;

    end if;


    if p_patient.is_new_born <> '1'

       and p_patient.visit_type = c_visit_type_visitor

       and p_patient.pass_border_no is null then

      raise_application_error(

        -20023,

        'Border Number is required for visitor registration.'

      );

    end if;


    if p_patient.pass_border_no is not null

       and not regexp_like(p_patient.pass_border_no, '^[0-9]{10}$') then

      raise_application_error(

        -20024,

        'Border Number must contain exactly 10 digits.'

      );

    end if;


    if iqama_exists(p_patient.iqama_no, p_current_patientno) then

      raise_application_error(

        -20025,

        'A patient already exists with this National ID / Iqama.'

      );

    end if;


    if border_number_exists(p_patient.pass_border_no, p_current_patientno) then

      raise_application_error(

        -20026,

        'A patient already exists with this Border Number.'

      );

    end if;

  end validate_identity;


  procedure validate_demographics (

    p_patient in t_patient_rec

  )

  is

    l_count number;

  begin

    if p_patient.p_name_en is null then

      raise_application_error(-20028, 'Patient first name in English is required.');

    end if;


    if p_patient.family_name_en is null then

      raise_application_error(-20029, 'Patient family name in English is required.');

    end if;


    if p_patient.six is null then

      raise_application_error(-20030, 'Gender is required.');

    elsif p_patient.six not in (1, 2) then

      raise_application_error(-20031, 'Gender is invalid.');

    end if;


    if p_patient.occupation_type_id is null then

      raise_application_error(-20032, 'Occupation is required.');

    end if;


    select count(*)

      into l_count

      from occupation_types

     where occupation_type_id = p_patient.occupation_type_id;


    if l_count = 0 then

      raise_application_error(-20033, 'Occupation is invalid.');

    end if;


    if p_patient.mar_status is null then

      raise_application_error(-20034, 'Marital status is required.');

    elsif p_patient.mar_status not in (1, 2, 3, 4) then

      raise_application_error(-20035, 'Marital status is invalid.');

    end if;


    if p_patient.relag_id is not null then

      select count(*)

        into l_count

        from relag

       where relag_id = p_patient.relag_id

         and is_active = 'Y';


      if l_count = 0 then

        raise_application_error(-20036, 'Religion is invalid or inactive.');

      end if;

    end if;

  end validate_demographics;


  procedure validate_birth_date (

    p_bdate in patient.bdate%type

  )

  is

  begin

    if p_bdate is null then

      raise_application_error(-20001, 'Date of birth is required.');

    elsif trunc(p_bdate) < date '1900-01-01' then

      raise_application_error(-20027, 'Date of birth cannot be earlier than 01-Jan-1900.');

    elsif trunc(p_bdate) > trunc(sysdate) then

      raise_application_error(-20002, 'Date of birth cannot be in the future.');

    end if;

  end validate_birth_date;



  procedure validate_common (

    p_patient           in t_patient_rec,

    p_current_patientno in patient.patientno%type

  )

  is

  begin

    if p_patient.phone_h is null then

      raise_application_error(-20037, 'Personal mobile is required.');

    end if;

    validate_demographics(p_patient);


    validate_birth_date(p_patient.bdate);


    if p_patient.card_start is not null

       and p_patient.card_end is not null

       and p_patient.card_end < p_patient.card_start then

      raise_application_error(-20003, 'Insurance card end date cannot be before start date.');

    end if;


    if p_patient.is_new_born not in ('0', '1') then

      raise_application_error(-20004, 'IS_NEW_BORN must be 0 or 1.');

    end if;


    if p_patient.is_new_born = '1' and p_patient.parent_patient_no is null then

      raise_application_error(-20005, 'Parent patient number is required for newborn.');

    end if;


    if p_patient.is_new_born = '1'

       and p_patient.patientno is not null

       and p_patient.parent_patient_no = p_patient.patientno then

      raise_application_error(-20006, 'Parent patient number cannot be the same as patient number.');

    end if;


    validate_identity(

      p_patient           => p_patient,

      p_current_patientno => p_current_patientno

    );

  end validate_common;



    procedure validate_create (

      p_patient in t_patient_rec

    )

    is

      l_exists number;

    begin

      if p_patient.patientno is null then

        raise_application_error(

          -20007,

          'Patient number was not supplied or generated.'

        );

      end if;


      select count(*)

        into l_exists

        from patient

       where patientno = p_patient.patientno;


      if l_exists > 0 then

        raise_application_error(

          -20012,

          'Patient number already exists.'

        );

      end if;

    end validate_create;



  procedure validate_update (

    p_patient                         in t_patient_rec,

    p_expected_object_version_number  in patient.object_version_number%type

  )

  is

  begin

    if p_patient.patientno is null then

      raise_application_error(-20008, 'Patient number is required for update.');

    end if;


    if p_expected_object_version_number is null then

      raise_application_error(-20009, 'Object version number is required for update.');

    end if;

  end validate_update;



procedure apply_coverage_rules (

  io_patient in out nocopy t_patient_rec

)

is

  l_cnt number;

begin

  io_patient.coverage_type := upper(trim_to_null(io_patient.coverage_type));

  io_patient.coverage_type := nvl(io_patient.coverage_type, 'CASH');


  ---------------------------------------------------------------------------

  -- Cash

  ---------------------------------------------------------------------------

  if io_patient.coverage_type = 'CASH' then


    io_patient.comp_code := ins_comp_util.get_cash_comp_code;


    io_patient.sub_comp_code   := null;

    io_patient.class_code      := null;

    io_patient.xgroup          := null;

    io_patient.pat_policy_no   := null;

    io_patient.card_id         := null;

    io_patient.card_start      := null;

    io_patient.card_end        := null;

    io_patient.ins_number      := null;

    io_patient.mainmember      := null;

    io_patient.relationcode    := null;

    io_patient.aramco_mr_no    := null;

    io_patient.member_id       := null;


    return;

  end if;



  ---------------------------------------------------------------------------

  -- Direct Contract

  ---------------------------------------------------------------------------

  if io_patient.coverage_type = 'DIRECT_CONTRACT' then


    if io_patient.comp_code is null then

      raise_application_error(-20101, 'Direct Company is required.');

    end if;


    select count(*)

      into l_cnt

      from companys c

     where c.comp_code = io_patient.comp_code

       and c.comp_type = 1

       and nvl(c.is_system, 'N') = 'N'

       and c.isactiive = 1;


    if l_cnt = 0 then

      raise_application_error(

        -20102,

        'Selected Direct Company is not valid or inactive.'

      );

    end if;


    io_patient.sub_comp_code   := null;

    io_patient.class_code      := null;

    io_patient.xgroup          := null;

    io_patient.pat_policy_no   := null;

    io_patient.card_id         := null;

    io_patient.card_start      := null;

    io_patient.card_end        := null;

    io_patient.ins_number      := null;

    io_patient.mainmember      := null;

    io_patient.relationcode    := null;

    io_patient.aramco_mr_no    := null;

    io_patient.member_id       := null;


    return;

  end if;



  ---------------------------------------------------------------------------

  -- Insurance

  ---------------------------------------------------------------------------

  if io_patient.coverage_type = 'INSURANCE' then

    if io_patient.relationcode is null then

      raise_application_error(

        -20108,

        'Relationship to Subscriber is required for insurance coverage.'

      );

    elsif io_patient.relationcode not in (
      'self',
      'spouse',
      'child',
      'parent',
      'common',
      'other',
      'injured'
    ) then

      raise_application_error(

        -20109,

        'Relationship to Subscriber is invalid.'

      );

    end if;


    if io_patient.sub_comp_code is null then

      raise_application_error(

        -20103,

        'Policy No / Policy Holder is required.'

      );

    end if;


    if io_patient.class_code is null then

      raise_application_error(

        -20104,

        'Class is required.'

      );

    end if;


    -------------------------------------------------------------------------

    -- Derive provider, policy no, and Related Provider from selected policy

    -------------------------------------------------------------------------

    begin

      select c.parent_comp,

             c.policy_no,

             c.xgroup

        into io_patient.comp_code,

             io_patient.pat_policy_no,

             io_patient.xgroup

        from companys c

        join companys p

          on p.comp_code = c.parent_comp

         and p.comp_type = 2

         and nvl(p.is_system, 'N') = 'N'

       where c.comp_code = io_patient.sub_comp_code

         and c.comp_type = 3

         and nvl(c.is_system, 'N') = 'N'

         and c.isactiive = 1

         and p.isactiive = 1

         and trunc(sysdate) between trunc(c.efect_date)

                               and nvl(trunc(c.contend), date '4712-12-31');


    exception

      when no_data_found then

        raise_application_error(

          -20106,

          'Selected Policy is not active, valid, or does not exist.'

        );


      when too_many_rows then

        raise_application_error(

          -20107,

          'Selected Policy is not unique.'

        );

    end;


    -------------------------------------------------------------------------

    -- Validate class belongs to selected policy

    -------------------------------------------------------------------------

    select count(*)

      into l_cnt

      from disc_classes d

     where d.comp_code = io_patient.sub_comp_code

       and d.class_code = io_patient.class_code

       and nvl(d.isactiive, 1) = 1;


    if l_cnt = 0 then

      raise_application_error(

        -20105,

        'Selected Class is not valid for the selected Policy.'

      );

    end if;


    return;

  end if;



  ---------------------------------------------------------------------------

  -- Invalid coverage type

  ---------------------------------------------------------------------------

  raise_application_error(

    -20100,

    'Invalid Coverage Type.'

  );


end apply_coverage_rules;



  procedure derive_newborn_values (

    io_patient in out nocopy t_patient_rec

  )

  is

  begin

    if io_patient.is_new_born = '1' then

      begin

        select p.visit_type

          into io_patient.visit_type

          from patient p

         where p.patientno = io_patient.parent_patient_no;

      exception

        when no_data_found then

          raise_application_error(

            -20010,

            'Parent patient not found: ' || io_patient.parent_patient_no

          );

        when too_many_rows then

          raise_application_error(

            -20011,

            'Parent patient is not unique: ' || io_patient.parent_patient_no

          );

      end;

    else

      io_patient.parent_patient_no := null;

    end if;

  end derive_newborn_values;



    procedure fetch_result (

      p_patientno in patient.patientno%type,

      p_result    out nocopy t_save_result

    )

    is

    begin

      select p.patientno,

             p.patientname,

             p.patientname_ar,

             p.object_version_number,

             p.last_upd_date,

             p.upd_by

        into p_result.patientno,

             p_result.patientname,

             p_result.patientname_ar,

             p_result.object_version_number,

             p_result.last_upd_date,

             p_result.upd_by

        from patient p

       where p.patientno = p_patientno;


    exception

      when no_data_found then

        raise_application_error(

          -20015,

          'Patient result fetch failed. Patient number was not found: ' || p_patientno

        );


      when too_many_rows then

        raise_application_error(

          -20016,

          'Patient result fetch failed. Patient number is not unique: ' || p_patientno

        );

    end fetch_result;

  procedure load_prior_patient_values (
    p_patientno in patient.patientno%type,
    p_pairs     out nocopy t_name_pairs_rec,
    p_phone_h   out patient.phone_h%type
  )
  is
  begin
    select p_name_ar,
           p_name_en,
           father_name_ar,
           father_name_en,
           grand_f_name_ar,
           grand_f_name_en,
           family_name_ar,
           family_name_en,
           phone_h
      into p_pairs.p_name_ar,
           p_pairs.p_name_en,
           p_pairs.father_name_ar,
           p_pairs.father_name_en,
           p_pairs.grand_f_name_ar,
           p_pairs.grand_f_name_en,
           p_pairs.family_name_ar,
           p_pairs.family_name_en,
           p_phone_h
      from patient
     where patientno = p_patientno;
  exception
    when no_data_found then
      null;
  end load_prior_patient_values;

  procedure lock_mobile_sharing (
    p_phone_h in patient.phone_h%type
  )
  is
    l_lock_bucket patient_mobile_lock_bucket.lock_bucket%type;
  begin
    select ora_hash(p_phone_h, 4095)
      into l_lock_bucket
      from dual;

    select lock_bucket
      into l_lock_bucket
      from patient_mobile_lock_bucket
     where lock_bucket = l_lock_bucket
       for update wait 30;
  exception
    when others then
      if sqlcode in (-54, -30006) then
        raise_application_error(
          -20039,
          'Unable to validate personal mobile sharing because the mobile lock is busy. Try again.'
        );
      end if;
      raise;
  end lock_mobile_sharing;

  procedure validate_mobile_sharing (
    p_phone_h           in patient.phone_h%type,
    p_current_patientno in patient.patientno%type,
    p_prior_phone_h    in patient.phone_h%type
  )
  is
    l_max_patients pls_integer;
    l_count        pls_integer;
  begin
    if p_current_patientno is not null
       and trim_to_null(p_prior_phone_h) = p_phone_h then
      return;
    end if;

    l_max_patients := fnd_app_settings_pkg.get_max_patients_per_mobile;

    if l_max_patients = 0 then
      return;
    end if;

    lock_mobile_sharing(p_phone_h);

    select count(*)
      into l_count
      from patient p
     where trim(p.phone_h) = p_phone_h
       and (
         p_current_patientno is null
         or p.patientno <> p_current_patientno
       );

    if l_count >= l_max_patients then
      raise_application_error(
        -20038,
        'Personal mobile is already linked to the maximum allowed number of patient records ('
        || l_max_patients || ').'
      );
    end if;
  end validate_mobile_sharing;

  procedure record_learning_error (
    p_operation       in varchar2,
    p_error_code      in number,
    p_error_message   in varchar2,
    p_error_backtrace in varchar2
  )
  is
  begin
    insert into app_audit_log (
      user_id,
      session_id,
      module_name,
      action_type,
      error_message,
      ip_address
    ) values (
      substr(nvl(sys_context('APEX$SESSION', 'APP_USER'), user), 1, 50),
      sys_context('USERENV', 'SESSIONID'),
      'PATIENT_MGMT_PKG.NAME_TRANSLITERATION',
      'ERROR',
      substr(
        p_operation || ' learning failed [' || p_error_code || ']: ' ||
        p_error_message || ' ' || p_error_backtrace,
        1,
        4000
      ),
      sys_context('USERENV', 'IP_ADDRESS')
    );
  end record_learning_error;

  procedure learn_patient_name_pairs (
    p_patient   in t_patient_rec,
    p_prior     in t_name_pairs_rec,
    p_is_create in boolean
  )
  is
    l_error_code      number;
    l_error_message   varchar2(4000);
    l_error_backtrace varchar2(4000);

    procedure learn_if_changed (
      p_old_ar in varchar2,
      p_old_en in varchar2,
      p_new_ar in varchar2,
      p_new_en in varchar2
    )
    is
    begin
      if p_is_create
         or not patient_util.is_same_name_transliteration_pair(
           p_old_ar, p_old_en, p_new_ar, p_new_en
         )
      then
        patient_util.learn_name_transliteration(p_new_ar, p_new_en);
      end if;
    end learn_if_changed;
  begin
    savepoint patient_name_learning;
    begin
      learn_if_changed(
        p_prior.p_name_ar, p_prior.p_name_en,
        p_patient.p_name_ar, p_patient.p_name_en
      );
      learn_if_changed(
        p_prior.father_name_ar, p_prior.father_name_en,
        p_patient.father_name_ar, p_patient.father_name_en
      );
      learn_if_changed(
        p_prior.grand_f_name_ar, p_prior.grand_f_name_en,
        p_patient.grand_f_name_ar, p_patient.grand_f_name_en
      );
      learn_if_changed(
        p_prior.family_name_ar, p_prior.family_name_en,
        p_patient.family_name_ar, p_patient.family_name_en
      );
    exception
      when others then
        l_error_code := sqlcode;
        l_error_message := sqlerrm;
        l_error_backtrace := dbms_utility.format_error_backtrace;
        rollback to patient_name_learning;
        begin
          record_learning_error(
            case when p_is_create then 'CREATE' else 'UPDATE' end,
            l_error_code,
            l_error_message,
            l_error_backtrace
          );
        exception
          when others then
            raise_application_error(
              -20846,
              'Transliteration learning and audit logging both failed. ' ||
              'Learning code=' || l_error_code ||
              ', audit code=' || sqlcode
            );
        end;
    end;
  end learn_patient_name_pairs;


  ------------------------------------------------------------------------------

  -- Public API

  ------------------------------------------------------------------------------


  procedure create_patient(

    p_patient in out nocopy t_patient_rec,

    p_result  out nocopy t_save_result

  )

  is

    l_prior t_name_pairs_rec;

  begin

    normalize_patient(p_patient);

    derive_patientno_for_create(p_patient);

    apply_coverage_rules(p_patient);

    derive_newborn_values(p_patient);

    validate_common(

      p_patient           => p_patient,

      p_current_patientno => null

    );

    validate_create(p_patient);

    validate_mobile_sharing(
      p_phone_h           => p_patient.phone_h,
      p_current_patientno => null,
      p_prior_phone_h     => null
    );


    insert into patient (

      patientno,

      visit_type,

      iqama_no,

      file_expire_date,

      bdate,

      is_external_referral,

      p_name_ar,

      father_name_ar,

      grand_f_name_ar,

      family_name_ar,

      p_name_en,

      father_name_en,

      grand_f_name_en,

      family_name_en,

      natid,

      passport_no,

      pass_border_no,

      six,

      mar_status,

      relag_id,

      phone_h,

      phone_w,

      postal_code,

      address,

      the_email,

      emergency_contact_name,

      emergency_relation_id,

      emergency_mobile,

      nok_name,

      nok_mobile,

      relative_id,

      occupation_type_id,

      rem,

      info_center_id,

      coverage_type,

      comp_code,

      sub_comp_code,

      class_code,

      xgroup,

      card_id,

      pat_policy_no,

      card_start,

      card_end,

      ins_number,

      mainmember,

      relationcode,

      aramco_mr_no,

      member_id,

      is_new_born,

      parent_patient_no

    )

    values (

      p_patient.patientno,

      p_patient.visit_type,

      p_patient.iqama_no,

      p_patient.file_expire_date,

      p_patient.bdate,

      p_patient.is_external_referral,

      p_patient.p_name_ar,

      p_patient.father_name_ar,

      p_patient.grand_f_name_ar,

      p_patient.family_name_ar,

      p_patient.p_name_en,

      p_patient.father_name_en,

      p_patient.grand_f_name_en,

      p_patient.family_name_en,

      p_patient.natid,

      p_patient.passport_no,

      p_patient.pass_border_no,

      p_patient.six,

      p_patient.mar_status,

      p_patient.relag_id,

      p_patient.phone_h,

      p_patient.phone_w,

      p_patient.postal_code,

      p_patient.address,

      p_patient.the_email,

      p_patient.emergency_contact_name,

      p_patient.emergency_relation_id,

      p_patient.emergency_mobile,

      p_patient.nok_name,

      p_patient.nok_mobile,

      p_patient.relative_id,

      p_patient.occupation_type_id,

      p_patient.rem,

      p_patient.info_center_id,

      p_patient.coverage_type,

      p_patient.comp_code,

      p_patient.sub_comp_code,

      p_patient.class_code,

      p_patient.xgroup,

      p_patient.card_id,

      p_patient.pat_policy_no,

      p_patient.card_start,

      p_patient.card_end,

      p_patient.ins_number,

      p_patient.mainmember,

      p_patient.relationcode,

      p_patient.aramco_mr_no,

      p_patient.member_id,

      p_patient.is_new_born,

      p_patient.parent_patient_no

    );

    learn_patient_name_pairs(
      p_patient   => p_patient,
      p_prior     => l_prior,
      p_is_create => true
    );

    fetch_result(p_patient.patientno, p_result);


  exception

    when dup_val_on_index then

      raise_duplicate_identity_error(

        p_patient           => p_patient,

        p_current_patientno => null,

        p_fallback_code     => -20012,

        p_fallback_message  => 'Patient number already exists.'

      );

  end create_patient;



  procedure update_patient(

    p_patient                         in out nocopy t_patient_rec,

    p_expected_object_version_number  in patient.object_version_number%type,

    p_result                          out nocopy t_save_result

  )

  is

    l_dummy number;

    l_prior         t_name_pairs_rec;
    l_prior_phone_h patient.phone_h%type;
    l_mobile_changed pls_integer;

  begin

    normalize_patient(p_patient);

    apply_coverage_rules(p_patient);

    derive_newborn_values(p_patient);

    validate_common(

      p_patient           => p_patient,

      p_current_patientno => p_patient.patientno

    );

    validate_update(p_patient, p_expected_object_version_number);

    load_prior_patient_values(
      p_patientno => p_patient.patientno,
      p_pairs     => l_prior,
      p_phone_h   => l_prior_phone_h
    );

    l_mobile_changed :=
      case
        when nvl(fnd_sms_util.normalize_mobile(l_prior_phone_h), '#NULL#') <>
             nvl(fnd_sms_util.normalize_mobile(p_patient.phone_h), '#NULL#')
        then 1
        else 0
      end;

    validate_mobile_sharing(
      p_phone_h           => p_patient.phone_h,
      p_current_patientno => p_patient.patientno,
      p_prior_phone_h     => l_prior_phone_h
    );

    update patient p

       set p.visit_type              = p_patient.visit_type,

           p.iqama_no                = p_patient.iqama_no,

           p.file_expire_date        = p_patient.file_expire_date,

           p.bdate                   = p_patient.bdate,

           p.is_external_referral    = p_patient.is_external_referral,

           p.p_name_ar               = p_patient.p_name_ar,

           p.father_name_ar          = p_patient.father_name_ar,

           p.grand_f_name_ar         = p_patient.grand_f_name_ar,

           p.family_name_ar          = p_patient.family_name_ar,

           p.p_name_en               = p_patient.p_name_en,

           p.father_name_en          = p_patient.father_name_en,

           p.grand_f_name_en         = p_patient.grand_f_name_en,

           p.family_name_en          = p_patient.family_name_en,

           p.natid                   = p_patient.natid,

           p.passport_no             = p_patient.passport_no,

           p.pass_border_no          = p_patient.pass_border_no,

           p.six                     = p_patient.six,

           p.mar_status              = p_patient.mar_status,

           p.relag_id                = p_patient.relag_id,

           p.phone_h                 = p_patient.phone_h,

           p.phone_w                 = p_patient.phone_w,

           p.postal_code             = p_patient.postal_code,

           p.address                 = p_patient.address,

           p.the_email               = p_patient.the_email,

           p.emergency_contact_name = p_patient.emergency_contact_name,

           p.emergency_relation_id  = p_patient.emergency_relation_id,

           p.emergency_mobile       = p_patient.emergency_mobile,

           p.nok_name               = p_patient.nok_name,

           p.nok_mobile             = p_patient.nok_mobile,

           p.relative_id            = p_patient.relative_id,

           p.occupation_type_id      = p_patient.occupation_type_id,

           p.rem                     = p_patient.rem,

           p.info_center_id          = p_patient.info_center_id,

           p.coverage_type           = p_patient.coverage_type,

           p.comp_code               = p_patient.comp_code,

           p.sub_comp_code           = p_patient.sub_comp_code,

           p.class_code              = p_patient.class_code,

           p.xgroup                  = p_patient.xgroup,

           p.card_id                 = p_patient.card_id,

           p.pat_policy_no           = p_patient.pat_policy_no,

           p.card_start              = p_patient.card_start,

           p.card_end                = p_patient.card_end,

           p.ins_number              = p_patient.ins_number,

           p.mainmember              = p_patient.mainmember,

           p.relationcode            = p_patient.relationcode,

           p.aramco_mr_no            = p_patient.aramco_mr_no,

           p.member_id               = p_patient.member_id,

           p.is_new_born             = p_patient.is_new_born,

           p.parent_patient_no       = p_patient.parent_patient_no,

           p.otp_pass                = case
                                         when l_mobile_changed = 1 then 0
                                         else p.otp_pass
                                       end

     where p.patientno = p_patient.patientno

       and p.object_version_number = p_expected_object_version_number;


    if sql%rowcount = 0 then

      begin

        select 1

          into l_dummy

          from patient p

         where p.patientno = p_patient.patientno;


        raise_application_error(

          -20013,

          'This patient was changed by another user. Refresh and try again.'

        );

      exception

        when no_data_found then

          raise_application_error(

            -20014,

            'Patient not found: ' || p_patient.patientno

          );

      end;

    end if;

    learn_patient_name_pairs(
      p_patient   => p_patient,
      p_prior     => l_prior,
      p_is_create => false
    );

    fetch_result(p_patient.patientno, p_result);


      exception

    when dup_val_on_index then

      raise_duplicate_identity_error(

        p_patient           => p_patient,

        p_current_patientno => p_patient.patientno,

        p_fallback_code     => -20017,

        p_fallback_message  => 'Update failed because a unique patient value already exists.'

      );

  end update_patient;


end patient_mgmt_pkg;
/
