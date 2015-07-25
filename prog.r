require(knitr)
require(rmarkdown)
rmarkdown::render("hpk_daily.Rmd")

rmd_filename = paste0('hpk_daily_', gsub('[-:]', '_', Sys.Date()), '.html')

library(aws.signature)
library(aws.s3)

aws.s3::putobject(
  file = 'hpk_daily.html',
  bucket = 'hpk', 
  object = rmd_filename,
  parse_response = FALSE
)
