class Contribution
  include Mongoid::Document
  include Mongoid::Timestamps

  extend Memoist

  field :login, type: String
  field :full_name, type: String
  field :searched_at, type: Time # touch when search is started
  field :fetched_at, type: Time  # touch when fetch is finished
  field :analyzed_at, type: Time # touch when analyze is finished
  field :fetch_status, type: String

  has_one :github_user
  has_one :repository
  has_many :commits
  has_many :issues

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

  def my_commits
    fetch_commits if commits.nil?
    commits.select{|c| c.author_login == login }
  end

  def rival_commits
    fetch_commits if commits.nil?
    commits.reject{|c| c.author_login == login }
  end

  def fetch_commits
    # DEBUG CODE
    sha = full_name.include?('rails_template') ? 'contributor' : 'master'

    sawyer_commits = client.commits(full_name, sha: sha, per_page: 100)
    saved_commits = Commit.where(full_name: full_name, sha: sawyer_commits.map{|c| c.sha }).to_a
    processed_commits = []

    Parallel.each_with_index(sawyer_commits, in_threads: 5) do |commit, i|
      result =
        if saved_commits.any?{|c| c.sha == commit.sha }
          saved_commits.detect{|c| c.sha == commit.sha }
        else
          Commit.create_from_string(full_name, commit.sha)
        end

      processed_commits << {i: i, result: result}
    end

    self.commits =
      processed_commits.sort_by{|p| p[:i] }.map{|p| p[:result] }.flatten
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

  # @return [Hash]
  #   {
  #     searched_login:                     [Array<Commit>],
  #     login_who_has_the_most_commits:     [Array<Commit>],
  #     login_who_has_the_2nd_most_commits: [Array<Commit>],
  #     ...
  #     login_who_has_the_4th_most_commits: [Array<Commit>],
  #     others:                             [Array<Commit>]
  #   }
  def contributors
    fetch_commits if commits.nil?

    myself, rivals =
      [my_commits, rival_commits].map do |commits|
        commits.each_with_object({}) do |commit, memo|
          login = commit.author_login.to_sym
          if memo[login].nil?
            memo[login] = []
          end
          memo[login] << commit
        end
      end

    rivals = rivals.sort_by{|login, commits| commits.size }.reverse
    rivals_array = rivals.take(4) << [:others, rivals.drop(4).map{|login, commits| commits }.flatten]
    rivals_array.flat_map{|rival| rival.take(1) + rival.drop(1) }
    rivals = Hash[*rivals_array.flat_map{|rival| rival.take(1) + rival.drop(1) }]
    myself.merge(rivals)
  end
  memoize :contributors

  def commits_stats(start_time, end_time)
    start_day = start_time.to_date
    end_day = end_time.to_date

    point_start_seconds = start_time.beginning_of_day.to_i
    _base_data = {
      type: 'column',
      name: nil,
      pointInterval: 24 * 3_600 * 1_000,
      pointStart: point_start_seconds * 1_000,
      data: nil
    }

    commits_data = []
    additions_data = []
    deletions_data  = []

    contributors.each do |login, commits|
      commits_num = (start_day..end_day).map do |date|
        commits.select{|c| c.author_date.to_date == date }.size
      end

      additions_num = (start_day..end_day).map do |date|
        commits.select{|c| c.author_date.to_date == date }.sum{|c| c.stats[:additions] }
      end

      deletions_num = (start_day..end_day).map do |date|
        commits.select{|c| c.author_date.to_date == date }.sum{|c| c.stats[:deletions] }
      end

      commits_data << _base_data.deep_dup.merge(data: commits_num, name: login)
      additions_data << _base_data.deep_dup.merge(data: additions_num, name: login)
      deletions_data << _base_data.deep_dup.merge(data: deletions_num, name: login)
    end

    {
      start_day: start_day,
      end_day: end_day,
      commits: commits_data,
      additions: additions_data,
      deletions: deletions_data,
    }
  end
  memoize :commits_stats

  # Must run in background
  def self.fetch_all(login, full_name, start_day, end_day)
    contribution = Contribution.find_or_initialize_by(login: login, full_name: full_name)
    contribution.touch(:searched_at)
    contribution.update(fetch_status: "Let's go.")
    logger.info "Let's go. #{login} #{full_name}"
    contribution.save

    contribution.update(fetch_status: 'Fetching github user.')
    logger.info "Fetching github user. #{login} #{full_name}"
    bm('fetch_github_user'){ contribution.fetch_github_user }

    contribution.update(fetch_status: 'Fetching repository meta data.')
    logger.info "Fetching repository meta data. #{login} #{full_name}"
    bm('fetch_repository'){ contribution.fetch_repository }

    contribution.update(fetch_status: 'Fetching commits meta data. This is quite time-consuming.')
    logger.info "Fetching commits meta data. This is quite time-consuming. #{login} #{full_name}"
    bm('fetch_commits'){ contribution.fetch_commits }

    contribution.update(fetch_status: 'Fetching issues.')
    logger.info "Fetching issues. #{login} #{full_name}"
    bm('fetch_issues'){ contribution.fetch_issues }
    contribution.touch(:fetched_at)

    contribution.update(fetch_status: 'Fetching is completed.')
    logger.info "Fetching is completed. #{login} #{full_name}"

    contribution.update(fetch_status: 'Analyzing commits.')
    logger.info "Analyzing commits. #{login} #{full_name}"
    result = {
      contributors: bm('contributors'){ contribution.contributors },
      commits_stats: bm('commits_stats'){ contribution.commits_stats(start_day, end_day) },
    }
    RedisUtil.set(result_key(login, full_name), result)
    contribution.touch(:analyzed_at)

    contribution.update(fetch_status: nil)
    logger.info "Completed. #{login} #{full_name}"

    contribution.save
    contribution
  end

  def self.bm(name, &block)
    start = Time.now
    result = yield if block_given?
    logger.info "BENCHMARK: #{name} #{Time.now - start} sec"
    result
  end

  def self.result_key(login, full_name)
    "result:#{login}:#{full_name}"
  end

  def result_key
    self.class.result_key(login, full_name)
  end

  def recently_analyzed?
    analyzed_at && analyzed_at > Time.now - 5.minutes && RedisUtil.exists?(result_key)
  end

  def recently_fetched?
    fetched_at && fetched_at > Time.now - 5.minutes
  end

  def recently_searched?
    searched_at && searched_at > Time.now - 5.minutes
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
