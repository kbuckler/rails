# encoding: utf-8
require "cases/helper"
require 'models/topic'
require 'models/reply'
require 'models/person'
require 'models/developer'
require 'models/warehouse_thing'
require 'models/guid'
require 'models/owner'
require 'models/pet'
require 'models/event'

class ProtectedPerson < ActiveRecord::Base
  set_table_name 'people'
  attr_accessor :addon
  attr_protected :first_name
end

class DeprecatedPerson < ActiveRecord::Base
  set_table_name 'people'

  protected

  def validate
    errors[:name] << "always invalid"
  end

  def validate_on_create
    errors[:name] << "invalid on create"
  end

  def validate_on_update
    errors[:name] << "invalid on update"
  end
end

class ValidationsTest < ActiveRecord::TestCase
  fixtures :topics, :developers

  # Most of the tests mess with the validations of Topic, so lets repair it all the time.
  # Other classes we mess with will be dealt with in the specific tests
  repair_validations(Topic)

  def test_error_on_create
    r = WrongReply.new
    r.title = "Wrong Create"
    assert !r.valid?
    assert r.errors[:title].any?, "A reply with a bad title should mark that attribute as invalid"
    assert_equal ["is Wrong Create"], r.errors[:title], "A reply with a bad content should contain an error"
  end

  def test_error_on_update
    r = WrongReply.new
    r.title = "Bad"
    r.content = "Good"
    assert r.save, "First save should be successful"

    r.title = "Wrong Update"
    assert !r.save, "Second save should fail"

    assert r.errors[:title].any?, "A reply with a bad title should mark that attribute as invalid"
    assert_equal ["is Wrong Update"], r.errors[:title], "A reply with a bad content should contain an error"
  end

  def test_invalid_record_exception
    assert_raise(ActiveRecord::RecordInvalid) { WrongReply.create! }
    assert_raise(ActiveRecord::RecordInvalid) { WrongReply.new.save! }

    begin
      r = WrongReply.new
      r.save!
      flunk
    rescue ActiveRecord::RecordInvalid => invalid
      assert_equal r, invalid.record
    end
  end

  def test_exception_on_create_bang_many
    assert_raise(ActiveRecord::RecordInvalid) do
      WrongReply.create!([ { "title" => "OK" }, { "title" => "Wrong Create" }])
    end
  end

  def test_exception_on_create_bang_with_block
    assert_raise(ActiveRecord::RecordInvalid) do
      WrongReply.create!({ "title" => "OK" }) do |r|
        r.content = nil
      end
    end
  end

  def test_exception_on_create_bang_many_with_block
    assert_raise(ActiveRecord::RecordInvalid) do
      WrongReply.create!([{ "title" => "OK" }, { "title" => "Wrong Create" }]) do |r|
        r.content = nil
      end
    end
  end

  def test_scoped_create_without_attributes
    WrongReply.send(:with_scope, :create => {}) do
      assert_raise(ActiveRecord::RecordInvalid) { WrongReply.create! }
    end
  end

  def test_create_with_exceptions_using_scope_for_protected_attributes
    assert_nothing_raised do
      ProtectedPerson.send(:with_scope,  :create => { :first_name => "Mary" } ) do
        person = ProtectedPerson.create! :addon => "Addon"
        assert_equal person.first_name, "Mary", "scope should ignore attr_protected"
      end
    end
  end

  def test_create_with_exceptions_using_scope_and_empty_attributes
    assert_nothing_raised do
      ProtectedPerson.send(:with_scope,  :create => { :first_name => "Mary" } ) do
        person = ProtectedPerson.create!
        assert_equal person.first_name, "Mary", "should be ok when no attributes are passed to create!"
      end
    end
  end

  def test_create_without_validation
    reply = WrongReply.new
    assert !reply.save
    assert reply.save(false)
  end

  def test_create_without_validation_bang
    count = WrongReply.count
    assert_nothing_raised { WrongReply.new.save_without_validation! }
    assert count+1, WrongReply.count
  end

  def test_validates_acceptance_of_with_non_existant_table
    Object.const_set :IncorporealModel, Class.new(ActiveRecord::Base)

    assert_nothing_raised ActiveRecord::StatementInvalid do
      IncorporealModel.validates_acceptance_of(:incorporeal_column)
    end
  end

  def test_throw_away_typing
    d = Developer.new("name" => "David", "salary" => "100,000")
    assert !d.valid?
    assert_equal 100, d.salary
    assert_equal "100,000", d.salary_before_type_cast
  end

  def test_validates_acceptance_of_as_database_column
    Topic.validates_acceptance_of(:author_name)
    topic = Topic.create("author_name" => "Dan Brown")
    assert_equal "Dan Brown", topic["author_name"]
  end
end
