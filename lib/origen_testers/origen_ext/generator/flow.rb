# This shim is temporary to help NXP transition to Origen from
# our original internal version (RGen)
if defined? RGen::ORIGENTRANSITION
  require 'rgen/generator/flow'
else
  require 'origen/generator/flow'
end
module Origen
  class Generator
    class Flow
      alias_method :orig_create, :create

      # Create a call stack of flows so that we can work out where the nodes
      # of the ATP AST originated from
      def create(options = {}, &block)
        file, line = *caller[0].split(':')
        OrigenTesters::Flow.callstack << file
        flow_comments, comments = *_extract_comments(OrigenTesters::Flow.callstack.last, line.to_i)
        OrigenTesters::Flow.comment_stack << comments
        if OrigenTesters::Flow.flow_comments
          top = false
          name = options[:name] || Pathname.new(file).basename('.rb').to_s.sub(/^_/, '')
          Origen.interface.flow.group(name, description: flow_comments) do
            orig_create(options, &block)
          end
        else
          OrigenTesters::Flow.flow_comments = flow_comments
          if options.key?(:unique_ids)
            OrigenTesters::Flow.unique_ids = options.delete(:unique_ids)
          else
            OrigenTesters::Flow.unique_ids = true
          end
          top = true
          orig_create(options, &block)
        end
        OrigenTesters::Flow.callstack.pop
        OrigenTesters::Flow.comment_stack.pop
        OrigenTesters::Flow.flow_comments = nil if top
      end

      def _extract_comments(file, flow_line)
        flow_comments = []
        comments = {}
        comment = nil
        File.readlines(file).each_with_index do |line, i|
          if comment
            if line =~ /^\s*#-(.*)/
              # Nothing, just ignore but keep the comment open
            elsif line =~ /^\s*#(.*)/
              comment << Regexp.last_match(1).strip
            else
              comment = nil
            end
          else
            if line =~ /^\s*#[^-](.*)/
              if i < flow_line
                comment = flow_comments
              else
                comment = []
                comments[i + 1] = comment
              end
              comment << Regexp.last_match(1).strip
            end
          end
        end
        [flow_comments, comments]
      end
    end
  end
end
