module HomeHelper
  def profile_image_url(user)
    user.avatar.file.nil? ? default_avatar : user.avatar_url
  end

  def default_avatar
    ActionController::Base.helpers.asset_url('default-face.jpg', type: :image)
  end

  # Asset path for a fellow entry from config/fellows.yml (falls back to the
  # default face for placeholder entries with no photo yet).
  def fellow_image(fellow)
    fellow['image'].presence || 'default-face.jpg'
  end

  # Cohort group photos, shown as a plate under the cohort's heading on
  # /fellowship. Listed explicitly so a photo only appears once chosen.
  COHORT_PHOTOS = {
    '2025 Cohort' => '2025-cohort.jpg'
  }.freeze

  def cohort_photo(cohort)
    COHORT_PHOTOS[cohort]
  end
end
