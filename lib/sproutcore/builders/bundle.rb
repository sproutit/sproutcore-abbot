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
  class Builder::PackageInfo < Builder::Base
    
    def build(dst_path)
      begin
        require 'json'
      rescue
        raise "Cannot render bundle_info.js because json is not installed. Try running 'sudo gem install json' and try again."
      end
      
      # emit a bundle definition for the current target
      loader_name = entry.target.config.module_loader
      package_name = entry.manifest.package_name
      desc = entry.manifest.bundle_info
      lines = []
      lines << ";#{loader_name}.register('#{package_name}', #{desc.to_json});\n"
      
      if !entry.target.config.combine_javascript
        lines << "#{loader_name}.script('#{entry.cacheable_url}');\n"
      end
      
      writelines dst_path, lines
    end
    
  end

  # Builds a module_exports.js file defines all exports for a module for 
  # general use
  class Builder::PackageExports < Builder::Base
    
    def build(dst_path)
      
      entries = entry.source_entries.reject { |e| e.exports.nil? }
      
      package_name = entry.target.package_name
      loader_name = entry.target.config.module_loader
      
      has_main = false
      
      lines = []
      lines << "#{loader_name}.module('#{package_name}', 'package', function(require, exports, module) {\n"
      lines << "var m;\n"
      entries.each do |e| 
        next if e.package_exports.nil?
        
        if e.package_exports && e.package_exports.size>0
          lines << "m = require('#{package_name}', '#{e.module_name}');\n"
          e.package_exports.each do |exp|
            lines << "exports.#{exp[1]} = m.#{exp[1]};\n"
            has_main = true if exp[1] == 'main'
          end
        else
          lines << "require('#{package_name}', '#{e.module_name}');\n"
        end
        
      end
      
      lines << "});\n"
      
      # if this is a loadable target (i.e. an app), and a main() is defined,
      # then try to call it automatically when the package becomes ready.
      if entry.target.loadable?
        lines << "\n#{loader_name}.load('#{package_name}').then(function() {\n  #{loader_name}.require('#{package_name}','package').main();\n});\n\n"
      end
      
      
      if !entry.target.config.combine_javascript
        lines << "#{loader_name}.script('#{entry.cacheable_url}');"
      end
      
      writelines dst_path, lines
    end
    
  end
  
end
