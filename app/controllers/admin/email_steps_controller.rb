# frozen_string_literal: true

class Admin::EmailStepsController < ApplicationController
  include AdminAccess

  before_action :set_sequence
  before_action :set_step, only: [ :show, :edit, :update, :destroy  ]

  def show
  end

  def new
    next_position = (@sequence.email_steps.maximum(:position) || -1) + 1
    @step = @sequence.email_steps.build(position: next_position)
  end

  def create
    @step = @sequence.email_steps.build(step_params)

    if @step.save
      redirect_to admin_email_sequence_path(@sequence), notice: t("admin.email_steps.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @step.update(step_params)
      redirect_to admin_email_sequence_path(@sequence), notice: t("admin.email_steps.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @step.destroy
    redirect_to admin_email_sequence_path(@sequence), notice: t("admin.email_steps.deleted")
  end

  private

  def set_sequence
    @sequence = EmailSequence.find(params[:email_sequence_id])
  end

  def set_step
    @step = @sequence.email_steps.find(params[:id])
  end

  def step_params
    params.require(:email_step).permit(:position, :delay_seconds, :subject, :body_html, :body_text)
  end
end
