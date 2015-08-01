## ----lib-----------------------------------------------------------------
suppressPackageStartupMessages(suppressWarnings(library(readr)))
suppressPackageStartupMessages(suppressWarnings(library(dplyr)))
suppressPackageStartupMessages(suppressWarnings(library(zoo)))
suppressPackageStartupMessages(suppressWarnings(library(tidyr)))
suppressPackageStartupMessages(suppressWarnings(library(magrittr)))
suppressPackageStartupMessages(suppressWarnings(library(fitdistrplus)))
suppressPackageStartupMessages(suppressWarnings(library(knitr)))
library(forecast)
library(ggplot2)
library(ggthemes)

knitr::opts_chunk$set(cache = FALSE)

## ----csv-----------------------------------------------------------------

hpk_cur <- readr::read_csv(file = "http://hpk.s3-website-us-east-1.amazonaws.com/hpk_2015.csv", na = "-")

hpk_hist <- readr::read_csv(file = "http://hpk.s3-website-us-east-1.amazonaws.com/hpk_historic.csv")

owners <- readr::read_csv(file = "http://hpk.s3-website-us-east-1.amazonaws.com/all_owners.csv")


## ----abbrevs-------------------------------------------------------------

short_names <- data.frame(
  team_key = c(
    '346.l.49099.t.1', '346.l.49099.t.2', '346.l.49099.t.3',
    '346.l.49099.t.4', '346.l.49099.t.5', '346.l.49099.t.6',
    '346.l.49099.t.7', '346.l.49099.t.8', '346.l.49099.t.9',
    '346.l.49099.t.10', '346.l.49099.t.11', '346.l.49099.t.12'
  ),
  owner = c('bench', 'saud', 'eric', 'ptb', 'omar', 'carter',
    'whet', 'alm', 'mintz', 'czap', 'mcard', 'mo'
  ),
  stringsAsFactors = FALSE
)


## ----clean---------------------------------------------------------------

clean_cols <- function(df) {
  df <- as.data.frame(df)

  df[,c(1:6, 8)]
}


clean_rows <- function(df) {
  df <- df[!is.na(df$value), ]
  df <- df[!df$value == "", ]
  return(df)
}


clean_values <- function(df) {
  
  hpk1 <- df %>% dplyr::filter(!stat_id == 60 | is.na(stat_id))
  
  hpk2 <- df %>% dplyr::filter(stat_id == 60) 
  
  avg <- hpk2 %>%
    dplyr::rowwise() %>%
    dplyr::mutate(
      value = eval(parse(text = value))
    )
  
  h  <- hpk2
  ab <- hpk2
  h$value <- matrix(unlist(strsplit(h$value, split = '/')), ncol = 2, byrow = TRUE)[,1]
  ab$value <- matrix(unlist(strsplit(ab$value, split = '/')), ncol = 2, byrow = TRUE)[,2]
  h$stat_id <- NA
  ab$stat_id <- NA
  h$stat_name <- 'H'
  ab$stat_name <- 'AB'
  
  avg$value <- round(avg$value, 5)
    
  cleaned <- rbind(hpk1, h, ab, avg)
  
  cleaned$value <- as.numeric(cleaned$value)
  
  return(cleaned)
}


stat_metadata <- function(df) {
  
  meta_df <- data.frame(
    stat_name = c(
      "OBP", "R", "RBI", "SB", "TB", "AVG", "AB", "H",
      "ERA", "WHIP", "W", "SV", "K", 
      "IP", "Runs Allowed", "WH Allowed"),
    hit_pitch = c(rep("hit", 8), rep("pitch", 8))
  )
  
  df %>% dplyr::left_join(
    meta_df,
    by = 'stat_name'
  )
}

