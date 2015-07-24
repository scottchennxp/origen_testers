require 'active_support/concern'
module Testers
  # Including this module in a class gives it all the basics required
  # to generator vector-based test patterns
  module VectorBasedTester
    extend ActiveSupport::Concern

    require 'testers/vector_generator'
    require 'testers/timing'
    require 'testers/api'

    include VectorGenerator
    include Timing
    include API

    included do
    end

    module ClassMethods # :nodoc:
      # This overrides the new method of any class which includes this
      # module to force the newly created instance to be registered as
      # a tester with RGen
      def new(*args, &block) # :nodoc:
        if RGen.app.with_doc_tester?
          x = RGen::Tester::Doc.allocate
          if RGen.app.with_html_doc_tester?
            x.html_mode = true
          end
        else
          x = allocate
        end
        x.send(:initialize, *args, &block)
        x.register_tester
        x
      end
    end

    def register_tester # :nodoc:
      RGen.app.tester = self
    end
  end
end