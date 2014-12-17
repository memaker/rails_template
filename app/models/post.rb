class Post < ActiveRecord::Base
  include Authority::Abilities

  validates :title, presence: true
end