true_era_whip <- function(df) {
  #grab the target rows
  desired_rows <- c('ERA', 'WHIP', 'IP')
  
  target <- df %>% dplyr::filter(
    stat_name %in% desired_rows
  )
  
  #just IP
  ip_df <- target %>% 
    dplyr::filter(stat_name == 'IP') 
  names(ip_df)[names(ip_df) == 'value'] <- "IP"
  
  #convert and clean IP
  #mlb codes 1 out as .1, 2 outs as .2.  replace with 0.333, 0.667
  ip_df$IP <- gsub('.1', '.333', ip_df$IP, fixed = TRUE)
  ip_df$IP <- gsub('.2', '.667', ip_df$IP, fixed = TRUE)
  ip_df$IP <- as.numeric(ip_df$IP)

  #era and whip solo
  era_df <- target %>%
    dplyr::filter(stat_name == 'ERA')
  
  whip_df <- target %>%
    dplyr::filter(stat_name == 'WHIP')
  
  #join to ip
  era_df <- era_df %>% dplyr::inner_join(
    ip_df[, c('team_key', 'date', 'IP')],
    by = c("team_key", "date")
  )
  #weird phantom 0IP / ERA NA
  era_df <- era_df[!is.na(era_df$value), ]
  
  whip_df <- whip_df %>% dplyr::inner_join(
    ip_df[, c('team_key', 'date', 'IP')],
    by = c("team_key", "date")
  )
  whip_df <- whip_df[!is.na(whip_df$value), ]
  
  #recover actual runs allowed and walks hits given up
  era_df$value <- round((as.numeric(era_df$value) / 9) * era_df$IP, 0)
  era_df$stat_name <- 'Runs Allowed'
  era_df$stat_id <- NA
  era_df <- era_df %>% dplyr::select(-IP)
  era_df$date <- as.Date(era_df$date)
  era_df$value <- as.character(era_df$value)

  whip_df$value <- round(as.numeric(whip_df$value) * whip_df$IP, 0)
  whip_df$stat_name <- 'WH Allowed'
  whip_df$stat_id <- NA
  whip_df <- whip_df %>% dplyr::select(-IP)
  whip_df$date <- as.Date(whip_df$date)
  whip_df$value <- as.character(whip_df$value)
  
  dplyr::bind_rows(tbl_df(df), era_df, whip_df)
}


infer_pa <- function(reported_obp, reported_h, reported_ab) {
  if (reported_obp == 0) {
    return(list(0,0))
  }
  pa <- c(1:60)
  combs <- expand.grid(pa, pa)
  names(combs) <- c('ob', 'pa')
  combs$obp <- round(combs$ob / combs$pa, 3)
  
  #PA always bigger than AB, ob > h
  possible <- combs %>% dplyr::filter(
    pa >= quote(reported_ab) &
    ob >= quote(reported_h) &
    obp == quote(reported_obp)
  )
  
  if (nrow(possible) == 0) {
    print('obp pa inference problem :(')
   
    print(paste0('AB:', reported_ab))
    print(paste0('H:', reported_h))
    print(paste0('OBP:', reported_obp))
  }
  possible$pa_diff <- (possible$pa - reported_ab)
  
  #return
  list(
    possible[possible$pa_diff == min(possible$pa_diff), 'ob'][1],
    possible[possible$pa_diff == min(possible$pa_diff), 'pa'][1]
  )
}


clean_obp <- function(df) {
  
  not_obp <- df %>% dplyr::filter(!stat_name == 'OBP')

  #need three things: obp, avg, and ab
  is_obp <- df %>% dplyr::filter(stat_name == 'OBP')
  
  h <- df %>% dplyr::filter(stat_name == 'H')
  h <- h[, c('value', 'team_key', 'date')]
  names(h)[names(h) == 'value'] <- 'H'
  
  ab <- df %>% dplyr::filter(stat_name == 'AB')
  ab <- ab[, c('value', 'team_key', 'date')]
  names(ab)[names(ab) == 'value'] <- 'AB'

  munge <- is_obp %>%
    dplyr::left_join(h, by = c('date', 'team_key')) %>%
    dplyr::left_join(ab, by = c('date', 'team_key'))
  
  munge$OB <- NA
  munge$PA <- NA
  munge <- as.data.frame(munge)
  for (i in 1:nrow(munge)) {
    this_pa <- infer_pa(munge[i, 'value'], munge[i, 'H'], munge[i, 'AB'])
    munge[i, 'OB'] <- this_pa[[1]]
    munge[i, 'PA'] <- this_pa[[2]]
  }
  
  ob <- munge %>%
    dplyr::select(
      stat_id, OB, date, team_key, manager, team_name, stat_name, hit_pitch
    )
  names(ob)[names(ob) == 'OB'] <- 'value'
  ob$stat_name <- 'OB'
  ob$stat_id <- NA
  
  pa <- munge %>%
    dplyr::select(
      stat_id, PA, date, team_key, manager, team_name, stat_name, hit_pitch
    )
  names(pa)[names(pa) == 'PA'] <- 'value'
  pa$stat_name <- 'PA'
  pa$stat_id <- NA

  rbind(ob, pa, not_obp, is_obp)
}



