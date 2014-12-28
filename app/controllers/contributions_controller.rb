class ContributionsController < ApplicationController
  before_action :set_contribution, only: [:show, :edit, :update, :destroy]

  respond_to :html

  def index
    @contributions = Contribution.all
    respond_with(@contributions)
  end

  def calc_commits_stats(commits)
    today = DateTime.now.utc.to_date
    start_day = today.beginning_of_week
    end_day = today.end_of_week

    commits_data = (start_day..end_day).map do |date|
      commits.select{|c| c.date.to_date == date }.size
    end

    additions_data = (start_day..end_day).map do |date|
      commits.select{|c| c.date.to_date == date }.sum{|c| c.stats[:additions] }
    end

    deletions_data = (start_day..end_day).map do |date|
      commits.select{|c| c.date.to_date == date }.sum{|c| c.stats[:deletions] }
    end

    point_start_seconds = DateTime.now.utc.beginning_of_week.to_i
    _base_data = {
      type: 'column',
      name: nil,
      pointInterval: 24 * 3_600 * 1_000,
      pointStart: point_start_seconds * 1_000,
      data: nil
    }

    commits_data = _base_data.deep_dup.merge(data: commits_data, name: 'commits')
    additions_data = _base_data.deep_dup.merge(data: additions_data, name: 'additions')
    deletions_data = _base_data.deep_dup.merge(data: deletions_data, name: 'deletions')

    {
      start_day: start_day,
      end_day: end_day,
      all: [commits_data, additions_data, deletions_data],
      commits: [commits_data],
      additions: [additions_data],
      deletions: [deletions_data],
    }
  end

  def show
    @commits_stats = calc_commits_stats(@contribution.commits)
    respond_with(@contribution)
  end

  def new
    @contribution = Contribution.new
    respond_with(@contribution)
  end

  def edit
  end

  def create
    @contribution = Contribution.new(contribution_params)
    @contribution.save
    respond_with(@contribution)
  end

  def update
    @contribution.update(contribution_params)
    respond_with(@contribution)
  end

  def destroy
    @contribution.destroy
    respond_with(@contribution)
  end

  private

  def set_contribution
    full_name = params[:full_name] # octocat/Hello-World
    login = params[:login]         # octocat

    if full_name.present? && login.present?
      @contribution = Contribution.find_or_initialize_by(login: login, full_name: full_name)
      @contribution.fetch_github_user
      @contribution.fetch_repository
      @contribution.fetch_commits
      @contribution.fetch_issues
      @contribution.fetch_rivals

      @contribution.save
    end
  end

  def contribution_params
    params[:contribution]
  end
end
