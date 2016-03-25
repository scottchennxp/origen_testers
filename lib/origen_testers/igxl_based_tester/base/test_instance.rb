module OrigenTesters
  module IGXLBasedTester
    class Base
      class TestInstance
        attr_accessor :type, :index, :version, :append_version, :finalize, :meta

        def self.define
          # Generate accessors for all attributes and their aliases
          attrs.each do |attr|
            writer = "#{attr}=".to_sym
            reader = attr.to_sym
            attr_reader attr.to_sym unless method_defined? reader
            attr_writer attr.to_sym unless method_defined? writer
          end

          # Define the common aliases now, the instance type specific ones will
          # be created when the instance type is known
          self::TEST_INSTANCE_ALIASES.each do |_alias, val|
            writer = "#{_alias}=".to_sym
            reader = _alias.to_sym
            unless val.is_a? Hash
              unless method_defined? writer
                define_method("#{_alias}=") do |v|
                  send("#{val}=", v)
                end
              end
              unless method_defined? reader
                define_method("#{_alias}") do
                  send(val)
                end
              end
            end
          end
        end

        def self.attrs
          @attrs ||= begin
            attrs = self::TEST_INSTANCE_ATTRS.dup

            self::TEST_INSTANCE_EXTRA_ARGS.times do |i|
              attrs << "arg#{i}"
            end
            attrs << 'comment'
            attrs
          end
        end

        def initialize(name, type, attrs = {})
          @meta = {}
          @type = type
          @append_version = true
          self.name = name
          # Build the type specific accessors (aliases)
          self.class::TEST_INSTANCE_ALIASES[@type.to_sym].each do |_alias, val|
            define_singleton_method("#{_alias}=") do |v|
              send("#{val}=", v) if self.respond_to?("#{val}=", v)
            end
            define_singleton_method("#{_alias}") do
              send(val) if self.respond_to?(val)
            end
          end
          # Set the defaults
          self.class::TEST_INSTANCE_DEFAULTS[@type.to_sym].each do |k, v|
            send("#{k}=", v) if self.respond_to?("#{k}=", v)
          end
          # Then the values that have been supplied
          attrs.each do |k, v|
            send("#{k}=", v) if self.respond_to?("#{k}=", v)
          end
        end

        # Returns a hash containing key meta data about the test instance, this is
        # intended to be used in documentation
        def to_meta
          m = { 'Test' => name,
                'Type' => type
          }
          if type == :functional
            m['Pattern'] = pattern
          elsif type == :board_pmu || type == :pin_pmu
            m['Measure'] = fvmi? ? 'current' : 'voltage'
            if hi_lo_limit_valid & 2 != 0
              m['Hi'] = hi_limit
            end
            if hi_lo_limit_valid & 1 != 0
              m['Lo'] = lo_limit
            end
            if force_cond
              m['Force'] = force_cond
            end
          end
          m['DC'] = "#{dc_category} (#{dc_selector})"
          m['AC'] = "#{ac_category} (#{ac_selector})"
          m.merge(@meta)
        end

        def inspect
          "<TestInstance: #{name}, Type: #{type}>"
        end

        def ==(other_instance)
          self.class == other_instance.class &&
            unversioned_name.to_s == other_instance.unversioned_name.to_s &&
            self.class.attrs.all? do |attr|
              # Exclude test name, already examined above and don't want to include
              # the version in the comparison
              if attr == 'test_name'
                true
              else
                send(attr) == other_instance.send(attr)
              end
            end
        end

        def self.new_empty(name, attrs = {})
          new(name, :empty, attrs)
        end

        def self.new_functional(name, attrs = {})
          new(name, :functional, attrs)
        end

        def self.new_board_pmu(name, attrs = {})
          new(name, :board_pmu, attrs)
        end

        def self.new_pin_pmu(name, attrs = {})
          new(name, :pin_pmu, attrs)
        end

        def self.new_apmu_powersupply(name, attrs = {})
          new(name, :apmu_powersupply, attrs)
        end

        def self.new_mto_memory(name, attrs = {})
          new(name, :mto_memory, attrs)
        end

        # Returns the fully formatted test instance for insertion into an instance sheet
        def to_s(override_name = nil)
          l = "\t"
          self.class.attrs.each do |attr|
            if attr == 'test_name' && override_name
              l += "#{override_name}\t"
            else
              l += "#{send(attr)}\t"
            end
          end
          "#{l}"
        end

        def name
          if version && @append_version
            "#{@test_name}_v#{version}"
          else
            @test_name.to_s
          end
        end
        alias_method :test_name, :name

        def name=(val)
          self.test_name = val
        end

        def unversioned_name
          @test_name.to_s
        end

        # Set the cpu wait flags for the given test instance
        #   instance.set_wait_flags(:a)
        #   instance.set_wait_flags(:a, :c)
        def set_wait_flags(*flags)
          # This method is tester-specific and must be overridden by the child class
          fail 'The #{self.class} class has not defined a set_wait_flags method!'
        end

        # Set and enable the pre-charge voltage of a parametric test instance.
        def set_pre_charge(val)
          if val
            self.pre_charge_enable = 1
            self.pre_charge = val
          else
            self.pre_charge_enable = 0
          end
          self
        end
        alias_method :set_precharge, :set_pre_charge

        # Set and enable the hi limit of a parametric test instance, passing in
        # nil or false as the lim parameter will disable the hi limit.
        def set_hi_limit(lim)
          if lim
            self.hi_lo_limit_valid = hi_lo_limit_valid | 2
            self.hi_limit = lim
          else
            self.hi_lo_limit_valid = hi_lo_limit_valid & 1
          end
          self
        end
        alias_method :hi_limit=, :set_hi_limit

        # Set and enable the hi limit of a parametric test instance, passing in
        # nil or false as the lim parameter will disable the hi limit.
        def set_lo_limit(lim)
          if lim
            self.hi_lo_limit_valid = hi_lo_limit_valid | 1
            self.lo_limit = lim
          else
            self.hi_lo_limit_valid = hi_lo_limit_valid & 2
          end
          self
        end
        alias_method :lo_limit=, :set_lo_limit

        # Set the current range of the test instance, the following are valid:
        #
        # Board PMU
        # * 2uA
        # * 20uA
        # * 200uA
        # * 2mA
        # * 20mA
        # * 200mA
        # * :smart
        #
        # Pin PMU
        # * 200nA
        # * 2uA
        # * 20uA
        # * 200uA
        # * 2mA
        # * :auto
        # * :smart
        #
        # Examples
        #   instance.set_irange(:smart)
        #   instance.set_irange(:ua => 2)
        #   instance.set_irange(2.uA) # Same as above
        #   instance.set_irange(:ma => 200)
        #   instance.set_irange(0.2) # Same as above
        #   instance.set_irange(:a => 0.2) # Same as above
        def set_irange(r = nil, options = {})
          r, options = nil, r if r.is_a?(Hash)
          unless r
            if r = options.delete(:na) || options.delete(:nA)
              r = r / 1_000_000_000
            elsif r = options.delete(:ua) || options.delete(:uA)
              r = r / 1_000_000.0
            elsif r = options.delete(:ma) || options.delete(:mA)
              r = r / 1000.0
            elsif r = options.delete(:a) || options.delete(:A)
            else
              fail "Can't determine requested irange!"
            end
          end

          if @type == :board_pmu
            if r == :smart
              self.irange = 6
            else
              self.irange = case
                when r > 0.02 then 5
                when r > 0.002 then 4
                when r > 0.0002 then 3
                when r > 0.00002 then 2
                when r > 0.000002 then 1
                else 0
                end
            end

          else # :pin_pmu
            if r == :smart
              self.irange = 5
            elsif r == :auto
              fail 'Auto range not available in FIMV mode!' if self.fimv?
              self.irange = 6
            else
              if fimv?
                self.irange = case
                  when r > 0.0002 then 2
                  else 4
                  end
              else
                self.irange = case
                  when r > 0.0002 then 2
                  when r > 0.00002 then 4
                  when r > 0.000002 then 0
                  when r > 0.0000002 then 1
                  else 3
                  end
              end
            end
          end

          self
        end

        # Set the voltage range of the test instance, the following are valid:
        #
        # Board PMU
        # * 2V
        # * 5V
        # * 10V
        # * 24V
        # * :auto
        # * :smart
        #
        # Examples
        #   instance.set_vrange(:auto)
        #   instance.set_vrange(:v => 5)
        #   instance.set_vrange(5) # Same as above
        def set_vrange(r = nil, options = {})
          r, options = nil, r if r.is_a?(Hash)
          if r == :smart
            self.vrange = 4
          elsif r == :auto
            self.vrange = 5
          elsif !r
            if r = options.delete(:v) || options.delete(:V)
            else
              fail "Can't determine requested vrange!"
            end
          end
          self.vrange = case
            when r > 10 then 3
            when r > 5 then 2
            when r > 2 then 1
            else 0
            end
          self
        end

        # Set the meaure mode of a parametric test instance, either:
        # * :voltage / :fimv
        # * :current / :fvmi
        def set_measure_mode(mode)
          if mode == :current || mode == :fvmi
            self.measure_mode = 0
          elsif mode == :voltage || mode == :fimv
            self.measure_mode = 1
          else
            fail "Unknown measure mode: #{mode}"
          end
        end

        # Returns true if instance configured for force current, measure voltage
        def fimv?
          measure_mode == 1
        end

        # Returns true if instance configured for force voltage, measure current
        def fvmi?
          measure_mode == 0
        end
      end
    end
  end
end