## ----clean_df------------------------------------------------------------

hpk_clean <- hpk_cur %>%
  clean_cols %>%
  clean_rows %>%
  true_era_whip %>%
  clean_values %>%
  stat_metadata %>%
  clean_obp %>%
  clean_rows %>%
  tbl_df()

year_min <- hpk_clean %>%
  dplyr::mutate(
    year = as.numeric(format(as.Date(date), "%Y"))
  ) %>%
  dplyr::group_by(year) %>%
  dplyr::summarize(
    start_date = min(date),
    end_date = max(date)
  ) 

hpk_clean <- hpk_clean %>%
  dplyr::mutate(
    year = as.numeric(format(as.Date(date), "%Y"))
  ) %>%
  dplyr::left_join(
    year_min
  ) %>%
  dplyr::mutate(day_of_season = date - start_date) %>%
  dplyr::mutate(days_till_end = end_date - date) %>%
  dplyr::select(
    -year
  )


## ----helper_function-----------------------------------------------------

nbinom_wrapper <- function(x, stat, est = 1) {
  if (unique(stat) %in% c('R', 'RBI', 'SB', 'TB', 'OB', 'PA', 'W', 
                  'SV', 'K', 'Runs Allowed', 'WH Allowed', 'H', 'AB')
  ) {
    out <- fitdist(
      data = x,
      distr = 'nbinom',
      method = "mme"
    )
    out <- out$estimate[est] %>% unname() %>% as.numeric()
  } else {
    out <- -1
  }
  out
}

make_rolling <- function(df, n = c(2:60)) {
  
  df <- df %>%
    dplyr::group_by(stat_id, team_key, stat_name) %>%
    dplyr::arrange(team_key, stat_name, date)
  
  for (i in n) {
    print(i)
    df <- df %>%
      dplyr::mutate(
        foo_mean = rollmeanr(x = value, k = quote(i), na.pad = TRUE) %>% round(3),
        foo_sd = rollapply(
          data = value, width = quote(i), align = 'right', fill = NA, FUN = sd
        ) %>% round(3)
#         foo_nbinom_size = rollapply(
#           data = value, width = quote(i), align = 'right', fill = NA, 
#           FUN = nbinom_wrapper, stat = stat_name, est = 1
#         ),
#         foo_nbinom_mu = rollapply(
#           data = value, width = quote(i), align = 'right', fill = NA, 
#           FUN = nbinom_wrapper, stat = stat_name, est = 2
#         )        
      )
    names(df)[names(df) == 'foo_mean'] <- paste0('mean_', i)
    names(df)[names(df) == 'foo_sd'] <- paste0('sd_', i)
#     names(df)[names(df) == 'foo_nbinom_size'] <- paste0('nbinom_size_', i)
#     names(df)[names(df) == 'foo_nbinom_mu'] <- paste0('nbinom_mu_', i)  
  }
  
  return(df)
}


#foo <- make_rolling(hpk_clean, n=c(21, 28)) %>% tbl_df
#foo[foo$stat_name == 'R' & foo$day_of_season > 80, ] %>% head() %>% as.data.frame()


## ----cur_roll------------------------------------------------------------

#hpk_clean <- make_rolling(hpk_clean)
hpk_clean <- make_rolling(hpk_clean, n = c(7, 14, 21, 28))


