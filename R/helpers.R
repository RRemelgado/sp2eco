#' Estimates the precision of lat/lon coordinates
#' @param x 2-column matrix with observation coordinates.
#' @param y Numeric vector with uncertainty of coordinates in \emph{x}.
#' @param verbose Logical argument on whether progress should be reported.
#' @importFrom CoordinateCleaner clean_coordinates
#' @importFrom utils data setTxtProgressBar
#' @importFrom checkmate assert checkMatrix checkNumeric
#' @return A logical vector.
#' @details {Measures the precision (in meters) of lat/lon
#' coordinate pairs (given by \emph{x}) based on their decimal precision.
#' Existing coordinate precision values (given by \emph{y} are added.)}
#' @export

coordinate_precision = function(x, y, verbose=T) {

  # check arguments
  assert(checkMatrix(x, ncols=2), checkNumeric(y, len=nrow(x)))

  # estimate coordinate uncertainty ----
  #---------------------------------------------------------------------------#

  # if missing, set to 0
  y[is.na(y)] = 0

  if (verbose) pb = txtProgressBar(
    min=1, max=nrow(x), style=3, title="estimating coordinate precision")

  for (i in 1:nrow(x)) {

    # count decimals in the longitude
    r = strsplit(sprintf("%1.5f", x[i,1]), "[.]")[[1]][2]
    d = strsplit(r, "")[[1]]
    l = rle(d)$lengths
    l[length(l)] = 1
    nx = sum(l)

    # count decimals in the latitude
    r = strsplit(sprintf("%1.5f", x[i,2]), "[.]")[[1]][2]
    d = strsplit(r, "")[[1]]
    l = rle(d)$lengths
    l[length(l)] = 1
    ny = sum(l)

    # precision of latitude
    # NOTE: 5 decimal places ideal (1-m precision)
    lat_p = 10^(5-min(c(nx,ny)))

    # the precision of the longitude ongitude shrinks by cos(latitude)
    lon_p = lat_p * cos(x[i,2] * pi/180)

    # record precision
    y[i] = y[i] + mean(c(lat_p, lon_p))
    rm(lat_p, lon_p)

    if (verbose) setTxtProgressBar(pb, i)

  }

  return(y)

}

#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#

#' Test if species observations are contained in pixels.
#' @param x 2-column matrix with coordinate pairs.
#' @param y Spatial precision of each coordinate pair (in meters).
#' @param resolution Numeric vector with targeted pixel resolutions (in degrees).
#' @importFrom terra rast extract xyFromCell cellFromXY ext
#' @importFrom checkmate assert checkMatrix checkNumeric
#' @return A logical vector.
#' @details {Tests whether species observations (provided through \emph{x})
#' are contained in a pixel when accounting for their position in that pixel
#' and their coordinate uncertainty (given by \emph{y}). A coordinate pair
#' is said to be contained' if the buffer drawn around it by the respective
#' coordinate uncertainty does not extend beyond the boundaries of the pixel.}
#' @export

containment_test = function(x, y, resolution) {

  # check arguments ----
  #---------------------------------------------------------------------------#

  assert(
    checkMatrix(x, min.cols=2, any.missing=F),
    checkNumeric(y, len=nrow(x)),
    checkNumeric(resolution)
  )

  # apply resolution condition and update species names ----
  #---------------------------------------------------------------------------#

  # build reference grid(s) with target resolution(s)
  reference = rast(lapply(resolution, function(r)
    rast(ext(-180,180,-90,90), res=r, crs="epsg:4326")))

  # check cell membership ----
  #---------------------------------------------------------------------------#

  # estimate earth radius for each observation latitude
  lat_radius = earth_radius(as.vector(x[,2]))

  # convert coordinate uncertainty to degrees
  lon_u = y /((lat_radius * cos(x[,2]*pi/180) * pi / 180))
  lat_u = y / (lat_radius * pi / 180)

  # test results
  check = rep(FALSE,nrow(x))
  map_res = rep(0,nrow(x))

  # evaluate each focal resolution
  for (r in 1:length(resolution)) {

    # cases that have not yet passed the check
    ind  = which(!check)
    if (length(ind) == 0) next

    # infer cell of each observation
    cell = cellFromXY(reference[[r]], x[ind,])

    # get coordinates of cell centroid
    cxy = xyFromCell(reference[[r]], cell)

    # check which observations match the resolution criteria
    # also exclude duplicated records
    ind = ind[which(

      # duplicate check
      !duplicated(cell) &
        ((x[,1]+lon_u) < cxy[,1]+(resolution/2)) &
        ((x[,1]-lon_u) > cxy[,1]-(resolution/2)) &
        ((x[,2]+lat_u) < cxy[,2]+(resolution/2)) &
        ((x[,2]-lat_u) > cxy[,2]-(resolution/2)))]

    # updated check and record resolution
    check[ind] = TRUE
    map_res[ind] = r

  }

  return(data.frame(check=check, cell=cell, resolution=map_res))

}

