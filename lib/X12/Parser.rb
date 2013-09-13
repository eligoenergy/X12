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

require "rexml/document"
include REXML 

require 'pp'

module X12

  # $Id: Parser.rb 89 2009-05-13 19:36:20Z ikk $
  #
  # Main class for creating X12 parsers and factories.

  class Parser

    # These constitute prohibited file names under Microsoft
    MS_DEVICES = [   
                  'CON',
                  'PRN',
                  'AUX',
                  'CLOCK$',
                  'NUL',
                  'COM1',
                  'LPT1',
                  'LPT2',
                  'LPT3',
                  'COM2',
                  'COM3',
                  'COM4',
                 ]

    # Creates a parser out of a definition
    def initialize(file_name)
      @error = nil
      load_definitions(file_name)
      #puts PP.pp(self, '')
    end # initialize

    def load_definitions(file_name)
      file_name = cleanup_file_name(file_name)
      #puts "Reading definition from #{file_name}"

      save_definition = @x12_definition

      # Read and parse the definition
      @x12_definition = X12::XMLDefinitions.new(File.open(file_name, 'r').read)

      # Populate fields in all segments found in all the loops
      @x12_definition[X12::Loop].each_pair{|k, v|
        #puts "Populating definitions for loop #{k}"
        process_loop(v)
      } if @x12_definition[X12::Loop]

      # Merge the newly parsed definition into a saved one, if any.
      if save_definition
        @x12_definition.keys.each{|t|
          save_definition[t] ||= {}
          @x12_definition[t].keys.each{|u|
            save_definition[t][u] = @x12_definition[t][u] 
          }
          @x12_definition = save_definition
        }
      end
    end


    def cleanup_file_name(file_name)
      # Deal with Microsoft devices
      base_name = File.basename(file_name, '.xml')
      if MS_DEVICES.include?(base_name) then
        file_name = File.join(File.dirname, "#{base_name}_.xml")
      end

      # If just the file name is given and it is not actually present, fall back to the library files
      if File.dirname(file_name) == '.' && !File.readable?(file_name) then
        file_name = File.join(File.dirname(__FILE__), '..', '..', 'misc', File.basename(file_name))
      end

      file_name
    end
    private :cleanup_file_name

    # Parse a loop of a given name out of a string. Throws an exception if the loop name is not defined.
    def parse(loop_name, str)
      loop = @x12_definition[X12::Loop][loop_name]
      #puts "Loops to parse #{@x12_definition[X12::Loop].keys}"
      throw Exception.new("Cannot find a definition for loop #{loop_name}") unless loop
      loop = loop.dup
      loop.parse(str)
      return loop
    end # parse

    # Make an empty loop to be filled out with information
    def factory(loop_name)
      loop = @x12_definition[X12::Loop][loop_name]
      throw Exception.new("Cannot find a definition for loop #{loop_name}") unless loop
      loop = loop.dup
      return loop
    end # factory

    # Validates the X12 document. Returns true if the document is valid, false otherwise;
    # use 'error' method to access the error message.
    def validate(doc)
      @error = nil

      doc.nodes.each { |node|
        case node
        when X12::Field then
          if node.validation then
            table = @x12_definition[X12::Table] && @x12_definition[X12::Table][node.validation]
            if table.nil?
              @error = "#{node.parent.name}/#{node.name}: No validation table defined for #{node.validation}"
              return false
            end

            val = node.raw_value
            if val.nil? then
              if node.required then
                @error = "#{node.parent.name}/#{node.name}: Field required but not present"
                return false
              end
            else
              val2 = node.render
              unless table.has_key?(val2)
                @error = "#{node.parent.name}/#{node.name}: Value [#{val}] not in validation table #{node.validation}" 
                return false
              end

              if val2.length > node.max_length then
                @error = "#{node.parent.name}/#{node.name}: Value [#{val2}] too long (max_length=#{node.max_length})"
                return false
              end
            end
          end
        else 
          if node.has_content? then
            return false unless validate(node)
          end
        end
      }

      true
    end

    # Validates the X12 document and raises the Exception if invalid.
    def validate!(doc)
      raise Exception.new(@error) unless validate(doc)
    end

    private

    # Recursively scan the loop and instantiate fields' definitions for all its
    # segments
    def process_loop(loop)
      loop.nodes.each{ |node|
        case node
          when X12::Loop    then process_loop(node)
          when X12::Segment then process_segment(node) 
        end
      }
    end

    # Instantiate segment's fields as previously defined
    def process_segment(segment)
      #puts "Trying to process segment #{segment.inspect}"

      # If segment is already populated, do not overload.
      unless segment.nodes.size > 0
        segment_definition = @x12_definition[X12::Segment] && @x12_definition[X12::Segment][segment.name]

        if segment_definition.nil? then
          # If it's not already loaded, attempt to load it from a library file
          load_definitions(segment.name + '.xml')
          segment_definition = @x12_definition[X12::Segment][segment.name]
        end

        throw Exception.new("Cannot find a definition for segment #{segment.name}") if segment_definition.nil?

        segment_definition.nodes.each_index { |i|
          segment.nodes[i] = segment_definition.nodes[i]
        }

        segment.apply_overrides
      end

      segment.nodes.each { |node|
        # Make sure we have the validation table if any for this field. Try to read one in if missing.
        table = node.validation
        if table then
          unless @x12_definition[X12::Table] && @x12_definition[X12::Table][table]
            load_definitions(table + '.xml')
            throw Exception.new("Cannot find a definition for table #{table}") unless @x12_definition[X12::Table] && @x12_definition[X12::Table][table]
          end
        end
      }
    end

  end # Parser
end