## ----yest_data-----------------------------------------------------------

season_days <- hpk_clean$date %>% unique() %>% sort()

n_days <- season_days %>% length()
n_left <- (as.Date("2015-10-04") - Sys.Date()) %>% as.numeric

#get the last day of stats
yesterday <- season_days[n_days]

#make a bunch of time windows - prev week, 2 weeks, etc
hpk_yest <- hpk_clean %>% dplyr::filter(
  date == yesterday
) 

hpk_week <- hpk_clean %>% dplyr::filter(
  date <= yesterday & date >= season_days[n_days-6] 
)

hpk_2week <- hpk_clean %>% dplyr::filter(
  date <= yesterday & date >= yesterday - 13
)

hpk_3week <- hpk_clean %>% dplyr::filter(
  date <= yesterday & date >= yesterday - 20
)

hpk_4week <- hpk_clean %>% dplyr::filter(
  date <= yesterday & date >= yesterday - 26
)

hpk_month <- hpk_clean %>% dplyr::filter(
  date <= yesterday & date >= yesterday - 29
)

## ----standings-----------------------------------------------------------

h_points <- function(df) {
  h_total <- df %>% 
    dplyr::filter(
      stat_name %in% c('R', 'RBI', 'SB', 'TB', 'OB', 'PA')
    ) %>% 
    dplyr::group_by(
      team_key, stat_name
    ) %>% 
    dplyr::summarize(
      total_value = sum(value),
      n = n()
    )
  
  #h conversion here
  h_total <- convert_h_stats(h_total)

  h_points <- h_total %>% 
    dplyr::group_by(stat_name) %>%
    dplyr::mutate(
      rank = rank(total_value)
    ) 

  h_points
}


p_points <- function(df) {
  p_total <- df %>% 
    dplyr::filter(
      stat_name %in% c('W', 'SV', 'K', 'Runs Allowed', 'WH Allowed', 'IP')
    ) %>% 
    dplyr::group_by(
      team_key, stat_name
    ) %>% 
    dplyr::summarize(
      total_value = sum(value),
      n = n()
    )
  
  #p conversion here
  p_total <- convert_p_stats(p_total)
  
  #some are bad
  p_total$total_value <- ifelse(
    p_total$stat_name %in% c('ERA', 'WHIP'), p_total$total_value * -1,
    p_total$total_value
  )
  
  p_points <- p_total %>% 
    dplyr::group_by(stat_name) %>%
    dplyr::mutate(
      rank = rank(total_value)
    ) 

  p_points
}


p_totals <- function(df) {
  p_points(df) %>%
    dplyr::group_by(team_key) %>%
    dplyr::summarize(
      P = sum(rank)
    )
}


convert_p_stats <- function(df) {
  #non rate vs rate
  non_rate <- df %>%
    dplyr::filter(
      stat_name %in% c('W', 'SV', 'K')
    )
  rate <- df %>%
    dplyr::filter(
      stat_name %in% c('Runs Allowed', 'WH Allowed')
    )
  
  ip <- df %>%
    dplyr::filter(stat_name == 'IP')
  
  names(ip)[names(ip)=='total_value'] <- 'IP'
  
  #join rate to ip
  rate <- rate %>%
    dplyr::left_join(
      ip[, c('team_key', 'IP')],
      by = 'team_key'
    )
  
  rate$total_value <- rate$total_value / rate$IP
  #ERA on 9 inning scale
  rate$total_value <- ifelse(
    rate$stat_name == 'Runs Allowed', rate$total_value * 9, rate$total_value
  )
  rate$stat_name <- ifelse(
    rate$stat_name == 'Runs Allowed', 'ERA', 'WHIP'
  )
  
  dplyr::bind_rows(rate, non_rate)
}


