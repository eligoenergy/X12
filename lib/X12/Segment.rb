#--
#     This file is part of the X12Parser library that provides tools to
#     manipulate X12 messages using Ruby native syntax.
#
#     http://x12parser.rubyforge.org 
#     
#     Copyright (C) 2008 APP Design, Inc.
#
#     This library is free software; you can redistribute it and/or
#     modify it under the terms of the GNU Lesser General Public
#     License as published by the Free Software Foundation; either
#     version 2.1 of the License, or (at your option) any later version.
#
#     This library is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#     Lesser General Public License for more details.
#
#     You should have received a copy of the GNU Lesser General Public
#     License along with this library; if not, write to the Free Software
#     Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
#++
#
module X12

  # $Id: Segment.rb 82 2009-05-13 18:07:22Z ikk $
  #
  # Implements a segment containing fields or composites
    
  class Segment < Base
    # Flag denoting the segment from which should reset the rendered segment counter (usually that would be ST)
    attr_reader   :initial_segment
    attr_accessor :segment_position

    def initialize(params, nodes)
      @initial_segment  = params[:initial_segment] || false
      @overrides        = params[:overrides] || []
      @syntax_notes     = params[:syntax_notes]
      @segment_position = nil
      super
    end

    # Replaces fields loaded from definition skeleton for which overrides exist
    #   with their clones with overrides applied.
    def apply_overrides
      @overrides.each { |override| 
        nodes.each_with_index { |n, i| nodes[i] = n.apply_overrides(override) if n.name == override.name }
      }
    end

    # Parses this segment out of a string, puts the match into value, returns the rest of the string - nil
    # if cannot parse
    def parse(str)
      s = str
      #puts "Parsing segment #{name} from #{s} with regexp [#{regexp.source}]"
      m = regexp.match(s)
      #puts "Matched #{m ? m[0] : 'nothing'}"
      
      return nil unless m

      s = m.post_match
      self.parsed_str = m[0]
      parse_fields # Fill out the fields without waiting for them to be accessed

      s = do_repeats(s)

      #puts "Parsed segment "+self.inspect
      return s
    end # parse

    def each_segment(include_repeats = false, &block)
      segment = self
      while segment
        block.call(segment)
        segment = include_repeats && segment.next_repeat
      end
    end

=begin
    def segments_parsed(include_repeats = false)
      (parsed_str.nil? ? 0 : 1) + ((include_repeats && next_repeat) ? next_repeat.segments_parsed(true) : 0)
    end

    def enumerate_segments_old(start = 0, include_repeats = false)
      start = 0 if @initial_segment
      start += 1 unless parsed_str.nil?
      @segment_position = start
      ((include_repeats && next_repeat) ? next_repeat.enumerate_segments_old(start, true) : start)
    end

    # Render all components of this segment and all its repears as string suitable for EDI
    def render_old(root = self)
      res = ''

      if (self.repeats.begin > 0) || self.has_displayable_content? then
        # Either a mandatory segment, or has content. Proceed to render.
        if root.respond_to?(:segments_rendered) then
          root.segments_rendered = 0 if initial_segment
          # Current segment needs to be included in the count, so we increase in advance.
          root.segments_rendered += 1 unless root.segments_rendered.nil? 
        end

        nodes_str = ''
        nodes.reverse.each { |fld| # Building string in reverse in order to toss empty optional fields off the end.
          field = fld.render(root)
          nodes_str = root.field_separator + field + nodes_str if fld.required || nodes_str != '' || field != ''
        }
        res << (self.name + nodes_str + root.segment_separator)
      end

      res << next_repeat.render(root) if next_repeat # Recursively render the following segment
      res
    end # render
