library(knitr)
knitr::knit('hpk_daily.Rmd')

library(aws.signature)
library(aws.s3)

aws.s3::putobject(
  file = 'hpk_daily.html',
  bucket = 'hpk', 
  object = paste0('hpk_daily_', gsub('[-:]', '_', Sys.Date()), '.html'),
  parse_response = FALSE
)

