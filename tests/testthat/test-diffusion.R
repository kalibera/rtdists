context("Diffusion pdiffusion and ddiffusion functions.")

# Include the old non-vectorised pdiffusion and ddiffusion funcs to ensure they haven't been broken
# note that these functions still use a relative z and not  the absolute z used now by the diffusion functions.

# [MG 20150616]
# In line with LBA, adjust t0 to be the lower bound of the non-decision time distribution rather than the average 
# Called from pdiffusion, ddiffusion, rdiffusion 
recalc_t0 <- function (t0, st0) { t0 <- t0 + st0/2 }

old_ddiffusion <- function (t, response = c("upper", "lower"), 
                 a, v, t0, z = 0.5, d = 0, sz = 0, sv = 0, st0 = 0, 
                 precision = 3)
{
  t0 <- recalc_t0 (t0, st0) 
  
  # Check for illegal parameter values
  if(any(missing(a), missing(v), missing(t0))) stop("a, v, and/ot t0 must be supplied")
  pl <- c(a,v,t0,d,sz,sv,st0,z)
  if(length(pl)!=8) stop("Each parameter needs to be of length 1.")
  if(!is.numeric(pl)) stop("Parameters need to be numeric.")
  if (any(is.na(pl)) || !all(is.finite(pl))) stop("Parameters need to be numeric and finite.")
  
  response <- match.arg(response)
  if (response == "upper") i <- 2L
  if (response == "lower") i <- 1L
  
  # Call the C code
  densities <- vector(length=length(t))    
  output <- .C("dfastdm_b", 
               as.integer (length(t)),                 # 1  IN:  number of densities
               as.vector  (pl),                        # 2  IN:  parameters
               as.vector  (t),                         # 3  IN:  RTs
               as.double  (precision),                 # 4  IN:  precision
               as.integer (i),                         # 5  IN:  boundart 
               as.vector  (densities, mode="numeric")  # 6 OUT:  densities
  )
  
  abs(unlist(output[6]))
  
}

old_pdiffusion <- function (t, response = c("upper", "lower"), 
                 a, v, t0, z = 0.5, d = 0, sz = 0, sv = 0, st0 = 0, 
                 precision = 3, maxt = 1e4) 
{
  t0 <- recalc_t0 (t0, st0) 
  
  # Check for illegal parameter values
  if(any(missing(a), missing(v), missing(t0))) stop("a, v, and/ot t0 must be supplied")
  pl <- c(a,v,t0,d,sz,sv,st0,z)
  if(length(pl)!=8) stop("Each parameter needs to be of length 1.")
  if(!is.numeric(pl)) stop("Parameters need to be numeric.")
  if (any(is.na(pl)) || !all(is.finite(pl))) stop("Parameters need to be numeric and finite.")
  
  t[t>maxt] <- maxt
  if(!all(t == sort(t)))  stop("t needs to be sorted")
  
  response <- match.arg(response)
  if (response == "upper") i <- 2L
  if (response == "lower") i <- 1L
  
  # Call the C code
  pvalues <- vector(length=length(t))    
  output <- .C("pfastdm_b", 
               as.integer (length(t)),               # 1  IN:  number of densities
               as.vector  (pl),                      # 2  IN:  parameters
               as.vector  (t),                       # 3  IN:  RTs
               as.double  (precision),               # 4  IN:  number of densities
               as.integer (i),                       # 5  IN:  boundary 
               as.vector  (pvalues, mode="numeric")  # 6 OUT:  pvalues
  )
  
  unlist(output[6])
  
}

