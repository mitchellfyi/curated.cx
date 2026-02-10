# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'Database Rake Tasks' do
  before(:all) do
    # Load the rake tasks
    Rake.application.rake_require 'tasks/database'
    Rake::Task.define_task(:environment)
  end

  describe 'db:connections task' do
    before { Rake::Task['db:connections'].reenable }

    it 'should show database connection status' do
      expect { Rake::Task['db:connections'].invoke }.not_to raise_error
    end
  end

  describe 'db:close_connections task' do
    before { Rake::Task['db:close_connections'].reenable }

    it 'should close database connections' do
      expect { Rake::Task['db:close_connections'].invoke }.not_to raise_error
    end

    after do
      # Re-establish connection closed by the task so subsequent tests work
      ActiveRecord::Base.establish_connection
    end
  end

  describe 'db:create_safe task' do
    before { Rake::Task['db:create_safe'].reenable }

    it 'should not error when database already exists' do
      expect { Rake::Task['db:create_safe'].invoke }.not_to raise_error
    end
  end

  describe 'db:migrate_safe task' do
    before { Rake::Task['db:migrate_safe'].reenable }

    it 'should migrate database safely' do
      expect { Rake::Task['db:migrate_safe'].invoke }.not_to raise_error
    end
  end

  describe 'available tasks' do
    it 'should have all expected database tasks' do
      expected_tasks = [
        'db:reset_safe',
        'db:drop_safe',
        'db:create_safe',
        'db:migrate_safe',
        'db:setup_safe',
        'db:connections',
        'db:close_connections'
      ]

      expected_tasks.each do |task_name|
        expect(Rake::Task.task_defined?(task_name)).to be(true), "Task #{task_name} should be defined"
      end
    end
  end
end