convert_h_stats <- function(df) {
  #non rate vs rate
  non_rate <- df %>%
    dplyr::filter(
      stat_name %in% c('R', 'RBI', 'SB', 'TB')
    )
  rate <- df %>%
    dplyr::filter(
      stat_name %in% c('OB')
    )
  
  pa <- df %>%
    dplyr::filter(stat_name == 'PA')
  
  names(pa)[names(pa) == 'total_value'] <- 'PA'
  
  #join rate to pa
  rate <- rate %>%
    dplyr::left_join(
      pa[, c('team_key', 'PA')],
      by = 'team_key'
    )
  
  rate$total_value <- rate$total_value / rate$PA
  rate$stat_name <- 'OBP'
  
  dplyr::bind_rows(rate, non_rate)
}


h_totals <- function(df) {
  h_points(df) %>%
    dplyr::group_by(team_key, n) %>%
    dplyr::summarize(
      H = sum(rank)
    )
}


h_table_rank <- function(df) {
  
  df_detail <- h_points(df)
  df_points_wide <- tidyr::spread(df_detail[, c('team_key', 'stat_name', 'rank')], stat_name, rank)
  
  df_total <- h_totals(df)
  
  df_points_wide %>%
    dplyr::left_join(df_total, by = c('team_key')) %>%
    dplyr::arrange(-H)  %>%
    dplyr::left_join(
      owners[ ,c('team_key', 'manager', 'name')],
      by = 'team_key'
    ) %>%
    dplyr::select(
      manager, team_key, R, RBI, SB, TB, OBP, H
    )
}


h_table_stats <- function(df) {
  
  df_detail <- h_points(df)
  df_stats_wide <- tidyr::spread(df_detail[, c(1:4)], stat_name, total_value)
  df_stats_wide$OBP <- round(df_stats_wide$OBP, 3)
  
  df_total <- h_totals(df)
  
  df_stats_wide %>%
    dplyr::left_join(df_total) %>%
    dplyr::arrange(-H)  %>%
    dplyr::left_join(
      owners[ ,c('team_key', 'manager', 'name')],
      by = 'team_key'
    ) %>%
    dplyr::select(
      manager, team_key, R, RBI, SB, TB, OBP, H
    )
}


p_table_rank <- function(df) {
  
  df_detail <- p_points(df)
  df_points_wide <- tidyr::spread(df_detail[, c(1:2, 6)], stat_name, rank)
  
  df_total <- p_totals(df)
  
  df_points_wide %>%
    dplyr::left_join(df_total, by = "team_key") %>%
    dplyr::arrange(-P)  %>%
    dplyr::left_join(
      owners[ ,c('team_key', 'manager', 'name')],
      by = 'team_key'
    ) %>%
    dplyr::select(
      manager, team_key, W, SV, K, ERA, WHIP, P
    )
}


p_table_stats <- function(df) {
  
  df_detail <- p_points(df)
  df_stats_wide <- tidyr::spread(df_detail[, c(1:3)], stat_name, total_value)

  df_total <- p_totals(df)
  
  df_stats_wide <- df_stats_wide %>%
    dplyr::left_join(df_total) %>%
    dplyr::arrange(-P)  %>%
    dplyr::left_join(
      owners[ ,c('team_key', 'manager', 'name')],
      by = 'team_key'
    ) %>%
    dplyr::select(
      manager, team_key, W, SV, K, ERA, WHIP, P
    )
  
  df_stats_wide$ERA <- round(df_stats_wide$ERA * -1, 2)
  df_stats_wide$WHIP <- round(df_stats_wide$WHIP * -1, 3)
  
  df_stats_wide
}

all_table_stats <- function(df) {
  result <- h_table_stats(df) %>% 
    dplyr::left_join(
      p_table_stats(df)
    ) %>%
    dplyr::left_join(short_names) %>%
    dplyr::mutate(
      points = H + P,
      rank = rank(-points)
    ) %>%
    dplyr::arrange(
      rank
    ) %>%
    dplyr::select(-team_key, -manager) %>%
    dplyr::select(
      owner, R, RBI, SB, TB, OBP, H, W, SV, K, ERA, WHIP, P, points, rank
    )

  
  result
}