#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#

#' Find optimal entropy threshold
#' @param x A \emph{sparRaster} object.
#' @param n Number of bins to create.
#' @return A numeric element.
#' @details {For a \emph{spatRaster} object with probabilities between 0 and 1,
#' the function uses the workflow proposed by Kapur et al. (1985) to identify
#' the optimal maximum threshold to filter-out noise. For each map of empirical
#' ecosystem occurrence probabilities, we iterate through the distribution of those
#' probabilities defined by \emph{n} bins. At each bin (b), we distinguish pixels
#' with values below and above b and, for each of those groups (g), compute the
#' entropy (H) as  \eqn{\sum_{n=1}^{\infty} \frac{p_i}[P_b] * \log{\frac{p_b(g)}{P_b(g)}}}.
#' Here, \eqn{p_b(g)} is the normalized histogram value of a given bin belonging to the
#' focal group, and \eqn{P_b(g)} is the total probability mass function of the group.
#' After all iterations, the threshold which maximizes the total H between groups
#' is used as a cut-off value. Values above the threshold are preserved, consisting
#' of spatially coherent, high-probability pixels.}
#' @importFrom graphics hist
#' @importFrom checkmate assertTRUE
#' @references
#' Kapur, J. N. … Wong, A. K. C. (1985).
#' A new method for gray-level picture thresholding using the entropy of the histogram.
#' Computer Vision, Graphics, and Image Processing, 29(3), 273–285.
#' https://doi.org/10.1016/0734-189X(85)90125-2
#' @export

entropy_threshold = function(x, n=100) {

  # check argument
  assertTRUE(isa(x,"SpatRaster") | is.numeric(x))
  xc = class(x)[[1]]

  # estimate entropy threshold ----
  #---------------------------------------------------------------------------#

  if (xc == "SpatRaster") {
    # Read the image file, scale its values by 256, and convert it to a vector
    x = as.vector(x)
  }

  # remove NA values
  x[is.na(x)] = 0

  # normalized histogram
  h = hist(x, breaks=seq(0,1,length.out=n), plot = FALSE)
  p = h$counts / sum(h$counts)
  l = length(p)

  # iterate through each bin and record total entropy
  total_h = rep(0,l)
  for (b in 2:l) {

    # probabilities for two classes
    p0 = p[1:(b-1)] # background
    p1 = p[b:l] # foreground

    # sum of probabilities
    w0 = sum(p0)
    w1 = sum(p1)

    # estimate entropy values
    h0 = -sum((p0/w0) * log(p0/w0 + 1e-10))
    h1 = -sum((p1/w1) * log(p1/w1 + 1e-10))
    total_h[b] = h0 + h1

  }

  # return maximum entropy threshold
  return(h$breaks[which.max(total_h)+1])

}

#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#

