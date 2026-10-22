module Admissions
  # The staff-only /admissions area (SPEC §9, §9b). Only a signed-in user
  # holding an admissions role gets in; everyone else, signed in or not, gets
  # the site's ordinary not-found page, so the area isn't advertised.
  class BaseController < ApplicationController
    layout 'subpage'

    before_action :require_admissions_staff

    rescue_from(ActiveRecord::RecordNotFound) { route_not_found }

    rescue_from CanCan::AccessDenied do
      redirect_to admissions_root_path, alert: 'Only an admissions lead can do that.'
    end

    private

    def require_admissions_staff
      route_not_found unless current_user && can?(:read, Admissions::Round)
    end
  end
end
