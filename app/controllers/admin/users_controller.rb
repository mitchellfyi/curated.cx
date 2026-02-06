# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    include AdminAccess

    before_action :set_user, only: [ :show, :edit, :update, :destroy, :ban, :unban, :make_admin, :remove_admin, :assign_role, :remove_role ]

    # GET /admin/users
    def index
      @users = User.includes(:roles).order(created_at: :desc)

      # Search
      if params[:search].present?
        @users = @users.where("email ILIKE ? OR display_name ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
      end

      # Filter by role
      if params[:role].present?
        @users = @users.joins(:roles).where(roles: { name: params[:role] }).distinct
      end

      # Filter by admin status
      if params[:admins_only] == "true"
        @users = @users.where(admin: true)
      end

      @users = @users.page(params[:page]).per(50)
      @stats = build_stats
    end

    # GET /admin/users/:id
    def show
      @roles = @user.roles.includes(:resource)
      @recent_activity = build_recent_activity
    end

    # GET /admin/users/:id/edit
    def edit
    end

    # PATCH /admin/users/:id
    def update
      if @user.update(user_params)
        redirect_to admin_user_path(@user), notice: "User updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/users/:id
    def destroy
      if @user == current_user
        redirect_to admin_users_path, alert: "Cannot delete yourself."
      else
        @user.destroy
        redirect_to admin_users_path, notice: "User deleted."
      end
    end

    # POST /admin/users/:id/ban
    def ban
      # Create a site ban for the current site
      if Current.site
        SiteBan.find_or_create_by!(site: Current.site, user: @user) do |ban|
          ban.reason = params[:reason] || "Banned by admin"
          ban.banned_by = current_user
        end
        redirect_to admin_user_path(@user), notice: "User banned from #{Current.site.name}."
      else
        redirect_to admin_user_path(@user), alert: "No site context for ban."
      end
    end

    # POST /admin/users/:id/unban
    def unban
      if Current.site
        SiteBan.where(site: Current.site, user: @user).destroy_all
        redirect_to admin_user_path(@user), notice: "User unbanned."
      else
        redirect_to admin_user_path(@user), alert: "No site context."
      end
    end

    # POST /admin/users/:id/make_admin
    def make_admin
      unless current_user.admin?
        redirect_to admin_user_path(@user), alert: "Only admins can grant admin status."
        return
      end

      @user.update!(admin: true)
      redirect_to admin_user_path(@user), notice: "User is now a super admin."
    end

    # POST /admin/users/:id/remove_admin
    def remove_admin
      unless current_user.admin?
        redirect_to admin_user_path(@user), alert: "Only admins can revoke admin status."
        return
      end

      if @user == current_user
        redirect_to admin_user_path(@user), alert: "Cannot remove your own admin status."
        return
      end

      @user.update!(admin: false)
      redirect_to admin_user_path(@user), notice: "Admin status removed."
    end

    # POST /admin/users/:id/assign_role
    def assign_role
      role_name = params[:role_name]
      tenant = Current.tenant

      unless tenant
        redirect_to admin_user_path(@user), alert: "No tenant context."
        return
      end

      unless Role::TENANT_ROLES.include?(role_name)
        redirect_to admin_user_path(@user), alert: "Invalid role."
        return
      end

      unless can_assign_role?(role_name)
        redirect_to admin_user_path(@user), alert: "You cannot assign a role equal to or higher than your own."
        return
      end

      # Remove existing tenant roles first, then assign the new one
      Role::TENANT_ROLES.each { |r| @user.remove_role(r, tenant) }
      @user.add_role(role_name.to_sym, tenant)
      redirect_to admin_user_path(@user), notice: "Role updated to #{role_name.titleize}."
    end

    # DELETE /admin/users/:id/remove_role
    def remove_role
      tenant = Current.tenant

      unless tenant
        redirect_to admin_user_path(@user), alert: "No tenant context."
        return
      end

      @user.roles.where(resource: tenant).destroy_all
      redirect_to admin_user_path(@user), notice: "Tenant access removed."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:email, :display_name, :bio, :avatar_url)
    end

    def build_stats
      {
        total_users: User.count,
        admins: User.where(admin: true).count,
        this_week: User.where("created_at > ?", 1.week.ago).count,
        this_month: User.where("created_at > ?", 1.month.ago).count
      }
    end

    def can_assign_role?(role_name)
      return true if current_user.admin?

      my_level = current_user.highest_tenant_role(Current.tenant)&.then { |r| Role::HIERARCHY[r.name] } || 0
      target_level = Role::HIERARCHY[role_name] || 0
      my_level > target_level
    end

    def build_recent_activity
      {
        comments: @user.comments.order(created_at: :desc).limit(5),
        votes: @user.votes.order(created_at: :desc).limit(5),
        notes: @user.notes.order(created_at: :desc).limit(5),
        submissions: Submission.where(user: @user).order(created_at: :desc).limit(5)
      }
    end
  end
end
