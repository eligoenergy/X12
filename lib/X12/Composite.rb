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

  # $Id: Composite.rb 35 2008-11-13 18:33:44Z ikk $
  #
  # Class implementing a composite field.

  class Composite < Base

    # Make a printable representation of the composite
    def inspect
      "Composite " + super.inspect
    end

    def render(root = self)
#      return '' unless required || self.has_displayable_content?

      nodes_str = ''
      nodes.reverse.each { |fld| # Building string in reverse in order to toss empty optional fields off the end.
        field = fld.render(root)

        if fld.required || field != '' then
          nodes_str = root.composite_separator + nodes_str if nodes_str != ''
          nodes_str = field + nodes_str
        end

      }

      nodes_str
    end # render

    # Parses this composite out of a string, puts the match into value, returns the rest of the string
    # or +nil+ if unable to parse
    def parse(str)
      s = str
      #puts "Parsing composite #{name} from #{s} with regexp [#{regexp.source}]"
      m = regexp.match(s)
      #puts "Matched #{m ? m[0] : 'nothing'}"
      
      return nil unless m

      s = m.post_match
      @parsed_str = m[0]
      parse_fields # Fill out the fields without waiting for them to be accessed

      #puts "Parsed composite"+self.inspect
      s
    end # parse

    def regexp
      @regexp ||= Regexp.new("[^#{Regexp.escape(composite_separator)}]*(#{Regexp.escape(composite_separator)}[^#{Regexp.escape(composite_separator)}]*)*")
    end

    # Provide access to individual fields in the segment using dot-notation.
    def method_missing(meth, *args, &block)
      str = meth.to_s
      #puts "Missing #{str}"
      if str =~ /=$/ # Assignment
        str.chop!
        #puts str
        field = find_field(str)
        raise Exception.new("No field '#{str}' in composite '#{self.name}'") if field.nil?
        field.content = args[0]
      else # Retrieval
        super
      end # if assignment
    end

    # Finds a field in the segment and returns the respective X12::Field object, or +nil+ if not found.
    # * +field_name+ can be either a field name as defined for the respective segment by X12 standard, a user-defined alias, or a string with the field numeric code (for example, "01" or "SN01", SN being the current segment name)
    def find_field(field_name)
      #puts "Finding field [#{field_name}] in #{self.class} #{name}"
      nodes.find { |node| node.name == field_name || node.alias == field_name }
    end

    # Validate the composite
    # * +use_ext_charset+ - whether to validate alphanumeric values against X12's Basic or Advanced Character Set
    def valid?(use_ext_charset = true)
      @error_code = @error = nil

      if has_displayable_content? then
        return false if nodes.any? { |node|
          @error_code, @error = node.error_code, node.error unless node.valid?(use_ext_charset)
        }
      end

      return true
    end


  end
end
