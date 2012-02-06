require 'active_support/core_ext/class/attribute'

module SerializeWithOptions
  
  def self.extended(base)
    base.class_attribute :serialization_conf, :instance_reader => false, :instance_writer => false
    base.class_attribute :serialization_opts, :instance_reader => false, :instance_writer => false
  end

  def serialize_with_options(set = :default, &block)
    configuration = self.serialization_conf || {}
    options       = self.serialization_opts || {}
    
    conf = Config.new.instance_eval(&block)
    
    if Hash === set
      set, inherit_from = set.keys.first.to_sym, set.values.first.to_sym
      raise "Please define set #{inherit_from} before #{set}." unless configuration[inherit_from]
      configuration[set] = serialization_configuration(inherit_from).merge(conf.delete_if{|k, v| v.nil? })
    else
      configuration[set] = conf
    end

    self.serialization_conf = configuration
    self.serialization_opts = options

    include InstanceMethods
  end

  def serialization_configuration(set)
    conf = if self.serialization_conf
      self.serialization_conf[set] || self.serialization_conf[:default]
    end

    conf.try(:dup) || { :methods => nil, :only => nil, :except => nil }
  end

  def serialization_options(set)
    return {} if set == :all
    options = self.serialization_opts
    options[set] ||= serialization_configuration(set).tap do |opts|
      includes = opts.delete(:includes)

      if includes
        opts[:include] = includes.inject({}) do |hash, class_name|
          if class_name.is_a? Hash
            hash.merge(class_name)
          else
            begin
              klass = class_name.to_s.classify.constantize
              hash[class_name] = klass.serialization_configuration(set)
              hash[class_name][:include] = nil if hash[class_name].delete(:includes)
              hash
            rescue NameError
              hash.merge(class_name => { :include => nil })
            end
          end
        end
      end
    end
    self.serialization_opts = options
    options[set]
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
        opts = additional_opts || {}
      else
        opts = opts_or_set || {}
        set  = opts[:set] || :default
      end
      
      compile_serialization_options(self.class.serialization_options(set)).tap do |compiled_options|
        compiled_options.deep_merge!(opts) if opts && opts.any?
        compiled_options.delete(:set)
      end
    end
    
    def compile_serialization_options(opts)
      opts = opts.dup
      optional_methods = opts.delete(:optional_methods)
      return_nil_on = opts.delete(:return_nil_on)
      if optional_methods
        opts[:methods] = opts[:methods] ? opts[:methods].dup : []
        optional_methods.each do |array|
          opts[:methods] << array[0] if self.send(array[1])
        end
      end
      if return_nil_on
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
