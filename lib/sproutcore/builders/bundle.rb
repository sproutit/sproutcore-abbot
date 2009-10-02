# ===========================================================================
# Project:   Abbot - SproutCore Build Tools
# Copyright: ©2009 Apple Inc.
#            portions copyright @2006-2009 Sprout Systems, Inc.
#            and contributors
# ===========================================================================

require File.expand_path(File.join(File.dirname(__FILE__), 'base'))

module SC
  
  # Builds a bundle_info.js file which MUST be run *before* the framework is 
  # loaded by the application or framework doing the loading.
  class Builder::BundleInfo < Builder::Base
    
    def build(dst_path)
      begin
        require 'json'
      rescue
        raise "Cannot render bundle_info.js because json is not installed. Try running 'sudo gem install json' and try again."
      end
      
      # emit a bundle definition for the current target
      bundle_name = entry.manifest.bundle_name
      desc = entry.manifest.bundle_info
      lines = []
      lines << ";sc_loader.bundle('#{bundle_name}', #{desc.to_json});\n"
      lines << "sc_loader.script('#{entry.cacheable_url}');\n"
      
      writelines dst_path, lines
    end
    
  end

  # Builds a module_exports.js file defines all exports for a module for 
  # general use
  class Builder::ModuleExports < Builder::Base
    
    def build(dst_path)
      
      entries = entry.source_entries.reject { |e| e.exports.nil? }
      
      bundle_name = entry.target.bundle_name
      
      lines = []
      lines << "sc_loader.module('#{bundle_name}', 'exports', function(require, exports, module) {\n"
      lines << "var module;\n"
      entries.each do |e| 
        next if e.exports.size == 0
        
        lines << "module = require('#{bundle_name}', '#{e.module_name}');\n"
        e.exports.each do |exp|
          lines << "exports.#{exp} = module.#{exp};\n"
        end
      end
      
      lines << "});\n"
      lines << "sc_loader.script('#{entry.cacheable_url}');"
      writelines dst_path, lines
    end
    
  end
  
end
