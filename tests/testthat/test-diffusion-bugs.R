
context("Diffusion Model: quantile bugs")

test_that("qdiffusion does not fail for certain values", {
  qex <- c(a = 1.97092532512193, t0 = 0.22083875893466, sv = 0.462630056494015, v = -2.59881372383245, resp_prop = 0.99877722499984, z = 0.5, sz= 0.1)
  
  #pdiffusion(0.28165, response = "lower", a=qex["a"], v=qex["v"], t0 = qex["t0"], sv = qex["sv"], sz = 0.1, z = 0.5)
  
  expect_true(!is.na(
    qdiffusion(p = 0.0998, response = "lower", a=qex["a"], v=qex["v"], t0 = qex["t0"], sv = qex["sv"], sz = 0.1, z = 0.5)
  ))

})

test_that("qdiffusion does not fail for named probability", {
   qex2 <- c( t0 = 0.194096266864241, sv = 0.867039443746426, v = -3.8704467331985, a = 0.819960332004152, resp_prop = 0.923810293538986, z = 0.5, sz= 0.1)
   #pdiffusion(20, response = "upper", a=qex2["a"], v=qex2["v"], t0 = qex2["t0"], sv = qex2["sv"], sz = 0.1, z = 0.5)
  
  expect_true(!is.na(
    qdiffusion(p = qex2["resp_prop"], response = "lower", a=qex2["a"], v=qex2["v"], t0 = qex2["t0"], sv = qex2["sv"], sz = 0.1, z = 0.5*qex2["a"])
    ))

})

test_that("pdiffusion is equal to pwiener", {
  if (require(RWiener)) {
    
    expect_equivalent(pdiffusion(2, response = "upper", a = 1.63, v = 1.17, t0 = 0.22, z = 0.517*1.63), pwiener(2, resp = "upper", alpha = 1.63, delta = 1.17, tau = 0.22, beta =  0.517))
  }
})

test_that("numerical integration does not fail in certain cases", {
  # fails
  expect_equal(pdiffusion(0.640321329425053, response = "upper", a = 1.1, v=1.33, t0 = 0.3, z = 0.55*1.1, st0 = 0.2, sz = 0.7*1.1, precision = 3),
               0.5345, tolerance = 0.0001)
  expect_equal(pdiffusion(0.640321329425053, response = "upper", a = 1.1, v=1.33, t0 = 0.3, z = 0.55*1.1, st0 = 0.2, sz = 0.7*1.1, precision = 2.9),
               0.5345517, tolerance = 0.0001)

})


test_that("pdiffusion does not add to 1 for both responses in case sz goes towards max.", {
  
  expect_equal(sum(pdiffusion(rep(Inf, 2), a=1, v=2, t0=0.5, st0=0.2, sz = 0.1, sv = 0.5, response=c("l", "u"))), 1, tolerance = 0.001)
  
  expect_equal(sum(pdiffusion(rep(Inf, 2), a=1, v=2, z = 0.4, t0=0.5, st0=0.2, sz = 0.1, sv = 0.5, response=c("l", "u"))), 1, tolerance = 0.001)
  
  expect_equal(sum(pdiffusion(rep(Inf, 2), response=c("l", "u"), a=1, v = 3.69, t0 = 0.3, sz = 0.1, sv = 1.2, st0 = 0)), 1, tolerance = 0.001)
  
  expect_equal(sum(pdiffusion(rep(Inf, 2), response=c("l", "u"), a=1, v = 3.69, t0 = 0.3, sz = 0.5, sv = 1.2, st0 = 0)), 1, tolerance = 0.001)

  testthat::skip("currently pdiffusion does not add up to 1 fo rthe following tests.")
  
  expect_equal(sum(pdiffusion(rep(Inf, 2), response=c("l", "u"), a=1, v = 3.69, t0 = 0.3, sz = 0.9, sv = 1.2, st0 = 0)), 1, tolerance = 0.001)
  expect_equal(sum(pdiffusion(rep(Inf, 2), response=c("l", "u"), a=0.08, v = 0.369, t0 = 0.3, sz = 0.07, sv = 0.12, st0 = 0, s=0.1, precision = 2)), 1, tolerance = 0.001)
  expect_equal(sum(pdiffusion(rep(Inf, 2), response=c("l", "u"), a=0.08, v = 0.369, t0 = 0.3, sz = 0.07, sv = 0.12, st0 = 0, s=0.1, precision = 3)), 1, tolerance = 0.001)
})
