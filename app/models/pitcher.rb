class Pitcher < Player

  PITCHER_STATS.each do |stat|
    property "proj_#{stat}".to_sym, Integer
  end

  PITCHER_RATING_STATS.each do |stat|
    property "norm_#{stat}".to_sym, Float
  end

  property :proj_adj_ers
  property :proj_adj_whs

  TARGETS = %w(- - - 82 - 60 3.59 1059 1.265 - - - - -)

  def projections
    hash = {}
    PITCHER_STATS.each do |stat|
      hash[stat] = self.send("proj_#{stat}".to_sym)
    end
    hash
  end

  ###############################################
  # build_norms
  #
  # This generates the standardized score for the five pitcher rating stats

  def self.build_proj_adj_ers(mean_earned_run_average)
    Pitcher.all.each do |pitcher|
      pitcher.proj_adj_ers = -1*(pitcher.proj_er - (pitcher.proj_ip * mean_earned_run_average / 900))
      pitcher.save!
    end
  end

  def self.build_proj_adj_whs(mean_whip)
    Pitcher.all.each do |pitcher|
      pitcher.proj_adj_whs = -1*(pitcher.proj_walk + pitcher.proj_ha - (pitcher.proj_ip * mean_whip / 100))
      pitcher.save!
    end
  end

  def self.build_norms_and_reindex
    avg = {}
    stdev = {}

    PITCHER_RATING_STATS.each do |stat|
      avg[stat] = Pitcher.average(stat)
      stdev[stat] = Pitcher.stdev(stat)
    end

    Pitcher.build_proj_adj_ers(avg["era"])
    Pitcher.build_proj_adj_whs(avg["whip"])

    avg["adj_ers"] = Pitcher.average("adj_ers")
    avg["adj_whs"] = Pitcher.average("adj_whs")
    stdev["adj_ers"] = Pitcher.stdev("adj_ers")
    stdev["adj_whs"] = Pitcher.stdev("adj_whs")

    Pitcher.all.each do |pitcher|
      PITCHER_RATING_STATS.each do |stat|
        if (stat == "era")
          stat_to_use = "adj_ers"
        elsif (stat == "whip")
          stat_to_use = "adj_whs"
        else
          stat_to_use = stat
        end

        pitcher.send("norm_#{stat}=".to_sym, pitcher.rating(stat_to_use, avg[stat_to_use], stdev[stat_to_use]))
      end
      pitcher.norm_sum = (pitcher.norm_w + pitcher.norm_sv + pitcher.norm_era + pitcher.norm_k + pitcher.norm_whip).round(3)
      pitcher.save!
    end

    # now that all the norm_sums have been calculated, determine the top hitters by value and sum their norms
    total_draftable_value = Pitcher.draftable_value
    Pitcher.all.each do |pitcher|
      pitcher.norm_value = pitcher.norm_sum * SALARY_AVAIL * 0.35 / total_draftable_value
      pitcher.save!
    end

    Pitcher.reindex(batch_size: false)

  end

  ###############################################
  # draftable_value
  #
  # Once all the norm_sums have been assigned, this class method returns the cumulative value of the top hitters

  def self.draftable_value
    if Rails.env == "nl"
      draftable_count = 120 # 10 pitchers * 12 teams
    else
      draftable_count = 108 # 9 pitchers * 12 teams
    end
    Pitcher.all.map { |h| h.norm_sum }.sort { |a,b| b <=> a }.first(draftable_count).inject(0.0, :+)
  end

end