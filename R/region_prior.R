#' Derive regional Dirichlet distribution parameters
#' @param x 2-column data.frame with 'species' and occurrence 'region'.
#' @param y {3-column data.frame with 'species', their 'habitat' associations,
#' and the thematic 'group' of each 'habitat' type in the respective typology.}
#' @param lambda distance decay parameter.
#' @return A data.frame.
#' @details {Estimates empirical probabilities for each ecosystem type
#' distinguished in \emph{y}. First, for each unique ecosystem type, the
#' number of species using it as a habitat is recorded. This count is
#' weighted with a distance-decay function, where the strength of decay
#' is controlled by \emph{lambda}. Second, the empirical probability of
#' each ecosystem type is given by the ratio between the ecosystem-specific
#' weighted count and the sum of all weighted counts. The function returns
#' a data.frame with the following columns:
#' \describe{
#'  \item{ecosystem}{ecosystem type used as a habitat.}
#'  \item{w}{weighted species count.}
#'  \item{p}{emprirical probability of target 'ecosystem' occurring in the given 'region'.}
#'  \item{group}{Thematic group of the given 'ecosystem' types.}
#'  \item{region}{region within which empirical probabiltiies were estimated.}
#'}}
#' @importFrom plyr ddply summarize as.quoted
#' @importFrom utils txtProgressBar setTxtProgressBar
#' @importFrom dampack dirichlet_params
#' @importFrom checkmate assert checkDataFrame checkNumeric
#' @importFrom stats var
#' @export

# load packages ----
#-----------------------------------------------------------------------------#

region_prior = function(x, y, lambda) {

  # check arguments
  assert(
    checkDataFrame(x, col.names=c("species","region"), any.missing=F),
    checkDataFrame(y, col.names=c("species","habitat","group"), any.missing=F),
    checkNumeric(lambda))

  # remove duplicates
  x = x[!duplicated(x),]
  y = y[!duplicated(y),]

  # derive weighted species counts for each ecosystem type ----
  #---------------------------------------------------------------------------#

  # infer number of habitat associations per species
  nh = ddply(y, .variables=as.quoted("species"),
             summarize, n=length(unique(as.quoted("habitat"))))
  x$n = nh$n[match(x$species, nh$species)] # math to region checklist

  # reduce species to regions with weighted sums
  tmp = do.call(rbind, lapply(lambda, function(l) {
    do.call(rbind, lapply(unique(y$habitat), function(h) {
      ti = which(x$species %in% y$species[y$habitat == h])
      oa = ddply(x[ti,], .variables=as.quoted("region"),
                 summarize, w=sum(exp(l*(as.quoted("n")-1)),na.rm=T))
      oa$ecosystem = h
      oa$lambda = l
      return(oa)
    }))}))

  # add group information to weighted sum
  tmp$group = y$group[match(tmp$ecosystem,y$habitat)]

  rm(x,y)

  # derive occurrence probabilities ----
  #---------------------------------------------------------------------------#

  tmp$p = 0
  for (g in unique(tmp$group)) {
    for (l in lambda) {
      ti = which((tmp$group == g) & (tmp$lambda == l))
      tmp$p[ti] = tmp$w[ti] / sum(tmp$w[ti])
    }
  }

  # reduce to mean and var ----
  #---------------------------------------------------------------------------#

  tmp = ddply(tmp, .variables=as.quoted(c("region","group","ecosystem")),
              summarize, p_mean=mean(as.quoted("p"),na.rm=T),
              p_var=var(as.quoted("p"),na.rm=T))

  # estimate Dirichlet parameters ----
  #---------------------------------------------------------------------------#

  tmp$total_alpha = tmp$alpha = 0

  for (r in unique(tmp$region)) {
    for (g in unique(tmp$group)) {

      # find entries to update
      ti = which((tmp$region == r) & (tmp$group == g))

      # estimate shape parameter (alpha)
      tmp$alpha[ti] = dirichlet_params(tmp$p_mean[ti], tmp$p_var[ti])

      # add to total alpha
      tmp$total_alpha[ti] = sum(tmp$alpha[ti])

    }
  }

  return(tmp)

}
