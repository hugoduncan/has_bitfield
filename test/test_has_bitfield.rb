require 'helper'
require 'active_support/core_ext'
require 'active_support/test_case'

# ActiveRecord proxies
module Proxy
  class Column
    def name
      'flags'
    end
    def type
      :integer
    end
  end

  class Base < Hash
    def self.columns
      [Column.new]
    end

    def flags=(value)
      self[:flags] = value
    end

    def flags
      self[:flags]
    end

  end
end

class Foo < Proxy::Base
  include ::HasBitfield

  def self.table_name
    "foos"
  end

  has_bitfield(:my_flags,
               :as => :flags,
               1 => :active,
               2 => :suspended,
               3 => { :another => { :default => true } } )
end

class HasBitfieldTest < ActiveSupport::TestCase

  test "should raise an exception when a negative bit is specified" do
    assert_raises ArgumentError do
      eval(<<-EOF
        class Invalid < Proxy::Base
          include ::HasBitfield
          has_bitfield({ -1 => :error })
        end
        EOF
        )
    end
  end

  test "should raise an exception when a zero bit is specified" do
    assert_raises ArgumentError do
      eval(<<-EOF
        class Invalid < Proxy::Base
          include ::HasBitfield
          has_bitfield({ 0 => :error })
        end
      EOF
      )
    end
  end

  test "should raise an exception when a bit above 32 is specified" do
    assert_raises ArgumentError do
      eval(<<-EOF
        class Invalid < Proxy::Base
          include ::HasBitfield
          has_bitfield({ 33 => :error })
        end
      EOF
      )
    end
  end

  def setup
    @foo = Foo.new
  end

  test "test class should have flags field" do
    @foo.flags = 1
    assert_equal 1, @foo.flags
    assert_equal 1, @foo[:flags]

    @foo[:flags] = 2
    assert_equal 2, @foo.flags
    assert_equal 2, @foo[:flags]
  end

  test "should have my_flags reader" do
    @foo.flags = 1
    assert_equal 1, @foo.my_flags

    @foo[:flags] = 2
    assert_equal 2, @foo.my_flags
  end

  test "should return the initialized flag field" do
    @foo.initialize_my_flags
    assert_equal 4, @foo.my_flags
  end

  test "should correctly define predicate" do
    @foo[:flags] = 4
    assert !@foo.active?
    assert !@foo.suspended?
    assert @foo.another?
  end

  test "should correctly define reader" do
    @foo[:flags] = 4
    assert !@foo.active
    assert !@foo.suspended
    assert @foo.another
  end

  test "should correctly define assignment" do
    @foo[:flags] = 4
    @foo.active = true
    assert @foo.active?
    assert !@foo.suspended?
    assert @foo.another?

    @foo.active = false
    assert !@foo.active?
    assert !@foo.suspended?
    assert @foo.another?
  end

  test "should correctly assign from string" do
    @foo[:flags] = 4
    @foo.active="1"
    assert @foo.active
    @foo.active="0"
    assert !@foo.active
  end

  test "should define condition" do
    assert_equal "(foos.flags & 1 = 1)", Foo.active_condition
  end

  test "should define negated condition" do
    assert_equal "(foos.flags & 1 = 0)", Foo.not_active_condition
  end

  test "should correctly assign current value" do
    @foo[:flags] = 4
    @foo.active = true
    2.times do
      @foo.active = false
      assert !@foo.active?
    end
  end

  test "should have an initial value" do
    @foo.initialize_my_flags
    assert_equal false, @foo.active?
    assert_equal false, @foo.suspended?
    assert_equal true, @foo.another?
  end


end
