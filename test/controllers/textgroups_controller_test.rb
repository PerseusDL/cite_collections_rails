require 'test_helper'

class TextgroupsControllerTest < ActionController::TestCase
  setup do
    @textgroup = textgroups(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:textgroups)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create textgroup" do
    assert_difference('Textgroup.count') do
      post :create, textgroup: { created_by: @textgroup.created_by, edited_by: @textgroup.edited_by, groupname_eng: @textgroup.groupname_eng, has_mads: @textgroup.has_mads, mads_possible: @textgroup.mads_possible, notes: @textgroup.notes, textgroup: @textgroup.textgroup, urn: @textgroup.urn, urn_status: @textgroup.urn_status }
    end

    assert_redirected_to textgroup_path(assigns(:textgroup))
  end

  test "should show textgroup" do
    get :show, id: @textgroup
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @textgroup
    assert_response :success
  end

  test "should update textgroup" do
    patch :update, id: @textgroup, textgroup: { created_by: @textgroup.created_by, edited_by: @textgroup.edited_by, groupname_eng: @textgroup.groupname_eng, has_mads: @textgroup.has_mads, mads_possible: @textgroup.mads_possible, notes: @textgroup.notes, textgroup: @textgroup.textgroup, urn: @textgroup.urn, urn_status: @textgroup.urn_status }
    assert_redirected_to textgroup_path(assigns(:textgroup))
  end

  test "should destroy textgroup" do
    assert_difference('Textgroup.count', -1) do
      delete :destroy, id: @textgroup
    end

    assert_redirected_to textgroups_path
  end
end
