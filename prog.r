library(knitr)
knitr::knit('hpk_daily.Rmd')

library(aws.signature)
library(aws.s3)

rmd_filename = paste0('hpk_daily_', gsub('[-:]', '_', Sys.Date()), '.html')

aws.s3::putobject(
  file = 'hpk_daily.html',
  bucket = 'hpk', 
  object = rmd_filename,
  parse_response = FALSE
)
