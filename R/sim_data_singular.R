#' Simulate Data from Eigenvalue Structure
#'
#' The function returns either the results of penalized profile
#'    log-likelihood given a matrix of data or a vector of sample
#'    eigenvalues. The data matrix has the following decomposition
#'    \eqn{ X = WL + error}, where the rows of \eqn{X} are linear
#'    projections onto the subspace \eqn{ W } by some arbitrary latent
#'    vector plus error. The solution finds the rank of \eqn{W}, which
#'    represents the hidden structure in the data, such that \eqn{ X-WL }
#'    have independent and identically distributed components.
#'
#' @param N the full dimension of the data
#' @param K the true dimension of the
#' @param M the number of features of observations
#' @param sq_singular a vector of numeric values for the squared singular values.
#'    The other parameters can be skipped if this is supplied along with \eqn{N, K, M}.
#' @param sigma2 a positive numeric between 0 and 1 for the error variance.
#' @param last a positive numeric within reasonable range for the difference
#'    between the Kth eigenvalue and the (\eqn{K}+1)th, a very large difference
#'    might not be possible if \eqn{K} is large.
#' @param trend a character, one of \code{exponential}, \code{linear} and \code{quadratic}
#'   for the type of trend in squared singular values
#' @param rho a numeric value between 0 and 1 for the amount of auto-correlation, i.e. correlation
#'   between sequential observations or features.
#' @param dist a character specifying the error distribution to be one of \code{norm}, \code{t},
#'    for normal and student's t-distribution, respectively.
#' @param df an integer for the degrees of freedom if \code{dist} == \code{t}
#' @param datamat a logical to indicate whether both the data matrix and
#'    sample eigenvalues or only the sample eigenvalues should be returned
#'
#' @return a list containing the simulated data matrix and
#'    sample eigenvalues or a numerical vector of sample eigenvalues.
#'
#' @importFrom MASS mvrnorm
#' @importFrom mvtnorm rmvt
#' @importFrom Matrix nearPD
#' @importFrom pracma randortho
#'
#' @examples
#' \dontrun{
#' get_data_singular(N = 200, K = 5, M = 1000, sq_singular = c(5,4,2,1,1))
#' get_data_singular(N = 200, K = 5, M = 1000, sigma2 = 0.2, last= 0.1, trend = "exponential")
#' get_data_singular(N = 200, K = 5, M = 1000, sigma2 = 0.8, last= 0.1, trend = "exponential",
#'    rho = 0.2, df = 5, dist = "t")
#' }
#' @author Wei Q. Deng, \email{deng@utstat.toronto.edu}
#'
#'

get_data_singular <- function(N, K, M, sq_singular = NULL,
                              sigma2 = NULL, last= NULL, trend = NULL,
                              rho = NULL, df = NULL, dist = "norm",
                              datamat = TRUE) {

    if (K <= 0 | M <= 0 | N <= 0){
      stop("Please ensure all of N, K, and M are positive integers")
    }

    if (K >= N | K >= M) {
      stop("Please supply an integer K smaller than both N and M")
    }

  N <- as.integer(N);
  K <- as.integer(K);
  M <- as.integer(M);

  if(is.null(sq_singular)){

    if (sigma2 > 1 | sigma2 <= 0){
      stop("Please supply a sigma2 value between 0 and 1")
    }

    sigma2 <- as.numeric(sigma2)
    null_lambda <- rep(sigma2, N)
    d2 <- rep(NA, K)

    if (trend == "linear"){
      d2[K] <- last
      remain_var <- N-sigma2*N
      try(if(remain_var < 0) stop("not enough variance left for the first K-1 eigenvalues"));
      b = (remain_var - (K-1)*d2[K])/(K*(K-1))*2
      d2[1:(K-1)] <- d2[K] + b*(K-(1:(K-1)))

    } else if (trend == "quadratic") {
      d2[K] <- last
      remain_var <- N-sigma2*N
      try(if(remain_var < 0) stop("not enough variance left for the first K-1 eigenvalues"));
      b = (remain_var - (K-1)*d2[K])/(K*(K-1)*(K-1/2))*3
      d2[1:(K-1)] <- d2[K] + b*(K-(1:(K-1)))^2

    } else if (trend == "exponential"){
      d2[K] <- last
      remain_var <- N-sigma2*N
      solve_exp <- function(r){
        (1-r^(K-1))*d2[K] - r^(K-1)*(1-r)*(remain_var)
      }
      r <- stats::uniroot(solve_exp, c(0.0001,1-0.0001))$root
      d2[2:(K-1)] <- d2[K]/r^(K-2:(K-1));
      d2[1] <- remain_var - sum(d2[-1])
      d2 <- sort(d2, decreasing=T)
    }

    if (dist == "norm"){

      lambda <- sort(null_lambda + c(d2, rep(0, N - K)), decreasing = T)
      singular <- d2
      U <- pracma::randortho(N)[,1:K]
      S <- U%*%diag(singular)%*%t(U) + diag(rep(sigma2, N))
      X <- MASS::mvrnorm(M, mu = rep(0,N), Sigma = S)
      sam_eigen <- eigen(as.matrix(Matrix::nearPD((scale(X)))$mat))$val

    }else{

      errorT <- mvtnorm::rmvt(M, sigma = diag(sigma2, N), df = df)

      error_AR <- errorT
      error_AR[1, ] <- errorT[1, ]
      for(m in 2:M){
        error_AR[m, ] <- error_AR[(m - 1), ]*rho + errorT[m, ]
      }
      L <- MASS::mvrnorm(M, mu=rep(0, K), Sigma = diag(1, K), empirical=T) # M by N
      A <- diag(d2) # K by K
      W <- pracma::randortho(N) # N by N
      X <- ((W[,1:K]%*%sqrt(A))%*%t(L)) + t(error_AR)
      sam_eigen <- eigen(as.matrix(Matrix::nearPD(stats::cov(scale(t(X))))$mat))$val
    }


  }else{

    if (!is.numeric(sq_singular) | length(sq_singular) != K ){
      stop("Please ensure singular is a numerical vector of length K")
    }

    if (sum(sq_singular) >= N ){
      stop("Please ensure sum of the squared singular values is less than N,
           the total amount of standardized variance")
    }

    sigma2 <- 1 - sum(sq_singular)/N

    U <- pracma::randortho(N)[, 1:K]
    S <- U %*% diag(sq_singular) %*% t(U) + diag(rep(sigma2, N))
    SS <- as.matrix(Matrix::nearPD(S)$mat)
    X <- MASS::mvrnorm(M, mu = rep(0, N), Sigma = SS)
    sam_eigen <- eigen(as.matrix(Matrix::nearPD(stats::cov(scale(X)))$mat))$val
  }


    if (datamat == TRUE) {
        return(list(X, sam_eigen))
    } else {
        return(sam_eigen)
    }
}
