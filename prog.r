library(knitr)
knitr::knit('hpk_daily.Rmd')

library(aws.signature)
library(aws.s3)
library(RMandrill)

rmd_filename = paste0('hpk_daily_', gsub('[-:]', '_', Sys.Date()), '.html')

aws.s3::putobject(
  file = 'hpk_daily.html',
  bucket = 'hpk', 
  object = rmd_filename,
  parse_response = FALSE
)

RMandrill::mandrill_send_template(
  api_key = Sys.getenv("MANDRILL_KEY"),
  template_name = 'hpk-times',
  recipient = 'almartin@gmail.com',
  variables = data.frame(
    'name' = c('s3_link'), 
    'content' = c(paste0('https://s3.amazonaws.com/hpk/', rmd_filename))
  )
)
