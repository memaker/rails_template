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

      @contribution.save
      @contribution.fetch_commits
    end

    @contributions = Contribution.all
    respond_with(@contributions)
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
