class ContributionsController < ApplicationController
  before_action :set_contribution, only: [:show, :edit, :update, :destroy]

  respond_to :html

  def index
    @full_name = params[:full_name] # octocat/Hello-World
    @login = params[:login]         # octocat

    if @full_name.present? && @login.present?
      @contribution = Contribution.find_or_initialize_by(login: @login, full_name: @full_name)
      @contribution.fetch_github_user
      @contribution.fetch_repository
      @contribution.fetch_commits
      @contribution.fetch_issues

      @contribution.save
    end

    @hey = hey(@contribution.commits)

    @contributions = Contribution.all
    respond_with(@contributions)
  end

  def hey(commits)
    today = DateTime.now.utc.to_date

    commits_data = (today.beginning_of_week..today.end_of_week).map do |date|
      commits.select{|c| c.date.to_date == date }.size
    end

    additions_data = (today.beginning_of_week..today.end_of_week).map do |date|
      commits.select{|c| c.date.to_date == date }.sum{|c| c.stats[:additions] }
    end

    deletions_data = (today.beginning_of_week..today.end_of_week).map do |date|
      commits.select{|c| c.date.to_date == date }.sum{|c| c.stats[:deletions] }
    end

    [
      {
        type: 'column',
        name: 'commits',
        pointInterval: 24 * 3_600 * 1_000,
        pointStart: DateTime.now.utc.beginning_of_week.to_i * 1_000,
        data: commits_data
      }, {
        type: 'column',
        name: 'additions',
        pointInterval: 24 * 3_600 * 1_000,
        pointStart: DateTime.now.utc.beginning_of_week.to_i * 1_000,
        data: additions_data
      }, {
        type: 'column',
        name: 'deletions',
        pointInterval: 24 * 3_600 * 1_000,
        pointStart: DateTime.now.utc.beginning_of_week.to_i * 1_000,
        data: deletions_data
      }
    ]
  end

  def show
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
      @contribution = Contribution.find(params[:id])
    end

    def contribution_params
      params[:contribution]
    end
end
