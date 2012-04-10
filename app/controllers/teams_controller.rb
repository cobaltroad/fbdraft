class TeamsController < ApplicationController
  def show
    @team = Team.find(params[:id])
  end

  def index
    @teams = Team.by_rank(descending: true)
  end

  def new
    @team = Team.new
  end

  def create
    @team = Team.new(params[:team])
    if @team.save
      redirect_to @team
    else
      redirect_to action: "new"
    end
  end

  def addplayer
    @team = Team.find(params[:id])
    @player = Player.find(params[:player_id])
  end

end
