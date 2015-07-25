
#http://stackoverflow.com/a/10969107/561698
rmd_filename = paste0('hpk_daily_', gsub('[-:]', '_', Sys.Date()), '.html')
require(knitr) # required for knitting from rmd to md
require(markdown) # required for md to html 
knit('hpk_daily.Rmd', 'hpk_daily.md') # creates md file
markdownToHTML('test.md', rmd_filename) # creates html file


library(aws.signature)
library(aws.s3)

aws.s3::putobject(
  file = rmd_filename,
  bucket = 'hpk', 
  object = rmd_filename,
  parse_response = FALSE
)