test_that("ensure vectorised functions are equal to previous non-vectorised versions:", {
  
  # MATRIX VERSION: Set up parameter vectors
  test_vec_len <- 10
  vec_rts <- seq (1, 2.9, by=0.2)
  vec_bounds <- sample (c("upper","lower"), test_vec_len, replace=TRUE)
  
  vec_a   <- c(1,    1,    1,    2,    3,    3,    3,    4,    4,    4    )
  vec_z   <- rep (.20, test_vec_len)
  vec_v   <- rep (.30, test_vec_len)
  vec_t0  <- rep (.40, test_vec_len) 
  
  vec_d   <- rep (.50, test_vec_len)
  vec_sz  <- rep (.06, test_vec_len)
  vec_sv  <- rep (.70, test_vec_len)
  vec_st0 <- rep (.08, test_vec_len)
  
  correct_pdiffusion_vals <- vector(length=test_vec_len)
  correct_ddiffusion_vals <- vector(length=test_vec_len)
  for (i in 1:test_vec_len)
  {
    correct_pdiffusion_vals[i] <- old_pdiffusion(vec_rts[i], response=vec_bounds[i], a =vec_a[i], z=vec_z[i], v =vec_v[i], 
                               t0=vec_t0[i], d=vec_d[i], sz =vec_sz[i], sv=vec_sv[i], st0 = vec_st0[i])
    correct_ddiffusion_vals[i] <- old_ddiffusion(vec_rts[i], response=vec_bounds[i], a =vec_a[i], z=vec_z[i], v =vec_v[i], 
                               t0=vec_t0[i], d=vec_d[i], sz =vec_sz[i], sv=vec_sv[i], st0 = vec_st0[i])
  }  
  
  pdiffusions <- pdiffusion (vec_rts, response=vec_bounds, a=vec_a, z=vec_z*vec_a, v=vec_v, t0=vec_t0, d=vec_d, sz=vec_sz*vec_a, sv=vec_sv, st0=vec_st0)
  ddiffusions <- ddiffusion (vec_rts, response=vec_bounds, a=vec_a, z=vec_z*vec_a, v=vec_v, t0=vec_t0, d=vec_d, sz=vec_sz*vec_a, sv=vec_sv, st0=vec_st0)
  # Note: allow a lot of tolerance for pdiffusion difference due to sampling error 
  #       (should never be as high as 1e-3, though)
  #expect_that (pdiffusions, equals (correct_pdiffusion_vals, tolerance=1e-3)) # disabled due to wrong pdiffusion values initially (HS, 2016-05-19)
  expect_that (ddiffusions, equals (correct_ddiffusion_vals)) 
  
  # in the following code, z and sz are not adapted to absolute z scale.
  #pdiffusions2 <- pdiffusion (vec_rts, response=vec_bounds, a=vec_a, z=vec_z[1:sample(test_vec_len, 1)], v=vec_v[1:sample(test_vec_len, 1)], t0=vec_t0[1:sample(test_vec_len, 1)], d=vec_d[1:sample(test_vec_len, 1)], sz=vec_sz[1:sample(test_vec_len, 1)], sv=vec_sv[1:sample(test_vec_len, 1)], st0=vec_st0[1:sample(test_vec_len, 1)])
  ddiffusions2 <- ddiffusion (vec_rts, response=vec_bounds, a=vec_a, z=vec_z*vec_a, v=vec_v[1:sample(test_vec_len, 1)], t0=vec_t0[1:sample(test_vec_len, 1)], d=vec_d[1:sample(test_vec_len, 1)], sz=vec_sz*vec_a, sv=vec_sv[1:sample(test_vec_len, 1)], st0=vec_st0[1:sample(test_vec_len, 1)])
  #expect_that (pdiffusions2, equals (correct_pdiffusion_vals, tolerance=1e-3)) # disabled due to wrong pdiffusion values initially (HS, 2016-05-19)
  expect_that (ddiffusions2, equals (correct_ddiffusion_vals))
})


