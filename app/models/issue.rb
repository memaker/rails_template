class Issue
  include Mongoid::Document
  include Mongoid::Timestamps

  field :related_to, type: String
  field :number, type: Integer
  field :full_name, type: String
  field :state, type: String
  field :creator, type: String
  field :assignee, type: String

  belongs_to :contribution

  validates :related_to, :number, :full_name, :state, :creator, :assignee, presence: true

  index({ number: 1, full_name: 1 }, { unique: true, background: true })

  def closed?
    state == 'close'
  end

  def open?
    state == 'open'
  end

  def self.create_from_sawyer(issue, related_to)
    issue.url =~ %r{repos/(.+)/issues}
    full_name = $1
    create(
        related_to: related_to,
        number: issue.number,
        full_name: full_name,
        state: issue.state,
        creator: issue.user.login,
        assignee: issue.assignee.try(:login)
    )
  end
end
