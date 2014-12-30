class Contribution
  include Mongoid::Document
  include Mongoid::Timestamps

  include Contribution::Fetchable

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

  def my_commits
    fetch_commits if commits.nil?
    commits.select{|c| c.author_login == login }
  end

  def rival_commits
    fetch_commits if commits.nil?
    commits.reject{|c| c.author_login == login }
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
end
