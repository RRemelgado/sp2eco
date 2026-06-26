#-----------------------------------------------------------------------------#
#' Estimate Earth radius
#' @param latitude Target latitude.
#' @return The radius of the Earth.
#' @details Estimates the radius of the earth at a given latitude.
#' @export
#-----------------------------------------------------------------------------#

latitude_radius = function(latitude) {

  # Define constants
  Re = 6378.137  # Equatorial radius in km
  Rp = 6356.752  # Polar radius in km

  # Convert latitude to radians
  phi = latitude * pi / 180

  # Calculate the radius using the formula
  radius = sqrt(((Re^2 * cos(phi))^2 + (Rp^2 * sin(phi))^2) /
                  ((Re * cos(phi))^2 + (Rp * sin(phi))^2))

  return(radius)
}

#-----------------------------------------------------------------------------#
#' Exponential distance decay function
#' @param Distance Distance.
#' @param lambda Decay parameter
#' @return A normalized metric between 0 and 1, where 1 is a distance of 1.
#' @details {Applies an exponential distance decay function to the number
#' of habitats used by a species in order to derive a metric expressing
#' the degree of specialization of that species. The shape of the curve
#' is controlled by the parameter \emph{lambda}. The higher the lambda,
#' the stronger the decay of the degree of specializing with generalism}.
#' @export
#-----------------------------------------------------------------------------#

exponential_decay <- function(d, beta) {
  exp(-beta * (d - 1))
}

#-----------------------------------------------------------------------------#
#' Optimize distance decay
#' @param distances 2-element vector with a range of distances.
#' @param targets 2-element vector with desired values for \emph{distances}.
#' @return Beta coefficient for an exponential distance decay function.
#' @details {Estimates the optimal Beta coefficient in a distance decay
#' functionto derive a normalized metric on the degree of specialization
#' of individualspecies. The optimal Beta is that which enables that
#' specialized species(i.e. with one habitat preference) to receive
#' the highest value in themetric (i.e. 1), and that highly generalized
#' species (here those with 10 ormore ecosystem preferences) have a much
#' lower score (i.e. 0.001). Theoptimal Beta is determined using nonlinear
#' least squares fitting.}.
#' @seealso [exponential_decay()]
#' @export
#-----------------------------------------------------------------------------#

optimize_decay_beta = function(distances=c(1,6), targets=c(1,0.01)) {

  return(-log(targets[2] / targets[1]) / (distances[2]-distances[1]))

}

