require File.join(File.dirname(__FILE__), 'spec_helper')
describe SC::Builder::PackageExports do
  
  include SC::SpecHelpers
  include SC::BuilderSpecHelper
  
  before do
    std_before :module_test
    @target.config.load_debug = false
    @target.config.theme = nil
    @target.config.timestamp_urls = false
    @manifest.build!
    
    @entry = @manifest.entry_for('package_exports.js')
  end
  
  after do
    @entry = nil
    std_after
  end

  it "should generate a JS file with package exports" do
    @entry.build!
    path = @entry.build_path
    File.exist?(path).should be_true
    
    code = File.read(path)
    
    # verify key points...
    code.should =~ /#{Regexp.escape("tiki.module('module_test:index'")}/
    
    # should only define exports for foo & bar
    # other exports are defined in the fixture but not at package level
    exports = code.scan(/exports\.([^=]+)=/).flatten.map { |x| x.strip }.sort
    exports.should == %w(bar foo)
    
    #should only import core
    #other files are included but not with package exports
    imports = code.scan(/require\(\s?'([^']+)'\s?\)/).flatten.sort
    imports.should == %w(module_test:core)
    
    # should register script ID
    code.should =~ /#{Regexp.escape("tiki.script('#{@entry.script_id}')")}/
  end
  
end

describe SC::Builder::PackageInfo do
  
  include SC::SpecHelpers
  include SC::BuilderSpecHelper
  
  before do
    std_before :package_test
    @target.config.load_debug = false
    @target.config.theme = nil
    @target.config.timestamp_urls = false
  end
  
  after do
    @entry = nil
    std_after
  end

  def prep
    @manifest.build!

    if @target.config.combine_javascript
      @entry = @manifest.entry_for('package_info.js', :hidden => true) 
    else
      @entry = @manifest.entry_for('package_info.js')
    end
    
    @entry.should_not be_nil

    # get JS entries.  omit the combined entry if we are not combining
    script_entries = @manifest.entries.select do |x|
      (x.entry_type == :javascript) &&
      (@target.config.combine_javascript || x.filename != 'javascript.js')
    end
    
    # get JS entries.  omit the combined entry if we are not combining
    style_entries  = @manifest.entries.select do |x| 
      (x.entry_type == :css) &&
      (@target.config.combine_stylesheets || x.filename != 'stylesheet.css')
    end
    
    return [script_entries, style_entries]
  end
  
  def verify_entry(script_entries, style_entries)

    @entry.build!
    path = @entry.build_path
    File.exist?(path).should be_true
    
    code = File.read(path)

    # should register package info
    code.should =~ /#{Regexp.escape("tiki.register('package_test',")}/
    
    # let's get the package info JSON and verifiy it
    require 'json'
    
    # make a single line for regex
    info = code.gsub("\n", '').scan(/#{Regexp.escape("tiki.register('package_test',")}\s?(\{.+\})\s?\);/).flatten.first
    info = JSON.parse(info)
    info.should_not be_nil
    
    # should explicitly name required dependency
    info['depends'].should == ["req_target_1"] # required dependency

    # should include package info for required and dynamic
    info['packages'].keys.sort.should == %w(req_target_1 req_target_2)

    # verify scripts
    info_scripts = info['scripts']
    info_scripts.map { |x| x['url'] }.sort.should == script_entries.map { |x| x.cacheable_url }.sort

    info_scripts.map { |x| x['id'] }.sort.should == script_entries.map { |x| x.script_id }.sort

    # verify stlyes
    info_styles = info['stylesheets']
    info_urls   = info_styles.map { |x| x['url'] }.sort
    info_urls.should == style_entries.map { |x| x.cacheable_url }.sort

    info_ids    = info_styles.map { |x| x['id'] }.sort
    info_ids.should == style_entries.map { |x| x.script_id }.sort
    
    # should register script ID
    if @target.config.combine_javascript == false
      code.should =~ /#{Regexp.escape("tiki.script('#{@entry.script_id}')")}/
    end
  end
  
  it "should generate a JS file with package info" do
    @target.config.combine_javascript = false
    @target.config.combine_stylesheets = false

    script_entries, style_entries = prep
    script_entries.size.should > 1
    style_entries.size.should > 1

    verify_entry(script_entries, style_entries)
  end

  it "should generate a combined JS file with package info" do
    @target.config.combine_javascript = true
    @target.config.combine_stylesheets = true
    
    script_entries, style_entries = prep
    script_entries.size.should == 1
    style_entries.size.should == 1

    verify_entry(script_entries, style_entries)
  end
  
end
