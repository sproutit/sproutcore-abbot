# ===========================================================================
# Project:   Abbot - SproutCore Build Tools
# Copyright: ©2009 Apple Inc.
#            portions copyright @2006-2009 Sprout Systems, Inc.
#            and contributors
# ===========================================================================

require 'ostruct'

module SC

  # A manifest entry describes a single item that can be built by the build
  # system.  A manifest entry can be assigned any properties you like during
  # the manifest build process.
  #
  # A ManifestEntry must have at least the following properties to build:
  #
  #  bundle::       owner bundle
  #  build_rule::   name of the task to invoke to build this entry
  #  build_path::   absolute path to place built files
  #  staging_path:: absolute path to place staging files
  #  source_path::  absolute path to source file  
  #  source_paths:: arrays of source paths to use for build. alt to single
  #  is_hidden:: if true, entry is not included in build
  #
  class ManifestEntry < HashStruct

    def initialize(manifest, opts={})
      @manifest = manifest # store manifest has ivar
      super(opts)
    end
    
    # invoked whenever the manifest entry is first created.  This will invoke
    # the entry:prepare task if defined.
    def prepare!
      if !@is_prepared
        @is_prepared = true
        buildfile = manifest.target.buildfile
        if buildfile.task_defined? 'entry:prepare'
          buildfile.invoke 'entry:prepare',
            :entry => self,
            :manifest => self.manifest,
            :target => self.manifest.target,
            :config => self.manifest.target.config,
            :project => self.manifest.target.project
        end
      end
      return self
    end
    
    def prepared?; @is_prepared || false; end
    
    def inspect 
      "SC::ManifestEntry(#{filename}, build_task=>#{self.build_task}, entry_type=>#{self.entry_type}, is_hidden=>#{self.hidden?})"
    end
    
    def to_hash(opts={})
      ret = super()
      if ret[:source_entries]
        ret[:source_entries] = ret[:source_entries].map { |e| e.to_hash(opts)}
      end
      
      if only_keys = opts[:only]
        filtered = {}
        ret.each do |key, value|
          filtered[key] = value if only_keys.include?(key)
        end
        ret = filtered
      end
      
      if except_keys = opts[:except]
        filtered = {}
        ret.each do |key, value|
          filtered[key] = value unless except_keys.include?(key)
        end
        ret = filtered
      end

      return ret
    end
    
    ######################################################
    # CONVENIENCE METHODS
    #
    
    # true if the current manifest entry should not be included in the 
    # build.  The entry may still be used as an input for other entries and
    # it may still be referenced directly
    def hidden?; self[:hidden] ||= false; end
    
    # Sets the entry's hidden? property to true
    def hide!; self[:hidden] = true; self; end

    # true if the manifest entry represents a composite resource built from
    # one or more source entries.  Composite resources will have their 
    # source_entries staged before the entry itself is built to staged.
    def composite?; self[:composite]; end
    
    # Marks the entry as composite.  Returns self
    def composite!; self[:composite] = true; self; end
    
    # The owner manifest
    attr_accessor :manifest
    
    def dynamic?; self[:dynamic]; end
    
    # The owner target
    def target; @target ||= manifest.target; end
    
    # dynamic_required targets, only applicable to bundle_info entries
    def targets; self[:targets]; end
    
    # variation for dynamic_required targets, only applicable to bundle_info
    # entries
    def variation; self[:variation]; end
    
    # Returns a timestamp for when this file was last changed.  This will
    # reach back to the source entries, finding the latest original entry.
    def timestamp
      if dynamic? # MUST check for this first...
        timestamps = targets.map do |t|
          timestamps2 = t.manifest_for(variation).build!.entries.map do |e|
            ts = e.timestamp
            ts.nil? ? 0 : ts
          end
          timestamps2.max
        end
        timestamps.max
      elsif composite?

        source_entries.map { |e| e.timestamp || 0 }.max || Time.now.to_i
      else
        File.exist?(source_path) ? File.mtime(source_path).to_i : 0
      end
    end
    
    # Returns a URL with a possible timestamp token appended to the end of 
    # the entry if the target's timestamp_url config is set, or with a randomly
    # assigned domain name prepended if hyper-domaining is turned on.  Otherwise
    # returns the URL itself.
    def cacheable_url
      ret = self.url
      ret = [ret, self.timestamp].join('?') if target.config.timestamp_urls
      if target.config.hyper_domaining
        ret = [self.hyperdomain_prefix(ret), ret].join('') 
      end
      return ret
    end
    
    # If the hyper_domaining config is an array of strings, this will select
    # one of them based on the hash of the URL, and provide an absolute URL
    # to the entry. The hyperdomain includes the protocol. (http://, etc)
    def hyperdomain_prefix(url)
      hyperdomains = target.config.hyper_domaining
      index = url.hash % hyperdomains.length
      
      return "#{hyperdomains[index]}"
    end
    
    
    # Returns a unique ID representing this item when loaded as a script.
    # Useful for module loading.  Includes the build number, target name,
    # language, and filename
    def script_id
      ret = [manifest.language, target.build_number, self.filename].join('/')
      ret = [target.target_name.to_s[1..-1], ret].join(':')
      ret = [ret, self.timestamp].join('?') if target.config.timestamp_urls
      return ret
    end
    
    # Scans the source paths (first staging any source entries) for the 
    # passed regex.  Your block will be executed with each line that matched.
    # Returns the results of each block
    #
    # === Example
    #
    #  entry.extract_content(/require\((.+)\)/) { |line| $1 }
    #
    def scan_source(regexp, &block)
      if entries = self.source_entries
        entries.each { |entry| entry.stage! }
      end

      if paths = self.source_paths
        paths.each do |path|
          next unless File.exist?(path)
          
          # fine all directives in the source.  use file cache to make this 
          # fast later on.
          results = target.file_attr('scan_source', path) do
            ret = []
            File.readlines(path).each do |line|
              if (line.valid_encoding?)
                line.scan(regexp) { |result| ret << result }
              end
            end 
            ret
          end
          
          results.each { |result| yield(result) }
          
        end
      end
    end

    BUILD_DIRECTIVES_REGEX = /(sc_require|require|sc_resource)\(\s*(['"])(.+)['"]\s*\)/
    
    # use when module mode is turned on... 
    # look for lines that are comments or directives only.  must start with
    # //, /* or "
    END_BLOCK_COMMENT_REGEX    = /\s*\*\//
    BEGIN_BLOCK_COMMENT_REGEX  = /\s*\/\*/
    COMMENT_OR_DIRECTIVE = /^\s*((['"])(.+?)(\2)\s*;)?\s*(\/[\/\*].+)?\s*$/ 
        
    def scan_module(&block)
      
      # prep entries
      if entries = self.source_entries
        entries.each { |entry| entry.stage! }
      end

      if paths = self.source_paths
        paths.each do |path|
          next unless File.exist?(path)
          state = :start
          File.readlines(path).each do |line|
            case state
            when :start
              
              # line has a build directive or comment - its OK
              # NOTE: skip line if it has invalid encoding
              results = line.scan(COMMENT_OR_DIRECTIVE) rescue nil 
              if results && results.size > 0
                
                # handle build directive
                if directive = results[0][2]
                  args = directive.split(' ')
                  directive = args.shift
                  yield(directive, args)
                end
                
                # handle start of block comment
                if results[0][4] =~ /^\/\*.*[^\*\/]\s*$/
                  state = :block
                end
                
              else
                state = :code # beyond start of file
              end
            
            # while in block just look for closing block statement
            when :block
              if line =~ /\*\//
                state = (line =~ /\*\/\s*(\/\/.*)?$/) ? :start : :code
              end
            
            when :code
              break # nothing to do
            end
          end
        end
      end
    end
    
    # Scans the source paths for standard build directives and annotates the
    # entry accordingly.  You should only call this method on entries 
    # representing CSS or JavaScript resources.  It will yield undefined
    # results on all other file types.
    #
    def discover_build_directives!(force = false)
      
      target.begin_attr_changes
      
      self.required = []
      entry = self.transform? ? self.source_entry : self
      
      # use new module parser
      if self.use_modules && (force || (self.entry_type == :javascript))
        
        self.imports = []
        self.exports = []
        package_name = self.target.package_name
        loader_name = self.target.config.module_loader
        
        entry.scan_module do |directive, args|
          directive = directive.to_s.downcase.gsub(/^\s+/,'').gsub(/\s+$/,'')
          case directive 
          when 'resource'
            self.resource = (args.first || '').ext 
          
          when 'import'
            # handle import foo as bar
            if args.size == 3 && args[1] == 'as'
              a = args[0]
              if a =~ /^this:/
                a = [package_name, a[5..-1]].join(':')
              elsif !(a =~ /:/)
                if self.target.target_for(a)
                  a = [a, 'package'].join(':')
                elsif loader_name && self.target.target_for([loader_name,a] * '/')
                  a = [[loader_name, a].join('/'), 'package'].join(':')
                else
                  a = [package_name, a].join(':')
                end
              end
              self.imports << [a, args[2]]

            else
              # normalize.  if no explicit target, assume local
              args.each do |a|
                if a =~ /^this:/
                  a = [package_name, a[5..-1]].join(':')
                elsif !(a =~ /:/)
                  if self.target.target_for(a) 
                    a = [a, 'package'].join(':')
                  elsif loader_name && self.target.target_for([loader_name,a] * '/')
                    a = [[loader_name, a].join('/'), 'package'].join(':')
                  else
                    a = [package_name, a].join(':')
                  end
                end
                self.imports << [a, '*']
              end
            end
            
          when 'export'
            
            is_global  = args.first == 'global'
            is_package = is_global || (args.first == 'package')
            args.shift if is_global || is_package
            
            # convert to tuples; import/export names
            if args.size == 3 && args[1] == 'as'
              args = [[args[0], args[2]]]
            else
              args = args.map { |a| [a, a] }
            end
            
            # save in global exports if needed
            if is_global
              self.global_exports = [] if self.global_exports.nil?
              self.global_exports += args
            end
            
            # save in package exports if needed
            if is_package
              self.package_exports = [] if self.package_exports.nil?
              self.package_exports += args
            end

            # save regular exports always
            self.exports += args
            
          when 'use'
            case args[0]
            when 'modules'
              self.use_modules = (args[1] != 'false')
            when 'loader'
              self.use_loader  = self.notify_onload = (args[1] != 'false')
            when 'strict'
              # do nothing
              
            # for any other 'use' directive - just map directly into build
            # config
            else
              _val = args[1]
              case _val
              when 'false'
                _val = false
              when 'true'
                _val = true
              when nil
                _val = true
              end
                
              self[args[0]] = _val
              puts "discovered #{args[0]} = #{_val}"
            end
            
            
          when 'require'
            self.required += args
          end
        end
        
        self.imports = self.imports.compact.uniq
        self.exports = self.exports.compact.uniq
        
      # legacy directives for non-module loading and CSS files
      else
        entry.scan_source(BUILD_DIRECTIVES_REGEX) do |matches|
          # strip off any file ext
          filename = matches[2].ext ''
          case matches[0]
          when 'sc_require'
            self.required << filename
          when 'require'
            self.required << filename
          when 'sc_resource'
            self.resource = filename
          end
        end
        
      end
      
      target.end_attr_changes
      
    end
    
    def exports
      ret = self[:exports]
      if ret.nil? && (self.build_task == 'build:package_exports')
        ret = []
        (self.source_entries || []).each do |e|
          ret += (e.package_exports || [])
        end
        ret = ret.compact.uniq
      end
      return ret
    end
    
    def exports=(exp) 
      self[:exports] = exp
    end
    
    def module_preamble
      return '' if !self.use_modules
      lines = []
      v = self.manifest.variation
      
      # import symbols from other modules
      self.imports.each do |import|
        import, as_symbol = import # split array
        package_name, module_name = import.split(':')
        bundle_target = self.target.target_for(package_name)
        
        puts "IMPORT: import=#{import} as_symbol=#{as_symbol}"
        if bundle_target
          
          bundle_manifest = bundle_target.manifest_for(v).build!
          module_entry = bundle_manifest.entries.select { |e| 
            e.module_name == module_name 
          }.last
          
          # get last item so that transforms are ignored
          if module_entry.nil? && bundle_target.config.combine_javascript
            module_entry = bundle_manifest.entries(:hidden => true).select { |e| e.module_name == module_name }.last
          end
          
          if module_entry
            
            if as_symbol != '*' 
              lines << "var #{as_symbol} = require('#{package_name}:#{module_name}');"
              
            elsif (module_exports = module_entry.exports).size>0
              lines << "var $m__ = require('#{package_name}:#{module_name}'), #{module_exports.map { |s| "#{s[1]}=$m__.#{s[1]}" }.join(',')};"
              
            else
              lines << "require('#{package_name}:#{module_name}');"
            end

          else
            SC.logger.warn("cannot find module to import #{import}")
          end
            
        else
          SC.logger.warn("cannot find target to import #{import}")
        end
        
      end
      
      # setup export variables
      if self.exports.size>0
        lines << "var #{self.exports.map { |x| x[0].split('.').first }*','};"
      end
      
      return lines * ''
      
    end
    
    def module_postamble 
      return '' if !self.use_modules
      lines = [';'] # always add semicolon in case module code is missing one
      self.exports.each do |export|
        lines << "exports.#{export[1]} = #{export[0]};\n"
      end
      return lines * ''
    end
    
    ######################################################
    # BUILDING
    #

    # Invokes the entry's build task to build to its build path.  If the 
    # entry has source entries, they will be staged first.
    def build!
      build_to self.build_path
    end

    # Builds an entry into its staging path.  This method can be invoked on 
    # any entry whose output is required by another entry to be built.
    def stage!
      build_to self.staging_path
    end
    
    # Removes the build and staging files for this entry so the next 
    # build will rebuild.
    #
    # === Returns
    #  self
    def clean!
      FileUtils.rm(self.build_path) if File.exist?(self.build_path)
      FileUtils.rm(self.staging_path) if File.exist?(self.staging_path)
      return self 
    end
        
    # Diagnostic function.  Indicates what will happen if you called build
    def inspect_build_state
      inspect_build_to self.build_path
    end
    
    def inspect_staging_state
      inspect_build_to self.staging_path
    end
    
    
    def inline_contents
      unless File.exists?(self.staging_path)
    
        # stage source entries if needed...
        (self.source_entries || []).each { |e| e.stage! } if composite?
    
        # get build task and build it
        buildfile = manifest.target.buildfile
        if !buildfile.task_defined?(self.build_task)
          raise "Could not build entry #{self.filename} because build task '#{self.build_task}' is not defined"
        end
    
        buildfile.invoke 'build:minify:inline_javascript',
          :entry => self,
          :manifest => self.manifest,
          :target => self.manifest.target,
          :config => self.manifest.target.config,
          :project => self.manifest.target.project,
          :src_path => self.source_path,
          :src_paths => self.source_paths,
          :dst_path => self.staging_path
      end
      File.readlines(self.staging_path)
    end
     
    private 
    
    def inspect_build_to(dst_path)
      return "#{filename}: dst #{dst_path} not found" if !File.exist?(dst_path)
      dst_mtime = File.mtime(dst_path).to_i
      self.source_paths.each do |path|
        if path.nil?
          puts "WARN: nil path in #{filename}"
          next
        end
        
        return "#{filename}: src #{path} not found" if !File.exist?(path)
        
        src_mtime = File.mtime(path).to_i
        return "#{filename}: src #{path} is newer [#{dst_mtime} < #{src_mtime}]" if dst_mtime < src_mtime
      end
      return "#{filename}: will not build"
    end
    
    def build_to(dst_path)
      if self.build_task.nil?
        raise "no build task defined for #{self.filename}" 
      end

      # stage source entries if needed...
      (self.source_entries || []).each { |e| e.stage! } if composite?
      
      # get build task and build it
      buildfile = manifest.target.buildfile
      if !buildfile.task_defined?(self.build_task)
        raise "Could not build entry #{self.filename} because build task '#{self.build_task}' is not defined"
      end
      
      buildfile.invoke self.build_task,
        :entry => self,
        :manifest => self.manifest,
        :target => self.manifest.target,
        :config => self.manifest.target.config,
        :project => self.manifest.target.project,
        :src_path => self.source_path,
        :src_paths => self.source_paths,
        :dst_path => dst_path
        
      return self
    end
    

  end
  
end
