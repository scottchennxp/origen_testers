module OrigenTesters
  module IGXLBasedTester
    class UltraFLEX
      require 'origen_testers/igxl_based_tester/base/dc_specsets'
      class DCSpecsets < Base::DCSpecsets
        TEMPLATE = "#{Origen.root!}/lib/origen_testers/igxl_based_tester/ultraflex/templates/dc_specsets.txt.erb"
      end
    end
  end
end
