class AnnouncementSupport < ApplicationRecord
  belongs_to :announcement, counter_cache: :supports_count
  belongs_to :user

  validates :user_id, uniqueness: { scope: :announcement_id, message: "ya apoyaste esta novedad" }
end
