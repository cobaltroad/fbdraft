class RosterSpot
  include CouchRest::Model::Embeddable

  property :position,   String
  property :salary,     Integer
  property :contract,   String
  property :name,       String
  property :player_id,  String

  property :fantasy_team_id, String

  def team_view
    player = Player.find(self.player_id)
    {
        position: self.position,
        name: self.name,
        contract: "#{self.contract}-#{self.salary}",
        projections: player.projections,
        player_id: self.player_id
    }
  end

  def player
    Player.find(self.player_id)
  end
end

class Team < CouchRest::Model::Base

  property :name,   String
  property :owner,  String

  property :roster,   [RosterSpot]

  HITTER_TRACKING_STATS = HITTER_RATING_STATS + ["h", "ab"]
  HITTER_TRACKING_STATS.each do |stat|
    property "proj_#{stat}".to_sym, Integer
  end

  PITCHER_TRACKING_STATS = PITCHER_RATING_STATS + ["er", "walk", "ha", "ip"]
  PITCHER_TRACKING_STATS.each do |stat|
    property "proj_#{stat}".to_sym, Integer
  end

  RANKING_STATS = HITTER_RATING_STATS + PITCHER_RATING_STATS
  RANKING_STATS.each do |stat|
    property "rank_#{stat}".to_sym, Integer
  end

  MAXSPOTS  = (Rails.env == "nl" ?  25 :  23)
  MAXSALARY = (Rails.env == "nl" ? 280 : 260)

  design do
    RANKING_STATS.each do |stat|
      view "by_proj_#{stat}".to_sym
    end

    view :by_rank,
      map: "
        function(doc) {
          if (doc['type'] == 'Team') {
            hitter_sum  = doc['rank_avg'] + doc['rank_r'] + doc['rank_hr'] + doc['rank_rbi'] + doc['rank_sb'];
            pitcher_sum = doc['rank_w'] + doc['rank_sv'] + doc['rank_era'] + doc['rank_k'] + doc['rank_whip'];
            emit(hitter_sum + pitcher_sum, 1);
          }
        }
      "
  end

  ###############################################
  # projected totals
  #
  # These methods use player views to constract the totals for this team, which is then saved onto the team object

  def hitter_totals
    totals = {"h" => 0, "ab" => 1}
    Hitter.team_view(self).reduce.group_level(2).rows.each do |obj|
      totals[obj["key"][1]] = obj["value"]
    end
    # now correct for the averages
    totals["avg"] = (totals["h"]/totals["ab"].to_f).round(3)
    totals
  end

  def pitcher_totals
    totals = {"er" => 0, "walk" => 0, "ha" => 0, "ip" => 1}
    Pitcher.team_view(self).reduce.group_level(2).rows.each do |obj|
      totals[obj["key"][1]] = obj["value"]
    end
    # now correct for the averages
    totals["era"] = (totals["er"]*9/totals["ip"].to_f).round(3)
    totals["whip"] = ((totals["walk"] + totals["ha"])/totals["ip"].to_f).round(3)
    totals
  end

  def update_proj_totals
    hitter_hash = self.hitter_totals
    hitter_hash.each do |key, value|
      if key == "avg"
        self.proj_avg = value*1000
      else
        self.send("proj_#{key}=", value)
      end
    end
    pitcher_hash = self.pitcher_totals
    pitcher_hash.each do |key, value|
      if ["era", "whip"].include?(key)
        self.send("proj_#{key}=", value*1000)
      else
        self.send("proj_#{key}=", value)
      end
    end
    self.save
  end

  def self.update_proj_rank
    RANKING_STATS.map do |stat|
      rows = Team.send("by_proj_#{stat}").rows
      output = []
      rows.each_index do |i|
        row = rows[i]
        points = i+1
        team = Team.find(row["id"])
        team.send("rank_#{stat}=", points)
        team.save
        # the output is just for visually seeing the rankings
        output[i] = Hash["id", row["id"], "total", row["key"], "points", points]
      end
      [stat, output]
    end
  end

  ###############################################
  # roster finders

  def find_roster_spot(position=nil)
    if position.nil?
      self.roster.find_all { |spot| spot.position != "P" and spot.position != "R" }
    else
      self.roster.find_all { |spot| spot.position == position }
    end
  end

  def hitters
    self.find_roster_spot
  end

  def pitchers
    self.find_roster_spot("P")
  end

  def reserves
    self.find_roster_spot("R")
  end

  ###############################################

  def self.hitter_totals
    ranking = {}
    Hitter.team_view.reduce.group_level(2).rows.each do |row|
      team_id = row["key"][0]
      stat_label = row["key"][1]
      team_total = row["value"]

      if ranking[stat_label].nil?
        ranking[stat_label] = []
      end

      ranking[stat_label] << Hash[team_id, team_total]
    end

    # now sort them
    HITTER_RATING_STATS.each do |stat|
      hashes = ranking[stat]
      ranking[stat] = hashes.sort { |a,b| a.values <=> b.values }
    end

    ranking
  end

  def self.pitcher_totals_for_the_league
    Pitcher.team_view.reduce.group_level(2).rows
  end

  def total_salary
    self.roster.map { |spot| spot.salary }.inject(0, :+)
  end

  def positions_remaining
    MAXSPOTS - self.roster.count
  end

  def max_bid
    (MAXSALARY - self.total_salary) - self.positions_remaining + 1
  end
end