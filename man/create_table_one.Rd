% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/create_table_one.R
\name{create_table_one}
\alias{create_table_one}
\title{create_table_one for one sample size in AoAS paper}
\usage{
create_table_one(num_sims = 5, num_subj_processes = 11L,
  num_dist_processses = 4L, num_mesa_subj = 50L, alpha = 23,
  theta = 0.5, delta = -2.2, beta = 0.75, beta_bar = 0.85,
  sigma = 1, alpha_prior = rstap::normal(location = 25, scale = 4,
  autoscale = F), beta_prior = rstap::normal(location = 0, scale = 3,
  autoscale = F), theta_prior = rstap::log_normal(location = 0, scale =
  1), delta_prior = rstap::normal(location = 0, scale = 3, autoscale =
  F), skip_MESA = FALSE, iter = 4000, warmup = 2000, chains = 1,
  cores = 1, seed = NULL, file = NULL)
}
\arguments{
\item{num_sims}{number of simulations to run}

\item{num_subj_processes}{number of subject processes to simulate}

\item{num_mesa_subj}{number of subjects to sample from MESA data for MESA analysis}

\item{alpha}{intercept for generating outcome}

\item{theta}{true spatial scale under which datasets}

\item{delta}{simulated binary covariate regression effect}

\item{beta}{SAP effect}

\item{alpha_prior}{prior to be placed on intercept in model, must be an rstap:: namespace object}

\item{beta_prior}{prior to be placed on SAP effect}

\item{theta_prior}{prior to be placed on spatial scale}

\item{delta_prior}{prior to be placed on simulated binary covariate effect}

\item{skip_MESA}{Boolean value that indicates whether to run MESA model or not}

\item{iter}{number of iterations for which to run the stap_glm or stapdnd_glmer sampler}

\item{warmup}{number of iterations to warmup the sampler}

\item{chains}{number of independent MCMC chains to draw}

\item{cores}{number of cores with which to run chains in parallel}

\item{file}{path to file to save tables to in .tex format}

\item{num_dists_processes}{number of distance processes to simulate}
}
\value{
list of two table components table1_top -
which includes the coverage and diagnostic statistics broken down by parameter and
The remaining "raw" table component contains the pre-aggregation data-frames
}
\description{
create_table_one for one sample size in AoAS paper
}
