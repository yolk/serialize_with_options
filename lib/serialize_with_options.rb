module SerializeWithOptions

  def serialize_with_options(set = :default, &block)
    configuration = read_inheritable_attribute(:configuration) || {}
    options       = read_inheritable_attribute(:options) || {}

    configuration[set] = Config.new.instance_eval(&block)

    write_inheritable_attribute :configuration, configuration
    write_inheritable_attribute :options, options

    include InstanceMethods
  end

  def serialization_configuration(set)
    configuration = read_inheritable_attribute(:configuration)
    conf = if configuration
      configuration[set] || configuration[:default]
    end

    conf.try(:dup) || { :methods => nil, :only => nil, :except => nil }
  end

  def serialization_options(set)
    return {} if set == :all
    options = read_inheritable_attribute(:options)
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
    write_inheritable_attribute :options, options
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
      super(get_serialization_options(opts_or_set, additional_opts))
    end

    def to_json(opts_or_set = {}, additional_opts=nil)
      super([opts_or_set, additional_opts])
    end
    
    def as_json(opts_or_set = {}, additional_opts=nil)
      if additional_opts.nil? && opts_or_set.is_a?(Array) && opts_or_set.size == 2
        opts_or_set, additional_opts = *opts_or_set
      end
      
      super(get_serialization_options(opts_or_set, additional_opts))
    end

    private

    def get_serialization_options(opts_or_set, additional_opts)
      if opts_or_set.is_a? Symbol
        set  = opts_or_set
        opts = additional_opts || {}
      else
        opts = opts_or_set || {}
        set  = opts[:configuration] || :default
      end
      
      compile_serialization_options(self.class.serialization_options(set)).tap do |compiled_options|
        compiled_options.deep_merge!(opts) if opts && opts.any?
      end
    end
    
    def compile_serialization_options(opts)
      opts = opts.dup
      optional_methods = opts.delete(:optional_methods)
      if optional_methods
        opts[:methods] ||= []
        optional_methods.each do |array|
          opts[:methods] << array[0] if self.send(array[1])
        end
      end
      opts
    end
  end
end
