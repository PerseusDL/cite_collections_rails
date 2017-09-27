require 'test_helper'

class VersionTest < ActiveSupport::TestCase
  setup do
    v = [ "urn:cts:greekLit:tlg0012.tlg001.perseus-grc1","Iliad","Perseus Iliad","edition","true","published","","","test","test",""]
    @version = Version.new do |vr|
      vr.urn = v[0]
      vr.version = v[1]
      vr.label_eng = v[2]
      vr.desc_eng = v[3] 
      vr.ver_type = v[4] 
      vr.has_mods = v[5]
      vr.urn_status = v[6] 
      vr.redirect_to = v[7]
      vr.member_of = v[8]
      vr.created_by = v[9]
      vr.edited_by = v[10]
      vr.source_urn = v[11]
    end
  end

  teardown do 
    @version.destroy
  end

  test "has_match finds same exact info" do
    found = Version.is_match([ "urn:cts:greekLit:tlg0012.tlg001.perseus-grc1","Iliad","Perseus Iliad","edition","true","published","","","test","test",""])
    assert_equal 1, found.size
  end

  test "has_match finds same exact info except version num" do
    found = Version.is_match([ "urn:cts:greekLit:tlg0012.tlg001.perseus-grc2","Iliad","Perseus Iliad","edition","true","published","","","test","test",""])
    assert_equal 1, found.size
  end

  test "has_match does not find same exact info except work num" do
    found = Version.is_match([ "urn:cts:greekLit:tlg0012.tlg002.perseus-grc2","Iliad","Perseus Iliad","edition","true","published","","","test","test",""])
    assert_equal 0, found.size
  end

  test "has_match does not find same exact info except version and label" do
    found = Version.is_match([ "urn:cts:greekLit:tlg0012.tlg001.perseus-grc2","Iliad Other","Perseus Iliad","edition","true","published","","","test","test",""])
    assert_equal 1, found.size
  end

  test "has_match does not find same exact info except version and lang" do
    found = Version.is_match([ "urn:cts:greekLit:tlg0012.tlg001.perseus-grc2","Iliad","Perseus Iliad","edition","true","published","","","test","test",""])
    assert_equal 1, found.size
  end

end
