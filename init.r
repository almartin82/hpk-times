

my_packages = c("rmarkdown", "DT", "ggplot2", "readr", "dplyr", "zoo", "tidyr", "magrittr", "fitdistrplus", "httr", "XML", "devtools", "knitr")

				install_if_missing = function(p) {
  if (p %in% rownames(installed.packages()) == FALSE) {
    install.packages(p, dependencies = TRUE)
  }
  else {
    cat(paste("Skipping already installed package:", p, "\n"))
  }
}
invisible(sapply(my_packages, install_if_missing))

# github packages
devtools::install_github('cloudyr/aws.signature')
devtools::install_github('cloudyr/aws.s3')
devtools::install_github("almartin82/RMandrill", ref = 'almartin')
