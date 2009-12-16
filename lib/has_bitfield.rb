module HasBitfield

  def self.included(base)
    base.extend(ClassMethods)
  end

  FLAG_VALUE_OPTIONS = [:default] unless defined? FLAG_VALUE_OPTIONS
  FLAG_OPTIONS = [:as,:name] unless defined? FLAG_OPTIONS

  module ClassMethods
    def has_bitfield(name, flags_hash)
      @has_bitfield ||= {}
      values = {}
      bits = {}
      defaults = {}
      bit_names = {}
      field = flags_hash.delete(:as) || "#{name}_flags".to_sym
      @has_bitfield[name] = {
        :as => field,
        :values => values,
        :bit_names => bit_names,
        :defaults => defaults
      }

      default_mask = 0

      flags_hash.each do |key, flag|
        flag_name, options = hash_for_flag(flag)
        raise ArgumentError, "has_bitfield: keys should be positive integers less than or equal to 32.
 '#{key}' is invalid as a key for '#{flag_name}'." unless is_valid_bit?(key)

        value = 2**(key - 1)
        values[flag] = value
        bit_names[key] = flag
        default = options.has_key?(:default) ? options[:default] : false;
        defaults[key] = default
        default_mask = default_mask | value if default
        methods_for_flag(flag_name, value, field)
      end

      method_for_name(name, field)
      method_for_initialize(name, default_mask, field)
    end

    protected

    def methods_for_flag(flag, value, field)
      class_eval <<-EVAL
        def #{flag}?
          flag_set?(:#{field}, #{value})
        end

        def #{flag}
          flag_set?(:#{field}, #{value})
        end

        def #{flag}=(value)
          if value.is_a?(String)
            value = Integer(value)
            value = (value!=0)
          end
          value ? set_flag(:#{field}, #{value}) : clear_flag(:#{field}, #{value})
        end

        def self.#{flag}_condition
          condition_for_flag(:#{field}, #{value}, true)
        end

        def self.not_#{flag}_condition
          condition_for_flag(:#{field}, #{value}, false)
        end
        EVAL
    end

    def method_for_initialize(name, mask, field)
      class_eval <<-EVAL
          def initialize_#{name}
            self[:#{field}] = #{mask}
               end
        EVAL
    end

    def method_for_name(name, field)
      class_eval <<-EVAL
          def #{name}
            self[:#{field}]
          end
        EVAL
    end

    def flag_metadata
      @has_bitfield
    end

    def has_flag?(flag)
      @has_bitfield.any? { |name, meta| meta.values.keys.include?(flag) }
    end

    private
      def condition_for_flag(field, value, enabled)
        "(#{table_name}.#{field} & #{value} = #{enabled ? '1': '0'})"
      end

      def is_valid_bit?(key)
        key > 0 && key == key.to_i && key < 33
      end

      def hash_for_flag(value)
        if value.is_a?(Symbol)
          [ value, {} ]
        else
          if value.size != 1
            raise ArgumentError("invalid flag specification for #{value.inspect}")
          end
          [ value.keys[0], value.values[0] ]
        end
      end
  end # module

    private
  def set_flag(field, value)
    self[field] = self[field] | value
  end

  def clear_flag(field, value)
    self[field] = self[field] & ~value
  end

  def flag_set?(field, value)
    self[field] & value != 0
  end

  def flag_clear?(field, value)
    self[field] & value == 0
  end

end
