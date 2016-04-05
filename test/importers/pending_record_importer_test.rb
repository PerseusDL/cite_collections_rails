require 'test_helper'

class PendingRecordImporterTest < ActiveSupport::TestCase
  include ApplicationHelper

  setup do 
    @test_data = File.join(File.expand_path('../../data', __FILE__),'.')
    @tmp_dir = Dir.mktmpdir
    FileUtils.cp_r @test_data, @tmp_dir
  end


  teardown do
    FileUtils.rm_r @tmp_dir
  end

  test "the files are imported" do 
    cpi = PendingRecordImporter.new
    cpi.import(@tmp_dir)
    assert File.exists?(File.join(@tmp_dir,'catalog_data','mods','latinLit','stoa0040','stoa068','opp-lat1','stoa0040.stoa068.opp-lat1.mods1.xml'))
  end


end
