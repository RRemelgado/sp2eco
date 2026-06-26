#' Map Dirichlet distribution parameters
#' @param x character vector with paths to species range maps in a grid format.
#' @param y character vector with ecosystem types for each entry in \emph{y}.
#' @param lambda numeric vector with distance decay parameters.
#' @param path directory where to store outputs.
#' @param verbose Logical argument. Should progress be reported?
#' @return A SpatRaster.
#' @details {Estimates empirical probabilities for a set of each types (given by
#' \emph{y}). First, for each unique ecosystem type, the range maps of inhabiting
#' species (given by \emph{x}) are summed. The sum is weighted using a distance
#' decay function, where the strength of decay is controlled by the argument
#' \emph{lambda}. Second, the empirical probability of each ecosystem type is
#' given by the ratio between the ecosystem-specific weighted count and the sum
#' of all weighted counts. Third, for each raster cell, shape parameters for
#' the Dirichlet conjugate prior (alpha) are on the mean and standard deviation
#' of the empirical ecosystem occurrence probabilities derive for each lambda.
#' Note that intermediate outputs (i.e., weighted sums, probability maps) are
#' written into \emph{path}.}
#' @importFrom terra rast app writeRaster
#' @importFrom utils txtProgressBar setTxtProgressBar
#' @importFrom checkmate assert checkNumeric checkFileExists checkDirectory checkLogical
#' @export

# load packages ----
#-----------------------------------------------------------------------------#

range_prior = function(x, y, lambda, path, verbose=T) {

  # check arguments ----
  #---------------------------------------------------------------------------#

  assert(checkFileExists(x, access="r"),
         checkNumeric(y, len=length(x)),
         checkNumeric(lambda),
         checkDirectory(path, access="r"),
         checkLogical(verbose))

  if (!dir.exists(path)) {
    warning('creating path for outputs')
    dir.create(path)
  }

  # derived weighted species counts per ecosystem type ----
  #---------------------------------------------------------------------------#

  # unique ecosytem types
  eco = unique(y)

  if (verbose)
    pb = txtProgressBar(min=1, max=length(eco)*length(lambda),
                        style=3, title="mapping weighted counts")

  index = 1
  for (e in eco) {

    # stack range maps
    rm = rast(x[which(y == e)])

    for (l in lambda) {

      # lambda name string
      n = format(round(abs(l),2), nsmall=2)

      # derive and save weighted sum for l
      r = app(rm, function(i) sum(exp(l * (i[i > 0] - 1)), na.rm=T))
      o = file.path(path, paste0(e, "_l", n, "_weightedSum.tif"))
      writeRaster(r, o, overwrite=T)

      if (verbose) setTxtProgressBar(pb, index)
      index = index + 1

    }
  }

  if (verbose) close(pb)

  # derive empirical probabilities for each ecosystem type ----
  #---------------------------------------------------------------------------#

  if (verbose)
    pb = txtProgressBar(min=1, max=length(lambda),
                        style=3, title="mapping occurrence probabilities")

  index = 1
  for (l in lambda) {

    # lambda name string
    n = format(round(abs(l),2), nsmall=2)

    # load weight sum maps
    ws = rast(file.path(path, paste0(eco, "_l", n, "_weightedSum.tif")))

    # sum maps
    tw = app(ws, sum)

    # divide weighted sums by total to obtain empirical probabilities
    p = ws / tw

    # export each probability map separately
    for (i in 1:length(eco)) {
      o = file.path(path, paste0(eco[i], "_l", n, "_probability.tif"))
      writeRaster(p[[i]], o, overwrite=T)
    }

    if (verbose) setTxtProgressBar(pb, index)
    index = index + 1

  }

  if (verbose) close(pb)

  # write mean and SD of estimated probabilities ----
  #---------------------------------------------------------------------------#

  if (verbose)
    pb = txtProgressBar(min=1, max=length(lambda), style=3,
                        title="estimate meana and variance of probabilities")

  index = 1
  for (e in eco) {

    # load probability layers
    r = rast(list.files(path, paste0(e, "_l.*._probability.tif"), full.names=T))

    # estimate/save mean
    o = file.path(path, paste0(e, "_probability_mean.tif"))
    writeRaster(app(r, "mean", na.rm=T), o, overwrite=T)

    # estimate/save SD
    o = file.path(path, paste0(e, "_probability_var.tif"))
    writeRaster(app(r, "var", na.rm=T), o, overwrite=T)

    if (verbose) setTxtProgressBar(pb, index)
    index = index + 1

  }

  if (verbose) close(pb)

  # estimate Dirichlet distribution parameters for each pixel ----
  #---------------------------------------------------------------------------#

  # load probability layers (mean)
  p_mean = rast(file.path(path, paste0(eco, "_probability_mean.tif")))
  names(p_mean) = eco

  # load probability layers (var)
  p_var = rast(file.path(path, paste0(eco, "_probability_var.tif")))
  names(p_var) = eco

  # estimate parameters
  if (verbose) message("estimating Dirichlet distribution parameters")
  d_par = dirichlet_alpha(p_mean, p_var)
  names(d_par) = eco
  return(d_par)

}
