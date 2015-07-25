#
# Example R code to install packages
# See http://cran.r-project.org/doc/manuals/R-admin.html#Installing-packages for details
#

###########################################################
# Update this line with the R packages to install:

# install older version of colorspace package
my_packages = c("readr", "dplyr", "zoo", "ggplot2", "tidyr", "DT", "httr", "XML", 
                "devtools", "fitdistrplus", 'knitr', 'rmarkdown')

###########################################################

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
devtools::install_github("almartin82/RMandrill")