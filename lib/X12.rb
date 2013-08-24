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
$:.unshift(File.dirname(__FILE__))

require 'rubygems'
require 'date'

require 'X12/Base'
require 'X12/Empty'
require 'X12/Field'
require 'X12/Composite'
require 'X12/Segment'
require 'X12/Table'
require 'X12/Loop'
require 'X12/XMLDefinitions'
require 'X12/Parser'

# $Id: X12.rb 91 2009-05-13 22:11:10Z ikk $
#
# Package implementing direct manipulation of X12 structures using Ruby syntax.

module X12
  EMPTY = Empty.new()
end