all_table_rank <- function(df) {
  result <- h_table_rank(df) %>% 
    dplyr::left_join(
      p_table_rank(df),
      by = c("manager", "team_key")
    ) %>%
    dplyr::left_join(short_names, by = 'team_key') %>%
    dplyr::mutate(
      points = H + P,
      rank = rank(-points, ties.method = 'min')
    ) %>%
    dplyr::arrange(
      rank
    ) %>%
    dplyr::select(-team_key, -manager) %>%
    dplyr::select(
      owner, R, RBI, SB, TB, OBP, H, W, SV, K, ERA, WHIP, P, points, rank
    )
  
  result
}


best_h <- function(df) {
  stats <- h_table_stats(df)
  ranks <- h_table_rank(df)
  
  result <- stats %>%
    dplyr::left_join(
      ranks,
      by = c('manager', 'team_key')
    ) %>%
    dplyr::left_join(short_names)

  
  names(result) <- gsub('.x', '', names(result), fixed = TRUE)
  names(result) <- gsub('.y', '.', names(result), fixed = TRUE)
  
  result %>%
    dplyr::arrange(
      -H
    ) %>%
    dplyr::select_(
      'owner', 'R', 'RBI', 'SB', 'TB', 'OBP', 'R.', 'RBI.', 'SB.', 'TB.', 'OBP.', 'H'
    )
}


best_p <- function(df) {
  stats <- p_table_stats(df)
  ranks <- p_table_rank(df)
  
  result <- stats %>%
    dplyr::left_join(
      ranks,
      by = c('manager', 'team_key')
    ) %>%
    dplyr::left_join(short_names)

  
  names(result) <- gsub('.x', '', names(result), fixed = TRUE)
  names(result) <- gsub('.y', '.', names(result), fixed = TRUE)
  
  result %>%
    dplyr::arrange(
      -P
    ) %>%
    dplyr::select_(
      'owner', 'W', 'SV', 'K', 'ERA', 'WHIP', 'W.', 'SV.', 'K.', 'ERA.', 'WHIP.', 'P'
    )
}


## ----hit1----------------------------------------------------------------


forecast_data <- data.frame(
  clean_day_of_season = numeric(0),
  point_est = numeric(0),
  lower_80 = numeric(0),
  upper_80 = numeric(0),
  lower_95 = numeric(0),
  upper_95 = numeric(0),
  type = character(0),
  stat_name = character(0),
  team_key = character(0),
  stringsAsFactors = FALSE
)

sim_data <- data.frame(
  stat_value = numeric(0),
  stat_name = character(0),
  team_key = character(0),
  sim_number = integer(0),
  stringsAsFactors = FALSE
)

