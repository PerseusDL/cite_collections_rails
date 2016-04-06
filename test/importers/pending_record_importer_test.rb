require 'test_helper'

class PendingRecordImporterTest < ActiveSupport::TestCase
  include CiteColls

  setup do 
    @test_data = File.join(File.expand_path('../../data', __FILE__),'.')
    @tmp_dir = Dir.mktmpdir
    FileUtils.cp_r @test_data, @tmp_dir

    ## scenario one : mods file for an existing urn no mods file
    @version_one = Version.find_by_cts("urn:cts:greekLit:tlg0037.tlg001.opp-lat1")[0]

    @file_one = File.join(@tmp_dir,'catalog_data','mods','greekLit','tlg0037','tlg001','opp-lat1','tlg0037.tlg001.opp-lat1.mods1.xml')

    ## scenario two: new mods file without existing urn
    @file_two = File.join(@tmp_dir,'catalog_data','mods','latinLit','stoa0040','stoa068','opp-lat1','stoa0040.stoa068.opp-lat1.mods1.xml')

    ## scenario three: updated mods file for existing urn with mods file
    @file_three = File.join(@tmp_dir,'catalog_data','mods','greekLit','fhg0274','fhg001','opp-lat1','fhg0274.fhg001.opp-lat1.mods1.xml')

    # scenario four: version update fails if >1 existing mods file
    @file_four = File.join(@tmp_dir,'catalog_data','mods','greekLit','fhg0274','fhg001','opp-grc1','fhg0274.fhg001.opp-grc1.mods1.xml')

    # scenario five: new modsCollection, existing work
    @file_five = File.join(@tmp_dir,'catalog_data','mods','greekLit','tlg0016','tlg001','opp-grc2','tlg0016.tlg001.opp-grc2.mods1.xml')

    # scenario six: version update with a modsCollection
    @file_six = File.join(@tmp_dir,'catalog_data','mods','greekLit','tlg0016','tlg001','opp-grc1','tlg0016.tlg001.opp-grc1.mods1.xml')

    # scenario seven: version update with constituent records

    # scenario eight: version update with constituents that fail

    # scenario nine: version update that fails with invalid cts

    # scenario ten: new modsCollection with constituent records

    # scenario eleven: new mods without constituent records

    # scenario twelve: new mads

    # scenario thirteen: mads update

  end


  teardown do
    #FileUtils.rm_r @tmp_dir
  end

  test "the files are imported" do 
    cpi = PendingRecordImporter.new

    # verify state before import

    # one precheck
    assert_equal "No label", @version_one.label_eng
    assert_equal "false", @version_one.has_mods
    assert ! File.exists?(@file_one)

    # two precheck
    assert_equal 0, Version.find_by_cts("urn:cts:latinLit:stoa0040.stoa068.opp-lat1").size

    assert ! File.exists?(@file_two)

    # three precheck
    assert File.exists?(@file_three)

   # four precheck
    assert File.exists?(@file_four)
    assert_equal "MyText", Version.find_by_cts("urn:cts:greekLit:fhg0274.fhg001.opp-grc1")[0].label_eng

   # five precheck
    assert_equal 1, Version.find_by_cts("urn:cts:greekLit:tlg0016.tlg001.opp-grc1").size
    assert_equal 0, Version.find_by_cts("urn:cts:greekLit:tlg0016.tlg001.opp-grc2").size

   # six precheck
    assert ! File.exists?(@file_six)
    assert_equal "MyText", Version.find_by_cts("urn:cts:greekLit:tlg0016.tlg001.opp-grc1")[0].label_eng


    # do the import
    cpi.import(@tmp_dir)


    # one postcheck
    assert File.exists?(@file_one)
    @version_one.reload
    assert_equal "Epistulae, Epistolographoi hellenikoi Epistolographi graeci", @version_one.label_eng
    assert_equal "true", @version_one.has_mods

    # two postcheck
    assert File.exists?(@file_two)
    
    #added the work
    work_added = Work.find_by_work("urn:cts:latinLit:stoa0040.stoa068")
    assert_not_nil work_added
    assert_equal "In epistolam Joannis ad Parthos tractatus decem", work_added.title_eng

    #added the version
    version_added = Version.find_by_cts("urn:cts:latinLit:stoa0040.stoa068.opp-lat1")
    assert_equal 1, version_added.size
    assert_equal "In epistolam Joannis ad Parthos tractatus decem, Commentaire de la Première Epître de S. Jean", version_added[0].label_eng
    assert_equal "true", version_added[0].has_mods

    # three postcheck
    assert File.exists?(@file_three)
    f3 = File.open(@file_three)
    f3lines = f3.readlines
    fixed = f3lines.select{|l| l =~/Fixed Title/}
    assert_equal 1, fixed.size


    # four postcheck
    assert File.exists?(@file_four)
    f4 = File.open(@file_four)
    f4lines = f4.readlines
    f4fixed = f4lines.select{|l| l =~/New Title/}
    # shouldn't be the new mods file
    assert_equal 0, f4fixed.size
    # label shouldn't have been updated
    assert_equal "MyText", Version.find_by_cts("urn:cts:greekLit:fhg0274.fhg001.opp-grc1")[0].label_eng


    # five postcheck
    assert File.exists?(@file_five)
    assert_equal 1, Version.find_by_cts("urn:cts:greekLit:tlg0016.tlg001.opp-grc1").size
    assert_equal "Historiae, Herodoti Historiarum libri IX Volume 1;mods1-mods2", Version.find_by_cts("urn:cts:greekLit:tlg0016.tlg001.opp-grc2")[0].label_eng
    # make sure we have the full file including the collection info
    f5 = File.open(@file_five)
    f5lines = f5.readlines
    f5fixed = f5lines.select{|l| l =~/modsCollection/}
    assert_equal 2, f5fixed.size # start and end tag

    # six postcheck
    assert File.exists?(@file_six)
    assert_equal "Historiae, Herodoti Historiarum libri IX Volume 1;mods1-mods2", Version.find_by_cts("urn:cts:greekLit:tlg0016.tlg001.opp-grc2")[0].label_eng
  end


end
