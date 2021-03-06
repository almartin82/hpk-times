#devtools::load_all(pkg = "C:\\Users\\AMartin\\Dropbox\\repositories\\RMandrill")

suppressPackageStartupMessages(suppressWarnings(library(RMandrill)))

rmd_filename = paste0('hpk_daily_', gsub('[-:]', '_', Sys.Date()), '.html')

RMandrill::mandrill_send_template(
  api_key = Sys.getenv("MANDRILL_KEY"),
  template_name = 'hpk-times',
#  recipient = 'almartin@gmail.com',
#  recipient = data.frame(
#      email = c('almartin@gmail.com', 'czapmike@gmail.com'),
#      name = c('alm', 'czap'),
#      type = c('cc', 'cc'),
#      stringsAsFactors = FALSE
#     ),
  recipient = data.frame(
     email = c('almartin@gmail.com', 'czapmike@gmail.com', 'enusbaum@gmail.com', 
                'mikec116@gmail.com', 'ptbeatty@gmail.com', 'zoheri@gmail.com'),
     name = c('alm', 'czap', 'eric', 'card', 'ptb', 'omar'),
     type = c('to', 'to', 'to', 'to', 'to', 'to'),
     stringsAsFactors = FALSE
    ),
  global_variables = data.frame(
    'name' = c('s3_link'), 
    'content' = c(paste0('https://s3.amazonaws.com/hpk/', rmd_filename))
  )
)