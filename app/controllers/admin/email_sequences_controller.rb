# frozen_string_literal: true

class Admin::EmailSequencesController < ApplicationController
  include AdminAccess

  before_action :set_sequence, only: [ :show, :edit, :update, :destroy, :enable, :disable ]

  def index
    @sequences = EmailSequence
                              .order(created_at: :desc)
  end

  def show
    @steps = @sequence.email_steps.ordered
  end

  def new
    @sequence = EmailSequence.new(site: Current.site)
  end

  def create
    @sequence = EmailSequence.new(sequence_params)
    @sequence.site = Current.site

    if @sequence.save
      redirect_to admin_email_sequence_path(@sequence), notice: t("admin.email_sequences.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @sequence.update(sequence_params)
      redirect_to admin_email_sequence_path(@sequence), notice: t("admin.email_sequences.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @sequence.destroy
    redirect_to admin_email_sequences_path, notice: t("admin.email_sequences.deleted")
  end

  def enable
    @sequence.update!(enabled: true)
    redirect_to admin_email_sequence_path(@sequence), notice: t("admin.email_sequences.enabled")
  end

  def disable
    @sequence.update!(enabled: false)
    redirect_to admin_email_sequence_path(@sequence), notice: t("admin.email_sequences.disabled")
  end

  private

  def set_sequence
    @sequence = EmailSequence.find(params[:id])
  end

  def sequence_params
    params.require(:email_sequence).permit(:name, :trigger_type, :enabled).tap do |p|
      # Handle trigger_config as JSON
      if params[:email_sequence][:trigger_config].present?
        begin
          p[:trigger_config] = JSON.parse(params[:email_sequence][:trigger_config])
        rescue JSON::ParserError
          # Keep as-is, validation will catch invalid JSON
          p[:trigger_config] = params[:email_sequence][:trigger_config]
        end
      end
    end
  end
end
