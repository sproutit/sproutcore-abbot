require File.join(File.dirname(__FILE__), %w(.. spec_helper))

describe "manifest:prepare_build_tasks:combine package_exports" do
  
  include SC::SpecHelpers
  include SC::ManifestSpecHelpers
  
  describe "when use_loader = true" do

    before do
      std_before :builder_tests, :module_test
      @target.config.load_debug = false
      @target.config.theme = nil
      @target.config.timestamp_urls = false

      @manifest.build!
    end

    it "VERIFY PRECONDITIONS" do
      @target.config.use_modules.should be_true
      @target.config.use_loader.should be_true
    end

    it "should generate a package_info entry" do
      @manifest.entry_for('package_info.js').should_not be_nil
    end

    it "should include entry in the combined entry" do
      pkg = @manifest.entry_for('package_info.js')

      e = @manifest.entry_for('javascript.js')
      e.should_not be_nil

      e.ordered_entries.first.should == pkg
    end

    it "should be a combined entry that builds with the package builder and depends on all other entries" do
      pkg = @manifest.entry_for('package_info.js')
      e = @manifest.entry_for('javascript.js')
      expected = e.ordered_entries.reject { |x| x == pkg }

      expected = expected.map { |x| x.filename }.sort

      actual = pkg.source_entries.map { |x| x.filename }.sort
      actual.should == expected

      pkg.composite?.should be_true
      pkg.entry_type.should == :javascript
      pkg.build_task.should == 'build:package_info'
    end


  end

  describe "when use_loader = true but we have no JS" do
  
    before do
      std_before :builder_tests, :no_javascript
      @target.config.load_debug = false
      @target.config.theme = nil
      @target.config.timestamp_urls = false
    
      @manifest.build!
    end

    it "VERIFY PRECONDITIONS" do
      @target.config.use_loader.should be_true
    end
    
    it "should generate a package_info entry" do
      @manifest.entry_for('package_info.js').should_not be_nil
    end
  
  end
  
  describe "when use_loader = true but no items use the loader" do
    
    before do
      std_before :builder_tests, :no_loader_items_test
      @target.config.load_debug = false
      @target.config.theme = nil
      @target.config.timestamp_urls = false
      
      @manifest.build!
    end

    it "VERIFY PRECONDITIONS" do
      @target.config.use_loader.should be_true
    end
      
    it "should generate a package_info entry" do
      @manifest.entry_for('package_info.js').should_not be_nil
    end
    
  end

  describe "when use_loader = false" do
    
    before do
      std_before :builder_tests, :no_loader_test
      @target.config.load_debug = false
      @target.config.theme = nil
      @target.config.timestamp_urls = false
      
      @manifest.build!
    end

    it "VERIFY PRECONDITIONS" do
      @target.config.use_loader.should be_false
    end
      
    it "should NOT generate a package_info entry" do
      @manifest.entry_for('package_info.js').should be_nil
    end
    
  end

end
