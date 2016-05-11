model vbd {

  const e_delta_h = 1
  const e_delta_m = 1

  const e_setting = 2 // 0 = yap, 1 = fais
  const e_disease = 2 // 0 = dengue, 1 = zika
  const e_obs_id = 3 // 0 = yap/dengue, 1 = fais/dengue, 2 = yap/zika
                     // setting = obs_id % 2, disease = obs_id / 2

  dim delta_erlang_h(e_delta_h)
  dim delta_erlang_m(e_delta_m)
  dim setting(e_setting)
  dim disease(e_disease)
  dim obs_id(e_obs_id)

  param p_d_inc_h[disease]
  param p_d_inc_m[disease]
  param p_d_inf_h[disease]
  param p_d_life_m

  param p_p_asymptomatic[disease] // proportion of infections that are asymptomatic
  param p_lm[setting] // number of female vectors per human (log base 10)
  param p_N_h[setting]
  param p_initial_susceptible // proportion initially susceptible for dengue in Yap

  param p_rep[disease] // reporting rate

  param p_b_h[disease] // probability that a bite on a human leads to infection
  param p_b_m[disease] // probability that a bite on a vector leads to infection

  param p_tau[setting]

  param p_t_start[setting,disease]

  param p_phi_mult[disease]
  param p_phi_add[disease]

  // humans
  state S_h[setting,disease](has_output = 0) // susceptible
  state E_h[setting,disease,delta_erlang_h](has_output = 0) // incubating
  state I_h[setting,disease](has_output = 0) // infectious
  state Z_h[setting,disease](has_output = 0) // incidence
  state C_h[setting,disease] // cumulative incidence


  // vectors
  state S_m[setting,disease](has_output = 0) // susceptible
  state E_m[setting,disease,delta_erlang_m](has_output = 0) // incubating
  state I_m[setting,disease](has_output = 0) // infectious

  state next_obs[setting,disease](has_output = 0) // time of next observation
  state started[setting,disease](has_output = 0) // outbreak start switch

  obs Cases[obs_id]

  sub parameter {
    p_d_inc_h[disease] ~ log_gaussian(mean = log(5.9), std = 0.07)
    p_d_inc_m[disease] ~ log_gaussian(mean = log(9.8), std = 0.36)

    p_d_life_m ~ uniform(lower = 4, upper = 30)
    p_d_inf_h[disease] ~ truncated_gaussian(mean = 4.5, std = 1.78, lower = 0)

    p_p_asymptomatic[disease] ~ uniform(lower = 0, upper = 1)

    p_rep[disease] ~ uniform(lower = 0, upper = 1)

    p_b_h[disease] ~ uniform(lower = 0, upper = 1)
    p_b_m[disease] ~ uniform(lower = 0, upper = 1)

    p_lm[setting] ~ uniform(lower = -1, upper = 2)
    p_t_start[setting,disease] ~ uniform(lower = 0, upper = 64)

    p_phi_mult[disease] ~ uniform(lower = 0, upper = 0.5)
    p_phi_add[disease] ~ uniform(lower = 1, upper = 5)

    p_initial_susceptible ~ uniform(lower = 0, upper = 1)

    p_tau[setting] ~ uniform(lower = 0.3, upper = 1)
  }

  sub initial {
    S_h[setting,disease] <- (setting == 0 && disease == 0 ? p_initial_susceptible : 1) * p_N_h[setting]
    E_h[setting,disease,delta_erlang_h] <- 0
    I_h[setting,disease] <- 0
    C_h[setting,disease] <- 0
    Z_h[setting,disease] <- 0
    E_m[setting,disease,delta_erlang_m] <- 0
    S_m[setting,disease] <- 1
    I_m[setting,disease] <- 0
    next_obs[setting,disease] <- 0
    started[setting,disease] <- 0
  }

  sub transition {

    inline r_death_m = 1 / p_d_life_m
    inline r_births_m = 1 / p_d_life_m

    Z_h[setting,disease] <- (t_next_obs > next_obs[setting,disease] ? 0 : Z_h[setting,disease])
    next_obs[setting,disease] <- (t_next_obs > next_obs[setting,disease] ? t_next_obs : next_obs[setting,disease])

    I_h[setting,disease] <- (started[setting,disease] == 0 && t_now >= p_t_start[setting,disease] ? 1 : I_h[setting,disease])
    S_h[setting,disease] <- (started[setting,disease] == 0 && t_now >= p_t_start[setting,disease] ? S_h[setting,disease] - 1 : S_h[setting,disease])
    Z_h[setting,disease] <- (started[setting,disease] == 0 && t_now >= p_t_start[setting,disease] ? 1 : Z_h[setting,disease])
    started[setting,disease] <- (t_now >= p_t_start[setting,disease] ? 1 : 0)
    
    ode {
      dS_h[setting,disease]/dt =
      - p_tau[setting] * p_b_h[disease] * pow(10, p_lm[setting])* I_m[setting,disease] * S_h[setting,disease]

      dE_h[setting,disease,delta_erlang_h]/dt =
      + (delta_erlang_h == 0 ? p_tau[setting] * p_b_h[disease] * pow(10, p_lm[setting])* I_m[setting,disease] * S_h[setting,disease] : e_delta_h * (1 / p_d_inc_h[disease]) * E_h[setting,disease,delta_erlang_h - 1])
      - e_delta_h * (1 / p_d_inc_h[disease]) * E_h[setting,disease,delta_erlang_h]

      dI_h[setting,disease]/dt =
      + (1 - p_p_asymptomatic[disease]) * e_delta_h * (1 / p_d_inc_h[disease]) * E_h[setting,disease,e_delta_h - 1]
      - (1 / p_d_inf_h[disease]) * I_h[setting,disease]

      dZ_h[setting,disease]/dt =
      + (1 - p_p_asymptomatic[disease]) * e_delta_h * (1 / p_d_inc_h[disease]) * E_h[setting,disease,e_delta_h - 1]

      dC_h[setting,disease]/dt =
      + e_delta_h * (1 / p_d_inc_h[disease]) * E_h[setting,disease,e_delta_h - 1]

      dS_m[setting,disease]/dt =
      + r_births_m
      - p_tau[setting] * p_b_m[disease] * I_h[setting,disease] / p_N_h[setting] * S_m[setting,disease]
      - r_death_m * S_m[setting,disease]

      dE_m[setting,disease,delta_erlang_m]/dt =
      + (delta_erlang_m == 0 ? p_tau[setting] * p_b_m[disease] * I_h[setting,disease] / p_N_h[setting] * S_m[setting,disease] : e_delta_m * (1 / p_d_inc_m[disease]) * E_m[setting,disease,delta_erlang_m - 1])
      - e_delta_m * (1 / p_d_inc_m[disease]) * E_m[setting,disease,delta_erlang_m]
      - r_death_m * E_m[setting,disease,delta_erlang_m]

      dI_m[setting,disease]/dt =
      + e_delta_m * (1 / p_d_inc_m[disease]) * E_m[setting,disease,e_delta_m - 1]
      - r_death_m * I_m[setting,disease]
    }
  }

  sub observation {
    Cases[obs_id] ~ truncated_gaussian(mean = p_rep[obs_id / 2] * Z_h[obs_id % 2,obs_id / 2], std = sqrt(p_rep[obs_id / 2] * Z_h[obs_id % 2,obs_id / 2] + (p_phi_mult[obs_id / 2] ** 2) * (p_rep[obs_id / 2] ** 2) * (Z_h[obs_id % 2,obs_id / 2] ** 2) + p_phi_add[obs_id / 2]), lower = 0)
  }

  sub proposal_initial {
    S_h[setting,disease] <- (setting == 0 && disease == 0 ? p_initial_susceptible : 1) * p_N_h[setting]
    E_h[setting,disease,delta_erlang_h] <- 0
    I_h[setting,disease] <- 0
    C_h[setting,disease] <- 0
    Z_h[setting,disease] <- 0
    E_m[setting,disease,delta_erlang_m] <- 0
    S_m[setting,disease] <- 1
    I_m[setting,disease] <- 0
    next_obs[setting,disease] <- 0
    started[setting,disease] <- 0
  }
  sub proposal_parameter {
    p_d_inc_h[disease] ~ gaussian(mean = p_d_inc_h[disease], std = 0.05)
    p_d_inc_m[disease] ~ gaussian(mean = p_d_inc_m[disease], std = 0.1)
    p_d_inf_h[disease] ~ truncated_gaussian(mean = p_d_inf_h[disease], std = 0.05, lower = 0)
    p_d_life_m ~ truncated_gaussian(mean = p_d_life_m, std = 0.15, lower = 4, upper = 30)
    p_tau[setting] ~ truncated_gaussian(mean = p_tau[setting], std = 0.005, lower = 0.3, upper = 1)
    p_p_asymptomatic[disease] ~ truncated_gaussian(mean = p_p_asymptomatic[disease], std = 0.0035, lower = 0, upper = 1)
    p_lm[setting] ~ truncated_gaussian(mean = p_lm[setting], std = 0.0075, lower = -1, upper = 2)
    p_initial_susceptible ~ truncated_gaussian(mean = p_initial_susceptible, std = 0.003, lower = 0, upper = 1)
    p_rep[disease] ~ truncated_gaussian(mean = p_rep[disease], std = 0.015, lower = 0, upper = 1)
    p_b_h[disease] ~ truncated_gaussian(mean = p_b_h[disease], std = 0.002, lower = 0, upper = 1)
    p_b_m[disease] ~ truncated_gaussian(mean = p_b_m[disease], std = 0.002, lower = 0, upper = 1)
    p_t_start[setting,disease] ~ truncated_gaussian(mean = p_t_start[setting,disease], std = 0.5, lower = 0, upper = 64)
    p_phi_mult[disease] ~ truncated_gaussian(mean = p_phi_mult[disease], std = 0.001, lower = 0, upper = 0.5)
    p_phi_add[disease] ~ truncated_gaussian(mean = p_phi_add[disease], std = 0.05, lower = 1, upper = 5)
  }
}