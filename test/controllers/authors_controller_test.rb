require 'test_helper'

class AuthorsControllerTest < ActionController::TestCase
  setup do
    @author = authors(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:authors)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create author" do
    assert_difference('Author.count') do
      post :create, author: { alt_ids: @author.alt_ids, authority_name: @author.authority_name, canonical_id: @author.canonical_id, created_by: @author.created_by, edited_by: @author.edited_by, mads_file: @author.mads_file, redirect_to: @author.redirect_to, related_works: @author.related_works, urn: @author.urn, urn_status: @author.urn_status }
    end

    assert_redirected_to author_path(assigns(:author))
  end

  test "should show author" do
    get :show, id: @author
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @author
    assert_response :success
  end

  test "should update author" do
    patch :update, id: @author, author: { alt_ids: @author.alt_ids, authority_name: @author.authority_name, canonical_id: @author.canonical_id, created_by: @author.created_by, edited_by: @author.edited_by, mads_file: @author.mads_file, redirect_to: @author.redirect_to, related_works: @author.related_works, urn: @author.urn, urn_status: @author.urn_status }
    assert_redirected_to author_path(assigns(:author))
  end

  test "should destroy author" do
    assert_difference('Author.count', -1) do
      delete :destroy, id: @author
    end

    assert_redirected_to authors_path
  end
end
