## ----lib-----------------------------------------------------------------
library(readr)
library(dplyr)
library(zoo)
library(ggplot2)
library(tidyr)

knitr::opts_chunk$set(cache = TRUE)

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
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  return(df[, c(-6)])
}


clean_rows <- function(df) {
  df <- df[!is.na(df$value), ]
  df <- df[!df$value == "", ]
  return(df)
}


clean_values <- function(df) {
  
  hpk1 <- df %>% dplyr::filter(!stat_id == 60 | is.na(stat_id))
  
  hpk2 <- df %>% dplyr::filter(stat_id == 60) %>%
    dplyr::rowwise() %>%
    dplyr::mutate(
      value = eval(parse(text=value))
    )
  
  hpk2$value <- round(hpk2$value, 5)
    
  cleaned <- rbind(hpk1, hpk2)
  
  cleaned$value <- as.numeric(cleaned$value)
  
  return(cleaned)
}


stat_metadata <- function(df) {
  
  meta_df <- data.frame(
    stat_name = c(
      "OBP", "R", "RBI", "SB", "TB", "AVG",
      "ERA", "WHIP", "W", "SV", "K", 
      "IP", "Runs Allowed", "WH Allowed"),
    hit_pitch = c(rep("hit", 6), rep("pitch", 8))
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

## ----clean_df------------------------------------------------------------

hpk_clean <- hpk_cur %>%
  clean_cols %>%
  clean_rows %>%
  true_era_whip %>%
  clean_values %>%
  stat_metadata


## ----helper_function-----------------------------------------------------

make_rolling <- function(df, high_n = 60) {
  
  df <- df %>%
    dplyr::group_by(stat_id, team_key) %>%
    dplyr::arrange(team_key, stat_id, date)
  
  for (i in c(2:high_n)) {
    df <- df %>%
      dplyr::mutate(
        foo = rollmeanr(x = value, k = quote(i), na.pad = TRUE)
      )
    names(df)[names(df)=='foo'] <- paste0('roll_', i)
  }
  
  return(df)
}


## ----cur_roll------------------------------------------------------------

hpk_clean <- make_rolling(hpk_clean)


## ----yest_data-----------------------------------------------------------

yesterday <- Sys.Date() - 2 

hpk_yest <- hpk_clean %>% dplyr::filter(
  date == yesterday
) 

hpk_week <- hpk_clean %>% dplyr::filter(
  date <= yesterday & date >= yesterday - 8
)

hpk_month <- hpk_clean %>% dplyr::filter(
  date <= yesterday & date >= yesterday - 30
)


## ----standings-----------------------------------------------------------

h_points <- function(df) {
  h_total <- df %>% 
    dplyr::filter(
      stat_name %in% c('R', 'RBI', 'SB', 'TB', 'OBP')
    ) %>% 
    dplyr::group_by(
      team_key, stat_name
    ) %>% 
    dplyr::summarize(
      total_value = sum(value),
      n = n()
    )
  
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


h_totals <- function(df) {
  h_points(df) %>%
    dplyr::group_by(team_key, n) %>%
    dplyr::summarize(
      H = sum(rank)
    )
}


h_table_rank <- function(df) {
  
  df_detail <- h_points(df)
  df_points_wide <- tidyr::spread(df_detail[, c(1:2, 5)], stat_name, rank)
  
  df_total <- h_totals(df)
  
  df_points_wide %>%
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


h_table_stats <- function(df) {
  
  df_detail <- h_points(df)
  df_stats_wide <- tidyr::spread(df_detail[, c(1:4)], stat_name, total_value)
  df_stats_wide$OBP <- round(df_stats_wide$OBP / df_stats_wide$n, 3)
  
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
    dplyr::left_join(df_total) %>%
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
      p_table_rank(df)
    ) %>%
    dplyr::left_join(short_names) %>%
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


## ----try_it, eval = FALSE------------------------------------------------
## h_table_rank(hpk_week) %>% as.data.frame()
## h_table_rank(hpk_month) %>% as.data.frame()
## 
## h_table_stats(hpk_week) %>% as.data.frame()
## h_table_stats(hpk_month) %>% as.data.frame()
## 
## p_table_rank(hpk_week) %>% as.data.frame()
## p_table_rank(hpk_month) %>% as.data.frame()
## 
## p_table_stats(hpk_week) %>% as.data.frame()
## p_table_stats(hpk_month) %>% as.data.frame()
## 
## all_table_stats(hpk_month) %>% as.data.frame()
## all_table_rank(hpk_month) %>% as.data.frame()
## 

## ------------------------------------------------------------------------
n_days <- hpk_clean$date %>% unique() %>% sort() %>% length()

ranks_df <- data.frame(
  owner = character(0),
  date = (x = structure(rep(NA_real_, 0 ), class = "Date")),
  rank = integer(0),
  stringsAsFactors = FALSE
)

for (i in hpk_clean$date %>% unique() %>% sort()) {
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

rank_wide <- tidyr::spread(rank_counts, rank, n, fill = '')

## ------------------------------------------------------------------------
ggplot(
  data = hpk_hist %>% dplyr::filter(hit_pitch == 'hit' & scoring == TRUE),
  aes(
    x = roll_7
  )
) +
stat_density() +
theme_bw() +
facet_grid(
 facets = stat_name ~ .,
 scales = 'free'
)

