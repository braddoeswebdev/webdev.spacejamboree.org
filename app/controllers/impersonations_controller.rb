class ImpersonationsController < ApplicationController
  before_action :require_admin, only: :create

  def create
    user = User.find(params[:user_id])

    if user == Current.user
      redirect_to users_path, alert: "You cannot impersonate yourself.", status: :see_other
      return
    end

    admin_session = Current.session
    start_new_session_for(user).update!(impersonator_id: admin_session.id)

    redirect_to root_path, notice: "Now impersonating #{user.name}."
  end

  def destroy
    impersonated_session = Current.session
    admin_session = impersonated_session.impersonator

    if admin_session.nil?
      redirect_to root_path, alert: "You are not impersonating anyone.", status: :see_other
      return
    end

    impersonated_user_name = impersonated_session.user.name
    impersonated_session.destroy!
    Current.session = admin_session
    cookies.signed.permanent[:session_id] = { value: admin_session.id, httponly: true, same_site: :lax }

    redirect_to root_path, notice: "Stopped impersonating #{impersonated_user_name}.", status: :see_other
  end

  private

  def require_admin
    redirect_to root_path, alert: "You are not authorized to impersonate users." unless Current.user.admin?
  end
end
