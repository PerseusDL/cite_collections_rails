require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "clean_dirs mods" do 
    @files = clean_dirs(File.expand_path('../../data/catalog_pending/mods', __FILE__),'mods')
    @files.each do |f|
      assert_no_match(@files,"References and Secondary Works")
    end
    assert_equal 11, @files.size
  end

  test "clean_dirs mads" do 
    @files = clean_dirs(File.expand_path('../../data/catalog_pending/mads', __FILE__),'mads')
    @files.each do |f|
      assert_no_match(@files,"References and Secondary Works")
    end
    assert_equal 3, @files.size
  end

end
