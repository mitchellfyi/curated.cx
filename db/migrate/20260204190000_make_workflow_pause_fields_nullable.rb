# frozen_string_literal: true

class MakeWorkflowPauseFieldsNullable < ActiveRecord::Migration[8.1]
  def change
    # Allow paused_by and paused_at to be null initially
    # They are set when pause! is called, not on record creation
    change_column_null :workflow_pauses, :paused_by_id, true
    change_column_null :workflow_pauses, :paused_at, true
  end
end
