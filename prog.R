#suppressPackageStartupMessages(suppressWarnings(library(knitr)))
suppressPackageStartupMessages(suppressWarnings(library(rmarkdown)))
#suppressPackageStartupMessages(suppressWarnings(library(httr)))
#Sys.setenv("DISPLAY" = ":0.0")
#rmarkdown::render('hpk_daily.Rmd')
rmarkdown::render('foo.Rmd')

#rmd_filename = paste0('hpk_daily_', gsub('[-:]', '_', Sys.Date()), '.html')

#library(aws.signature)
#library(aws.s3)

#aws.s3::putobject(
#  file = 'hpk_daily.html',
#  bucket = 'hpk', 
#  object = rmd_filename,
#  parse_response = FALSE
#)

#if (file.exists('hpk_daily.html')) file.remove('hpk_daily.html')
#check in with dead man's snitch
#httr::GET('https://nosnch.in/87d799f117')