n_sim <- 10000

  
for (i in c('R', 'RBI', 'SB', 'TB')) {
  print(i)
  clean_asb <- hpk_clean[hpk_clean$stat_name == 'AB' & hpk_clean$value > 0, 'day_of_season'] %>% unique()
  clean_asb$clean_day_of_season <- rank(clean_asb$day_of_season %>% as.numeric())
    
  this_stat <- hpk_clean %>% dplyr::filter(stat_name == i)  %>%
    dplyr::left_join(short_names) %>%
    dplyr::left_join(clean_asb, by = 'day_of_season')
  
  this_stat <- this_stat %>%
    dplyr::group_by(team_key) %>%
    dplyr::arrange(stat_name, team_key, date) %>%
    dplyr::mutate(
      running_total = cumsum(value)
    )
  
  this_stat <- this_stat %>%
    dplyr::group_by(date, stat_name) %>%
    dplyr::mutate(
      leader = max(running_total),
      diff_from_leader = leader - running_total
    )
  
  unq_teams <- this_stat$team_key %>% unique()
  
  for (j in unq_teams) {
    print(j)
    this_team <- this_stat[this_stat$team_key == j, ]
    
    #stat_bats <- forecast::tbats(y = this_team$running_total)
    #stat_bats_forecast <- forecast(stat_bats, h = n_left)
    
    stat_ets <- forecast::ets(y = this_team$running_total)
    stat_ets_forecast <- forecast::forecast(stat_ets, h = n_left + 1)
    
    #record the forecast path
    this_observed <- data.frame(
      clean_day_of_season = this_team$clean_day_of_season,
      point_est = this_team$running_total,
      lower_80 = NA,
      upper_80 = NA,
      lower_95 = NA,
      upper_95 = NA,
      type = 'observed',
      stat_name = i,
      team_key = j,
      stringsAsFactors = FALSE
    )
    
    this_forecast <- data.frame(
      clean_day_of_season = seq(n_days, n_days + length(stat_ets_forecast$mean) - 1, 1),
      point_est = stat_ets_forecast$mean %>% as.numeric(),
      lower_80 = stat_ets_forecast$lower[, 1] %>% as.numeric(),
      upper_80 = stat_ets_forecast$upper[, 1] %>% as.numeric(),
      lower_95 = stat_ets_forecast$lower[, 2] %>% as.numeric(),
      upper_95 = stat_ets_forecast$upper[, 2] %>% as.numeric(),
      type = 'forecast',
      stringsAsFactors = FALSE
    )
    this_forecast$stat_name <- i
    this_forecast$team_key <- j
    
    forecast_data <- rbind(forecast_data, this_observed, this_forecast)
    
    #now simulate
    this_sim <- replicate(n_sim, {simulate(stat_ets, nsim = n_left + 1)[n_left + 1]})

    this_sim_df <- data.frame(
      stat_value = this_sim,
      stat_name = i,
      team_key = j,
      sim_number = c(1:n_sim),
      stringsAsFactors = FALSE
    )
    sim_data <- rbind(sim_data, this_sim_df)
    
  }
}
  
#owner names
forecast_data <- forecast_data %>% dplyr::left_join(short_names)
sim_data <- sim_data %>% dplyr::left_join(short_names)

#behind leader
forecast_data <- forecast_data %>%
  dplyr::group_by(
    stat_name, clean_day_of_season
  ) %>%
  dplyr::mutate(
    leader = max(point_est)
  ) %>%
  dplyr::mutate(
    point_trailing = leader - point_est,
    lower_95_trailing = leader - lower_95,
    upper_95_trailing = leader - upper_95
  ) %>%
  tbl_df()

#position
sim_data <- sim_data %>%
  group_by(stat_name, sim_number) %>%
  dplyr::mutate(
    final_points = rank(stat_value, ties.method = 'min')
  )

stat_labels <- forecast_data %>%
  dplyr::group_by(stat_name) %>%
  dplyr::filter(
    clean_day_of_season == n_days + n_left
  ) %>%
  dplyr::mutate(
    disp_label = paste0(round(lower_95,0), '-', round(upper_95, 0)),
    upper_y = max(lower_95_trailing, na.rm = TRUE),
    y_pos = 0.4 * upper_y,
    font_size = ifelse(stat_name == 'TB', 14, 19)
  ) 



#charts
h1_proj <- list()

for (k in c('R', 'RBI', 'SB', 'TB')) {
  this_stat <- k

  #plots
  p <- ggplot(
    data = forecast_data[forecast_data$stat_name == this_stat, ],
    aes(x = clean_day_of_season, color = type)
    ) +
  geom_text(
    data = stat_labels[stat_labels$stat_name == this_stat, ],
    aes(
      x = 89,
      y = y_pos,
      label = disp_label,
      size = font_size
    ),
    inherit.aes = FALSE,
    alpha = 0.325,
    fontface = 'bold'
  ) +
  geom_line(
    aes(y = point_trailing),
    size = 1.5
  ) +
  geom_line(
    aes(y = lower_95_trailing),
    color = '#F15A60',
    size = 0.5,
    lty = 'dashed'
  ) +
  geom_line(
    aes(y = upper_95_trailing),
    color = '#F15A60',
    size = 0.5,
    lty = 'dashed'
  ) +  
  theme_bw() +
  theme(
    legend.position = "none",
    panel.grid.major.x = element_blank(),
    strip.text.x = element_text(size = 12)
  ) +
  facet_wrap(~owner) +
  labs(
    x = 'day of season (no ASB)',
    y = 'amount behind leader',
    title = paste0(this_stat, ' | projections')
  ) +
  scale_color_few() +
  scale_size_identity()
    
  h1_proj[[k]] <- p

}


