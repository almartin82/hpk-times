library(RMandrill)

RMandrill::mandrill_send_template(
  api_key = Sys.getenv("MANDRILL_KEY"),
  template_name = 'hpk-times',
  recipient = c('almartin@gmail.com', 'czapmike@gmail.com', 'enusbaum@gmail.com', 
                'mikec116@gmail.com', 'ptbeatty@gmail.com'),
  variables = data.frame(
    'name' = c('s3_link'), 
    'content' = c(paste0('https://s3.amazonaws.com/hpk/', rmd_filename))
  )
)
