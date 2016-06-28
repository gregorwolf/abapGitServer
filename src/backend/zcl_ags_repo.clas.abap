class ZCL_AGS_REPO definition
  public
  create public .

public section.

  types:
    ty_repos_tt TYPE STANDARD TABLE OF zags_repos WITH DEFAULT KEY .
  types:
    ty_branches_tt TYPE STANDARD TABLE OF REF TO zcl_ags_branch WITH DEFAULT KEY .

  class-methods CREATE
    importing
      !IV_NAME type ZAGS_REPOS-NAME
      !IV_DESCRIPTION type ZAGS_REPOS-DESCRIPTION
    returning
      value(RO_REPO) type ref to ZCL_AGS_REPO
    raising
      ZCX_AGS_ERROR .
  class-methods LIST
    returning
      value(RT_LIST) type TY_REPOS_TT .
  methods CONSTRUCTOR
    importing
      !IV_NAME type ZAGS_REPOS-NAME
    raising
      ZCX_AGS_ERROR .
  methods DELETE
    raising
      ZCX_AGS_ERROR .
  methods GET_BRANCH
    importing
      !IV_BRANCH_NAME type ZAGS_BRANCH_NAME
    returning
      value(RO_BRANCH) type ref to ZCL_AGS_BRANCH
    raising
      ZCX_AGS_ERROR .
  methods GET_DATA
    returning
      value(RS_DATA) type ZAGS_REPOS .
  methods LIST_BRANCHES
    returning
      value(RT_LIST) type TY_BRANCHES_TT
    raising
      ZCX_AGS_ERROR .
  methods SET_DESCRIPTION
    importing
      !IV_DESCRIPTION type ZAGS_REPOS-DESCRIPTION
    raising
      ZCX_AGS_ERROR .
  PROTECTED SECTION.
private section.

  data MS_DATA type ZAGS_REPOS .

  class-methods INITIAL_COMMIT
    returning
      value(RV_COMMIT) type ZAGS_SHA1
    raising
      ZCX_AGS_ERROR .
ENDCLASS.



CLASS ZCL_AGS_REPO IMPLEMENTATION.


  METHOD constructor.

    SELECT SINGLE * FROM zags_repos
      INTO ms_data
      WHERE name = iv_name.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ags_error
        EXPORTING
          textid = zcx_ags_error=>m002.
    ENDIF.

  ENDMETHOD.


  METHOD create.

    DATA: lt_list TYPE ty_repos_tt,
          ls_repo TYPE zags_repos.


    ASSERT NOT iv_name CA '/\'.
    ASSERT NOT iv_name IS INITIAL.

    lt_list = list( ).
    READ TABLE lt_list WITH KEY name = iv_name TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      RAISE EXCEPTION TYPE zcx_ags_error
        EXPORTING
          textid = zcx_ags_error=>m001.
    ENDIF.

    ls_repo-repo = zcl_ags_util=>uuid( ).
    ls_repo-name = iv_name.
    ls_repo-description = iv_description.
    ls_repo-head = 'master' ##NO_TEXT.

    INSERT zags_repos FROM ls_repo.
    ASSERT sy-subrc = 0.

    ro_repo = NEW zcl_ags_repo( iv_name ).
    zcl_ags_branch=>create(
      io_repo   = ro_repo
      iv_name   = ls_repo-head
      iv_commit = initial_commit( ) ).

  ENDMETHOD.


  METHOD delete.

    DATA(lt_branches) = list_branches( ).
    LOOP AT lt_branches ASSIGNING FIELD-SYMBOL(<lo_branch>).
      <lo_branch>->delete( ).
    ENDLOOP.

    DELETE FROM zags_repos WHERE name = ms_data-name.
    ASSERT sy-subrc = 0.

  ENDMETHOD.


  METHOD get_branch.

    LOOP AT list_branches( ) INTO ro_branch.
      IF ro_branch->get_data( )-name = iv_branch_name.
        RETURN.
      ENDIF.
    ENDLOOP.

    ASSERT 0 = 1.

  ENDMETHOD.


  METHOD get_data.

    rs_data = ms_data.

  ENDMETHOD.


  METHOD initial_commit.

    DATA: lv_user   TYPE string.


    DATA(lo_blob) = NEW zcl_ags_obj_blob( ).
    lo_blob->set_data( zcl_ags_util=>string_to_xstring_utf8( 'test' ) ) ##NO_TEXT.
    lo_blob->save( ).

    DATA(lo_tree) = NEW zcl_ags_obj_tree( ).
    lo_tree->add_file( iv_chmod = zcl_ags_obj_tree=>c_chmod-file
                       iv_name  = 'test.txt'
                       iv_sha1  = lo_blob->sha1( ) ) ##NO_TEXT.
    lo_tree->save( ).

    lv_user = |initial <foo@bar.com> { zcl_ags_util=>get_time( ) }|.

    DATA(lo_commit) = NEW zcl_ags_obj_commit( ).
    lo_commit->set_tree( lo_tree->sha1( ) ).
    lo_commit->set_author( lv_user ) ##NO_TEXT.
    lo_commit->set_committer( lv_user ) ##NO_TEXT.
    lo_commit->set_body( 'initial' ) ##NO_TEXT.
    lo_commit->save( ).

    rv_commit = lo_commit->sha1( ).

  ENDMETHOD.


  METHOD list.

    SELECT * FROM zags_repos
      INTO TABLE rt_list.                               "#EC CI_NOWHERE

  ENDMETHOD.


  METHOD list_branches.

    DATA: lt_list   TYPE TABLE OF zags_branches-name,
          lo_branch TYPE REF TO zcl_ags_branch.


    SELECT name FROM zags_branches
      INTO TABLE lt_list
      WHERE repo = ms_data-repo
      ORDER BY name ASCENDING.

    LOOP AT lt_list ASSIGNING FIELD-SYMBOL(<lv_list>).
      CREATE OBJECT lo_branch
        EXPORTING
          io_repo = me
          iv_name = <lv_list>.

      APPEND lo_branch TO rt_list.
    ENDLOOP.

  ENDMETHOD.


  METHOD set_description.

    UPDATE zags_repos SET
      description = iv_description
      WHERE name = ms_data-name.
    ASSERT sy-subrc = 0.

    ms_data-description = iv_description.

  ENDMETHOD.
ENDCLASS.