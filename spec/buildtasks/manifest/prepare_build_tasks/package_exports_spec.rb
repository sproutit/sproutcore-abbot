require File.join(File.dirname(__FILE__), %w(.. spec_helper))

describe "manifest:prepare_build_tasks:combine package_exports" do
  
  include SC::SpecHelpers
  include SC::ManifestSpecHelpers
  
  describe "when use_modules = true" do
    
    before do
      std_before :builder_tests, :module_test
      @target.config.load_debug = false
      @target.config.theme = nil
      @target.config.timestamp_urls = false
      
      @manifest.build!
    end

    it "VERIFY PRECONDITIONS" do
      @target.config.use_modules.should be_true
    end
      
    it "should generate a package_exports entry" do
      @manifest.entry_for('package_exports.js').should_not be_nil
    end
    
    it "should include entry in the combined entry" do
      pkg = @manifest.entry_for('package_exports.js')
      
      e = @manifest.entry_for('javascript.js')
      e.should_not be_nil

      e.ordered_entries.last.should == pkg
    end
    
    it "should be a combined entry that builds with the package builder and depends on all other entries" do
      pkg = @manifest.entry_for('package_exports.js')
      e = @manifest.entry_for('javascript.js')
      expected = e.ordered_entries.reject do |x| 
        (x == pkg) || (x.filename == 'package_info.js')
      end
       
      expected = expected.map { |x| x.filename }.sort

      actual = pkg.source_entries.map { |x| x.filename }.sort
      actual.should == expected
      
      pkg.composite?.should be_true
      pkg.build_task.should == 'build:package_exports'
    end
    
    
  end
  
  describe "when use_modules = true but no items use modules" do
    
    before do
      std_before :builder_tests, :no_modules_test
      @target.config.load_debug = false
      @target.config.theme = nil
      @target.config.timestamp_urls = false
      
      @manifest.build!
    end

    it "VERIFY PRECONDITIONS" do
      @target.config.use_modules.should be_true
    end
      
    it "should NOT generate a package_exports entry" do
      @manifest.entry_for('package_exports.js').should be_nil
    end
    
  end

  describe "when use_modules = false" do
    
    before do
      std_before :builder_tests, :javascript_test
      @target.config.load_debug = false
      @target.config.theme = nil
      @target.config.timestamp_urls = false
      
      @manifest.build!
    end

    it "VERIFY PRECONDITIONS" do
      @target.config.use_modules.should be_false
    end
      
    it "should NOT generate a package_exports entry" do
      @manifest.entry_for('package_exports.js').should be_nil
    end
    
  end
  
  describe "when use_modules = true but target has package.js" do
    
    before do
      std_before :builder_tests, :package_test
      @target.config.load_debug = false
      @target.config.theme = nil
      @target.config.timestamp_urls = false
      
      @manifest.build!
    end

    it "VERIFY PRECONDITIONS" do
      @target.config.use_modules.should be_true
      @manifest.entry_for('source/package.js').should_not be_nil
    end
      
    it "should NOT generate a package_exports entry" do
      @manifest.entry_for('package_exports.js').should be_nil
    end
    
  end

end
