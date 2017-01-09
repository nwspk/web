class UsersController < ApplicationController
  before_filter :authenticate_user!

  def update
    current_user.update(user_params)

    respond_to do |format|
      format.json { respond_with_bip(current_user) }
      format.html { redirect_to dashboard_path }
    end
  end

  private

  def user_params
    params.require(:user).permit(:showcase_text, :ring_size, :name, :email, :url, :avatar)
  end
end