test_that("ensure vectorised functions are equal to previous non-vectorised versions (v2):", {
  
  n_test <- 20
  rts <- rdiffusion(n_test, a=1, z=0.5, v=2, t0=0.5, d=0, sz = 0, sv = 0, st0 = 0)
  
  correct_pdiffusion_vals <- vector("numeric", n_test)
  correct_ddiffusion_vals <- vector("numeric", n_test)
  for (i in seq(1, n_test, by = 2))
  {
    correct_pdiffusion_vals[i] <- old_pdiffusion(sort(rts[, "rt"])[i], response=as.character(rts[i, "response"]), a=1, z=0.5, v=2, t0=0.5, d=0, sz = 0, sv = 0, st0 = 0)
    correct_pdiffusion_vals[i+1] <- old_pdiffusion(sort(rts[, "rt"])[i+1], response=as.character(rts[i+1, "response"]), a=1.5, z=0.75, v=2.25, t0=0.4, d=0.1, sz = 0.1, sv = 0.1, st0 = 0.1)
    correct_ddiffusion_vals[i] <- old_ddiffusion(rts[i, "rt"], response=as.character(rts[i, "response"]), a=1, z=0.5, v=2, t0=0.5, d=0, sz = 0, sv = 0, st0 = 0)
    correct_ddiffusion_vals[i+1] <- old_ddiffusion(rts[i+1, "rt"], response=as.character(rts[i+1, "response"]), a=1.5, z=0.75, v=2.25, t0=0.4, d=0.1, sz = 0.1, sv = 0.1, st0 = 0.1)
  }  
  
  pdiffusions <- pdiffusion(sort(rts[, "rt"]), response=as.character(rts[, "response"]), 
                            a=c(1, 1.5), z=c(0.5, 0.75)*c(1, 1.5), v=c(2, 2.25), t0=c(0.5, 0.4), 
                            d=c(0,0.1), sz = c(0,0.1)*c(1, 1.5), sv = c(0,0.1), st0 = c(0, 0.1))
  ddiffusions <- ddiffusion (rts[, "rt"], response=as.character(rts[, "response"]), 
                             a=c(1, 1.5), z=c(0.5, 0.75)*c(1, 1.5), v=c(2, 2.25), t0=c(0.5, 0.4), 
                             d=c(0,0.1), sz = c(0,0.1)*c(1, 1.5), sv = c(0,0.1), st0 = c(0, 0.1))
  # Note: allow a lot of tolerance for pdiffusion difference due to sampling error 
  #       (should never be as high as 1e-3, though)
  #expect_equal(pdiffusions, correct_pdiffusion_vals, tolerance=1e-3) ## disabled due to wrong pdiffusion values initially (HS, 2016-05-19)
  expect_equal(ddiffusions, correct_ddiffusion_vals)
  
})


test_that("diffusion functions work with numeric and factor boundaries", {
  n_test <- 20
  rts <- rdiffusion(n_test, a=1, z=0.5, v=2, t0=0.5, d=0, sz = 0, sv = 0, st0 = 0)
  expect_is(ddiffusion(rts$rt, response = rts$response, a=1, z=0.5, v=2, t0=0.5, d=0, sz = 0, sv = 0, st0 = 0), "numeric")
  expect_is(pdiffusion(sort(rts$rt), response = rts$response, a=1, z=0.5, v=2, t0=0.5, d=0, sz = 0, sv = 0, st0 = 0), "numeric")
  expect_is(ddiffusion(rts$rt, response = sample(1:2, 20, replace = TRUE), a=1, z=0.5, v=2, t0=0.5, d=0, sz = 0, sv = 0, st0 = 0), "numeric")
  expect_is(pdiffusion(sort(rts$rt), response = sample(1:2, 20, replace = TRUE), a=1, z=0.5, v=2, t0=0.5, d=0, sz = 0, sv = 0, st0 = 0), "numeric")
  expect_error(ddiffusion(rts$rt, rep_len(1:3, length.out=20), a=1, z=0.5, v=2, t0=0.5, d=0, sz = 0, sv = 0, st0 = 0), "response")
  expect_error(pdiffusion(sort(rts$rt), rep_len(1:3, length.out=20), a=1, z=0.5, v=2, t0=0.5, d=0, sz = 0, sv = 0, st0 = 0), "response")
})

