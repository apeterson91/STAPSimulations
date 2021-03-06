#' create datasets for sample size for second simulation figure
#'
#' @param num_sims number of simulations to run
#' @param num_subj number of subjects to simulate
#' @param num_mesa_subj number of subjects to sample from MESA data for MESA analysis
#' @param num_dists number of distances to simulate
#' @param alpha intercept for generating outcome
#' @param theta true spatial scale under which datasets
#' @param delta simulated binary covariate regression effect
#' @param beta SAP effect
#' @param alpha_prior prior to be placed on intercept in model, must be an rstap:: namespace object
#' @param beta_prior prior to be placed on SAP effect
#' @param theta_prior prior to be placed on spatial scale
#' @param delta_prior prior to be placed on simulated binary covariate effect
#' @param iter number of iterations for which to run the stap_glm or stapdnd_glmer sampler
#' @param warmup number of iterations to warmup the sampler
#' @param chains number of independent MCMC chains to draw #'
#' @param cores number of cores with which to run chains in parallel
#' @return list with 4 values, the raw and summary differences in beta and terminal distance
#'
#' @export
create_table_two <- function(num_sims = 5,
                             num_subj = 100,
                             num_dists = 30,
                             alpha = 23,
                             theta =  .5,
                             shape = 5,
                             delta = -2.2,
                             beta = .75,
                             alpha_prior = rstap::normal(location = 25, scale = 4, autoscale =F),
                             beta_prior = rstap::normal(location = 0, scale = 3, autoscale = F),
                             theta_prior = rstap::log_normal(location = 0 , scale = 1),
                             delta_prior = rstap::normal(location = 0, scale = 3, autoscale = F),
                             iter = 4E3,
                             warmup = 2E3,
                             chains = 1,
                             cores = 1,
                             file = NULL){

    print("Simulating Data")

    # Exponential
    edatasets <- purrr::map(1:num_sims,function(x) generate_hpp_dataset(seed = x,
                                                                num_subj = num_subj,
                                                                num_dists = num_dists,
                                                                alpha = alpha,
                                                                theta = theta,
                                                                delta = delta,
                                                                beta = beta,
                                                                K = function(x) {exp(-x)}))

    # Weibull

    wdatasets <- purrr::map(1:num_sims, function(x) generate_hpp_dataset(seed = x,
                                                                 num_subj = num_subj,
                                                                 num_dists = num_dists,
                                                                 alpha = alpha,
                                                                 theta = theta,
                                                                 shape = shape,
                                                                 delta = delta,
                                                                 beta = beta))
    # DLM - 1

    ddatasets <- purrr::map(1:num_sims, function(x) generate_dlm_dataset(seed = x,
                                                                         alpha = alpha,
                                                                         beta = beta,
                                                                         delta = delta,
                                                                         K = function(x) {(x<=theta)*1}) )

    # DLM - 2

    d2datasets <- purrr::map(1:num_sims, function(x) generate_dlm_dataset(seed = x,
                                                                         alpha = alpha,
                                                                         beta = beta,
                                                                         delta = delta,
                                                                         K = function(x) {(x<=theta)*(1-x^2)} ))

    # Fit DLM under DLM
    print("Fitting DLM simulated models under DLM Framework")

    dlm_lists <- purrr::map(ddatasets,function(x){
        lag <- seq(from = .1,to = floor(max(x$bef_data$Distance)), by = .1)
        Conc <- suppressWarnings(x$bef_data %>%
            dplyr::mutate(bins = cut(Distance,breaks = c(0,lag),
                                     include.lowest = TRUE )) %>%
            dplyr::group_by(subj_id,bins) %>% dplyr::count() %>%
            dplyr::rename(count = n) %>%
            tidyr::spread(bins,count) %>%
            dplyr::ungroup() %>%
            dplyr::select(-subj_id))
        labs <- rep(0,ncol(Conc))
        names(labs) <- colnames(Conc)
        Conc <- as.matrix(tidyr::replace_na(Conc, replace = lapply(labs,identity)))
        out <- list(Conc = Conc[,1:(NCOL(Conc)-1)],
                    outcome = x$subject_data$outcome,
                    sex = x$subject_data$sex,
                    lag = lag)
    })

    cps <- numeric(num_sims) # changepoints
    for(i in 1:num_sims){
        assign("sex", dlm_lists[[i]]$sex, envir = globalenv())
        assign("outcome",dlm_lists[[i]]$outcome,envir = globalenv())
        assign("Conc", dlm_lists[[i]]$Conc, envir = globalenv())
        assign("lag",dlm_lists[[i]]$lag, envir = globalenv())
        fit <- dlmBE::dlm(outcome ~ sex + dlmBE::cr(lag,Conc))
        ci <- dlmBE::confint.dlMod(fit, coef=FALSE)
        non0 <- !(ci[, 1] <= 0.05 & ci[, ncol(ci)] >= 0.05)
        rslt <- lapply(dlmBE::lagIndex(fit),
                       function(i) {
                           x <- non0[i]
                           which(x & !c(tail(x, -1), TRUE) & c(FALSE, head(x, -1)))
                       })
        cps[i] <- lag[unlist(rslt)[1]+1]
        cps[which(is.na(cps))] <- max(lag)
    }


    dlm_lists <- purrr::map(d2datasets,function(x){
        lag <- seq(from = .1,to = floor(max(x$bef_data$Distance)), by = .1)
        Conc <- suppressWarnings(x$bef_data %>%
            dplyr::mutate(bins = cut(Distance,breaks = c(0,lag),
                                     include.lowest = TRUE )) %>%
            dplyr::group_by(subj_id,bins) %>% dplyr::count() %>%
            dplyr::rename(count = n) %>%
            tidyr::spread(bins,count) %>%
            dplyr::ungroup() %>%
            dplyr::select(-subj_id))
        labs <- rep(0,ncol(Conc))
        names(labs) <- colnames(Conc)
        Conc <- as.matrix(tidyr::replace_na(Conc, replace = lapply(labs,identity)))
        out <- list(Conc = Conc[,1:(NCOL(Conc)-1)],
                    outcome = x$subject_data$outcome,
                    sex = x$subject_data$sex,
                    lag = lag)
    })


    cp2s <- numeric(num_sims) # changepoints
    for(i in 1:num_sims){
        assign("sex", dlm_lists[[i]]$sex, envir = globalenv())
        assign("outcome",dlm_lists[[i]]$outcome,envir = globalenv())
        assign("Conc", dlm_lists[[i]]$Conc, envir = globalenv())
        assign("lag",dlm_lists[[i]]$lag, envir = globalenv())
        fit <- dlmBE::dlm(outcome ~ sex + dlmBE::cr(lag,Conc))
        ci <- dlmBE::confint.dlMod(fit, coef=FALSE)
        non0 <- !(ci[, 1] <= 0.05 & ci[, ncol(ci)] >= 0.05)
        rslt <- lapply(dlmBE::lagIndex(fit),
                       function(i) {
                           x <- non0[i]
                           which(x & !c(tail(x, -1), TRUE) & c(FALSE, head(x, -1)))
                       })
        cp2s[i] <- lag[unlist(rslt)[1]+1]
        cp2s[which(is.na(cp2s))] <- max(lag)
    }

    dlm_lists <- purrr::map(edatasets,function(x){
        lag <- seq(from = .1,to = floor(max(x$bef_data$Distance)), by = .1)
        Conc <- suppressWarnings(x$bef_data %>%
            dplyr::mutate(bins = cut(Distance,breaks = c(0,lag),
                                     include.lowest = TRUE )) %>%
            dplyr::group_by(subj_id,bins) %>% dplyr::count() %>%
            dplyr::rename(count = n) %>%
            tidyr::spread(bins,count) %>%
            dplyr::ungroup() %>%
            dplyr::select(-subj_id))
        labs <- rep(0,ncol(Conc))
        names(labs) <- colnames(Conc)
        Conc <- as.matrix(tidyr::replace_na(Conc, replace = lapply(labs,identity)))
        out <- list(Conc = Conc[,1:(NCOL(Conc)-1)],
                    outcome = x$subject_data$outcome,
                    sex = x$subject_data$sex,
                    lag = lag)
    })

    cpes <- numeric(num_sims) # changepoints
    for(i in 1:num_sims){
        assign("sex", dlm_lists[[i]]$sex, envir = globalenv())
        assign("outcome",dlm_lists[[i]]$outcome,envir = globalenv())
        assign("Conc", dlm_lists[[i]]$Conc, envir = globalenv())
        assign("lag",dlm_lists[[i]]$lag, envir = globalenv())
        fit <- dlmBE::dlm(outcome ~ sex + dlmBE::cr(lag,Conc))
        ci <- dlmBE::confint.dlMod(fit, coef=FALSE)
        non0 <- !(ci[, 1] <= 0.05 & ci[, ncol(ci)] >= 0.05)
        rslt <- lapply(dlmBE::lagIndex(fit),
               function(i) {
                   x <- non0[i]
                   which(x & !c(tail(x, -1), TRUE) & c(FALSE, head(x, -1)))
               })
        cpes[i] <- lag[unlist(rslt)[1]+1]
        cpes[which(is.na(cpes))] <- max(lag)
    }

    dlm_lists <- purrr::map(wdatasets,function(x){
        lag <- seq(from = .1,to = floor(max(x$bef_data$Distance)), by = .1)
        Conc <- suppressWarnings(x$bef_data %>%
            dplyr::mutate(bins = cut(Distance,breaks = c(0,lag),
                                     include.lowest = TRUE )) %>%
            dplyr::group_by(subj_id,bins) %>% dplyr::count() %>%
            dplyr::rename(count = n) %>%
            tidyr::spread(bins,count) %>%
            dplyr::ungroup() %>%
            dplyr::select(-subj_id))
        labs <- rep(0,ncol(Conc))
        names(labs) <- colnames(Conc)
        Conc <- as.matrix(tidyr::replace_na(Conc, replace = lapply(labs,identity)))
        out <- list(Conc = Conc[,1:(NCOL(Conc)-1)],
                    outcome = x$subject_data$outcome,
                    sex = x$subject_data$sex,
                    lag = lag)
    })

    cpws <- numeric(num_sims) # changepoints
    for(i in 1:num_sims){
        assign("sex", dlm_lists[[i]]$sex, envir = globalenv())
        assign("outcome",dlm_lists[[i]]$outcome,envir = globalenv())
        assign("Conc", dlm_lists[[i]]$Conc, envir = globalenv())
        assign("lag",dlm_lists[[i]]$lag, envir = globalenv())
        fit <- dlmBE::dlm(outcome ~ sex + dlmBE::cr(lag,Conc))
        ci <- dlmBE::confint.dlMod(fit, coef=FALSE)
        non0 <- !(ci[, 1] <= 0.05 & ci[, ncol(ci)] >= 0.05)
        rslt <- lapply(dlmBE::lagIndex(fit),
               function(i) {
                   x <- non0[i]
                   which(x & !c(tail(x, -1), TRUE) & c(FALSE, head(x, -1)))
               })
        cpws[i] <- lag[unlist(rslt)[1]+1]
        cpws[which(is.na(cpws))] <- max(lag)
    }

    # STAP Model fitting

    # Fit DLM under Exponential
    print("Fitting DLM model [1] under Exponential Exposure Function")
    de <- purrr::map(ddatasets,function(x){
        rstap::stap_glm(outcome ~ sex + sap(FF,exp),
                        subject_data = x$subject_data,
                        distance_data = x$bef_data,
                        max_distance = 10,
                        subject_ID = "subj_id",
                        prior = delta_prior,
                        prior_stap = beta_prior,
                        prior_intercept = alpha_prior,
                        prior_theta = theta_prior,
                        chains = chains,
                        cores = cores,
                        iter = iter,
                        warmup = warmup)})

    # Fit DLM under Weibull
    print("Fitting DLM model [1] under Weibull Exposure Function")
    dw <- purrr::map(ddatasets,function(x){
        rstap::stap_glm(outcome~sex + sap(FF,wei),
                        subject_data = x$subject_data,
                        distance_data = x$bef_data,
                        max_distance = 10,
                        subject_ID = "subj_id",
                        prior = delta_prior,
                        prior_stap = beta_prior,
                        prior_intercept = alpha_prior,
                        prior_theta = list(FF=list(spatial=list(theta=theta_prior,shape=rstap::log_normal(0,1)))),
                        chains = chains,
                        cores = cores,
                        iter = iter,
                        warmup = warmup)})

    # Fit DLM2 under Exponential

    print("Fitting DLM model [2] under Weibull Exposure Function")
    d2e <- purrr::map(d2datasets,function(x){
        rstap::stap_glm(outcome~sex + sap(FF,exp),
                        subject_data = x$subject_data,
                        distance_data = x$bef_data,
                        max_distance = 10,
                        subject_ID = "subj_id",
                        prior = delta_prior,
                        prior_stap = beta_prior,
                        prior_intercept = alpha_prior,
                        prior_theta = theta_prior,
                        chains = chains,
                        cores = cores,
                        iter = iter,
                        warmup = warmup)})

    # Fit DLM2 under Weibull

    print("Fitting DLM model [2] under Weibull Exposure Function")
    d2w <- purrr::map(d2datasets,function(x){
        rstap::stap_glm(outcome~sex + sap(FF,wei),
                        subject_data = x$subject_data,
                        distance_data = x$bef_data,
                        max_distance = 10,
                        subject_ID = "subj_id",
                        prior = delta_prior,
                        prior_stap = beta_prior,
                        prior_intercept = alpha_prior,
                        prior_theta = list(FF=list(spatial=list(theta=theta_prior,shape=rstap::log_normal(0,1)))),
                        chains = chains,
                        cores = cores,
                        iter = iter,
                        warmup = warmup)})


    # Fit Exponential under Exponential

    print("Fitting Exponential model under Exponential Exposure Function")
    ee <- purrr::map(edatasets,function(x){
        rstap::stap_glm(outcome~sex + sap(FF,exp),
                subject_data = x$subject_data,
                distance_data = x$bef_data,
                max_distance = 10,
                subject_ID = "subj_id",
                prior = delta_prior,
                prior_stap = beta_prior,
                prior_intercept = alpha_prior,
                prior_theta = theta_prior,
                chains = chains,
                cores = cores,
                iter = iter,
                warmup = warmup)})


    # Fit Exponential under Weibull
    print("Fitting Exponential model under Weibull Exposure Function")
    ew <- purrr::map(edatasets,function(x){
        rstap::stap_glm(outcome~sex + sap(FF,wei),
                subject_data = x$subject_data,
                distance_data = x$bef_data,
                max_distance = 10,
                subject_ID = "subj_id",
                prior = delta_prior,
                prior_stap = beta_prior,
                prior_intercept = alpha_prior,
                prior_theta = list(FF=list(spatial=list(theta=theta_prior,shape=rstap::log_normal(0,1)))),
                chains = chains,
                cores = cores,
                iter = iter,
                warmup = warmup)})

    # Fit Weibull under Exponential
    print("Fitting Weibull model under Exponential Exposure Function")
    we <- purrr::map(wdatasets,function(x){
        rstap::stap_glm(outcome~sex + sap(FF,exp),
                subject_data = x$subject_data,
                distance_data = x$bef_data,
                max_distance = 10,
                subject_ID = "subj_id",
                prior = delta_prior,
                prior_stap = beta_prior,
                prior_intercept = alpha_prior,
                prior_theta = theta_prior,
                cores = cores,
                chains = chains,
                cores = cores,
                iter = iter,
                warmup = warmup)})

    # Fit Weibull under Weibull
    print("Fitting Weibull model under Weibull Exposure Function")
    ww <- purrr::map(wdatasets,function(x){
        rstap::stap_glm(outcome ~ sex + sap(FF,wei),
                subject_data = x$subject_data,
                distance_data = x$bef_data,
                max_distance = 10,
                subject_ID = "subj_id",
                prior = delta_prior,
                prior_stap = beta_prior,
                prior_intercept = alpha_prior,
                prior_theta = list(FF=list(spatial=list(theta=theta_prior,shape=rstap::log_normal(0,1)))),
                chains = chains,
                cores = cores,
                iter = iter,
                warmup = warmup)})

    print("Aggregating Simulation Statistics")
    term_step_d <- tibble::tibble(sim_id = 1:num_sims,
                              Simulated_Function = "Step Function",
                              Modeled_Function = "DLM",
                              True_termination = theta,
                              Estimate_termination = cps,
                              )


    term_step_e <- tibble::tibble(sim_id = 1:num_sims,
                                Simulated_Function = rep("Step Function",num_sims),
                                Modeled_Function = rep("Exponential", num_sims),
                                True_termination = theta,
                                Estimate_termination = purrr::map_dbl(de,function(x) rstap::stap_termination(x,max_value=10)[2]))


    term_step_w <- tibble::tibble(sim_id = 1:num_sims,
                                Simulated_Function = rep("Step Function",num_sims),
                                Modeled_Function = rep("Weibull", num_sims),
                                True_termination = theta,
                                Estimate_termination = purrr::map_dbl(dw,function(x) rstap::stap_termination(x,max_value=10)[2]))


    term_q_d <- tibble::tibble(sim_id = 1:num_sims,
                              Simulated_Function = "Quadratic Step",
                              Modeled_Function = "DLM",
                              True_termination = theta,
                              Estimate_termination = cp2s)


    term_q_e <- tibble::tibble(sim_id = 1:num_sims,
                              Simulated_Function = rep("Quadratic Step",num_sims),
                              Modeled_Function = rep("Exponential", num_sims),
                              True_termination = theta,
                              Estimate_termination = purrr::map_dbl(d2e,function(x) rstap::stap_termination(x,max_value=10)[2]))


    term_q_w <- tibble::tibble(sim_id = 1:num_sims,
                                 Simulated_Function = rep("Quadratic Step",num_sims),
                                 Modeled_Function = rep("Weibull", num_sims),
                                 True_termination = theta,
                                 Estimate_termination = purrr::map_dbl(d2w,function(x) rstap::stap_termination(x,max_value=10)[2]))

    term_e_d <- tibble::tibble(sim_id = 1:num_sims,
                                 Simulated_Function = "Exponential",
                                 Modeled_Function = "DLM",
                                 True_termination = uniroot(function(x) exp(-(x/theta)) - 0.05,interval = c(0,10))$root,
                                 Estimate_termination = cpes)

    term_exp  <- tibble::tibble(sim_id = 1:num_sims,
                                Simulated_Function = rep("Exponential",num_sims),
                                Modeled_Function = rep("Exponential",num_sims),
                                True_termination = uniroot(function(x) exp(-(x/theta)) - 0.05,interval = c(0,10))$root,
                                Estimate_termination = purrr::map_dbl(ee,function(a) rstap::stap_termination(a,max_value=10)[2])
    )

    term_e_w <- tibble::tibble(sim_id = 1:num_sims,
                                  Simulated_Function = rep("Exponential",num_sims),
                                  Modeled_Function = rep("Weibull",num_sims),
                                  True_termination = uniroot(function(x) exp(-(x/theta)) - 0.05,interval = c(0,10))$root,
                                  Estimate_termination = purrr::map_dbl(ew,function(a) rstap::stap_termination(a,max_value=10)[2])
    )

    term_w_d <- tibble::tibble(sim_id = 1:num_sims,
                                  Simulated_Function = "Weibull",
                                  Modeled_Function = "DLM",
                                  True_termination = uniroot(function(x){ exp(-(x/theta)^shape) - 0.05},interval = c(0,10))$root,
                                  Estimate_termination = cpws)

    term_w_e <- tibble::tibble(sim_id = 1:num_sims,
                                  Simulated_Function = rep("Weibull",num_sims),
                                  Modeled_Function = rep("Exponential",num_sims),
                                  True_termination = uniroot(function(x){ exp(-(x/theta)^shape) - 0.05},interval = c(0,10))$root,
                                  Estimate_termination = purrr::map_dbl(we,function(a) rstap::stap_termination(a,max_value=10)[2])
    )

    term_wei <- tibble::tibble(sim_id = 1:num_sims,
                                        Simulated_Function = rep("Weibull",num_sims),
                                        Modeled_Function = rep("Weibull",num_sims),
                                        True_termination = uniroot(function(x){ exp(-(x/theta)^shape) - 0.05},interval = c(0,10))$root,
                                        Estimate_termination = purrr::map_dbl(ww,function(a) rstap::stap_termination(a,max_value=10)[2])
    )

    out <- dplyr::bind_rows(term_step_d,term_step_e,term_step_w,
                            term_q_d, term_q_e,term_q_w,
                            term_e_d,term_exp,term_e_w,
                            term_w_d,term_w_e,term_wei) %>%
            dplyr::mutate(Termination_Difference=abs(True_termination - Estimate_termination)/True_termination ) %>%
            dplyr::group_by(Simulated_Function,Modeled_Function) %>%
            dplyr::summarise(mean_difference = 100*mean(Termination_Difference)) %>%
            dplyr::ungroup() %>%
            tidyr::spread(Modeled_Function,mean_difference) %>%
        dplyr::select(Simulated_Function,Exponential,Weibull,DLM)

    raw_table_one <-  dplyr::bind_rows(term_step_d,term_step_e,term_step_w,
                                 term_q_d, term_q_e,term_q_w,
                                 term_e_d,term_exp,term_e_w,
                                 term_w_d,term_w_e,term_wei) %>%
        dplyr::mutate(Termination_Difference=abs(True_termination - Estimate_termination)/True_termination,
                      Percent_Difference = (Termination_Difference)*100 )



# |hat(beta) - beta| table ------------------------------------------------------

    print("Aggregating Simulation Statistics")




    term_step_e <- tibble::tibble(sim_id = 1:num_sims,
                                  Simulated_Function = rep("Step Function",num_sims),
                                  Modeled_Function = rep("Exponential", num_sims),
                                  True_beta = beta,
                                  Estimate_beta = purrr::map_dbl(de,function(x)  coef(x)["FF"] ))


    term_step_w <- tibble::tibble(sim_id = 1:num_sims,
                                  Simulated_Function = rep("Step Function",num_sims),
                                  Modeled_Function = rep("Weibull", num_sims),
                                  True_beta = beta,
                                  Estimate_beta = purrr::map_dbl(dw,function(x) coef(x)["FF"]))


    term_q_e <- tibble::tibble(sim_id = 1:num_sims,
                               Simulated_Function = rep("Quadratic Step",num_sims),
                               Modeled_Function = rep("Exponential", num_sims),
                               True_beta = beta,
                               Estimate_beta = purrr::map_dbl(d2e,function(x) coef(x)["FF"] ))


    term_q_w <- tibble::tibble(sim_id = 1:num_sims,
                               Simulated_Function = rep("Quadratic Step",num_sims),
                               Modeled_Function = rep("Weibull", num_sims),
                               True_beta = beta,
                               Estimate_beta = purrr::map_dbl(d2w,function(x) coef(x)["FF"] ))

    term_exp  <- tibble::tibble(sim_id = 1:num_sims,
                                Simulated_Function = rep("Exponential",num_sims),
                                Modeled_Function = rep("Exponential",num_sims),
                                True_beta = beta,
                                Estimate_beta = purrr::map_dbl(ee,function(a) coef(a)["FF"])
    )

    term_e_w <- tibble::tibble(sim_id = 1:num_sims,
                               Simulated_Function = rep("Exponential",num_sims),
                               Modeled_Function = rep("Weibull",num_sims),
                               True_beta = beta,
                               Estimate_beta = purrr::map_dbl(ew,function(a) coef(a)["FF"])
    )


    term_w_e <- tibble::tibble(sim_id = 1:num_sims,
                               Simulated_Function = rep("Weibull",num_sims),
                               Modeled_Function = rep("Exponential",num_sims),
                               True_beta = beta,
                               Estimate_beta = purrr::map_dbl(we,function(a) coef(a)["FF"])
    )

    term_wei <- tibble::tibble(sim_id = 1:num_sims,
                               Simulated_Function = rep("Weibull",num_sims),
                               Modeled_Function = rep("Weibull",num_sims),
                               True_beta = beta,
                               Estimate_beta = purrr::map_dbl(ww,function(a) coef(a)["FF"])
    )

    out2 <- dplyr::bind_rows(term_step_e,term_step_w,
                             term_q_e,term_q_w,
                            term_exp,term_e_w,
                            term_w_e,term_wei) %>%
        dplyr::mutate(Effect_Difference = abs(True_beta - Estimate_beta),
                      Percent_Difference = Effect_Difference/True_beta) %>%
        dplyr::group_by(Simulated_Function,Modeled_Function) %>%
        dplyr::summarise(mean_difference = 100*mean(Percent_Difference)) %>%
        dplyr::ungroup() %>%
        tidyr::spread(Modeled_Function,mean_difference) %>%
        dplyr::select(Simulated_Function,Exponential,Weibull)


    raw_table_two <-  dplyr::bind_rows(term_step_e,term_step_w,
                                        term_q_e,term_q_w,
                                       term_exp,term_e_w,
                                       term_w_e,term_wei) %>%
        dplyr::mutate(Effect_Difference = abs(True_beta - Estimate_beta)/True_beta,
                      Percent_Difference = (Effect_Difference)*100)


# Return values -----------------------------------------------------------




    return(list(summary_distance_table = out,
                raw_distance_table = raw_table_one,
                summary_beta_table = out2,
                raw_beta_table = raw_table_two
                ))
}

