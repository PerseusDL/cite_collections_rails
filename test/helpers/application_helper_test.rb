require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "clean_dirs" do 
    @files = clean_dirs(File.expand_path('../../data', __FILE__))
    @files.each do |f|
      assert_no_match(@files,"References and Secondary Works")
    end
    assert_equal 1, @files.size
  end

end