h2_proj <- list()

for (l in c('R', 'RBI', 'SB', 'TB')) {
  print(l)
  this_stat <- l

  pct_outcomes <- sim_data[sim_data$stat_name == this_stat, ] %>%
    dplyr::group_by(owner, final_points) %>%
    dplyr::summarize(
      pct = sum(n()) / quote(n_sim),
      ypos = quote(n_sim) * 0.03
    )
  
  #plots
  p <- ggplot(
    data = sim_data[sim_data$stat_name == this_stat, ],
    aes(x = final_points)
    ) +
  geom_histogram(color = 'white', binwidth = 1) + 
  geom_text(
    data = pct_outcomes, 
    aes(x = final_points + 0.5, y = ypos, label = round(pct * 100, 0)),
    color = 'hotpink',
    size = 6,
    angle = 90
  ) +
  facet_wrap(~owner, scales = 'free_x') + 
  theme_bw() +
  theme(
    legend.position = "none",
    panel.grid.major.x = element_blank(),
    strip.text.x = element_text(size = 12),
    axis.text.x = element_text(size = 9),
    axis.ticks.x = element_blank()
  ) +
  scale_x_continuous(
    breaks = c(1.5:12.5),
    labels = c(1:12),
    limits = c(0,13)
  )
  
  h2_proj[[l]] <- p
}
h2_proj[['R']]


## ----print_h1, eval=FALSE------------------------------------------------
## library(Cairo)
## 
## expander <- 1.3
## Cairo(
##   width = 11 * expander, height = 8.5 * expander,
##   file = 'h_proj.pdf', type = "pdf",
##   bg = "transparent",
##   canvas = "white", units = "in"
## )
##   print(h1_proj)
## dev.off()

## ----h1_scratch, eval=FALSE----------------------------------------------
## 
##   ggplot(
##     data = this_stat,
##     aes(
##       x = day_of_season,
##       y = diff_from_leader
##     )
##   ) +
##   geom_line() +
## 
##   ggplot() +
##   geom_abline(
##     data = bb_data,
##     aes(
##       intercept = intercept,
##       slope = slope
##     )
##   ) +
##   theme_bw() +
##   facet_wrap(~team_key)
## 
## 
##   p <- ggplot(mtcars, aes(x = wt, y=mpg), . ~ cyl) + geom_point()
## df <- data.frame(a=rnorm(10, 25), b=rnorm(10, 0))
## p + geom_abline(aes(intercept=intercept, slope=slope), data=bb_data)
## 
## 
## 
##   ggplot(
##     data = this_stat,
##     aes(
##       x = day_of_season,
##       y = diff_from_leader
##     )
##   ) +
##   geom_line() +
##   stat_smooth() +
##   theme_bw() +
##   facet_wrap(~ owner)
## 
## 

## ----place_count---------------------------------------------------------
ranks_df <- data.frame(
  owner = character(0),
  date = (x = structure(rep(NA_real_, 0 ), class = "Date")),
  rank = integer(0),
  stringsAsFactors = FALSE
)

for (i in hpk_clean$date %>% unique() %>% sort()) {
  print(i %>% as.Date())
  through_today <- hpk_clean %>% dplyr::filter(date <= i)
  today_ranks <- all_table_rank(through_today)
  
  ranks_df <- rbind(
    ranks_df, data.frame(
      owner = today_ranks$owner, date = i, rank = today_ranks$rank)
  )
}

rank_counts <- ranks_df %>%
  dplyr::group_by(owner, rank) %>%
  dplyr::summarize(
    n = n()
  )

rank_avg <- ranks_df %>%
  dplyr::group_by(owner) %>%
  dplyr::summarize(
    avg_pos = round(mean(rank), 1)
  ) %>%
  dplyr::arrange(
    avg_pos
  )

rank_wide <- tidyr::spread(rank_counts, rank, n, fill = '')

