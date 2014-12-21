class Post < ActiveRecord::Base
  include Authority::Abilities

  validates :title, :description, presence: true
end
