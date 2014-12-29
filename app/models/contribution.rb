class Contribution
  include Mongoid::Document
  include Mongoid::Timestamps

  field :login, type: String
  field :full_name, type: String

  has_one :github_user
  has_one :repository
  has_many :commits
  has_many :issues

  attr_accessor :rivals

  validates :login, :full_name, presence: true

  index({ login: 1, full_name: 1 }, { unique: true, background: true })

  def fetch_github_user
    if github_user.blank?
      _github_user = GithubUser.find_or_initialize_by(login: login)
      if _github_user.new_record?
        _github_user = GithubUser.create_from_string(login)
      end
      self.github_user = _github_user
    end
  end

  def fetch_repository
    if repository.blank?
      _repository = Repository.find_or_initialize_by(full_name: full_name)
      if _repository.new_record?
        _repository = Repository.create_from_string(full_name)
      end
      self.repository = _repository
    end
  end

  def fetch_commits
    # DEBUG CODE
    sha = full_name.include?('rails_template') ? 'contributor' : 'master'

    # TODO fetch in parallel
    self.commits =
      client.commits(full_name, author: login, sha: sha, per_page: 100).map do |commit|
        if Commit.where(full_name: full_name, sha: commit.sha).exists?
          Commit.find_by(full_name: full_name, sha: commit.sha)
        else
          Commit.create_from_string(full_name, commit.sha)
        end
      end
  end

  def fetch_issues
    self.issues =
      if Issue.where(full_name: full_name, related_to: login).exists?
        Issue.where(full_name: full_name, related_to: login)
      else
        _issues = client.issues(full_name, assignee: login, per_page: 100)
        _issues += client.issues(full_name, creator: login, per_page: 100)
        _issues.uniq! { |i| i.number }
        _issues.map { |issue| Issue.create_from_sawyer(issue, login) }
      end
  end

  def fetch_rivals
    # DEBUG CODE
    sha = full_name.include?('rails_template') ? 'contributor' : 'master'

    # TODO fetch in parallel
    rival_commits =
      client.commits(full_name, sha: sha, per_page: 100).map do |commit|
        next if commit.author.login == login

        if Commit.where(full_name: full_name, sha: commit.sha).exists?
          Commit.find_by(full_name: full_name, sha: commit.sha)
        else
          Commit.create_from_string(full_name, commit.sha)
        end
      end.compact

    self.rivals =
      rival_commits.inject({}) do |memo, commit|
        login = commit.author_login
        if memo[login].nil?
          memo[login] = {login: login, commits: []}
        end
        memo[login]['commits'] << commit

        memo
      end
  end

  def self.fetch_all(login, full_name)
    contribution = Contribution.find_or_initialize_by(login: login, full_name: full_name)
    contribution.fetch_github_user
    contribution.fetch_repository
    contribution.fetch_commits
    contribution.fetch_issues
    contribution.fetch_rivals
    contribution.save

    contribution
  end

  def additions_sum
    commits.inject(0){|sum, commit| sum + commit.stats[:additions] }
  end

  def deletions_sum
    commits.inject(0){|sum, commit| sum + commit.stats[:deletions] }
  end

  private

  def client
    OctokitUtil.client
  end
end
