class Hitter < Player

  HITTER_STATS.each do |stat|
    property "proj_#{stat}".to_sym, Integer
  end

  HITTER_RATING_STATS.each do |stat|
    property "norm_#{stat}".to_sym, Float
  end

  property :proj_adj_hits

  # NL Target
  TARGETS = %w(- 0.273 - - 830 - - - 193 809 - - 127 -)

  def projections
    hash = {}
    HITTER_STATS.each do |stat|
      hash[stat] = self.send("proj_#{stat}".to_sym)
    end
    hash
  end

  ###############################################
  # build_norms
  #
  # This generates the standardized score for the five hitter rating stats

  def self.build_proj_adj_hits(mean_batting_average)
    Hitter.all.each do |hitter|
      hitter.proj_adj_hits = hitter.proj_h - (hitter.proj_ab * mean_batting_average / 1000)
      hitter.save!
    end
  end

  def self.build_norms_and_reindex
    avg = {}
    stdev = {}

    HITTER_RATING_STATS.each do |stat|
      avg[stat] = Hitter.average(stat)
      stdev[stat] = Hitter.stdev(stat)
    end

    Hitter.build_proj_adj_hits(avg["avg"])

    avg["adj_hits"] = Hitter.average("adj_hits")
    stdev["adj_hits"] = Hitter.stdev("adj_hits")

    Hitter.all.each do |hitter|
      HITTER_RATING_STATS.each do |stat|
        if (stat == "avg")
          stat_to_use = "adj_hits"
        else
          stat_to_use = stat
        end

        hitter.send("norm_#{stat}=".to_sym, hitter.rating(stat_to_use, avg[stat_to_use], stdev[stat_to_use]))
      end
      hitter.norm_sum = (hitter.norm_avg + hitter.norm_r + hitter.norm_hr + hitter.norm_rbi + hitter.norm_sb).round(3)
      hitter.save!
    end

    # now that all the norm_sums have been calculated, determine the top hitters by value and sum their norms
    total_draftable_value = Hitter.draftable_value
    Hitter.all.each do |hitter|
      hitter.norm_value = hitter.norm_sum * SALARY_AVAIL * 0.65 / total_draftable_value
      hitter.save!
    end

    Hitter.reindex(batch_size: false)

  end

  ###############################################
  # draftable_value
  #
  # Once all the norm_sums have been assigned, this class method returns the cumulative value of the top hitters

  def self.draftable_value
    if Rails.env == "nl"
      draftable_count = 180 # 15 hitters * 12 teams
    else
      draftable_count = 156 # 13 hitters * 12 teams
    end
    Hitter.all.map { |h| h.norm_sum }.sort { |a,b| b <=> a }.first(draftable_count).inject(0.0, :+)
  end

end