class Player < CouchRest::Model::Base
  include Sunspot::Rails::Searchable

  property :name,       String
  property :team,       String
  property :pos,        String
  property :other_pos,  String
  property :league,     String
  property :norm_sum,   Float
  property :norm_value, Float

  belongs_to :fantasy_team, class_name: "Team"

  timestamps!

  searchable do
    text :name, :team, :pos
  end

  def self.query(string)
    Player.search { fulltext "#{string}" }.results
  end

  def eligible_pos_array
    if self.other_pos.nil?
      other_pos_split = []
    else
      other_pos_split = self.other_pos.split(',').map(&:strip)
    end
    [self.pos] + other_pos_split
  end

  def eligible_pos
    self.eligible_pos_array.join(', ')
  end

  def eligible_pos=(pos_string)
    array = pos_string.split(',').map(&:strip)
    self.update_attributes(pos: array[0], other_pos: array[1..-1].join(', '))
  end

  def eligible_pos_options
    pos_hash = {
      "1B" => ["1B", "CO", "UT"],
      "2B" => ["2B", "MI", "UT"],
      "SS" => ["SS", "MI", "UT"],
      "3B" => ["3B", "CO", "UT"],
      "C"  => ["C",  "UT"],
      "LF" => ["OF", "UT"],
      "CF" => ["OF", "UT"],
      "RF" => ["OF", "UT"],
      "OF" => ["OF", "UT"],
      "UT" => ["UT"],
      "DH" => ["UT"],
      "SP" => ["P"],
      "RP" => ["P"]
    }
    pos_array = self.eligible_pos_array.map { |pos| pos_hash[pos] || ["XX"]}.flatten.uniq + ["R"]
    pos_array.map { |pos| [pos, pos] }
  end

  def roster_spot
    if self.fantasy_team.nil?
      nil
    else
      self.fantasy_team.roster.find { |rs| rs.player_id = self.id }
    end
  end

  def rating(property, mean, stdev)
    value = self.send("proj_#{property}".to_sym).to_f
    ((value - mean.to_f)/stdev.to_f).round(3)
  end

  def self.inherited(subclass)
    super

    subclass.class_eval do

      ###########################################
      # statistics

      def self.proj_view(property, pos=nil)
        view = self.send("by_proj_#{property}".to_sym)
        if pos.nil?
          view
        else
          view.startkey(["#{pos}"]).endkey(["#{pos}",{}])
        end
      end

      def self.values(property, pos=nil)
        self.proj_view(property, pos).values
      end

      def self.average(property, pos=nil)
        self.proj_view(property, pos).reduce.values[0]['mean']
      end

      def self.stdev(property, pos=nil)
        self.proj_view(property, pos).reduce.values[0]['stdev']
      end

      def self.team_view(team=nil)
        view = self.send("by_team_and_stat".to_sym)
        if team.nil?
          view
        else
          view.startkey(["#{team.id}"]).endkey(["#{team.id}",{}])
        end
      end

      ###########################################
      # views

      design do

          superclass_stats = %w(name team league pos norm_sum)
          subclass_stats = []
          subclass_norms = []
          if subclass.to_s == "Hitter"
            hitter_stats   = HITTER_STATS + ["adj_hits"]
            subclass_stats = hitter_stats.map { |stat| "proj_#{stat}" }
            subclass_norms = HITTER_RATING_STATS.map { |stat| "norm_#{stat}" }
            subclass_array = (HITTER_RATING_STATS + ["h", "ab"]).map { |stat| "'#{stat}'"}.join(', ')
          elsif subclass.to_s == "Pitcher"
            pitcher_stats  = PITCHER_STATS + ["adj_ers", "adj_whs"]
            subclass_stats = pitcher_stats.map { |stat| "proj_#{stat}" }
            subclass_norms = PITCHER_RATING_STATS.map { |stat| "norm_#{stat}" }
            subclass_array = (PITCHER_RATING_STATS + ["er", "walk", "ha", "ip"]).map { |stat| "'#{stat}'"}.join(', ')
          end

          all_stats = superclass_stats + subclass_stats + subclass_norms

          all_stats.each do |stat|
            view "by_#{stat}".to_sym,
              map: "
                function(doc) {
                  if ((doc['type'] == '#{subclass.to_s}') && (doc['#{stat}'] != null)) {
                    strings = ['name', 'team', 'pos', 'league'];
                    if (strings.indexOf('#{stat}') == -1) {
                      value = doc['#{stat}'];
                    } else {
                      value = 1;
                    }
                    emit([doc['pos'], doc['#{stat}']], value);
                  }
                }
              ",
              reduce: "
                function(key, values, rereduce) {
                  if (!rereduce){
                    var count = values.length
                    var mean = sum(values)/count
                    var sumsq = sum(
                                values.map(function(v) {
                                  return v*v
                                })
                               )/count
                    var stdev = Math.sqrt(sumsq-Math.pow(mean,2));

                    return {'mean': mean, 'stdev' : stdev, 'sumsq': sumsq, 'count': count }
                  } else {
                    var count = sum(
                                values.map(function(v){
                                  return v.count
                                 })
                              )
                    var mean = sum(
                                values.map(function(v){
                                  return v.mean * (v.count / count)
                                })
                              )
                    var sumsq = sum(
                                values.map(function(v){
                                  return v.sumsq * (v.count / count)
                                })
                              )
                    var stdev = Math.sqrt(sumsq-Math.pow(mean,2));

                    return {'mean': mean, 'stdev': stdev, 'sumsq': sumsq, 'count': count}
                  }
                }
              "

            view "avail_by_pos_and_#{stat}".to_sym,
              map: "
                function(doc) {
                  if ((doc['type'] == '#{subclass.to_s}') && (doc['#{stat}'] != null) && (doc['fantasy_team_id'] == null)) {
                    if (doc['other_pos'] != '') {
		                  tokens = (doc['pos'] + ', ' + doc['other_pos']).split(/, /);
                    } else {
                      tokens = [doc['pos']];
                    }
                    strings = ['name', 'team', 'pos', 'league'];
                    tokens.map(function(token) {
                      if (strings.indexOf('#{stat}') == -1) {
                        value = doc['#{stat}'];
                      } else {
                        value = tokens.length;
                      }
                      emit([token, doc['#{stat}']], value);
                    });
                  }
                }
              "

            view "avail_by_#{stat}".to_sym,
              map: "
                function(doc) {
                  if ((doc['type'] == '#{subclass.to_s}') && (doc['#{stat}'] != null) && (doc['fantasy_team_id'] == null)) {
                    emit(doc['#{stat}'], 1);
                  }
                }
              "
          end

          view :by_team_and_stat,
            map: "
              function(doc) {
                if ((doc['type'] == '#{subclass.to_s}') && (doc['fantasy_team_id'] != null)) {
                  strings = [#{subclass_array}]
                  for (i in strings) {
                    string = strings[i]
                    emit([doc['fantasy_team_id'], string], doc['proj_' + string]);
                  }
                }
              }
            ",
            reduce: "
              function(key, values, rereduce) {
                return sum(values);
              }
            "


      end

    end
  end

end

