## install_github("libbi/rbi")
library('rbi')
## install_github("sbfnk/rbi.helpers")
library('rbi.helpers')

library('magrittr')

library('cowplot')

###################
## model fitting ##
###################

## read observation data
obs <- readRDS("fit_data.rds")

## set model directory
model_dir <- path.expand("~/code/vbd/bi")

## sample size for serology
serology_sample <- data.frame(time=0, value=633)

## load model and fix population size
vbd_model <- bi_model(paste(model_dir, "vbd.bi", sep="/")) %>%
  fix(N=2.675e+6,
      p_p_immune=0.06)

## fit
bi <- libbi(vbd_model, input=list(serology_sample=serology_sample),
            obs=obs,
            end_time=max(obs$Sero$time)) %>%
  optimise() %>%
  sample(proposal="prior", nsamples=1000) %>%
  adapt_proposal(min=0.1, max=0.4) %>%
  sample(sample_obs=TRUE, nsamples=100000, thin=10)

## plot
p <- plot(bi, date.origin=as.Date("2015-01-05") - 7, date.unit="week", obs=c("Serology", "Incidence"), verbose=TRUE, type=c("obs", "param", "logeval"))
ggsave("sero.pdf", p$obs)

## save
saveRDS(bi, "salvador.rds")

