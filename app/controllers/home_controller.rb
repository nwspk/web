class HomeController < ApplicationController
  layout 'subpage', except: [:index]

  def index
    @events  = Event.public_and_confirmed.upcoming
    @fellows = User.fellows
    @past_events = Event.public_and_confirmed.archive
  end

  def fellowship
    # Static register loaded from config/fellows.yml (see lib/tasks / tmp scripts
    # that generate it from the CSV register + scraped photos). Pre-sorted
    # latest-cohort-first; group_by preserves that order.
    fellows = YAML.load_file(Rails.root.join('config', 'fellows.yml'))
    @cohorts = fellows.group_by { |f| f['cohort'] }
  end

  def residency
    @fellows = User.fellows
    @alumni  = User.alumni
  end

  def study_with_us
    @fellows = User.fellows
    @alumni  = User.alumni
  end

  def course2023
    @fellows = User.fellows
    @alumni  = User.alumni
  end

  def residents
    @fellows = User.fellows
  end
end
