class PlayersController < ApplicationController

  before_filter :get_player, except: [:index]

  def show
  end

  def index
    if params[:type] == "hitters"
      if params[:pos]
        @players = Hitter.send("avail_by_pos_and_#{sort_column}", startkey: start_key, endkey: end_key, descending: sort_dir).page(params[:page])
      else
        @players = Hitter.send("avail_by_#{sort_column}", descending: sort_dir).page(params[:page])
      end

    elsif params[:type] == "pitchers"
      if params[:pos]
        @players = Pitcher.send("avail_by_pos_and_#{sort_column}", startkey: start_key, endkey: end_key, descending: sort_dir).page(params[:page])
      else
        @players = Pitcher.send("avail_by_#{sort_column}", descending: sort_dir).page(params[:page])
      end

    elsif params[:q]
      @players = Player.query(params[:q])
      render "search_results"
    else
      @players = []
    end
  end

  def edit
  end

  def update
    if params[:hitter]
      @player.update_attributes(params[:hitter])
    elsif params[:pitcher]
      @player.update_attributes(params[:pitcher])
    end

    redirect_to action: "show", id: @player.id
  end

  def assign_roster
    team = Team.find(params[:roster_spot]["fantasy_team_id"])

    @player.update_attributes(fantasy_team: team)

    name = @player.name
    rs = RosterSpot.new(position:         params[:roster_spot]["position"],
                        salary:           params[:roster_spot]["salary"],
                        contract:         params[:roster_spot]["contract"],
                        name:             name,
                        player_id:        params[:id],
                        fantasy_team_id:  team.id)
    team.roster << rs
    if team.save
      team.update_proj_totals
      Team.update_proj_rank
      redirect_to team_path(team)
    else
      redirect_to action: "show", id: params[:id]
    end
  end

  def update_roster
    team = Team.find(params[:roster_spot]["fantasy_team_id"])

    current_team = @player.fantasy_team
    rs = current_team.roster.find{ |rs| rs.player_id = params[:id] }
    current_team.roster.delete(rs)
    current_team.save

    @player.update_attributes(fantasy_team: team)

    unless team.nil?
      name = @player.name
      rs = RosterSpot.new(position:         params[:roster_spot]["position"],
                          salary:           params[:roster_spot]["salary"],
                          contract:         params[:roster_spot]["contract"],
                          name:             name,
                          player_id:        params[:id],
                          fantasy_team_id:  team.id)
      team.roster << rs
      if team.save
        team.update_proj_totals
        Team.update_proj_rank
        redirect_to team_path(team)
      else
        redirect_to action: "show", id: params[:id]
      end
    else
      redirect_to action: "show", id: params[:id]
    end
  end

  private

  def get_player
    @player = Player.find(params[:id])
  end

  def sort_column
    params[:sort].nil? ? "norm_sum" : params[:sort]
  end

  def sort_dir
    asc_sort_params = %w(name team pos proj_era proj_whip)
    asc_sort_params.include?(params[:sort]) ? false : true
  end

  def start_key
    asc_sort_params = %w(name team pos proj_era proj_whip)
    asc_sort_params.include?(params[:sort]) ? [params[:pos]] : [params[:pos], {}]
  end

  def end_key
    asc_sort_params = %w(name team pos proj_era proj_whip)
    asc_sort_params.include?(params[:sort]) ? [params[:pos], {}] : [params[:pos]]
  end
end
