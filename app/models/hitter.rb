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

  def self.build_norms_and_reindex
    avg = {}
    stdev = {}

    HITTER_RATING_STATS.each do |stat|
      avg[stat], stdev[stat] = Hitter.avg_stdev(stat)
    end

    Hitter.database.bulk_save(
      Hitter.all.each do |hitter|
        hitter.proj_adj_hits = hitter.proj_h - (hitter.proj_ab * avg["avg"] / 1000)
      end
    )

    avg["adj_hits"], stdev["adj_hits"] = Hitter.avg_stdev("adj_hits")

    Hitter.database.bulk_save(
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
      end
    )

    # now that all the norm_sums have been calculated, determine the top hitters by value and sum their norms
    total_draftable_value = Hitter.draftable_value
    Hitter.database.bulk_save(
      Hitter.all.each do |hitter|
        hitter.norm_value = hitter.norm_sum * SALARY_AVAIL * 0.65 / total_draftable_value
      end
    )

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

  def self.delete_all
    self.database.bulk_save( self.all.each { |doc| doc['_deleted'] = true } )
  end

end