#' Estimate Earth's radius
#' @param x A \emph{numeric} vector with latitudes (in degrees).
#' @return Earth radius estimates for each element in \emph{x} (in meters).
#' @importFrom checkmate assertNumeric
#' @details
#' The radius of the Earth varies with latitude. Equatorial radius is ~6,378 km,
#' while the polar radius is ~6,357 km. At a given latitude, given by \emph{x},
#' the radius of the Earth is given by
#' \eqn{\sqrt{\frac{(a^2*cos(Φ))^2 + (b^2 * sin(Φ))^2}[a * cos(Φ))^2 + (b + sin(Φ))^2)}}
#' where \emph{a} is the equatorial radius, \emph{b} is the polar radius, and
#' \emph{Φ} is the latitude in radians.
#' @export

earth_radius = function(x) {

  # check input
  assertNumeric(x)

  # WGS-84 ellipsoidal constants
  a = 6378137.0 # equatorial radius (m)
  b = 6356752.3 # polar radius (m)

  # Convert latitude to radians
  x_rad = x * pi / 180

  # Calculate radius (uses formula from Geodetic Reference System)
  r = sqrt(((a^2 * cos(x_rad))^2 + (b^2 * sin(x_rad))^2) /
             ((a * cos(x_rad))^2 + (b * sin(x_rad))^2))

  return(r)

}

#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#

#' Estimates, or maps, Dirichlet distribution parameters
#' @param x numeric vector or a multi-layered \emph{SpatRaster} object.
#' @param y numeric vector or a multi-layered \emph{SpatRaster} object.
#' @importFrom dampack dirichlet_params
#' @importFrom terra cellFromXY
#' @importFrom checkmate assert checkClass checkFALSE
#' @return A numeric vector or a set of SpatRaster objects.
#' @details {Estimates distribution parameters for each pixel, or across
#' all values, based on the mean (\emph{x}) and variance (\emph{y} of
#' estimate empirical probabilities of ecosystem occurrences.}
#' @export

dirichlet_alpha = function(x, y) {

  assert(checkClass(x, classes=c("SpatRaster","numeric")),
         checkClass(y, classes=c("SpatRaster","numeric")),
         checkFALSE(isa(x, "SpatRaster") & !isa(y, "SpatRaster")),
         checkFALSE(isa(x, "SpatRaster") & !isa(y, "SpatRaster")))

  if (class(x)[[1]] == "SpatRaster") {

    # infer which pixels to use
    cell = which(as.vector(app(x, max)) > 0)
    xy = xyFromCell(x[[1]], cell)
    o = x[[1]]*0

    ## extract values for each pixel
    z = names(x)
    x = extract(x, xy)
    y = extract(y, xy)

    # estimate alpha parameters for each class
    da = do.call(rbind, lapply(1:nrow(xy), function(i) {
      data.frame(class=z, cell=cell[i],
                 alpha=dirichlet_params(
                   unlist(x[i,]), unlist(y[i,])))}))

    # map and export parameters
    o = rast(lapply(z, function(e) {
      i = which(da$class == e)
      r = o
      names(r) = e
      r[da$cell[i]] = da$alpha[i]
      return(r)
    }))

    return(o)

  } else {

    # estimate alpha parameters for each class
    return(data.frame(alpha=dirichlet_params(x, y)))

  }

}

#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#

#' Derived weighted sum of distance weights
#' @param x numeric vector of counts.
#' @param lambda numeric vector of distance-decay parameters.
#' @importFrom checkmate assert checkNumeric
#' @importFrom stats var
#' @return a named vector with a mean and standard deviation.
#' @details {Estimates the mean and standard deviation of the sum of
#' \emph{x} after applying an exponential distance decay function. The
#' number of iterations is equal to the length of \emph{lambda}, which
#' control the strength of the decay with higher values in \emph{x}. The
#' function returns the mean and variance of the total weights for each lambda.}
#' @export

weighted_sum = function(x,lambda) {

  # check arguments
  assert(checkNumeric(x), checkNumeric(lambda))

  # return possible weights
  v = do.call(cbind, lapply(lambda, function(l) exp(l*(x-1))))

  # derive mean & variance of weights
  return(data.frame(mean=apply(v, 1, mean), var=apply(v, 1, var)))

}
