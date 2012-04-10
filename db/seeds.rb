Hitter.all.each(&:destroy)

hitter_file = File.open("db/batters.csv", "r")
hitter_csv = hitter_file.read
hitter_file.close

hitter_contents = hitter_csv.split("\n")
hitter_keys = hitter_contents.shift.split(',')
hitter_contents.each do |hitter_line|
  hitter = Hash[hitter_keys.zip(hitter_line.split(','))]

  if (Rails.env == "#{hitter["LG"]}l" and hitter[" AB"].to_i != 0)
    if ["LF","CF","RF"].include?(hitter["Position"])
      hitter_position = "OF"
    else
      hitter_position = hitter["Position"]
    end
    Hitter.create(
      name:           hitter["Name"],
      team:           hitter["Team"],
      league:         hitter["LG"],
      pos:            hitter_position,
      other_pos:      "",
      proj_avg:       (hitter[" AVG"].to_f*1000).to_i,
      proj_obp:       (hitter[" OBP"].to_f*1000).to_i,
      proj_slg:       (hitter[" SLG"].to_f*1000).to_i,
      proj_ab:        hitter[" AB"].to_i,
      proj_r:         hitter["R"].to_i,
      proj_h:         hitter[" H"].to_i,
      proj_2b:        hitter[" 2B"].to_i,
      proj_3b:        hitter[" 3B"].to_i,
      proj_hr:        hitter[" HR"].to_i,
      proj_rbi:       hitter["RBI"].to_i,
      proj_bb:        hitter[" BB"].to_i,
      proj_so:        hitter[" K"].to_i,
      proj_sb:        hitter["SB"].to_i,
      proj_cs:        hitter["CS"].to_i
    )
  end
end

Hitter.build_norms_and_reindex

Pitcher.all.each(&:destroy)

pitcher_file = File.open("db/pitchers.csv","r")
pitcher_csv = pitcher_file.read
pitcher_file.close

pitcher_contents = pitcher_csv.split("\n")
pitcher_keys = pitcher_contents.shift.split(',')
pitcher_contents.each do |pitcher_line|
  pitcher = Hash[pitcher_keys.zip(pitcher_line.split(','))]

  if (Rails.env == "#{pitcher["LG"]}l" and pitcher["IP"].to_i != 0)
    Pitcher.create(
      name:           pitcher["Name"],
      team:           pitcher["Team"],
      league:         pitcher["LG"],
      pos:            "#{pitcher['Role']}P",
      other_pos:      "",
      proj_g:         pitcher["G"].to_i,
      proj_gs:        pitcher["GS"].to_i,
      proj_ip:        pitcher["IP"].to_i,
      proj_w:         pitcher["W"].to_i,
      proj_l:         pitcher["L"].to_i,
      proj_sv:        pitcher["Sv"].to_i,
      proj_era:       (pitcher["ERA"].to_f*100).to_i,
      proj_k:         pitcher["K"].to_i,
      proj_whip:      (pitcher["WHIP"].to_f*100).to_i,
      proj_walk:      pitcher["BB"].to_i,
      proj_ha:        pitcher["H"],
      proj_er:        pitcher["ER"].to_i,
      proj_k9:        (pitcher["K/9"].to_f*100).to_i,
      proj_bb9:       (pitcher["BB/9"].to_f*100).to_i
    )
  end
end

Pitcher.build_norms_and_reindex