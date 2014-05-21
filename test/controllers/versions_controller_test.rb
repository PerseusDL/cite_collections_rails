require 'test_helper'

class VersionsControllerTest < ActionController::TestCase
  setup do
    @version = versions(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:versions)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create version" do
    assert_difference('Version.count') do
      post :create, version: { created_by: @version.created_by, desc_eng: @version.desc_eng, edited_by: @version.edited_by, has_mods: @version.has_mods, label_eng: @version.label_eng, member_of: @version.member_of, redirect_to: @version.redirect_to, type: @version.type, urn: @version.urn, urn_status: @version.urn_status, version: @version.version }
    end

    assert_redirected_to version_path(assigns(:version))
  end

  test "should show version" do
    get :show, id: @version
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @version
    assert_response :success
  end

  test "should update version" do
    patch :update, id: @version, version: { created_by: @version.created_by, desc_eng: @version.desc_eng, edited_by: @version.edited_by, has_mods: @version.has_mods, label_eng: @version.label_eng, member_of: @version.member_of, redirect_to: @version.redirect_to, type: @version.type, urn: @version.urn, urn_status: @version.urn_status, version: @version.version }
    assert_redirected_to version_path(assigns(:version))
  end

  test "should destroy version" do
    assert_difference('Version.count', -1) do
      delete :destroy, id: @version
    end

    assert_redirected_to versions_path
  end
end