test_that("diffusion functions are identical with all input options", {
  rt1 <- rdiffusion(500, a=1, v=2, t0=0.5)
  # get density for random RTs:
  ref <- sum(log(ddiffusion(rt1$rt, rt1$response, a=1, v=2, t0=0.5)))  # response is factor
  expect_identical(sum(log(ddiffusion(rt1$rt, as.numeric(rt1$response), a=1, v=2, t0=0.5))),
                   ref)
  expect_identical(sum(log(ddiffusion(rt1$rt, as.character(rt1$response), a=1, v=2, t0=0.5))),
                   ref)
  expect_identical(sum(log(ddiffusion(rt1, a=1, v=2, t0=0.5))), ref)
  
  rt2 <- rt1[order(rt1$rt),]
  
  ref2 <- pdiffusion(rt2$rt, rt2$response, a=1, v=2, t0=0.5)
  expect_identical(pdiffusion(rt2$rt, as.numeric(rt2$response), a=1, v=2, t0=0.5), ref2)
  expect_identical(pdiffusion(rt2$rt, as.character(rt2$response), a=1, v=2, t0=0.5), ref2)
  expect_identical(pdiffusion(rt2, a=1, v=2, t0=0.5), ref2)
  
#   rt3 <- data.frame(p = rep(seq(0.1, 0.9, 0.2), 2),
#                     response = rep(c("upper", "lower"), each = 5))
  
  rt3 <- data.frame(p = rep(c(0.05, 0.1), 2),
                    response = rep(c("upper", "lower"), each = 2))
  ref3 <- qdiffusion(rt3$p, rt3$response, a=1, v=2, t0=0.5)
  expect_identical(qdiffusion(rt3$p, as.numeric(rt3$response), a=1, v=2, t0=0.5), ref3)
  expect_identical(qdiffusion(rt3$p, as.character(rt3$response), a=1, v=2, t0=0.5), ref3)
  expect_identical(qdiffusion(rt3, a=1, v=2, t0=0.5), ref3)
  
})


test_that("qdiffusion is equivalent to manual calculation",{
  p11_fit <- structure(list(par = structure(c(1.32060063610882, 3.27271614698074, 0.338560144920614, 0.34996447540773, 0.201794924457386, 1.05516829794661), .Names = c("a", "v", "t0", "sz", "st0", "sv"))))
  q <- c(0.1, 0.3, 0.5, 0.7, 0.9)
  
#   i_pdiffusion <- function(x, args, value, response) {
#     abs(value - do.call(pdiffusion, args = c(rt = x, args, response = response)))
#   }
  #pred_dir <- sapply(q*prop_correct, function(y) optimize(i_pdiffusion, c(0, 3), args = as.list(p11_fit$par), value = y, response = "upper")[[1]])

  expect_equal(qdiffusion(q, response = "upper", a=p11_fit$par["a"], v=p11_fit$par["v"], t0=p11_fit$par["t0"], sz=p11_fit$par["sz"]*p11_fit$par["a"], st0=p11_fit$par["st0"], sv=p11_fit$par["sv"], scale_p = TRUE),c(0.474993255765253, 0.548947327845059, 0.607841745594437, 0.681887193854516, 0.844859938530477), tolerance=0.0001)
  
  expect_equal(suppressWarnings(qdiffusion(q, response = "lower", a=p11_fit$par["a"], v=p11_fit$par["v"], t0=p11_fit$par["t0"], sz=p11_fit$par["sz"]*p11_fit$par["a"], st0=p11_fit$par["st0"], sv=p11_fit$par["sv"])),as.numeric(rep(NA, 5)))
})