=end

    # Render all components of this particular segment as string suitable for EDI
    def render(root = self)
      return '' unless required? || self.has_displayable_content?

      nodes_str = ''
      nodes.reverse.each { |fld| # Building string in reverse in order to toss empty optional fields off the end.
        field = fld.render(root)
        nodes_str = root.field_separator + field + nodes_str if fld.required || nodes_str != '' || field != ''
      }

      self.name + nodes_str + root.segment_separator
    end # render

    # Returns a regexp that matches this particular segment
    def regexp
      unless @regexp
        if self.nodes.any? { |i| i.is_constant? } then
          # It's a very special regexp if there are constant fields
          re_str = self.nodes.inject("^#{name}#{Regexp.escape(field_separator)}"){|s, i|
            field_re = i.simple_regexp(field_separator, segment_separator) + Regexp.escape(field_separator) + '?'
            field_re = "(#{field_re})?" unless (i.required || i.is_constant?)
            s + field_re
          } + Regexp.escape(segment_separator)
          @regexp = Regexp.new(re_str)
        else
          # Simple match
          @regexp = Regexp.new("^#{name}#{Regexp.escape(field_separator)}[^#{Regexp.escape(segment_separator)}]*#{Regexp.escape(segment_separator)}")
        end
        #puts sprintf("%s %p", name, @regexp)
      end
      @regexp
    end

    # Returns the hash of fields that have an alias with their corresponding content values
    def to_hsh
      hsh = {}

      # If the segment hasn't been parsed yet, let's parse it
      parse_fields if @fields.nil? && @parsed_str

      nodes.each { |node|
        hsh[node.alias] = node.content unless node.alias.nil?
      }

      hsh
    end

    # Recursively find a sub-element
    def find(name)
      #puts "Finding [#{name}] in #{self.class} #{name}"
      find_field(name).content
    end

    # Finds a field in the segment. Returns EMPTY if not found.
    def find_field(field_name)
      #puts "Finding field [#{field_name}] in #{self.class} #{name}"

      # If the segment hasn't been parsed yet, let's parse it
      parse_fields if @fields.nil? && @parsed_str

      if field_name =~ /^(?:#{self.name})?(\d\d)$/ then
        nodes[$1.to_i - 1]
      else
        nodes.find { |node| node.name == field_name || node.alias == field_name } || EMPTY
      end
    end

    # Validate the segment - whether incoming or outgoing. use_ext_charset controls whether 
    #   the X12's Basic or Advanced Character Set is expected for alphanumeric values.
    def valid?(use_ext_charset = true)
      @error_code = @error = nil

      if has_displayable_content? then
        return false if nodes.find { |node| @error_code, @error = 8, node.error unless node.valid?(use_ext_charset) }

        if !@syntax_notes.empty? then
          @syntax_notes.each { |note|
            deps = note.unpack('a1a2a2a2a2a2a2a2a2').reject(&:empty?) # Never seen more than 5, but just in case...
            mode = deps.shift

            case mode
            when 'C' then # Conditional. If the first element is present, then the others must be present
              f = find_field(deps.shift)
              mode = 'P' if f && f.has_displayable_content?
            when 'L' then # List Conditional. If the first element is present, then at least one of the others must be present
              f = find_field(deps.shift)
              mode = 'R' if f && f.has_displayable_content?
            end

            case mode
            when 'P' then # Paired or multiple. If any are used, all must be used
              c = deps.count{ |i| find_field(i).has_displayable_content? }
              if c != 0 && c != deps.size then
                @error_code, @error = 10, "#{self.name}: exclusion condition violated"
                return false 
              end
            when 'R' then # Required. At least one of those noted must be used
              unless deps.any?{ |i| find_field(i).has_displayable_content? } then
                @error_code, @error = 2, "#{self.name}: conditional required data element missing"
                return false 
              end
            when 'E' then # Exclusion. No more than one may be used
              if deps.count{ |i| find_field(i).has_displayable_content? } > 1 then
                @error_code, @error = 10, "#{self.name}: exclusion condition violated"
                return false 
              end
            end
          }
        end

        # Recursively check if all the repeats of this segment are correct.
        if next_repeat && !next_repeat.valid?(use_ext_charset) then
          @error_code, @error = next_repeat.error_code, next_repeat.error
          return false 
        end
      else
        if required? then
          @error_code, @error = 3, "#{self.name}: mandatory segment missing"
          return false 
        end
      end

      return true
    end

    def parse_fields
      segment_data = @parsed_str.gsub(Regexp.new("#{Regexp.escape(segment_separator)}$"), '')
      @fields = segment_data.split(Regexp.new(Regexp.escape(field_separator)))
      self.nodes.each_with_index{ |node, ind| node.parse(@fields[ind + 1]) }
    end
    private :parse_fields

  end # Segment
end # X12
