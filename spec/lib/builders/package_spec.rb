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
    @manifest.build!
    
    @entry = @manifest.entry_for('package_info.js')
  end
  
  after do
    @entry = nil
    std_after
  end

  it "should generate a JS file with package exports" do
    @entry.should_not be_nil
    @entry.build!
    path = @entry.build_path
    File.exist?(path).should be_true
    
    code = File.read(path)

    # should register package info
    code.should =~ /#{Regexp.escape("tiki.register('package_test',")}/
    
    # let's get the package info JSON and verifiy it
    require 'json'
    info = code.scan(/#{Regexp.escape("tiki.register('package_test',")}\s?(\{.+\})\s?\);/).flatten.first
    info = JSON.parse(info)
    info.should_not be_nil
    
    # should explicitly name required dependency
    info['depends'].should == ["req_target_1"] # required dependency

    # should include package info for required and dynamic
    info['packages'].keys.sort.should == %w(req_target_1 req_target_2)

    script_entries = @entry.source_entries + [@entry]
    info_scripts = info['scripts']
    
    info_scripts.map { |x| x['url'] }.sort.should == script_entries.map { |x| x.cacheable_url }.sort

    info_scripts.map { |x| x['id'] }.sort.should == script_entries.map { |x| x.script_id }.sort
    
    # should register script ID
    code.should =~ /#{Regexp.escape("tiki.script('#{@entry.script_id}')")}/
  end
  
end