test_that("s works as expected", {
  set.seed(1)
  x <- rdiffusion(n = 100, a = 1, v = 2, t0 = 0.3, z = 0.5, s = 1)
  set.seed(1)
  y <- rdiffusion(n = 100, a = 0.1, v = 0.2, t0 = 0.3, z = 0.05, s = 0.1)
  expect_identical(x, y)
  set.seed(1)
  z <- rdiffusion(n = 100, a = 0.1, v = 0.2, t0 = 0.3, s = 0.1)
  expect_identical(x, z)
  expect_identical(
    ddiffusion(x[x$response == "upper", "rt"], a = 1, v = 2, t0 = 0.3, z = 0.5, s=1), 
    ddiffusion(x[x$response == "upper", "rt"], a = 0.1, v = 0.2, t0 = 0.3, z = 0.05, s=0.1)
    )
  expect_identical(
    ddiffusion(x[x$response == "upper", "rt"], a = 1, v = 2, t0 = 0.3, z = 0.5, s=1), 
    ddiffusion(x[x$response == "upper", "rt"], a = 0.1, v = 0.2, t0 = 0.3, s=0.1)
    )
  expect_identical(
    pdiffusion(sort(x[x$response == "upper", "rt"]), a = 1, v = 2, t0 = 0.3, z = 0.5, s=1),
    pdiffusion(sort(x[x$response == "upper", "rt"]), a = 0.1, v = 0.2, t0 = 0.3, z = 0.05, s=0.1)
  )
  expect_identical(
    pdiffusion(sort(x[x$response == "upper", "rt"]), a = 1, v = 2, t0 = 0.3, z = 0.5, s=1),
    pdiffusion(sort(x[x$response == "upper", "rt"]), a = 0.1, v = 0.2, t0 = 0.3, s=0.1)
  )
  expect_identical(
    qdiffusion(0.6, a = 1, v = 2, t0 = 0.3, z = 0.5, s=1),
    qdiffusion(0.6, a = 0.1, v = 0.2, t0 = 0.3, z = 0.05, s=0.1)
  )
  expect_identical(
    qdiffusion(0.6, a = 1, v = 2, t0 = 0.3, z = 0.5, s=1),
    qdiffusion(0.6, a = 0.1, v = 0.2, t0 = 0.3, s=0.1)
  )
})

test_that("scale_p works as expected", {
  (max_p <- pdiffusion(20, a=1, v=2, t0=0.5, st0=0.2, sz = 0.1, sv = 0.5, response="u"))
  # [1] 0.8705141
  # to get predicted quantiles, scale required quantiles by maximally predicted response rate:
  qs <- c(.1, .3, .5, .7, .9)
  expect_equal(qdiffusion(qs*max_p, a=1, v=2, t0=0.5, st0=0.2, sz = 0.1, sv = 0.5, response="u"),
                    qdiffusion(qs, a=1, v=2, t0=0.5, st0=0.2, sz = 0.1, sv = 0.5, response="u", scale_p = TRUE))
  
})

test_that("rdiffusion recovers Table 1 from Wagenmakers et al. (2007)", {
  set.seed(2)
  n <- 1e4 # number of samples
  # take parameter valeus from Table 2 and set s to 0.1
  george <- rdiffusion(n, a = 0.12, v = 0.25, t0 = 0.3, s = 0.1)
  rich   <- rdiffusion(n, a = 0.12, v = 0.25, t0 = 0.25, s = 0.1)
  amy    <- rdiffusion(n, a = 0.08, v = 0.25, t0 = 0.3, s = 0.1)
  mark   <- rdiffusion(n, a = 0.08, v = 0.25, t0 = 0.25, s = 0.1)
  
  george$id <- "george"
  rich$id <- "rich"
  amy$id <- "amy"
  mark$id <- "mark"
  
  wag <- rbind(george, rich, amy, mark)
  wag$id <- factor(wag$id, levels = c("george", "rich", "amy", "mark"))
  
  expect_equal(aggregate(rt ~ id, wag, mean)$rt, c(0.517, 0.467, 0.422, 0.372), tolerance = 0.003)
  
  expect_equal(aggregate(as.numeric(response)-1 ~ id, wag, mean)[,2], c(0.953, 0.953, 0.881, 0.881), tolerance = 0.01)
  
  expect_equal(aggregate(rt ~ id, wag, var)$rt, c(0.024, 0.024, 0.009, 0.009), tolerance = 0.003)
})


test_that("pdiffusion recovers proportions of Table 1 from Wagenmakers et al. (2007)", {
  
  props <- pdiffusion(rep(Inf, 4), a = rep(c(0.12, 0.08), each = 2), v = 0.25, t0 = c(0.3, 0.25), s = 0.1)
  expect_equal(props, c(0.953, 0.953, 0.881, 0.881), tolerance = 0.001)
  
  props <- pdiffusion(rep(Inf, 4), a = rep(c(0.12, 0.08), each = 2), v = 0.25, t0 = c(0.3, 0.25), z = rep(c(0.06, 0.04), each = 2), s = 0.1)
  expect_equal(props, c(0.953, 0.953, 0.881, 0.881), tolerance = 0.001)
})
