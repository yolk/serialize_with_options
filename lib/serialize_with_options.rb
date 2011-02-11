module SerializeWithOptions

  def serialize_with_options(set = :default, &block)
    options = read_inheritable_attribute(:serialization_options) || {:all => {}}
    
    conf = Config.new.instance_eval(&block)
    
    if Hash === set
      set, inherit_from = set.keys.first.to_sym, set.values.first.to_sym
      raise "Please define set #{inherit_from} before #{set}." unless options[inherit_from]
      conf = serialization_options(inherit_from).merge(conf.delete_if{|k, v| v.nil? })
    end
    
    options[set] = {}
    options[set][:default] = conf

    write_inheritable_attribute :serialization_options, options

    include InstanceMethods
  end

  def serialization_options(set, select=nil)
    conf = read_inheritable_attribute(:serialization_options)
    select = Array(select) if select
    select_key = select ? select.sort.join(",") : :default
    options = (conf && (conf[set] || conf[:default])) || {}
    
    (options[select_key] ||= options[:default].try(:dup).tap do |opts|
      if opts
        opts[:methods] = opts[:methods].map(&:to_s) & select if opts[:methods]
        if opts[:only].try(:any?)
          opts[:only] = opts[:only].map(&:to_s) & select
          opts.delete(:except)
        else
          opts[:except] = (opts[:except] || []).map(&:to_s) | columns_hash.keys - (select)
          opts.delete(:only)
        end
      end
    end).try(:dup) || { :methods => nil, :only => nil, :except => nil }
  end

  class Config
    undef_method :methods
    Instructions = [:skip_instruct, :dasherize, :skip_types, :root_in_json].freeze

    def initialize
      @data = { :methods => nil, :only => nil, :except => nil }
    end

    def method_missing(method, *args)
      @data[method] = Instructions.include?(method) ? args.first : args
      @data
    end
  end

  module InstanceMethods
    def to_xml(opts_or_set = {}, additional_opts=nil)
      serialization_options_after_wrapper super(get_serialization_options(opts_or_set, additional_opts))
    end

    def to_json(opts_or_set = {}, additional_opts=nil)
      super([opts_or_set, additional_opts])
    end
    
    def as_json(opts_or_set = {}, additional_opts=nil)
      if additional_opts.nil? && opts_or_set.is_a?(Array) && opts_or_set.size == 2
        opts_or_set, additional_opts = *opts_or_set
      end
      
      serialization_options_after_wrapper super(get_serialization_options(opts_or_set, additional_opts))
    end

    private

    def get_serialization_options(opts_or_set, additional_opts)
      if opts_or_set.is_a? Symbol
        set  = opts_or_set
        opts = additional_opts.try(:dup) || {}
      else
        opts = opts_or_set.try(:dup) || {}
        set  = opts[:set] || :default
      end
      
      compile_serialization_options(self.class.serialization_options(set, opts.delete(:select))).tap do |compiled_options|
        compiled_options.deep_merge!(opts) if opts.any?
        compiled_options.delete(:set)
      end
    end
    
    def compile_serialization_options(opts)
      if optional_methods = opts.delete(:optional_methods)
        opts[:methods] = opts[:methods] ? opts[:methods].dup : []
        optional_methods.each do |array|
          opts[:methods] << array[0] if self.send(array[1])
        end
      end
      if return_nil_on = opts.delete(:return_nil_on)
        @serialization_options_return_nil_on_cache = {}
        return_nil_on.each do |attr|
          @serialization_options_return_nil_on_cache[attr] = read_attribute(attr)
          write_attribute attr, nil
        end
      end
      opts
    end
    
    def serialization_options_after_wrapper(data)
      @serialization_options_return_nil_on_cache.each do |attr, value|
        write_attribute(attr, value)
      end if @serialization_options_return_nil_on_cache
      @serialization_options_return_nil_on_cache = nil
      data
    end
  end
end
