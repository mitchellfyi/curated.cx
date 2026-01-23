class RenameModelNameToAiModelInEditorialisations < ActiveRecord::Migration[8.0]
  def change
    # Pre-launch: table is empty, safe to rename directly
    safety_assured { rename_column :editorialisations, :model_name, :ai_model }
  end
end
