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
require 'X12'
require 'test/unit'

class Test270Parse < Test::Unit::TestCase
  TEST_REPEAT = 100

  @@p = nil
  @@parser = X12::Parser.new('misc/270.xml')

  def setup
    unless @@p
      @@m=<<-EOT
ST*270*1001~
BHT*0022*13*LNKJNFGRWDLR*20070724*1726~
HL*1**20*1~
NM1*PR*2*BIG PAYOR*****PI*CHICAGO BLUES~
HL*2*1*21*1~
NM1*1P*1******SV*daw~
HL*3*2*22*0~
NM1*IL*1*Doe*Joe~
DMG*D8*19700725~
DTP*307*D8*20070724~
EQ*60~
SE*12*1001~
EOT
      @@m.gsub!(/\n/,'')

      @@p = @@parser.parse('270', @@m)
      # @@p.show
    end
    @r = @@p

  end # setup

  def teardown
    # Nothing
  end # teardown

  def test_ST
    assert_equal('ST*270*1001~', @r.ST.to_s)
    assert_equal('270', @r.ST.TransactionSetIdentifierCode)
  end # test_ST

  def test_L2000A_NM1
    assert_equal('BIG PAYOR', @r.L2000A.L2100A.NM1.NameLastOrOrganizationName)
  end

  def test_L2000C_NM1
    assert_equal('Joe', @r.L2000C.L2100C.NM1.NameFirst)
  end

  def test_L2000A_HL
    assert_equal('', @r.L2000A.HL.HierarchicalParentIdNumber)
  end

  def test_absent
    assert_nil(@r.L2000D.HHH)
    assert_nil(@r.L2000B.L2111)
    assert_nil(@r.L2000C.L2100C.N3.AddressInformation1)
  end # test_absent

  def test_validity
    assert_equal(true, @r.valid?)
  end

  def test_segment_counter
    assert_equal(12, @r.segments_parsed)
    assert_equal(4, @r.L2000C.L2100C.segments_parsed)
    assert_equal(1, @r.L2000C.L2100C.L2110C.segments_parsed)
    assert_equal(0, @r.L2000D.segments_parsed)
  end

  def test_segment_enumerator
    @r.enumerate_segments
    assert_equal(1, @r.ST.segment_position)
    assert_equal(2, @r.BHT.segment_position)
    assert_equal(3, @r.L2000A.HL.segment_position)
    assert_equal(4, @r.L2000A.L2100A.NM1.segment_position)
    assert_equal(5, @r.L2000B.HL.segment_position)
    assert_equal(6, @r.L2000B.L2100B.NM1.segment_position)
    assert_equal(7, @r.L2000C.HL.segment_position)
    assert_equal(8, @r.L2000C.L2100C.NM1.segment_position)
    assert_equal(9, @r.L2000C.L2100C.DMG.segment_position)
    assert_equal(10, @r.L2000C.L2100C.DTP.segment_position)
    assert_equal(11, @r.L2000C.L2100C.EQ.segment_position)
    assert_equal(12, @r.SE.segment_position)
  end

  def test_timing
    start = Time::now
    TEST_REPEAT.times do
      @r = @@parser.parse('270', @@m)
      test_ST
      test_L2000A_NM1
      test_L2000C_NM1
      test_L2000A_HL
      test_absent
    end
    finish = Time::now
    puts sprintf("Parses per second, 270: %.2f, elapsed: %.1f", TEST_REPEAT.to_f/(finish-start), finish-start)
  end # test_timing

end # TestParse
