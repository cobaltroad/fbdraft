fbdraft_config = File.read(Rails.root.join('config','fbdraft.yml'))
hash = YAML.load(fbdraft_config)

HITTER_STATS = hash["hitter"].map(&:keys).flatten
HITTER_LABELS = hash["hitter"].map(&:values).flatten

PITCHER_STATS = hash["pitcher"].map(&:keys).flatten
PITCHER_LABELS = hash["pitcher"].map(&:values).flatten

HITTER_RATING_STATS = hash["hitter_rating"]
PITCHER_RATING_STATS = hash["pitcher_rating"]

HITTER_RATIO_STATS = hash["hitter_ratio"]
PITCHER_RATIO_STATS = hash["pitcher_ratio"]

SALARY_CAP = hash["salary_cap"][Rails.env]

# assume 12 teams available.  This measures the total salary availability

SALARY_AVAIL = (hash["salary_cap"][Rails.env] - hash["roster_size"][Rails.env])*12

LEAGUE_NAME = hash["league_name"][Rails.env]