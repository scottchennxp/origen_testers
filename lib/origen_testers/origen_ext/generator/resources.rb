# This shim is temporary to help NXP transition to Origen from
# our original internal version (RGen)
if defined? RGen::ORIGENTRANSITION
  require 'rgen/generator/resources'
else
  require 'origen/generator/resources'
end
module Origen
  class Generator
    class Resources
      alias_method :orig_create, :create

      # Patching to make resources_mode apply much earlier
      def create(options = {}, &block)
        OrigenTesters::Interface.with_resources_mode do
          orig_create(options, &block)
        end
      end
    end
  end
end
