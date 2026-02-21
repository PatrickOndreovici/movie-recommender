class Video < ApplicationRecord
  belongs_to :user

  validates :status, presence: true
end
